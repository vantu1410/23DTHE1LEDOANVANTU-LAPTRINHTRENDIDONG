using System.Net;
using System.Net.Mail;
using System.Net.Http.Json;

namespace LEDOANVANTU2.Api.Services;

public sealed class OtpEmailSender(
    IConfiguration configuration,
    IWebHostEnvironment environment,
    ILogger<OtpEmailSender> logger,
    IHttpClientFactory httpClientFactory)
{
    public async Task<string?> SendAsync(string destination, string code, string purpose, CancellationToken cancellationToken)
    {
        var brevoApiKey = configuration["Brevo:ApiKey"];
        var from = configuration["Smtp:From"];
        if (!string.IsNullOrWhiteSpace(brevoApiKey))
        {
            if (string.IsNullOrWhiteSpace(from))
                throw new InvalidOperationException("Cần cấu hình Smtp__From là email người gửi đã xác minh trong Brevo.");

            await SendWithBrevoAsync(from, destination, code, purpose, brevoApiKey, cancellationToken);
            return null;
        }

        var smtp = configuration.GetSection("Smtp");
        var host = smtp["Host"];
        var user = smtp["Username"];
        var password = smtp["Password"];
        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(from))
        {
            if (!environment.IsDevelopment())
                throw new InvalidOperationException("Chưa cấu hình dịch vụ gửi OTP. Trên Render miễn phí, hãy thêm Brevo__ApiKey và Smtp__From đã xác minh.");
            logger.LogWarning("OTP for {Destination} ({Purpose}) is {Code}; configure an email provider before deployment.", destination, purpose, code);
            return code;
        }

        using var message = new MailMessage(from, destination)
        {
            Subject = "Mã xác thực TuTime",
            Body = $"Mã OTP {purpose} của bạn là {code}. Mã hết hạn sau 5 phút.",
            IsBodyHtml = false
        };
        using var client = new SmtpClient(host, int.TryParse(smtp["Port"], out var port) ? port : 587)
        {
            EnableSsl = true,
            Credentials = string.IsNullOrWhiteSpace(user) ? CredentialCache.DefaultNetworkCredentials : new NetworkCredential(user, password),
            Timeout = 15000
        };
        try
        {
            await client.SendMailAsync(message, cancellationToken);
        }
        catch (Exception ex) when (ex is SmtpException or OperationCanceledException)
        {
            logger.LogWarning(ex, "SMTP delivery failed for OTP to {Destination}.", destination);
            throw new InvalidOperationException("Không gửi được email OTP qua SMTP. Render miễn phí chặn cổng SMTP; hãy cấu hình Brevo API qua HTTPS.", ex);
        }
        return null;
    }

    private async Task SendWithBrevoAsync(string from, string destination, string code, string purpose, string apiKey, CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.brevo.com/v3/smtp/email");
        request.Headers.Add("api-key", apiKey);
        request.Headers.Accept.ParseAdd("application/json");
        request.Content = JsonContent.Create(new
        {
            sender = new { email = from, name = configuration["Brevo:SenderName"] ?? "TuTime" },
            to = new[] { new { email = destination } },
            subject = "Mã xác thực TuTime",
            textContent = $"Mã OTP {purpose} của bạn là {code}. Mã hết hạn sau 5 phút."
        });

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(15));
        using var response = await httpClientFactory.CreateClient().SendAsync(request, timeout.Token);
        if (response.IsSuccessStatusCode) return;

        var detail = await response.Content.ReadAsStringAsync(timeout.Token);
        logger.LogWarning("Brevo rejected OTP email with HTTP {StatusCode}: {Detail}", (int)response.StatusCode, detail);
        throw new InvalidOperationException($"Brevo không gửi được OTP (HTTP {(int)response.StatusCode}). Kiểm tra API key và email người gửi đã xác minh.");
    }
}
