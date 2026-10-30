using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using LEDOANVANTU2.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LEDOANVANTU2.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class ProfileController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id)) return Unauthorized();
        var user = await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct);
        return user is null ? Unauthorized() : Ok(new { user.Id, user.FullName, user.Username, user.Email, user.Role });
    }

    [HttpPut]
    public async Task<IActionResult> Update(UpdateProfileRequest request, CancellationToken ct)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id)) return Unauthorized();
        var user = await db.Users.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (user is null) return Unauthorized();
        var name = request.FullName.Trim();
        if (name.Length < 2 || name.Length > 120) return BadRequest(new { message = "Họ tên cần từ 2 đến 120 ký tự." });
        user.FullName = name;
        var employees = await db.Employees.Where(e => e.UserId == id).ToListAsync(ct);
        foreach (var employee in employees) employee.FullName = name;
        await db.SaveChangesAsync(ct);
        return Ok(new { user.Id, user.FullName, user.Username, user.Email, user.Role });
    }
}
public sealed record UpdateProfileRequest([Required, StringLength(120, MinimumLength = 2)] string FullName);
