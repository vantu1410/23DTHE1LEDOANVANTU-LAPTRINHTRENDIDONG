using LEDOANVANTU2.Api.Data;
using LEDOANVANTU2.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace LEDOANVANTU2.Api.Services;

public static class EmployeeRegistration
{
    // The caller saves this profile together with the successful OTP verification.
    public static async Task<string?> EnsureProfileAsync(AppDbContext db, AppUser user, CancellationToken ct)
    {
        if (user.Role != "Employee" || await db.Employees.AnyAsync(e => e.UserId == user.Id, ct))
            return null;

        var email = user.Email.Trim().ToLowerInvariant();
        var existing = await db.Employees.SingleOrDefaultAsync(e => e.Email.ToLower() == email, ct);
        if (existing is not null)
        {
            if (existing.UserId.HasValue || NormalizeName(existing.FullName) != NormalizeName(user.FullName))
                return "Email đã có hồ sơ nhân viên khác. Vui lòng nhờ quản trị viên kiểm tra họ tên và liên kết tài khoản.";

            existing.UserId = user.Id;
            existing.Email = email;
            return null;
        }

        var baseCode = $"NV-{user.Id:D3}";
        var code = baseCode;
        for (var suffix = 1; await db.Employees.AnyAsync(e => e.Code == code, ct); suffix++)
            code = $"{baseCode}-{suffix}";

        db.Employees.Add(new Employee
        {
            Email = email,
            UserId = user.Id,
            FullName = user.FullName.Trim(),
            Code = code,
            Role = "Nhân viên"
        });
        return null;
    }

    public static string NormalizeName(string value) =>
        string.Join(" ", value.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries)).ToLowerInvariant();
}
