import 'package:flutter/material.dart';
import '../../models/reminder.dart';
import '../../services/reminders_service.dart';

class ReminderFormScreen extends StatefulWidget {
  final AppReminder? reminder;
  const ReminderFormScreen({super.key, this.reminder});

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _service = RemindersService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _title;
  DateTime? _date;
  TimeOfDay? _time;
  String _repeatType = 'none';
  bool _saving = false;

  bool get _isEdit => widget.reminder != null;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _title = TextEditingController(text: r?.title ?? '');
    _repeatType = r?.repeatType ?? 'none';
    if (r != null && r.remindAt.isNotEmpty) {
      final parts = r.remindAt.split(' ');
      _date = DateTime.tryParse(parts[0]);
      if (parts.length > 1) {
        final t = parts[1].split(':');
        if (t.length == 2) {
          _time = TimeOfDay(hour: int.tryParse(t[0]) ?? 0, minute: int.tryParse(t[1]) ?? 0);
        }
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر التاريخ والوقت')));
      return;
    }
    setState(() => _saving = true);
    final dateStr =
        '${_date!.year.toString().padLeft(4, '0')}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}';
    final timeStr = '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
    final reminder = AppReminder(
      id: widget.reminder?.id,
      title: _title.text.trim(),
      remindAt: '$dateStr $timeStr',
      repeatType: _repeatType,
    );
    try {
      if (_isEdit) {
        await _service.update(widget.reminder!.id!, reminder);
      } else {
        await _service.create(reminder);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ التذكير')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل التذكير' : 'تذكير جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'نص التذكير', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_date == null
                        ? 'اختر التاريخ'
                        : '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_time == null
                        ? 'اختر الوقت'
                        : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _repeatType,
              decoration: const InputDecoration(labelText: 'التكرار', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('مرة واحدة')),
                DropdownMenuItem(value: 'daily', child: Text('يومي')),
                DropdownMenuItem(value: 'weekly', child: Text('أسبوعي')),
              ],
              onChanged: (v) => setState(() => _repeatType = v ?? 'none'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'حفظ التعديلات' : 'إضافة التذكير'),
            ),
          ],
        ),
      ),
    );
  }
}
