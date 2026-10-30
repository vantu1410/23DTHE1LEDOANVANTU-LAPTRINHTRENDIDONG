class PunchRecord {
  PunchRecord(
    this.action,
    this.time,
    this.place,
    this.method, {
    this.recordId,
    this.userId,
    this.employeeName,
    this.username,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.distanceFromOfficeMeters,
    this.overtimeMinutes,
    this.approvalLabel,
  });

  final String action;
  final DateTime time;
  final String place;
  final String method;
  final int? recordId;
  final int? userId;
  final String? employeeName;
  final String? username;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final double? distanceFromOfficeMeters;
  final int? overtimeMinutes;
  final String? approvalLabel;
}
