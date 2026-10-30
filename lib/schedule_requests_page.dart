import 'package:flutter/material.dart';

import 'services/schedule_request_api.dart';

class ScheduleRequestsPage extends StatefulWidget {
  const ScheduleRequestsPage({
    super.key,
    required this.api,
    required this.isAdmin,
    required this.userId,
  });
  final ScheduleRequestApi api;
  final bool isAdmin;
  final int? userId;
  @override
  State<ScheduleRequestsPage> createState() => _ScheduleRequestsPageState();
}

class _ScheduleRequestsPageState extends State<ScheduleRequestsPage> {
  List<ScheduleEntry> entries = [];
  bool loading = true;
  int? reviewing;
  String? error;
  String filter = 'all';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.list();
      if (mounted) setState(() => entries = result);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    final result = await Navigator.push<ScheduleEntry>(
      context,
      MaterialPageRoute(builder: (_) => _NewRequestPage(api: widget.api)),
    );
    if (!mounted || result == null) return;
    setState(() {
      entries.insert(0, result);
      filter = 'all';
      error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã gửi đơn, chờ quản trị viên duyệt.')),
    );
  }

  Future<void> review(ScheduleEntry entry, bool approve) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Duyệt đơn?' : 'Từ chối đơn?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${entry.name}\n${entry.title} · ${entry.dateLabel} · ${entry.timeLabel}',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú phản hồi (nếu có)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Duyệt' : 'Từ chối'),
          ),
        ],
      ),
    );
    final text = note.text.trim();
    // The dialog may still animate after it returns; its controller is released later.
    Future<void>.delayed(const Duration(milliseconds: 500), note.dispose);
    if (confirmed != true || !mounted) return;
    setState(() => reviewing = entry.id);
    try {
      final saved = await widget.api.review(entry.id, approve, text);
      if (!mounted) return;
      setState(() {
        final i = entries.indexWhere((e) => e.id == entry.id);
        if (i >= 0) entries[i] = saved;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(saved.statusLabel)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => reviewing = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.isAdmin ? 'Duyệt đi muộn / về sớm' : 'Xin đi muộn / về sớm',
      ),
      actions: [
        IconButton(
          onPressed: loading ? null : load,
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Ca chuẩn 08:00–17:00 · Giờ Việt Nam'),
          const SizedBox(height: 8),
          const Text(
            'Gửi thời gian và lý do. Sau khi được duyệt, lượt vào/tan ca nằm trong thời gian cho phép sẽ có nhãn xác nhận trong lịch sử chấm công.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading || reviewing != null ? null : create,
            icon: const Icon(Icons.add),
            label: const Text('Tạo đơn mới'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children:
                {
                      'all': 'Tất cả',
                      'pending': 'Chờ duyệt',
                      'approved': 'Đã duyệt',
                      'rejected': 'Từ chối',
                    }.entries
                    .map(
                      (e) => ChoiceChip(
                        label: Text(e.value),
                        selected: filter == e.key,
                        onSelected: (_) => setState(() => filter = e.key),
                      ),
                    )
                    .toList(),
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(error!),
            ),
          if (!loading &&
              error == null &&
              entries
                  .where((e) => filter == 'all' || e.status == filter)
                  .isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Chưa có đơn trong mục này.'),
            ),
          ...entries
              .where((e) => filter == 'all' || e.status == filter)
              .map(
                (e) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.title} · ${e.statusLabel}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(e.name),
                        const SizedBox(height: 8),
                        Text(
                          '${e.dateLabel} · ${e.type == 'late' ? 'Đến chậm nhất' : 'Về từ'} ${e.timeLabel}',
                        ),
                        Text('Lý do: ${e.reason}'),
                        if (e.reviewer != null)
                          Text('Người xử lý: ${e.reviewer}'),
                        if (e.note.isNotEmpty) Text('Phản hồi: ${e.note}'),
                        if (widget.isAdmin &&
                            e.status == 'pending' &&
                            e.userId != widget.userId)
                          Wrap(
                            spacing: 12,
                            children: [
                              FilledButton(
                                onPressed: reviewing != null
                                    ? null
                                    : () => review(e, true),
                                child: const Text('Duyệt'),
                              ),
                              TextButton(
                                onPressed: reviewing != null
                                    ? null
                                    : () => review(e, false),
                                child: const Text('Từ chối'),
                              ),
                            ],
                          ),
                        if (widget.isAdmin &&
                            e.status == 'pending' &&
                            e.userId == widget.userId)
                          const Text(
                            'Cần quản trị viên khác duyệt đơn của bạn.',
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          if (entries.length >= 100)
            const Text('Đang hiển thị 100 đơn gần nhất.'),
        ],
      ),
    ),
  );
}

class _NewRequestPage extends StatefulWidget {
  const _NewRequestPage({required this.api});
  final ScheduleRequestApi api;
  @override
  State<_NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends State<_NewRequestPage> {
  final reason = TextEditingController();
  String type = 'late';
  late DateTime date = today();
  TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
  bool saving = false;
  String? error;
  DateTime today() {
    final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(vn.year, vn.month, vn.day);
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final minutes = time.hour * 60 + time.minute;
    if (reason.text.trim().isEmpty || minutes <= 480 || minutes >= 1020) {
      setState(() => error = 'Nhập lý do và chọn giờ sau 08:00, trước 17:00.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final saved = await widget.api.create(
        type,
        date,
        minutes,
        reason.text.trim(),
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tạo đơn xin phép')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Loại đơn'),
          items: const [
            DropdownMenuItem(value: 'late', child: Text('Xin đi muộn')),
            DropdownMenuItem(value: 'early', child: Text('Xin về sớm')),
          ],
          onChanged: saving
              ? null
              : (value) => setState(() {
                  type = value!;
                  time = TimeOfDay(hour: type == 'late' ? 9 : 16, minute: 0);
                }),
        ),
        const SizedBox(height: 12),
        ListTile(
          title: const Text('Ngày làm việc'),
          subtitle: Text('${date.day}/${date.month}/${date.year}'),
          trailing: const Icon(Icons.calendar_month),
          onTap: saving
              ? null
              : () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: today(),
                    lastDate: today().add(const Duration(days: 90)),
                  );
                  if (selected != null && mounted) {
                    setState(() => date = selected);
                  }
                },
        ),
        ListTile(
          title: Text(type == 'late' ? 'Giờ dự kiến đến' : 'Giờ xin về sớm'),
          subtitle: Text(
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} · Giờ Việt Nam',
          ),
          trailing: const Icon(Icons.schedule),
          onTap: saving
              ? null
              : () async {
                  final selected = await showTimePicker(
                    context: context,
                    initialTime: time,
                  );
                  if (selected != null && mounted) {
                    setState(() => time = selected);
                  }
                },
        ),
        TextField(
          controller: reason,
          enabled: !saving,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Lý do xin phép'),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(error!),
          ),
        FilledButton(
          onPressed: saving ? null : submit,
          child: Text(saving ? 'Đang gửi…' : 'Gửi đơn'),
        ),
      ],
    ),
  );
}
