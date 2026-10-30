using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using LEDOANVANTU2.Api.Controllers;
using LEDOANVANTU2.Api.Data;
using LEDOANVANTU2.Api.Models;
using LEDOANVANTU2.Api.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace LEDOANVANTU2.Api.Tests;

public sealed class EmployeeRegistrationTests : IAsyncLifetime
{
    private const string CorrectOtp = "123456";
    private const string InitialPassword = "Employee123!";
    private readonly SqliteConnection connection = new("Data Source=:memory:");
    private readonly PasswordHasher<AppUser> hasher = new();
    private AppDbContext db = null!;

    public async Task InitializeAsync()
    {
        await connection.OpenAsync();
        db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(connection).Options);
        await db.Database.EnsureCreatedAsync();
        // Production adds these filtered unique indexes in Program.cs.
        // SQLite exercises real relational constraints rather than EF InMemory behavior.
        await db.Database.ExecuteSqlRawAsync("""
            CREATE UNIQUE INDEX "IX_Employee_UserLink" ON "Employees" ("UserId") WHERE "UserId" IS NOT NULL;
            CREATE UNIQUE INDEX "IX_Employee_EmailLink" ON "Employees" ("Email") WHERE "Email" <> '';
            """);
    }

    public async Task DisposeAsync()
    {
        await db.DisposeAsync();
        await connection.DisposeAsync();
    }

    [Fact]
    public async Task Register_does_not_create_an_employee_before_email_is_confirmed()
    {
        var result = await Auth().Register(new RegisterRequest(
            "Lê Đoàn Văn Tú", "employee@example.test", "employee", InitialPassword), default);

        Assert.IsType<OkObjectResult>(result);
        Assert.False((await db.Users.SingleAsync()).EmailVerified);
        Assert.Empty(await db.Employees.ToListAsync());
    }

    [Fact]
    public async Task Valid_registration_otp_creates_one_linked_employee_and_cannot_be_reused()
    {
        var user = await UserWithOtp();
        var result = await Auth().VerifyOtp(new VerifyOtpRequest(user.Username, CorrectOtp), default);

        Assert.IsType<OkObjectResult>(result);
        db.ChangeTracker.Clear();
        var savedUser = await db.Users.SingleAsync();
        var employee = await db.Employees.SingleAsync();
        Assert.True(savedUser.EmailVerified);
        Assert.Null(savedUser.OtpHash);
        Assert.Equal(savedUser.Id, employee.UserId);
        Assert.Equal(savedUser.FullName, employee.FullName);
        Assert.Equal(savedUser.Email, employee.Email);
        Assert.False(string.IsNullOrWhiteSpace(employee.Code));
        Assert.Equal("Nhân viên", employee.Role);

        var replay = await Auth().VerifyOtp(new VerifyOtpRequest(user.Username, CorrectOtp), default);
        Assert.IsType<UnauthorizedObjectResult>(replay);
        Assert.Equal(1, await db.Employees.CountAsync());
    }

    [Theory]
    [InlineData("654321", false)]
    [InlineData(CorrectOtp, true)]
    public async Task Invalid_or_expired_otp_creates_no_employee(string suppliedOtp, bool expired)
    {
        var user = await UserWithOtp(expired: expired);

        var result = await Auth().VerifyOtp(new VerifyOtpRequest(user.Username, suppliedOtp), default);

        Assert.IsType<UnauthorizedObjectResult>(result);
        db.ChangeTracker.Clear();
        Assert.False((await db.Users.SingleAsync()).EmailVerified);
        Assert.Empty(await db.Employees.ToListAsync());
    }

    [Fact]
    public async Task Registration_reuses_matching_manual_profile_and_preserves_its_details()
    {
        var user = await UserWithOtp();
        var manual = new Employee
        {
            FullName = "  lê   đoàn văn tú  ", Email = user.Email,
            Code = "NV-MANUAL", Role = "Kỹ thuật"
        };
        db.Employees.Add(manual);
        await db.SaveChangesAsync();
        var originalId = manual.Id;

        var result = await Auth().VerifyOtp(new VerifyOtpRequest(user.Username, CorrectOtp), default);

        Assert.IsType<OkObjectResult>(result);
        db.ChangeTracker.Clear();
        var employee = await db.Employees.SingleAsync();
        Assert.Equal(originalId, employee.Id);
        Assert.Equal(user.Id, employee.UserId);
        Assert.Equal("NV-MANUAL", employee.Code);
        Assert.Equal("Kỹ thuật", employee.Role);
    }

    [Fact]
    public async Task Generated_employee_code_avoids_an_existing_manual_code()
    {
        var user = await UserWithOtp();
        var reservedCode = $"NV-{user.Id:D3}";
        db.Employees.Add(new Employee
        {
            FullName = "Another employee", Email = "another@example.test", Code = reservedCode
        });
        await db.SaveChangesAsync();

        var result = await Auth().VerifyOtp(new VerifyOtpRequest(user.Username, CorrectOtp), default);

        Assert.IsType<OkObjectResult>(result);
        var linked = await db.Employees.SingleAsync(e => e.UserId == user.Id);
        Assert.NotEqual(reservedCode, linked.Code);
        Assert.Equal(2, await db.Employees.CountAsync());
    }

    [Fact]
    public async Task Conflicting_manual_name_does_not_verify_user_or_consume_otp()
    {
        var user = await UserWithOtp();
        var originalOtpHash = user.OtpHash;
        db.Employees.Add(new Employee
        {
            FullName = "Different person", Email = user.Email, Code = "NV-CONFLICT"
        });
        await db.SaveChangesAsync();

        var result = await Auth().VerifyOtp(new VerifyOtpRequest(user.Username, CorrectOtp), default);

        Assert.IsType<ConflictObjectResult>(result);
        db.ChangeTracker.Clear();
        var savedUser = await db.Users.SingleAsync();
        Assert.False(savedUser.EmailVerified);
        Assert.Equal(originalOtpHash, savedUser.OtpHash);
        Assert.Equal("register", savedUser.OtpPurpose);
        Assert.Null((await db.Employees.SingleAsync()).UserId);
    }

    [Fact]
    public async Task Admin_registration_verification_does_not_create_employee_profile()
    {
        var user = await UserWithOtp(role: "Admin");

        var result = await Auth().VerifyOtp(new VerifyOtpRequest(user.Username, CorrectOtp), default);

        Assert.IsType<OkObjectResult>(result);
        Assert.Empty(await db.Employees.ToListAsync());
    }

    [Fact]
    public async Task Login_otp_keeps_existing_linked_profile_without_creating_another()
    {
        var user = await UserWithOtp(purpose: "login", verified: true);
        db.Employees.Add(new Employee
        {
            UserId = user.Id, FullName = user.FullName, Email = user.Email,
            Code = "NV-EXISTING", Role = "Kế toán"
        });
        await db.SaveChangesAsync();

        var result = await Auth().VerifyOtp(new VerifyOtpRequest(user.Username, CorrectOtp), default);

        Assert.IsType<OkObjectResult>(result);
        Assert.Equal("NV-EXISTING", (await db.Employees.SingleAsync()).Code);
    }

    [Fact]
    public async Task Manual_add_creates_hashed_login_credentials_with_employee_code_as_username()
    {
        var result = await Employees().CreateEmployee(new CreateEmployeeRequest(
            "manual@example.test", "Nguyễn Văn An", "NV-100", "Kỹ thuật",
            InitialPassword: InitialPassword), default);

        Assert.IsType<CreatedAtActionResult>(Unwrap(result));
        var account = await db.Users.SingleAsync();
        var employee = await db.Employees.SingleAsync();
        Assert.Equal("NV-100", account.Username);
        Assert.Equal("Employee", account.Role);
        Assert.False(account.EmailVerified);
        Assert.Equal(account.Id, employee.UserId);
        Assert.NotEqual(InitialPassword, account.PasswordHash);
        Assert.NotEqual(PasswordVerificationResult.Failed,
            hasher.VerifyHashedPassword(account, account.PasswordHash, InitialPassword));
    }

    [Fact]
    public async Task Editing_a_manually_created_unverified_profile_keeps_its_login_link()
    {
        var created = await Employees().CreateEmployee(new CreateEmployeeRequest(
            "manual@example.test", "Nguyễn Văn An", "NV-104", "Kỹ thuật",
            InitialPassword: InitialPassword), default);
        Assert.IsType<CreatedAtActionResult>(Unwrap(created));
        db.ChangeTracker.Clear();
        var account = await db.Users.SingleAsync();
        var profile = await db.Employees.SingleAsync();

        var updated = await Employees().UpdateEmployee(profile.Id, new Employee
        {
            Id = profile.Id, FullName = profile.FullName, Email = profile.Email,
            Code = "NV-UPDATED", Role = "Nhân sự"
        }, default);

        Assert.IsType<OkObjectResult>(updated);
        db.ChangeTracker.Clear();
        var savedProfile = await db.Employees.SingleAsync();
        Assert.Equal(account.Id, savedProfile.UserId);
        Assert.Equal("NV-UPDATED", savedProfile.Code);
        Assert.Equal("Nhân sự", savedProfile.Role);
        Assert.False((await db.Users.SingleAsync()).EmailVerified);

        var login = Assert.IsType<OkObjectResult>(await Auth().Login(
            new LoginRequest(account.Username, InitialPassword), default));
        var otp = JsonSerializer.SerializeToElement(login.Value).GetProperty("debugOtp").GetString();
        Assert.False(string.IsNullOrWhiteSpace(otp));
        Assert.IsType<OkObjectResult>(await Auth().VerifyOtp(
            new VerifyOtpRequest(account.Username, otp!), default));
        Assert.Equal(1, await db.Employees.CountAsync());
    }

    [Fact]
    public async Task Changing_email_before_manual_account_activation_is_rejected_without_breaking_login()
    {
        var created = await Employees().CreateEmployee(new CreateEmployeeRequest(
            "manual@example.test", "Nguyễn Văn An", "NV-105", "Kỹ thuật",
            InitialPassword: InitialPassword), default);
        Assert.IsType<CreatedAtActionResult>(Unwrap(created));
        db.ChangeTracker.Clear();
        var account = await db.Users.SingleAsync();
        var profile = await db.Employees.SingleAsync();

        var result = await Employees().UpdateEmployee(profile.Id, new Employee
        {
            Id = profile.Id, FullName = profile.FullName, Email = "different@example.test",
            Code = profile.Code, Role = profile.Role
        }, default);

        Assert.IsType<ConflictObjectResult>(result);
        db.ChangeTracker.Clear();
        var savedProfile = await db.Employees.SingleAsync();
        var savedAccount = await db.Users.SingleAsync();
        Assert.Equal("manual@example.test", savedProfile.Email);
        Assert.Equal(savedAccount.Id, savedProfile.UserId);
        Assert.Equal("manual@example.test", savedAccount.Email);
        Assert.False(savedAccount.EmailVerified);
        Assert.IsType<OkObjectResult>(await Auth().Login(
            new LoginRequest(account.Username, InitialPassword), default));
    }

    [Fact]
    public async Task Manually_created_account_can_login_and_activate_by_otp_without_registering()
    {
        var created = await Employees().CreateEmployee(new CreateEmployeeRequest(
            "manual@example.test", "Nguyễn Văn An", "NV-101", "Kỹ thuật",
            InitialPassword: InitialPassword), default);
        Assert.IsType<CreatedAtActionResult>(Unwrap(created));

        var login = Assert.IsType<OkObjectResult>(await Auth().Login(
            new LoginRequest("NV-101", InitialPassword), default));
        var otp = JsonSerializer.SerializeToElement(login.Value).GetProperty("debugOtp").GetString();
        Assert.False(string.IsNullOrWhiteSpace(otp));
        Assert.Equal("activate", (await db.Users.SingleAsync()).OtpPurpose);

        var verified = await Auth().VerifyOtp(new VerifyOtpRequest("NV-101", otp!), default);

        Assert.IsType<OkObjectResult>(verified);
        db.ChangeTracker.Clear();
        Assert.True((await db.Users.SingleAsync()).EmailVerified);
        Assert.Equal(1, await db.Users.CountAsync());
        Assert.Equal(1, await db.Employees.CountAsync());
    }

    [Fact]
    public async Task Manual_add_reuses_verified_account_without_resetting_its_password()
    {
        var existing = await UserWithOtp(verified: true, purpose: "login");
        var oldPasswordHash = existing.PasswordHash;
        var oldUsername = existing.Username;

        var result = await Employees().CreateEmployee(new CreateEmployeeRequest(
            existing.Email, existing.FullName, "NV-102", "Nhân viên",
            InitialPassword: "ShouldNeverReplace123!"), default);

        Assert.IsType<CreatedAtActionResult>(Unwrap(result));
        db.ChangeTracker.Clear();
        var savedUser = await db.Users.SingleAsync();
        Assert.Equal(oldPasswordHash, savedUser.PasswordHash);
        Assert.Equal(oldUsername, savedUser.Username);
        Assert.True(savedUser.EmailVerified);
        Assert.Equal(existing.Id, (await db.Employees.SingleAsync()).UserId);
    }

    [Fact]
    public async Task Registration_retry_cannot_overwrite_a_pending_admin_provisioned_account()
    {
        var created = await Employees().CreateEmployee(new CreateEmployeeRequest(
            "manual@example.test", "Nguyễn Văn An", "NV-106", "Kỹ thuật",
            InitialPassword: InitialPassword), default);
        Assert.IsType<CreatedAtActionResult>(Unwrap(created));
        db.ChangeTracker.Clear();
        var account = await db.Users.SingleAsync();
        var originalHash = account.PasswordHash;

        var result = await Auth().Register(new RegisterRequest(
            account.FullName, account.Email, account.Username, "DifferentPassword123!"), default);

        Assert.IsType<ConflictObjectResult>(result);
        db.ChangeTracker.Clear();
        var savedAccount = await db.Users.SingleAsync();
        Assert.Equal(originalHash, savedAccount.PasswordHash);
        Assert.NotEqual(PasswordVerificationResult.Failed,
            hasher.VerifyHashedPassword(savedAccount, savedAccount.PasswordHash, InitialPassword));
        Assert.Equal(PasswordVerificationResult.Failed,
            hasher.VerifyHashedPassword(savedAccount, savedAccount.PasswordHash, "DifferentPassword123!"));
        Assert.False(savedAccount.EmailVerified);
        Assert.Null(savedAccount.OtpHash);
        Assert.Equal(savedAccount.Id, (await db.Employees.SingleAsync()).UserId);
    }

    [Fact]
    public async Task Manual_add_without_initial_password_does_not_create_partial_account_or_profile()
    {
        var result = await Employees().CreateEmployee(new CreateEmployeeRequest(
            "manual@example.test", "Nguyễn Văn An", "NV-103", "Nhân viên"), default);

        Assert.IsType<BadRequestObjectResult>(Unwrap(result));
        Assert.Empty(await db.Users.ToListAsync());
        Assert.Empty(await db.Employees.ToListAsync());
    }

    private async Task<AppUser> UserWithOtp(
        string purpose = "register", bool verified = false, bool expired = false, string role = "Employee")
    {
        var user = new AppUser
        {
            FullName = "Lê Đoàn Văn Tú", Email = "employee@example.test", Username = "employee",
            PasswordHash = "pending", Role = role, EmailVerified = verified,
            OtpPurpose = purpose,
            OtpHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes($"employee:{CorrectOtp}"))),
            OtpExpiresAtUtc = DateTimeOffset.UtcNow.AddMinutes(expired ? -1 : 5)
        };
        user.PasswordHash = hasher.HashPassword(user, InitialPassword);
        db.Users.Add(user);
        await db.SaveChangesAsync();
        return user;
    }

    private AuthController Auth()
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Jwt:Key"] = new string('k', 64), ["Jwt:Issuer"] = "test", ["Jwt:Audience"] = "test"
        }).Build();
        var environment = new DevelopmentEnvironment();
        var sender = new OtpEmailSender(configuration, environment,
            NullLogger<OtpEmailSender>.Instance, new NoNetworkClientFactory());
        return new AuthController(db, hasher, sender, configuration, environment);
    }

    private EmployeeApiController Employees() => new(db, hasher);

    private static IActionResult Unwrap(object result) => result switch
    {
        IActionResult direct => direct,
        ActionResult<Employee> wrapped => wrapped.Result ?? new OkObjectResult(wrapped.Value),
        _ => throw new InvalidOperationException("Unexpected controller response type")
    };

    private sealed class NoNetworkClientFactory : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => throw new InvalidOperationException("Tests must not send network email.");
    }

    private sealed class DevelopmentEnvironment : IWebHostEnvironment
    {
        public string ApplicationName { get; set; } = "LEDOANVANTU2.Api.Tests";
        public string EnvironmentName { get; set; } = "Development";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
        public string WebRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider WebRootFileProvider { get; set; } = new NullFileProvider();
    }
}
