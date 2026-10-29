using System.Net;
using System.Net.Mail;

namespace LEDOANVANTU2.Api.Services;

public sealed class OtpEmailSender(IConfiguration configuration, IWebHostEnvironment environment, ILogger<OtpEmailSender> logger)
{
    public async Task<string?> SendAsync(string destination, string code, string purpose, CancellationToken cancellationToken)
    {
        var section = configuration.GetSection("Smtp");
        var host = section["Host"];
        var user = section["Username"];
        var password = section["Password"];
        var from = section["From"];

        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(from))
        {
            if (!environment.IsDevelopment())
                throw new InvalidOperationException("SMTP chưa được cấu hình; API không thể gửi OTP.");
            logger.LogWarning("OTP for {Destination} ({Purpose}) is {Code}; configure SMTP before deployment.", destination, purpose, code);
            return code;
        }

        using var message = new MailMessage(from, destination)
        {
            Subject = "Mã xác thực TuTime",
            Body = $"Mã OTP {purpose} của bạn là {code}. Mã hết hạn sau 5 phút.",
            IsBodyHtml = false
        };
        using var client = new SmtpClient(host, int.TryParse(section["Port"], out var port) ? port : 587)
        {
            EnableSsl = true,
            Credentials = string.IsNullOrWhiteSpace(user) ? CredentialCache.DefaultNetworkCredentials : new NetworkCredential(user, password)
        };
        await client.SendMailAsync(message, cancellationToken);
        return null;
    }
}
