using System.Text;
using LEDOANVANTU2.Api.Data;
using LEDOANVANTU2.Api.Models;
using LEDOANVANTU2.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);
var provider = builder.Configuration["Database:Provider"] ?? "SqlServer";
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
if (string.IsNullOrWhiteSpace(connectionString))
    connectionString = builder.Configuration["DATABASE_URL"];
if (string.IsNullOrWhiteSpace(connectionString))
    throw new InvalidOperationException("Cấu hình ConnectionStrings:DefaultConnection hoặc DATABASE_URL trước khi chạy API.");

var jwtKey = builder.Configuration["Jwt:Key"];
if (string.IsNullOrWhiteSpace(jwtKey) || Encoding.UTF8.GetByteCount(jwtKey) < 32)
    throw new InvalidOperationException("Cấu hình Jwt:Key tối thiểu 32 byte bằng user-secrets hoặc biến môi trường.");

builder.Services.AddDbContext<AppDbContext>(options =>
{
    if (provider.Equals("Postgres", StringComparison.OrdinalIgnoreCase))
        options.UseNpgsql(ParsePostgresUrl(connectionString));
    else
        options.UseSqlServer(connectionString);
});
builder.Services.AddScoped<IPasswordHasher<AppUser>, PasswordHasher<AppUser>>();
builder.Services.AddSingleton<OtpEmailSender>();
builder.Services.AddHttpClient();
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddCors(options => options.AddPolicy("MobileApp", policy =>
    policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidIssuer = builder.Configuration["Jwt:Issuer"],
        ValidateAudience = true,
        ValidAudience = builder.Configuration["Jwt:Audience"],
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
        ValidateLifetime = true,
        ClockSkew = TimeSpan.FromSeconds(30)
    };
});
builder.Services.AddAuthorization();

var app = builder.Build();
await using (var scope = app.Services.CreateAsyncScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    var isPostgres = provider.Equals("Postgres", StringComparison.OrdinalIgnoreCase);
    if (isPostgres)
        await db.Database.EnsureCreatedAsync();
    else
        await db.Database.MigrateAsync();
    await EnsureAttendanceLocationColumnsAsync(db, isPostgres);
    await EnsureEmployeeLinksAsync(db, isPostgres);
    await EnsureScheduleRequestsAsync(db, isPostgres);
    await BootstrapAdminAsync(scope.ServiceProvider, builder.Configuration);
}
app.UseSwagger();
app.UseSwaggerUI();
app.UseCors("MobileApp");
app.UseAuthentication();
app.UseAuthorization();
app.MapGet("/", () => Results.Redirect("/swagger/index.html"));
app.MapGet("/health", () => Results.Ok(new { status = "ok", app = "LEDOANVANTU2.Api", revision = Environment.GetEnvironmentVariable("RENDER_GIT_COMMIT") }));
app.MapControllers();
app.Run();

static string ParsePostgresUrl(string value)
{
    if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) || (uri.Scheme != "postgres" && uri.Scheme != "postgresql"))
        return value;
    var userInfo = uri.UserInfo.Split(':', 2);
    var builder = new Npgsql.NpgsqlConnectionStringBuilder
    {
        Host = uri.Host,
        Port = uri.Port > 0 ? uri.Port : 5432,
        Database = Uri.UnescapeDataString(uri.AbsolutePath.TrimStart('/')),
        Username = Uri.UnescapeDataString(userInfo[0]),
        Password = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : string.Empty,
        SslMode = Npgsql.SslMode.Require
    };
    return builder.ConnectionString;
}

static async Task EnsureAttendanceLocationColumnsAsync(AppDbContext db, bool isPostgres)
{
    if (isPostgres)
    {
        await db.Database.ExecuteSqlRawAsync("""
            ALTER TABLE "AttendanceRecords"
            ADD COLUMN IF NOT EXISTS "Latitude" double precision NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS "Longitude" double precision NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS "AccuracyMeters" double precision NULL;
            ALTER TABLE "AttendanceRecords"
            ADD COLUMN IF NOT EXISTS "OvertimeMinutes" integer NULL;
            """);
        return;
    }

    await db.Database.ExecuteSqlRawAsync("""
        IF COL_LENGTH(N'dbo.AttendanceRecords', N'Latitude') IS NULL
            ALTER TABLE [dbo].[AttendanceRecords] ADD [Latitude] float NOT NULL CONSTRAINT [DF_AttendanceRecords_Latitude] DEFAULT (0);
        IF COL_LENGTH(N'dbo.AttendanceRecords', N'Longitude') IS NULL
            ALTER TABLE [dbo].[AttendanceRecords] ADD [Longitude] float NOT NULL CONSTRAINT [DF_AttendanceRecords_Longitude] DEFAULT (0);
        IF COL_LENGTH(N'dbo.AttendanceRecords', N'AccuracyMeters') IS NULL
            ALTER TABLE [dbo].[AttendanceRecords] ADD [AccuracyMeters] float NULL;
        IF COL_LENGTH(N'dbo.AttendanceRecords', N'OvertimeMinutes') IS NULL
            ALTER TABLE [dbo].[AttendanceRecords] ADD [OvertimeMinutes] int NULL;
        """);
}

