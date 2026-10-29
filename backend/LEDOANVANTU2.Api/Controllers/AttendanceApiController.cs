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
        var query = db.AttendanceRecords.AsNoTracking();
        if (!User.IsInRole("Admin")) query = query.Where(x => x.UserId == userId);
        return Ok(await query.OrderByDescending(x => x.RecordedAtUtc).Take(200).ToListAsync(ct));
    }

    [HttpPost]
    public async Task<IActionResult> Create(AttendanceRequest request, CancellationToken ct)
    {
        const string expectedQr = "TUTIME:OFFICE:23DTHE1LEDOANVANTU-GROUP8";
        if (!string.Equals(request.QrToken, expectedQr, StringComparison.Ordinal))
            return BadRequest(new { message = "QR không hợp lệ. Hãy quét đúng mã QR cố định của công ty." });

        var latitude = configuration.GetValue<double>("Office:Latitude");
        var longitude = configuration.GetValue<double>("Office:Longitude");
        var radius = configuration.GetValue<double>("Office:RadiusMeters", 150);
        var distance = DistanceMeters(request.Latitude, request.Longitude, latitude, longitude);
        if (distance > radius)
            return StatusCode(StatusCodes.Status403Forbidden, new { message = $"Ngoài vùng chấm công ({distance:0}m; giới hạn {radius:0}m)." });

        var record = new AttendanceRecord
        {
            UserId = CurrentUserId(),
            Type = request.Type,
            RecordedAtUtc = DateTimeOffset.UtcNow,
            DistanceFromOfficeMeters = Math.Round(distance, 1),
            Verification = "QR công ty + GPS"
        };
        db.AttendanceRecords.Add(record);
        await db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(GetHistory), new { id = record.Id }, record);
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

public sealed record AttendanceRequest(string Type, double Latitude, double Longitude, string QrToken);
