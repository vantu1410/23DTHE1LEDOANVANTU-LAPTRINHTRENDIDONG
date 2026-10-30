using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using LEDOANVANTU2.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

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
        var currentUserIdValue = User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? User.FindFirstValue("sub");
        if (!int.TryParse(currentUserIdValue, out var currentUserId))
            return Unauthorized(new { message = "Token không có mã người dùng hợp lệ." });
        if (id == currentUserId)
            return BadRequest(new { message = "Không thể xóa tài khoản admin đang đăng nhập." });

        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var user = await db.Users.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (user is null) return NotFound(new { message = "Không tìm thấy tài khoản." });

        if (user.Role == "Admin")
        {
            var adminCount = await db.Users.CountAsync(x => x.Role == "Admin", ct);
            if (adminCount <= 1)
                return Conflict(new { message = "Không thể xóa admin cuối cùng của hệ thống." });
        }

        await db.AttendanceRecords.Where(x => x.UserId == id).ExecuteDeleteAsync(ct);
        await db.Employees.Where(x => x.UserId == id).ExecuteUpdateAsync(s => s.SetProperty(x => x.UserId, (int?)null), ct);
        db.Users.Remove(user);
        try
        {
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
        }
        catch (DbUpdateException)
        {
            await transaction.RollbackAsync(ct);
            return Conflict(new { message = "Không thể xóa tài khoản vì dữ liệu liên quan vẫn đang được sử dụng." });
        }
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
