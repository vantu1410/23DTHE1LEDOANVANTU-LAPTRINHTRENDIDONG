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
public sealed class AttendanceApiController(AppDbContext db, IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetHistory(CancellationToken ct)
    {
        var userId = CurrentUserId();
        var isAdmin = User.IsInRole("Admin");
        var query =
            from record in db.AttendanceRecords.AsNoTracking()
            join user in db.Users.AsNoTracking() on record.UserId equals user.Id
            where isAdmin || record.UserId == userId
            orderby record.RecordedAtUtc descending
            select new AttendanceHistoryDto(
                record.Id,
                record.UserId,
                user.FullName,
                user.Username,
                record.Type,
                record.RecordedAtUtc,
                record.DistanceFromOfficeMeters,
                record.Latitude,
                record.Longitude,
                record.AccuracyMeters,
                record.OvertimeMinutes,
                record.Verification);
        return Ok(await query.Take(200).ToListAsync(ct));
    }

    [HttpPost]
    public async Task<IActionResult> Create(AttendanceRequest request, CancellationToken ct)
    {
        const string expectedQr = "TUTIME:OFFICE:23DTHE1LEDOANVANTU-GROUP8";
        if (!string.Equals(request.QrToken, expectedQr, StringComparison.Ordinal))
            return BadRequest(new { message = "QR không hợp lệ. Hãy quét đúng mã QR cố định của công ty." });
        if (!double.IsFinite(request.Latitude) || request.Latitude is < -90 or > 90 ||
            !double.IsFinite(request.Longitude) || request.Longitude is < -180 or > 180)
            return BadRequest(new { message = "Tọa độ GPS không hợp lệ. Hãy bật vị trí chính xác rồi thử lại." });

        var latitude = configuration.GetValue<double>("Office:Latitude");
        var longitude = configuration.GetValue<double>("Office:Longitude");
        var distance = DistanceMeters(request.Latitude, request.Longitude, latitude, longitude);
        var localTime = TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, TimeZoneInfo.FindSystemTimeZoneById("Asia/Ho_Chi_Minh"));
        int? overtimeMinutes = null;
        if (request.Type.Equals("checkOut", StringComparison.OrdinalIgnoreCase))
        {
            var shiftEnd = new TimeSpan(17, 0, 0);
            overtimeMinutes = localTime.TimeOfDay > shiftEnd
                ? (int)(localTime.TimeOfDay - shiftEnd).TotalMinutes
                : 0;
        }

        var record = new AttendanceRecord
        {
            UserId = CurrentUserId(),
            Type = request.Type,
            RecordedAtUtc = DateTimeOffset.UtcNow,
            DistanceFromOfficeMeters = Math.Round(distance, 1),
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            AccuracyMeters = request.AccuracyMeters is > 0 and var accuracy && double.IsFinite(accuracy)
                ? accuracy
                : null,
            OvertimeMinutes = overtimeMinutes,
            Verification = "QR công ty + GPS"
        };
        db.AttendanceRecords.Add(record);
        await db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(GetHistory), new { id = record.Id }, record);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> CancelAttendance(int id, CancellationToken ct)
    {
        var record = await db.AttendanceRecords.FindAsync([id], ct);
        if (record is null)
            return NotFound(new { message = "Không tìm thấy lượt chấm công." });

        db.AttendanceRecords.Remove(record);
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    private int CurrentUserId()
    {
        var value = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        return int.TryParse(value, out var id) ? id : throw new UnauthorizedAccessException("Token không có mã người dùng hợp lệ.");
    }

    private static double DistanceMeters(double lat1, double lon1, double lat2, double lon2)
    {
        const double earthRadius = 6_371_000;
        static double ToRadians(double degrees) => degrees * Math.PI / 180;
        var dLat = ToRadians(lat2 - lat1);
        var dLon = ToRadians(lon2 - lon1);
        var a = Math.Pow(Math.Sin(dLat / 2), 2) +
                Math.Cos(ToRadians(lat1)) * Math.Cos(ToRadians(lat2)) * Math.Pow(Math.Sin(dLon / 2), 2);
        return earthRadius * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    }
}

public sealed record AttendanceRequest(
    string Type,
    double Latitude,
    double Longitude,
    string QrToken,
    double? AccuracyMeters = null);

public sealed record AttendanceHistoryDto(
    int Id,
    int UserId,
    string FullName,
    string Username,
    string Type,
    DateTimeOffset RecordedAtUtc,
    double DistanceFromOfficeMeters,
    double Latitude,
    double Longitude,
    double? AccuracyMeters,
    int? OvertimeMinutes,
    string Verification);
