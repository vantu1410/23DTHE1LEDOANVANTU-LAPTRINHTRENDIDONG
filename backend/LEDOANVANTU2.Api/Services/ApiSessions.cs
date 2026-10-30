using System.Security.Cryptography;
using System.Text;
using LEDOANVANTU2.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace LEDOANVANTU2.Api.Services;

public static class ApiSessions
{
    public static string Hash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    public static async Task<bool> IsActiveAsync(AppDbContext db, int userId, string token, CancellationToken ct)
    {
        var hash = Hash(token);
        return await db.Users.AnyAsync(u => u.Id == userId && u.EmailVerified, ct)
            && !await db.FeatureRecords.AnyAsync(r => r.UserId == userId && r.Kind == "revoked-token" && r.Data == hash, ct);
    }
}
