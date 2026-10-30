import 'package:flutter/material.dart';

import 'models/employee.dart';

class EmployeeEditorDialog extends StatefulWidget {
  const EmployeeEditorDialog({
    super.key,
    this.existing,
    required this.initialCode,
    required this.save,
  });
  final Employee? existing;
  final String initialCode;
  final Future<Employee> Function(Employee employee) save;

  @override
  State<EmployeeEditorDialog> createState() => _EmployeeEditorDialogState();
}

class _EmployeeEditorDialogState extends State<EmployeeEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _code = TextEditingController(
    text: widget.existing?.code ?? widget.initialCode,
  );
  late final _job = TextEditingController(
    text: widget.existing?.role ?? 'Nhân viên',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _code.dispose();
    _job.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.save(
        Employee(
          _name.text.trim(),
          _job.text.trim(),
          _code.text.trim(),
          id: widget.existing?.id,
          email: _email.text.trim().toLowerCase(),
          userId: widget.existing?.userId,
          present: widget.existing?.present ?? false,
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String? _required(String? text, String label, int max) {
    final value = (text ?? '').trim();
    if (value.isEmpty) return 'Vui lòng nhập $label.';
    if (value.length > max) return '$label tối đa $max ký tự.';
    return null;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        widget.existing == null ? 'Thêm nhân viên' : 'Cập nhật nhân viên',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (v) => _required(v, 'họ tên', 120),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _email,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email tài khoản nhân viên',
                  helperText: 'Nhập email để liên kết với tài khoản nhân viên.',
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  final error = _required(v, 'email', 254);
                  if (error != null) return error;
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(v!.trim())) {
                    return 'Email không hợp lệ.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _code,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Mã nhân viên'),
                validator: (v) => _required(v, 'mã nhân viên', 32),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _job,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Phòng ban / chức vụ',
                ),
                validator: (v) => _required(v, 'chức vụ', 80),
              ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      LinearProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Đang lưu thông tin, vui lòng chờ…'),
                    ],
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
        ),
      ],
    ),
  );
}
