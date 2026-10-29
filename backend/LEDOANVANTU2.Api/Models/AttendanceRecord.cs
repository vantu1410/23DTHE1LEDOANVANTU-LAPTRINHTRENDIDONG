namespace LEDOANVANTU2.Api.Models;

public sealed class AttendanceRecord
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public required string Type { get; set; }
    public DateTimeOffset RecordedAtUtc { get; set; }
    public double DistanceFromOfficeMeters { get; set; }
    public required string Verification { get; set; }
}
