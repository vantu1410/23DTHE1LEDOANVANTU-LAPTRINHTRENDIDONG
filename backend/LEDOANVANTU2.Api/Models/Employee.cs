namespace LEDOANVANTU2.Api.Models;

public sealed class Employee
{
    public int Id { get; set; }
    public required string FullName { get; set; }
    public required string Code { get; set; }
    public string Role { get; set; } = "Nhân viên";
    public bool IsPresent { get; set; }
}
