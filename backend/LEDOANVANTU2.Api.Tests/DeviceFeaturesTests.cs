using System.Globalization;
using System.Security.Claims;
using System.Text.Json;
using LEDOANVANTU2.Api.Controllers;
using LEDOANVANTU2.Api.Data;
using LEDOANVANTU2.Api.Models;
using LEDOANVANTU2.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace LEDOANVANTU2.Api.Tests;

public sealed class DeviceFeaturesTests : IAsyncLifetime
{
    private readonly SqliteConnection connection = new("Data Source=:memory:");
    private AppDbContext db = null!;
    private readonly CancellationToken ct = default;
    private static readonly IConfiguration Configuration = new ConfigurationBuilder().AddInMemoryCollection(
        new Dictionary<string, string?> { ["Jwt:Key"] = "local-test-key-with-at-least-32-bytes" }).Build();
    public async Task InitializeAsync()
    {
        await connection.OpenAsync();
        db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseSqlite(connection).Options);
        await db.Database.EnsureCreatedAsync();
        db.Users.AddRange(new AppUser { Id = 1, FullName = "One", Username = "one", Email = "one@example.test", PasswordHash = "test", EmailVerified = true },
            new AppUser { Id = 2, FullName = "Two", Username = "two", Email = "two@example.test", PasswordHash = "test", EmailVerified = true });
        await db.SaveChangesAsync();
    }
    public async Task DisposeAsync() { await db.DisposeAsync(); await connection.DisposeAsync(); }
    private static T AsUser<T>(T controller, int id = 1) where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() };
        controller.HttpContext.User = new ClaimsPrincipal(new ClaimsIdentity(new[] { new Claim(ClaimTypes.NameIdentifier, id.ToString()) }, "test"));
        return controller;
    }
    private static JsonElement Json(IActionResult result) => JsonSerializer.SerializeToElement(Assert.IsType<OkObjectResult>(result).Value);
    private static double[] Face(int axis) { var values = new double[192]; values[axis] = 1; return values; }

    [Fact]
    public async Task Settings_persist_per_user_and_reject_invalid_scale()
    {
        var one = AsUser(new SettingsController(db));
        Assert.IsType<OkObjectResult>(await one.Update(new SettingsRequest(1.2, 0xFF14243A), ct));
        Assert.Equal(1.2, Json(await one.Get(ct)).GetProperty("TextScale").GetDouble());
        Assert.Equal(1, Json(await AsUser(new SettingsController(db), 2).Get(ct)).GetProperty("TextScale").GetDouble());
        Assert.IsType<BadRequestObjectResult>(await one.Update(new SettingsRequest(double.NaN, 0xFF14243A), ct));
        Assert.IsType<BadRequestObjectResult>(await one.Update(new SettingsRequest(1, 123), ct));
        Assert.Single(await db.FeatureRecords.ToListAsync());
    }

    [Fact]
    public async Task Location_is_validated_and_link_is_culture_independent_and_private()
    {
        var controller = AsUser(new LocationsController(db));
        var previous = CultureInfo.CurrentCulture;
        try
        {
            CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("vi-VN");
            var result = Json(await controller.Create(new LocationRequest(10.7769, 106.7009, 5), ct));
            Assert.Equal("https://www.google.com/maps?q=10.776900,106.700900", result.GetProperty("mapsUrl").GetString());
        }
        finally { CultureInfo.CurrentCulture = previous; }
        Assert.IsType<BadRequestObjectResult>(await controller.Create(new LocationRequest(91, 100), ct));
        Assert.IsType<BadRequestObjectResult>(await controller.Create(new LocationRequest(10, 100, -1), ct));
        Assert.Equal(1, Json(await controller.History(ct)).GetArrayLength());
        Assert.Equal(0, Json(await AsUser(new LocationsController(db), 2).History(ct)).GetArrayLength());
    }

    [Fact]
    public async Task Pressure_computes_and_stores_statistics_and_scopes_history()
    {
        var controller = AsUser(new PressureController(db));
        var result = Json(await controller.Record(new PressureRequest(new double[] { 1010, 1012, 1014 }), ct));
        Assert.Equal(1012, result.GetProperty("average").GetDouble());
        Assert.Equal(1010, result.GetProperty("minimum").GetDouble());
        Assert.Equal(1014, result.GetProperty("maximum").GetDouble());
        Assert.True(result.GetProperty("warning").GetBoolean());
        Assert.Equal(1, Json(await controller.History(ct)).GetArrayLength());
        Assert.Equal(0, Json(await AsUser(new PressureController(db), 2).History(ct)).GetArrayLength());
    }

    [Theory]
    [InlineData(0)]
    [InlineData(601)]
    public async Task Pressure_rejects_empty_or_oversized_batches(int length)
    {
        var values = Enumerable.Repeat(1013.0, length).ToArray();
        Assert.IsType<BadRequestObjectResult>(await AsUser(new PressureController(db)).Record(new PressureRequest(values), ct));
        Assert.Empty(await db.FeatureRecords.ToListAsync());
    }

    [Fact]
    public async Task Face_templates_are_encrypted_matched_on_server_and_removed_after_five_failures()
    {
        var controller = AsUser(new FaceController(db, Configuration));
        controller.Request.Headers.Authorization = "Bearer face-session";
        Assert.IsType<OkObjectResult>(await controller.Enroll(new FaceRequest(Face(0)), ct));
        var row = await db.FeatureRecords.SingleAsync();
        Assert.DoesNotContain("Embedding", row.Data);
        Assert.DoesNotContain(JsonSerializer.Serialize(Face(0)), row.Data);
        Assert.True(Json(await controller.Verify(new FaceRequest(Face(0)), ct)).GetProperty("matched").GetBoolean());
        Assert.IsType<ConflictObjectResult>(await AsUser(new FaceController(db, Configuration), 2).Verify(new FaceRequest(Face(0)), ct));
        for (var i = 0; i < 5; i++) Assert.IsType<UnauthorizedObjectResult>(await controller.Verify(new FaceRequest(Face(1)), ct));
        Assert.False(Json(await controller.Status(ct)).GetProperty("enabled").GetBoolean());
        Assert.False(await ApiSessions.IsActiveAsync(db, 1, "face-session", ct));
        Assert.IsType<ConflictObjectResult>(await controller.Verify(new FaceRequest(Face(0)), ct));
    }

    [Fact]
    public async Task Face_invalid_vectors_are_rejected_and_disable_removes_reference()
    {
        var controller = AsUser(new FaceController(db, Configuration));
        Assert.IsType<BadRequestObjectResult>(await controller.Enroll(new FaceRequest(new double[192]), ct));
        Assert.IsType<BadRequestObjectResult>(await controller.Enroll(new FaceRequest(new double[3]), ct));
        await controller.Enroll(new FaceRequest(Face(0)), ct);
        Assert.IsType<NoContentResult>(await controller.Disable(ct));
        Assert.Empty(await db.FeatureRecords.ToListAsync());
    }

    [Fact]
    public async Task Revoked_token_is_rejected_without_revoking_other_tokens_or_users()
    {
        db.FeatureRecords.Add(new FeatureRecord { UserId = 1, Kind = "revoked-token", Data = ApiSessions.Hash("old-token") });
        await db.SaveChangesAsync();
        Assert.False(await ApiSessions.IsActiveAsync(db, 1, "old-token", ct));
        Assert.True(await ApiSessions.IsActiveAsync(db, 1, "new-token", ct));
        Assert.True(await ApiSessions.IsActiveAsync(db, 2, "old-token", ct));
        Assert.False(await ApiSessions.IsActiveAsync(db, 999, "new-token", ct));
    }
}
