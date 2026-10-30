using System.ComponentModel.DataAnnotations;

namespace LEDOANVANTU2.Api.Models;

public sealed class ScheduleRequest
{
    public int Id { get; set; }
    public int UserId { get; set; }
    [MaxLength(16)] public required string Type { get; set; }
    public DateOnly WorkDate { get; set; }
    public int TimeMinutes { get; set; }
    [MaxLength(500)] public required string Reason { get; set; }
    [MaxLength(16)] public string Status { get; set; } = "pending";
    public DateTimeOffset CreatedAtUtc { get; set; }
    public int? ReviewedByUserId { get; set; }
    public DateTimeOffset? ReviewedAtUtc { get; set; }
    [MaxLength(500)] public string ReviewNote { get; set; } = "";
}
