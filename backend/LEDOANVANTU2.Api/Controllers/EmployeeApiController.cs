using System.Security.Claims;
using System.ComponentModel.DataAnnotations;
using LEDOANVANTU2.Api.Data;
using LEDOANVANTU2.Api.Models;
using LEDOANVANTU2.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LEDOANVANTU2.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class EmployeeApiController(AppDbContext db, IPasswordHasher<AppUser> passwordHasher) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Employee>>> GetEmployees(CancellationToken ct)
    {
        var all = await db.Employees.ToListAsync(ct);
        var users = await db.Users.Where(u => u.EmailVerified).ToListAsync(ct);
        foreach (var e in all.Where(e => e.UserId == null && e.Email != ""))
        {
            var matches = users.Where(u => u.Email.Trim().Equals(e.Email.Trim(), StringComparison.OrdinalIgnoreCase) && Normalize(u.FullName) == Normalize(e.FullName)).ToList();
            if (matches.Count == 1 && !all.Any(other => other.UserId == matches[0].Id)) e.UserId = matches[0].Id;
        }
        await db.SaveChangesAsync(ct);
        var local = TimeZoneInfo.ConvertTimeBySystemTimeZoneId(DateTimeOffset.UtcNow, "Asia/Ho_Chi_Minh");
        var start = new DateTimeOffset(local.Date, local.Offset).ToUniversalTime();
        var end = start.AddDays(1);
        var present = await db.AttendanceRecords.AsNoTracking().Where(r => r.Type == "checkIn" && r.RecordedAtUtc >= start && r.RecordedAtUtc < end).Select(r => r.UserId).Distinct().ToListAsync(ct);
        foreach (var e in all) e.IsPresent = e.UserId.HasValue && present.Contains(e.UserId.Value);
        var id = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Ok(all.Where(e => User.IsInRole("Admin") || e.UserId?.ToString() == id).OrderBy(e => e.Code));
    }

    private static string Normalize(string value) => string.Join(" ", value.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries)).ToLowerInvariant();

    private async Task<string?> Link(Employee employee, CancellationToken ct)
    {
        var previousUserId = employee.UserId;
        employee.Email = employee.Email.Trim().ToLowerInvariant();
        if (previousUserId.HasValue && await db.Users.AnyAsync(u => u.Id == previousUserId && !u.EmailVerified && u.Email != employee.Email, ct))
            return "Tài khoản chưa xác nhận email lần đầu. Hãy giữ nguyên email đã tạo và hoàn tất đăng nhập bằng OTP trước khi đổi liên kết.";
        employee.UserId = null;
        if (await db.Employees.AnyAsync(e => e.Id != employee.Id && e.Email == employee.Email, ct)) return "Email đã thuộc hồ sơ nhân viên khác.";
        var user = await db.Users.SingleOrDefaultAsync(u => u.Email == employee.Email && (u.EmailVerified || u.Id == previousUserId), ct);
        if (user == null) return null;
        if (Normalize(user.FullName) != Normalize(employee.FullName)) return "Họ tên chưa khớp tài khoản có email này.";
        employee.UserId = user.Id;
        return null;
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<Employee>> GetEmployee(int id, CancellationToken ct)
    {
        var employee = await db.Employees.FindAsync([id], ct);
        if (employee is null) return NotFound();
        if (!User.IsInRole("Admin") && employee.UserId?.ToString() != User.FindFirstValue(ClaimTypes.NameIdentifier)) return Forbid();
        return Ok(employee);
    }

    [HttpPost]
    [Authorize(Roles = "Admin")]
    public async Task<ActionResult<Employee>> CreateEmployee(CreateEmployeeRequest request, CancellationToken ct)
    {
        var employee = new Employee
        {
            Email = request.Email,
            FullName = request.FullName,
            Code = request.Code,
            Role = request.Role
        };
        var validation = Validate(employee);
        if (validation is not null) return BadRequest(new { message = validation });
        employee.FullName = employee.FullName.Trim();
        employee.Code = employee.Code.Trim();
        employee.Role = employee.Role.Trim();
        if (await db.Employees.AnyAsync(x => x.Code == employee.Code, ct))
            return Conflict(new { message = "Mã nhân viên đã tồn tại." });
        employee.Email = employee.Email.Trim().ToLowerInvariant();
        if (await db.Employees.AnyAsync(e => e.Email == employee.Email, ct))
            return Conflict(new { message = "Email đã có hồ sơ nhân viên. Hãy tải lại danh sách và sửa hồ sơ có sẵn." });

        var user = await db.Users.SingleOrDefaultAsync(u => u.Email == employee.Email, ct);
        if (user is not null && EmployeeRegistration.NormalizeName(user.FullName) != EmployeeRegistration.NormalizeName(employee.FullName))
            return Conflict(new { message = "Họ tên chưa khớp tài khoản có email này." });
        if (user is not null && await db.Employees.AnyAsync(e => e.UserId == user.Id, ct))
            return Conflict(new { message = "Tài khoản đã liên kết với hồ sơ nhân viên khác." });

        var accountCreated = user is null || !user.EmailVerified;
        if (accountCreated)
        {
            if (string.IsNullOrEmpty(request.InitialPassword) || request.InitialPassword.Length is < 8 or > 128)
                return BadRequest(new { message = "Email chưa có tài khoản đã xác nhận. Nhập mật khẩu ban đầu từ 8 đến 128 ký tự để nhân viên có thể đăng nhập ngay." });

            var username = user?.Username ?? (string.IsNullOrWhiteSpace(request.Username) ? employee.Code : request.Username.Trim());
            if (username.Length is < 3 or > 40)
                return BadRequest(new { message = "Tên đăng nhập phải có từ 3 đến 40 ký tự." });
            if (user is null && await db.Users.AnyAsync(u => u.Username == username, ct))
                return Conflict(new { message = "Tên đăng nhập đã được sử dụng. Vui lòng chọn tên khác." });

            user ??= new AppUser
            {
                Username = username,
                Email = employee.Email,
                FullName = employee.FullName,
                PasswordHash = "pending",
                Role = "Employee"
            };
            user.PasswordHash = passwordHasher.HashPassword(user, request.InitialPassword);
            user.OtpHash = null;
            user.OtpPurpose = null;
            user.OtpExpiresAtUtc = null;
        }

        try
        {
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            if (user!.Id == 0)
            {
                db.Users.Add(user);
                await db.SaveChangesAsync(ct);
            }
            employee.UserId = user.Id;
            db.Employees.Add(employee);
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
        }
        catch (DbUpdateException)
        {
            return Conflict(new { message = "Mã nhân viên, email hoặc tên đăng nhập vừa được sử dụng. Hãy tải lại danh sách và kiểm tra trước khi thêm lại." });
        }

        return CreatedAtAction(nameof(GetEmployee), new { id = employee.Id }, new
        {
            employee.Id, employee.Email, employee.UserId, employee.FullName, employee.Code,
            employee.Role, employee.IsPresent, loginUsername = user!.Username, accountCreated
        });
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateEmployee(int id, Employee input, CancellationToken ct)
    {
        if (id != input.Id) return BadRequest(new { message = "ID trên URL và nội dung không khớp." });
        var validation = Validate(input);
        if (validation is not null) return BadRequest(new { message = validation });
        var employee = await db.Employees.FindAsync([id], ct);
        if (employee is null) return NotFound();
        var code = input.Code.Trim();
        if (await db.Employees.AnyAsync(x => x.Id != id && x.Code == code, ct))
            return Conflict(new { message = "Mã nhân viên đã thuộc về hồ sơ khác." });
        employee.FullName = input.FullName.Trim();
        employee.Code = code;
        employee.Role = input.Role.Trim();
        employee.Email = input.Email;
        var linkError = await Link(employee, ct);
        if (linkError != null) return Conflict(new { message = linkError });
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateException) { return Conflict(new { message = "Mã nhân viên đã thuộc về hồ sơ khác." }); }
        return Ok(employee);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteEmployee(int id, CancellationToken ct)
    {
        var employee = await db.Employees.FindAsync([id], ct);
        if (employee is null) return NotFound();
        db.Employees.Remove(employee);
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    private static string? Validate(Employee employee)
    {
        if (string.IsNullOrWhiteSpace(employee.Email) || employee.Email.Length > 254 || !new EmailAddressAttribute().IsValid(employee.Email)) return "Vui lòng nhập email hợp lệ để liên kết tài khoản.";
        if (string.IsNullOrWhiteSpace(employee.FullName)) return "Vui lòng nhập họ tên nhân viên.";
        if (string.IsNullOrWhiteSpace(employee.Code)) return "Vui lòng nhập mã nhân viên.";
        if (string.IsNullOrWhiteSpace(employee.Role)) return "Vui lòng nhập phòng ban hoặc chức vụ.";
        if (employee.FullName.Trim().Length > 120 || employee.Code.Trim().Length > 32 || employee.Role.Trim().Length > 80)
            return "Họ tên, mã nhân viên hoặc chức vụ vượt quá độ dài cho phép.";
        return null;
    }
}

public sealed record CreateEmployeeRequest(
    string Email, string FullName, string Code, string Role,
    string? Username = null, string? InitialPassword = null);
