namespace LEDOANVANTU2.Api.Models;

public sealed class AppUser
{
    public int Id { get; set; }
    public required string FullName { get; set; }
    public required string Email { get; set; }
    public required string Username { get; set; }
    public required string PasswordHash { get; set; }
    public string Role { get; set; } = "Employee";
    public bool EmailVerified { get; set; }
    public string? OtpHash { get; set; }
    public string? OtpPurpose { get; set; }
    public DateTimeOffset? OtpExpiresAtUtc { get; set; }
}
