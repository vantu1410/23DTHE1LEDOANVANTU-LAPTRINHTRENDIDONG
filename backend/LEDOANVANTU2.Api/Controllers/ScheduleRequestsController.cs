using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using LEDOANVANTU2.Api.Data;
using LEDOANVANTU2.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LEDOANVANTU2.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class ScheduleRequestsController(AppDbContext db) : ControllerBase
{
    private int CurrentId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var id = CurrentId;
        var admin = User.IsInRole("Admin");
        return Ok(await Project(db.ScheduleRequests.AsNoTracking().Where(r => admin || r.UserId == id)
            .OrderByDescending(r => r.CreatedAtUtc).Take(100)).ToListAsync(ct));
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateScheduleRequest request, CancellationToken ct)
    {
        var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeBySystemTimeZoneId(DateTimeOffset.UtcNow, "Asia/Ho_Chi_Minh").DateTime);
        if (request.WorkDate < today || request.WorkDate > today.AddDays(90))
            return BadRequest(new { message = "Chọn ngày từ hôm nay đến 90 ngày tới." });
        if (string.IsNullOrWhiteSpace(request.Reason)) return BadRequest(new { message = "Vui lòng nhập lý do." });
        if (request.Type is not ("late" or "early") || request.TimeMinutes <= 480 || request.TimeMinutes >= 1020)
            return BadRequest(new { message = "Thời gian phải nằm sau 08:00 và trước 17:00." });
        var id = CurrentId;
        if (await db.ScheduleRequests.AnyAsync(r => r.UserId == id && r.WorkDate == request.WorkDate && r.Type == request.Type && r.Status != "rejected", ct))
            return Conflict(new { message = "Đã có đơn cùng loại cho ngày này đang chờ hoặc đã được duyệt." });
        var row = new ScheduleRequest {
            UserId = id, Type = request.Type, WorkDate = request.WorkDate,
            TimeMinutes = request.TimeMinutes, Reason = request.Reason.Trim(), CreatedAtUtc = DateTimeOffset.UtcNow
        };
        db.ScheduleRequests.Add(row);
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateException) { return Conflict(new { message = "Không lưu được đơn. Hãy tải lại để kiểm tra đơn đã gửi." }); }
        return Ok(await Project(db.ScheduleRequests.Where(r => r.Id == row.Id)).SingleAsync(ct));
    }

    [HttpPost("{id:int}/review")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Review(int id, ReviewScheduleRequest request, CancellationToken ct)
    {
        var row = await db.ScheduleRequests.AsNoTracking().SingleOrDefaultAsync(r => r.Id == id, ct);
        if (row is null) return NotFound(new { message = "Không tìm thấy đơn." });
        if (row.UserId == CurrentId) return BadRequest(new { message = "Không thể tự duyệt đơn của chính mình." });
        if (request.Status is not ("approved" or "rejected")) return BadRequest(new { message = "Trạng thái duyệt không hợp lệ." });
        var reviewer = CurrentId;
        var now = DateTimeOffset.UtcNow;
        var note = request.Note.Trim();
        var updated = await db.ScheduleRequests.Where(r => r.Id == id && r.Status == "pending")
            .ExecuteUpdateAsync(s => s.SetProperty(r => r.Status, request.Status)
                .SetProperty(r => r.ReviewedByUserId, reviewer).SetProperty(r => r.ReviewedAtUtc, now)
                .SetProperty(r => r.ReviewNote, note), ct);
        if (updated == 0) return Conflict(new { message = "Đơn đã được xử lý. Hãy tải lại danh sách." });
        return Ok(await Project(db.ScheduleRequests.Where(r => r.Id == id)).SingleAsync(ct));
    }

    private IQueryable<ScheduleRequestDto> Project(IQueryable<ScheduleRequest> query) => query.Select(r => new ScheduleRequestDto(
        r.Id, r.UserId, db.Users.Where(u => u.Id == r.UserId).Select(u => u.FullName).FirstOrDefault() ?? "Tài khoản đã xóa",
        r.Type, r.WorkDate, r.TimeMinutes, r.Reason, r.Status, r.CreatedAtUtc, r.ReviewNote,
        db.Users.Where(u => u.Id == r.ReviewedByUserId).Select(u => u.FullName).FirstOrDefault(), r.ReviewedAtUtc));
}

public sealed record CreateScheduleRequest([Required] string Type, DateOnly WorkDate,
    [Range(481, 1019)] int TimeMinutes, [Required, StringLength(500)] string Reason);
public sealed record ReviewScheduleRequest([Required] string Status, [StringLength(500)] string Note = "");
public sealed record ScheduleRequestDto(int Id, int UserId, string FullName, string Type,
    DateOnly WorkDate, int TimeMinutes, string Reason, string Status, DateTimeOffset CreatedAtUtc,
    string ReviewNote, string? ReviewerName, DateTimeOffset? ReviewedAtUtc);
