using System.Security.Claims;
using System.ComponentModel.DataAnnotations;
using LEDOANVANTU2.Api.Data;
using LEDOANVANTU2.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LEDOANVANTU2.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class EmployeeApiController(AppDbContext db) : ControllerBase
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
        employee.Email = employee.Email.Trim().ToLowerInvariant();
        employee.UserId = null;
        if (await db.Employees.AnyAsync(e => e.Id != employee.Id && e.Email == employee.Email, ct)) return "Email đã thuộc hồ sơ nhân viên khác.";
        var user = await db.Users.SingleOrDefaultAsync(u => u.Email == employee.Email && u.EmailVerified, ct);
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
    public async Task<ActionResult<Employee>> CreateEmployee(Employee employee, CancellationToken ct)
    {
        var validation = Validate(employee);
        if (validation is not null) return BadRequest(new { message = validation });
        employee.FullName = employee.FullName.Trim();
        employee.Code = employee.Code.Trim();
        employee.Role = employee.Role.Trim();
        if (await db.Employees.AnyAsync(x => x.Code == employee.Code, ct))
            return Conflict(new { message = "Mã nhân viên đã tồn tại." });
        employee.Id = 0;
        var linkError = await Link(employee, ct);
        if (linkError != null) return Conflict(new { message = linkError });
        db.Employees.Add(employee);
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateException) { return Conflict(new { message = "Mã nhân viên đã tồn tại." }); }
        return CreatedAtAction(nameof(GetEmployee), new { id = employee.Id }, employee);
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