static async Task BootstrapAdminAsync(IServiceProvider services, IConfiguration configuration)
{
    var username = configuration["BootstrapAdmin:Username"];
    var password = configuration["BootstrapAdmin:Password"];
    var email = configuration["BootstrapAdmin:Email"];
    var fullName = configuration["BootstrapAdmin:FullName"];
    if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password) ||
        string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(fullName)) return;

    var db = services.GetRequiredService<AppDbContext>();
    if (await db.Users.AnyAsync(x => x.Username == username)) return;
    var user = new AppUser
    {
        Username = username.Trim(),
        Email = email.Trim().ToLowerInvariant(),
        FullName = fullName.Trim(),
        PasswordHash = "pending",
        Role = "Admin",
        EmailVerified = true
    };
    user.PasswordHash = services.GetRequiredService<IPasswordHasher<AppUser>>()
        .HashPassword(user, password);
    db.Users.Add(user);
    await db.SaveChangesAsync();
}

static async Task EnsureEmployeeLinksAsync(AppDbContext db, bool postgres)
{
    if (postgres)
        await db.Database.ExecuteSqlRawAsync("""
            ALTER TABLE "Employees" ADD COLUMN IF NOT EXISTS "Email" text NOT NULL DEFAULT '';
            ALTER TABLE "Employees" ADD COLUMN IF NOT EXISTS "UserId" integer NULL;
            CREATE UNIQUE INDEX IF NOT EXISTS "IX_Employee_UserLink" ON "Employees" ("UserId") WHERE "UserId" IS NOT NULL;
            CREATE UNIQUE INDEX IF NOT EXISTS "IX_Employee_EmailLink" ON "Employees" ("Email") WHERE "Email" <> '';
            """);
    else
        await db.Database.ExecuteSqlRawAsync("""
            IF COL_LENGTH('dbo.Employees', 'Email') IS NULL ALTER TABLE dbo.Employees ADD Email nvarchar(254) NOT NULL DEFAULT '';
            IF COL_LENGTH('dbo.Employees', 'UserId') IS NULL ALTER TABLE dbo.Employees ADD UserId int NULL;
            """);
    if (!postgres) await db.Database.ExecuteSqlRawAsync("""
            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Employee_UserLink') CREATE UNIQUE INDEX IX_Employee_UserLink ON dbo.Employees(UserId) WHERE UserId IS NOT NULL;
            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Employee_EmailLink') CREATE UNIQUE INDEX IX_Employee_EmailLink ON dbo.Employees(Email) WHERE Email <> '';
            """);
}


static async Task EnsureScheduleRequestsAsync(AppDbContext db, bool postgres)
{
    if (postgres)
        await db.Database.ExecuteSqlRawAsync("""
            CREATE TABLE IF NOT EXISTS "ScheduleRequests" (
                "Id" integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                "UserId" integer NOT NULL, "Type" varchar(16) NOT NULL,
                "WorkDate" date NOT NULL, "TimeMinutes" integer NOT NULL,
                "Reason" varchar(500) NOT NULL, "Status" varchar(16) NOT NULL DEFAULT 'pending',
                "CreatedAtUtc" timestamp with time zone NOT NULL,
                "ReviewedByUserId" integer NULL, "ReviewedAtUtc" timestamp with time zone NULL,
                "ReviewNote" varchar(500) NOT NULL DEFAULT ''
            );
            CREATE UNIQUE INDEX IF NOT EXISTS "IX_Schedule_Active" ON "ScheduleRequests" ("UserId", "WorkDate", "Type") WHERE "Status" <> 'rejected';
            """);
    else
        await db.Database.ExecuteSqlRawAsync("""
            IF OBJECT_ID(N'dbo.ScheduleRequests', N'U') IS NULL
            BEGIN
                CREATE TABLE dbo.ScheduleRequests (
                    Id int IDENTITY PRIMARY KEY, UserId int NOT NULL, Type nvarchar(16) NOT NULL,
                    WorkDate date NOT NULL, TimeMinutes int NOT NULL, Reason nvarchar(500) NOT NULL,
                    Status nvarchar(16) NOT NULL DEFAULT 'pending', CreatedAtUtc datetimeoffset NOT NULL,
                    ReviewedByUserId int NULL, ReviewedAtUtc datetimeoffset NULL,
                    ReviewNote nvarchar(500) NOT NULL DEFAULT ''
                );
                CREATE UNIQUE INDEX IX_Schedule_Active ON dbo.ScheduleRequests(UserId, WorkDate, Type) WHERE Status <> 'rejected';
            END
            """);
}
