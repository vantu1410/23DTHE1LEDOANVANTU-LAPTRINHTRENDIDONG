using LEDOANVANTU2.Api.Models;

namespace LEDOANVANTU2.Api.Services;

public static class ScheduleApproval
{
    public static string? Label(ScheduleRequest request, int userId, string punchType, DateTime localTime)
    {
        if (request.UserId != userId || request.Status != "approved" ||
            request.WorkDate != DateOnly.FromDateTime(localTime)) return null;
        var minutes = localTime.Hour * 60 + localTime.Minute;
        if (punchType == "checkIn" && request.Type == "late" && minutes > 8 * 60 && minutes <= request.TimeMinutes)
            return "Đi muộn đã được duyệt";
        if (punchType == "checkOut" && request.Type == "early" && minutes < 17 * 60 && minutes >= request.TimeMinutes)
            return "Về sớm đã được duyệt";
        return null;
    }
}
