namespace LEDOANVANTU2.Api.Models;

public sealed class FeatureRecord
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string Kind { get; set; } = "";
    public string Data { get; set; } = "";
    public DateTimeOffset CreatedAtUtc { get; set; } = DateTimeOffset.UtcNow;
}
