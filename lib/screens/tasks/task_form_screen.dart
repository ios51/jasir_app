import 'package:flutter/material.dart';
import '../../services/tasks_service.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _service = TasksService();
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  String _startType = 'immediate';
  String _endType = 'open';
  DateTime? _startDate;
  DateTime? _dueDate;
  bool _saving = false;

  String? _fmt(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.create(
        title: _title.text.trim(),
        startType: _startType,
        startDate: _startType == 'scheduled' ? _fmt(_startDate) : null,
        endType: _endType,
        dueDate: _endType == 'deadline' ? _fmt(_dueDate) : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إضافة المهمة')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مهمة جديدة')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'عنوان المهمة', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            const Text('متى تبدأ؟', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<String>(
              value: 'immediate',
              groupValue: _startType,
              title: const Text('فورية'),
              onChanged: (v) => setState(() => _startType = v!),
            ),
            RadioListTile<String>(
              value: 'scheduled',
              groupValue: _startType,
              title: const Text('بتاريخ لاحق'),
              onChanged: (v) => setState(() => _startType = v!),
            ),
            if (_startType == 'scheduled')
              OutlinedButton.icon(
                onPressed: _pickStartDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(_fmt(_startDate) ?? 'اختر تاريخ البداية'),
              ),
            const SizedBox(height: 16),
            const Text('متى تنتهي؟', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<String>(
              value: 'open',
              groupValue: _endType,
              title: const Text('مفتوحة (بدون موعد نهائي)'),
              onChanged: (v) => setState(() => _endType = v!),
            ),
            RadioListTile<String>(
              value: 'deadline',
              groupValue: _endType,
              title: const Text('بموعد نهائي'),
              onChanged: (v) => setState(() => _endType = v!),
            ),
            if (_endType == 'deadline')
              OutlinedButton.icon(
                onPressed: _pickDueDate,
                icon: const Icon(Icons.event_busy),
                label: Text(_fmt(_dueDate) ?? 'اختر الموعد النهائي'),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('إضافة المهمة'),
            ),
          ],
        ),
      ),
    );
  }
}
