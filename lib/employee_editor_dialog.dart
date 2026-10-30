import 'package:flutter/material.dart';

import 'models/employee.dart';

typedef EmployeeEditorSave = Future<Employee> Function(
  Employee employee, {
  String? username,
  String? initialPassword,
});

class EmployeeEditorDialog extends StatefulWidget {
  const EmployeeEditorDialog({
    super.key,
    this.existing,
    required this.initialCode,
    required this.save,
  });
  final Employee? existing;
  final String initialCode;
  final EmployeeEditorSave save;

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
  final _username = TextEditingController();
  final _initialPassword = TextEditingController();
  bool _saving = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _code.dispose();
    _job.dispose();
    _username.dispose();
    _initialPassword.dispose();
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
        username: widget.existing == null && _username.text.trim().isNotEmpty
            ? _username.text.trim()
            : null,
        initialPassword:
            widget.existing == null && _initialPassword.text.isNotEmpty
            ? _initialPassword.text
            : null,
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
                decoration: InputDecoration(
                  labelText: 'Email tài khoản nhân viên',
                  helperText: widget.existing == null
                      ? 'Email nhận OTP khi đăng nhập; tài khoản đã có sẽ được liên kết.'
                      : 'Nhập email để liên kết với tài khoản nhân viên.',
                  helperMaxLines: 3,
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
                textInputAction: widget.existing == null
                    ? TextInputAction.next
                    : TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Phòng ban / chức vụ',
                ),
                validator: (v) => _required(v, 'chức vụ', 80),
              ),
              if (widget.existing == null) ...[
                const SizedBox(height: 20),
                const Text(
                  'Tài khoản đăng nhập',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nếu email chưa có tài khoản, nhập mật khẩu ban đầu để nhân viên đăng nhập ngay, không cần đăng ký. Nếu đã có tài khoản, giữ nguyên mật khẩu hiện tại.',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('employee-username'),
                  controller: _username,
                  enabled: !_saving,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập (không bắt buộc)',
                    helperText: 'Để trống: dùng mã nhân viên. Có thể đăng nhập bằng email.',
                    helperMaxLines: 2,
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isNotEmpty &&
                        (value.length < 3 || value.length > 40)) {
                      return 'Tên đăng nhập phải từ 3 đến 40 ký tự.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('employee-initial-password'),
                  controller: _initialPassword,
                  enabled: !_saving,
                  textInputAction: TextInputAction.done,
                  obscureText: _hidePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const <String>[],
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu ban đầu',
                    helperText:
                        'Bắt buộc khi tạo tài khoản mới; từ 8 đến 128 ký tự.',
                    helperMaxLines: 2,
                    suffixIcon: IconButton(
                      onPressed: _saving
                          ? null
                          : () =>
                                setState(() => _hidePassword = !_hidePassword),
                      tooltip: _hidePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) {
                    final value = v ?? '';
                    if (value.isNotEmpty &&
                        (value.length < 8 || value.length > 128)) {
                      return 'Mật khẩu phải từ 8 đến 128 ký tự.';
                    }
                    return null;
                  },
                ),
              ],
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
