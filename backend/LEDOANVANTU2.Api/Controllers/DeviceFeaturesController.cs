using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using LEDOANVANTU2.Api.Data;
using LEDOANVANTU2.Api.Models;
using LEDOANVANTU2.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LEDOANVANTU2.Api.Controllers;

[ApiController]
[Authorize]
public abstract class DeviceFeatureController(AppDbContext db) : ControllerBase
{
    protected AppDbContext Db => db;
    protected int UserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub")!);
    protected Task<FeatureRecord?> Find(string kind, CancellationToken ct) =>
        db.FeatureRecords.SingleOrDefaultAsync(r => r.UserId == UserId && r.Kind == kind, ct);
    protected async Task<bool> Save(string kind, string data, CancellationToken ct)
    {
        var record = await Find(kind, ct);
        if (record is null) db.FeatureRecords.Add(new FeatureRecord { UserId = UserId, Kind = kind, Data = data });
        else { record.Data = data; record.CreatedAtUtc = DateTimeOffset.UtcNow; }
        try { await db.SaveChangesAsync(ct); return true; }
        catch (DbUpdateException) { return false; }
    }
}

[Route("api/Settings")]
public sealed class SettingsController(AppDbContext db) : DeviceFeatureController(db)
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        var record = await Find("settings", ct);
        return Ok(record is null ? new SettingsRequest(1, 0xFF0B0D11) : JsonSerializer.Deserialize<SettingsRequest>(record.Data));
    }
    [HttpPut]
    public async Task<IActionResult> Update(SettingsRequest request, CancellationToken ct)
    {
        if (!double.IsFinite(request.TextScale) || request.TextScale is < .85 or > 1.4 ||
            !new long[] { 0xFF0B0D11, 0xFF14243A, 0xFF183328, 0xFF342238 }.Contains(request.Background))
            return BadRequest(new { message = "Cỡ chữ hoặc màu nền không hợp lệ." });
        if (!await Save("settings", JsonSerializer.Serialize(request), ct))
            return Conflict(new { message = "Cài đặt vừa được cập nhật trên thiết bị khác. Hãy thử lưu lại." });
        return Ok(request);
    }
}
public sealed record SettingsRequest(double TextScale, long Background);

[Route("api/Locations")]
public sealed class LocationsController(AppDbContext db) : DeviceFeatureController(db)
{
    [HttpPost]
    public async Task<IActionResult> Create(LocationRequest request, CancellationToken ct)
    {
        if (!double.IsFinite(request.Latitude) || request.Latitude is < -90 or > 90 ||
            !double.IsFinite(request.Longitude) || request.Longitude is < -180 or > 180 ||
            request.AccuracyMeters.HasValue && (!double.IsFinite(request.AccuracyMeters.Value) || request.AccuracyMeters < 0))
            return BadRequest(new { message = "Vị trí GPS hoặc sai số không hợp lệ." });
        var mapsUrl = FormattableString.Invariant($"https://www.google.com/maps?q={request.Latitude:F6},{request.Longitude:F6}");
        var result = new { request.Latitude, request.Longitude, request.AccuracyMeters, mapsUrl };
        var row = new FeatureRecord { UserId = UserId, Kind = "location", Data = JsonSerializer.Serialize(result) };
        Db.FeatureRecords.Add(row);
        await Db.SaveChangesAsync(ct);
        return Ok(new { row.Id, row.CreatedAtUtc, result.Latitude, result.Longitude, result.AccuracyMeters, result.mapsUrl });
    }
    [HttpGet]
    public async Task<IActionResult> History(CancellationToken ct)
    {
        var rows = await Db.FeatureRecords.AsNoTracking().Where(r => r.UserId == UserId && r.Kind == "location")
            .OrderByDescending(r => r.Id).Take(100).ToListAsync(ct);
        return Ok(rows.Select(r => new { r.Id, r.CreatedAtUtc, location = JsonSerializer.Deserialize<JsonElement>(r.Data) }));
    }
}
public sealed record LocationRequest(double Latitude, double Longitude, double? AccuracyMeters = null);

[Route("api/Pressure")]
public sealed class PressureController(AppDbContext db) : DeviceFeatureController(db)
{
    [HttpPost]
    public async Task<IActionResult> Record(PressureRequest request, CancellationToken ct)
    {
        if (request.Values is null || request.Values.Length is < 1 or > 600 ||
            request.Values.Any(v => !double.IsFinite(v) || v is < 100 or > 1200))
            return BadRequest(new { message = "Cần từ 1 đến 600 mẫu áp suất hợp lệ (100–1200 hPa)." });
        var result = new
        {
            current = request.Values[^1], minimum = request.Values.Min(), maximum = request.Values.Max(),
            average = request.Values.Average(), count = request.Values.Length,
            delta = request.Values.Max() - request.Values.Min(),
            warning = request.Values.Max() - request.Values.Min() >= 2,
            values = request.Values
        };
        var row = new FeatureRecord { UserId = UserId, Kind = "pressure", Data = JsonSerializer.Serialize(result) };
        Db.FeatureRecords.Add(row);
        await Db.SaveChangesAsync(ct);
        return Ok(result);
    }
    [HttpGet]
    public async Task<IActionResult> History(CancellationToken ct)
    {
        var rows = await Db.FeatureRecords.AsNoTracking().Where(r => r.UserId == UserId && r.Kind == "pressure")
            .OrderByDescending(r => r.Id).Take(50).ToListAsync(ct);
        return Ok(rows.Select(r => new { r.Id, r.CreatedAtUtc, statistics = JsonSerializer.Deserialize<JsonElement>(r.Data) }));
    }
}
public sealed record PressureRequest([Required] double[] Values);

