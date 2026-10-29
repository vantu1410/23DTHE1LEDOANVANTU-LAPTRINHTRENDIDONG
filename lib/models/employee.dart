class Employee {
  Employee(this.name, this.role, this.code, {this.present = false, this.id});

  final int? id;
  String name;
  String role;
  String code;
  bool present;

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    (json['fullName'] ?? json['name'] ?? '').toString(),
    (json['role'] ?? json['department'] ?? 'Nhân viên').toString(),
    (json['code'] ?? json['employeeCode'] ?? '').toString(),
    present: json['present'] as bool? ?? json['isPresent'] as bool? ?? false,
    id: (json['id'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'fullName': name,
    'role': role,
    'code': code,
    'isPresent': present,
  };
}
