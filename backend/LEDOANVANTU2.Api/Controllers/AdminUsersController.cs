using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using LEDOANVANTU2.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LEDOANVANTU2.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public sealed class AdminUsersController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<AdminUserDto>>> GetUsers(CancellationToken ct)
    {
        var users = await db.Users
            .AsNoTracking()
            .OrderBy(x => x.Role)
            .ThenBy(x => x.Username)
            .Select(x => new AdminUserDto(
                x.Id,
                x.FullName,
                x.Email,
                x.Username,
                x.Role,
                x.EmailVerified))
            .ToListAsync(ct);
        return Ok(users);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeleteUser(int id, CancellationToken ct)
    {
        var currentUserIdValue = User.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(currentUserIdValue, out var currentUserId))
            return Unauthorized(new { message = "Token không có mã người dùng hợp lệ." });
        if (id == currentUserId)
            return BadRequest(new { message = "Không thể xóa tài khoản admin đang đăng nhập." });

        var user = await db.Users.FindAsync([id], ct);
        if (user is null) return NotFound(new { message = "Không tìm thấy tài khoản." });

        if (user.Role == "Admin")
        {
            var adminCount = await db.Users.CountAsync(x => x.Role == "Admin", ct);
            if (adminCount <= 1)
                return Conflict(new { message = "Không thể xóa admin cuối cùng của hệ thống." });
        }

        var attendanceRecords = await db.AttendanceRecords
            .Where(x => x.UserId == id)
            .ToListAsync(ct);
        db.AttendanceRecords.RemoveRange(attendanceRecords);
        db.Users.Remove(user);
        await db.SaveChangesAsync(ct);
        return NoContent();
    }
}

public sealed record AdminUserDto(
    int Id,
    string FullName,
    string Email,
    string Username,
    string Role,
    bool EmailVerified);
