using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.ComponentModel.DataAnnotations;
using LEDOANVANTU2.Api.Data;
using LEDOANVANTU2.Api.Models;
using LEDOANVANTU2.Api.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

namespace LEDOANVANTU2.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class AuthController(
    AppDbContext db,
    IPasswordHasher<AppUser> passwordHasher,
    OtpEmailSender otpSender,
    IConfiguration configuration,
    IWebHostEnvironment environment) : ControllerBase
{
    [HttpPost("register")]
    public async Task<IActionResult> Register(RegisterRequest request, CancellationToken ct)
    {
        var username = request.Username.Trim();
        var email = request.Email.Trim().ToLowerInvariant();
        var user = await db.Users.FirstOrDefaultAsync(
            x => x.Username == username || x.Email == email,
            ct);
        var retryingUnverifiedRegistration = user is not null &&
            !user.EmailVerified &&
            string.Equals(user.Username, username, StringComparison.OrdinalIgnoreCase) &&
            string.Equals(user.Email, email, StringComparison.OrdinalIgnoreCase);
        if (user is not null && !retryingUnverifiedRegistration)
            return Conflict(new { message = "Tên đăng nhập hoặc email đã được sử dụng." });

        user ??= new AppUser
        {
            FullName = request.FullName.Trim(),
            Email = email,
            Username = username,
            PasswordHash = "pending",
            Role = "Employee"
        };
        user.PasswordHash = passwordHasher.HashPassword(user, request.Password);
        user.FullName = request.FullName.Trim();
        user.Email = email;
        user.Username = username;
        var code = NewOtp();
        SetOtp(user, code, "register");
        if (!retryingUnverifiedRegistration) db.Users.Add(user);
        await db.SaveChangesAsync(ct);
        string? debugCode;
        try
        {
            debugCode = await otpSender.SendAsync(email, code, "đăng ký", ct);
        }
        catch
        {
            if (!retryingUnverifiedRegistration)
            {
                db.Users.Remove(user);
                await db.SaveChangesAsync(ct);
            }
            throw;
        }
        var message = retryingUnverifiedRegistration
            ? "Tài khoản chưa xác nhận. Đã gửi mã OTP mới đến email đăng ký."
            : "Đã gửi OTP đến email đăng ký.";
        return Ok(new { message, otpRequired = true, debugOtp = environment.IsDevelopment() ? debugCode : null });
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest request, CancellationToken ct)
    {
        var username = request.Username.Trim();
        var user = await db.Users.SingleOrDefaultAsync(x => x.Username == username, ct);
        if (user is null || !user.EmailVerified || passwordHasher.VerifyHashedPassword(user, user.PasswordHash, request.Password) == PasswordVerificationResult.Failed)
            return Unauthorized(new { message = "Tên đăng nhập hoặc mật khẩu không đúng." });

        var code = NewOtp();
        SetOtp(user, code, "login");
        await db.SaveChangesAsync(ct);
        var debugCode = await otpSender.SendAsync(user.Email, code, "đăng nhập", ct);
        return Ok(new { message = "Đã gửi mã OTP đến email của bạn.", otpRequired = true, debugOtp = environment.IsDevelopment() ? debugCode : null });
    }

    [HttpPost("verify-otp")]
    public async Task<IActionResult> VerifyOtp(VerifyOtpRequest request, CancellationToken ct)
    {
        var user = await db.Users.SingleOrDefaultAsync(x => x.Username == request.Username.Trim(), ct);
        if (user is null || user.OtpHash is null || user.OtpExpiresAtUtc <= DateTimeOffset.UtcNow || user.OtpPurpose is null || !MatchesOtp(user, request.Code))
            return Unauthorized(new { message = "OTP không hợp lệ hoặc đã hết hạn." });

        if (user.OtpPurpose == "register") user.EmailVerified = true;
        user.OtpHash = null;
        user.OtpPurpose = null;
        user.OtpExpiresAtUtc = null;
        await db.SaveChangesAsync(ct);

        return Ok(new
        {
            accessToken = CreateToken(user),
            user = new { id = user.Id, fullName = user.FullName, username = user.Username, email = user.Email, role = user.Role }
        });
    }

    private string CreateToken(AppUser user)
    {
        var key = configuration["Jwt:Key"];
        if (string.IsNullOrWhiteSpace(key) || Encoding.UTF8.GetByteCount(key) < 32)
            throw new InvalidOperationException("Jwt:Key phải có ít nhất 32 byte và được cấu hình qua secret/environment.");
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new Claim(JwtRegisteredClaimNames.UniqueName, user.Username),
            new Claim(ClaimTypes.Name, user.FullName),
            new Claim(ClaimTypes.Role, user.Role)
        };
        var credentials = new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)), SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            issuer: configuration["Jwt:Issuer"],
            audience: configuration["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddHours(8),
            signingCredentials: credentials);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static string NewOtp() => RandomNumberGenerator.GetInt32(100000, 1000000).ToString();

    private static void SetOtp(AppUser user, string code, string purpose)
    {
        user.OtpHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes($"{user.Username}:{code}")));
        user.OtpPurpose = purpose;
        user.OtpExpiresAtUtc = DateTimeOffset.UtcNow.AddMinutes(5);
    }

    private static bool MatchesOtp(AppUser user, string code)
    {
        var expected = Convert.FromHexString(user.OtpHash!);
        var actual = SHA256.HashData(Encoding.UTF8.GetBytes($"{user.Username}:{code.Trim()}"));
        return CryptographicOperations.FixedTimeEquals(expected, actual);
    }
}

public sealed record RegisterRequest(
    [Required, MinLength(2), MaxLength(120)] string FullName,
    [Required, EmailAddress, MaxLength(254)] string Email,
    [Required, MinLength(3), MaxLength(40)] string Username,
    [Required, MinLength(8), MaxLength(128)] string Password);

public sealed record LoginRequest([Required] string Username, [Required] string Password);
public sealed record VerifyOtpRequest([Required] string Username, [Required, StringLength(6, MinimumLength = 6)] string Code);
