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
        employee.Id = 0;
        db.Employees.Add(employee);
        await db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(GetEmployee), new { id = employee.Id }, employee);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateEmployee(int id, Employee input, CancellationToken ct)
    {
        if (id != input.Id) return BadRequest(new { message = "ID trên URL và nội dung không khớp." });
        var employee = await db.Employees.FindAsync([id], ct);
        if (employee is null) return NotFound();
        employee.FullName = input.FullName.Trim();
        employee.Code = input.Code.Trim();
        employee.Role = input.Role.Trim();
        employee.IsPresent = input.IsPresent;
        await db.SaveChangesAsync(ct);
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
}
