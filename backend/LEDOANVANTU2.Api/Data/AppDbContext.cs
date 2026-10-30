using LEDOANVANTU2.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace LEDOANVANTU2.Api.Data;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<FeatureRecord> FeatureRecords => Set<FeatureRecord>();
    public DbSet<Employee> Employees => Set<Employee>();
    public DbSet<AttendanceRecord> AttendanceRecords => Set<AttendanceRecord>();
    public DbSet<ScheduleRequest> ScheduleRequests => Set<ScheduleRequest>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<AppUser>().HasIndex(x => x.Username).IsUnique();
        modelBuilder.Entity<AppUser>().HasIndex(x => x.Email).IsUnique();
        modelBuilder.Entity<Employee>().HasIndex(x => x.Code).IsUnique();
        modelBuilder.Entity<AttendanceRecord>().HasIndex(x => new { x.UserId, x.RecordedAtUtc });
        modelBuilder.Entity<ScheduleRequest>().HasIndex(x => new { x.UserId, x.WorkDate });
    }
}