[Route("api/Face")]
public sealed class FaceController(AppDbContext db, IConfiguration configuration) : DeviceFeatureController(db)
{
    private byte[] Key => SHA256.HashData(Encoding.UTF8.GetBytes("TuTime.Face.v1:" + configuration["Jwt:Key"]));
    private byte[] Aad => Encoding.UTF8.GetBytes(UserId.ToString());
    private string Encrypt(FaceTemplate template)
    {
        var bytes = JsonSerializer.SerializeToUtf8Bytes(template);
        var nonce = RandomNumberGenerator.GetBytes(12);
        var tag = new byte[16];
        var ciphertext = new byte[bytes.Length];
        using var aes = new AesGcm(Key, 16);
        aes.Encrypt(nonce, bytes, ciphertext, tag, Aad);
        return Convert.ToBase64String(nonce.Concat(tag).Concat(ciphertext).ToArray());
    }
    private FaceTemplate Decrypt(string value)
    {
        var bytes = Convert.FromBase64String(value);
        var plaintext = new byte[bytes.Length - 28];
        using var aes = new AesGcm(Key, 16);
        aes.Decrypt(bytes.AsSpan(0, 12), bytes.AsSpan(28), bytes.AsSpan(12, 16), plaintext, Aad);
        return JsonSerializer.Deserialize<FaceTemplate>(plaintext)!;
    }
    private static bool Valid(double[]? embedding) => embedding is { Length: 192 } &&
        embedding.All(double.IsFinite) && embedding.Sum(v => v * v) is > 0 and < double.PositiveInfinity;

    [HttpGet]
    public async Task<IActionResult> Status(CancellationToken ct) => Ok(new { enabled = await Find("face", ct) is not null });

    [HttpPost("enroll")]
    public async Task<IActionResult> Enroll(FaceRequest request, CancellationToken ct)
    {
        if (!Valid(request.Embedding)) return BadRequest(new { message = "Mẫu khuôn mặt không hợp lệ (192 giá trị hữu hạn)." });
        if (!await Save("face", Encrypt(new FaceTemplate(request.Embedding, 0)), ct))
            return Conflict(new { message = "Mẫu khuôn mặt vừa được cập nhật. Hãy thử đăng ký lại." });
        return Ok(new { enabled = true, message = "Đã đăng ký khuôn mặt trên API." });
    }
    [HttpPost("verify")]
    public async Task<IActionResult> Verify(FaceRequest request, CancellationToken ct)
    {
        if (!Valid(request.Embedding)) return BadRequest(new { message = "Mẫu khuôn mặt không hợp lệ." });
        var record = await Find("face", ct);
        if (record is null) return Conflict(new { message = "Chưa đăng ký khuôn mặt hoặc đã bị khóa sau 5 lần sai. Hãy đăng nhập OTP và đăng ký lại." });
        FaceTemplate template;
        try { template = Decrypt(record.Data); }
        catch (Exception ex) when (ex is CryptographicException or FormatException or ArgumentException or JsonException)
        { return Conflict(new { message = "Cần đăng ký lại khuôn mặt sau khi khóa mã hóa thay đổi." }); }
        var norm = Math.Sqrt(template.Embedding.Sum(v => v * v)) * Math.Sqrt(request.Embedding.Sum(v => v * v));
        var similarity = template.Embedding.Zip(request.Embedding, (a, b) => a * b).Sum() / norm;
        var matched = double.IsFinite(similarity) && similarity >= .70;
        if (!matched && template.Failures + 1 >= 5)
        {
            Db.FeatureRecords.Remove(record);
            var header = Request.Headers.Authorization.ToString();
            if (header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            {
                var hash = ApiSessions.Hash(header[7..].Trim());
                if (!await Db.FeatureRecords.AnyAsync(r => r.UserId == UserId && r.Kind == "revoked-token" && r.Data == hash, ct))
                    Db.FeatureRecords.Add(new FeatureRecord { UserId = UserId, Kind = "revoked-token", Data = hash });
            }
        }
        else record.Data = Encrypt(template with { Failures = matched ? 0 : template.Failures + 1 });
        await Db.SaveChangesAsync(ct);
        return matched ? Ok(new { matched = true }) : Unauthorized(new { message = "Khuôn mặt không khớp. Sau 5 lần sai cần đăng nhập OTP và đăng ký lại." });
    }
    [HttpDelete]
    public async Task<IActionResult> Disable(CancellationToken ct)
    {
        var record = await Find("face", ct);
        if (record is not null) { Db.FeatureRecords.Remove(record); await Db.SaveChangesAsync(ct); }
        return NoContent();
    }
}
public sealed record FaceRequest([Required] double[] Embedding);
public sealed record FaceTemplate(double[] Embedding, int Failures);
