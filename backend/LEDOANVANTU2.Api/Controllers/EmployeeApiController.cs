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
    public async Task<ActionResult<IEnumerable<Employee>>> GetEmployees(CancellationToken ct) =>
        Ok(await db.Employees.AsNoTracking().OrderBy(x => x.Code).ToListAsync(ct));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<Employee>> GetEmployee(int id, CancellationToken ct)
    {
        var employee = await db.Employees.FindAsync([id], ct);
        return employee is null ? NotFound() : Ok(employee);
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
        employee.IsPresent = input.IsPresent;
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateException) { return Conflict(new { message = "Mã nhân viên đã thuộc về hồ sơ khác." }); }
        return NoContent();
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
        if (string.IsNullOrWhiteSpace(employee.FullName)) return "Vui lòng nhập họ tên nhân viên.";
        if (string.IsNullOrWhiteSpace(employee.Code)) return "Vui lòng nhập mã nhân viên.";
        if (string.IsNullOrWhiteSpace(employee.Role)) return "Vui lòng nhập phòng ban hoặc chức vụ.";
        if (employee.FullName.Trim().Length > 120 || employee.Code.Trim().Length > 32 || employee.Role.Trim().Length > 80)
            return "Họ tên, mã nhân viên hoặc chức vụ vượt quá độ dài cho phép.";
        return null;
    }
}
