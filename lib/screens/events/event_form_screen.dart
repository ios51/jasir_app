import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../services/events_service.dart';
import '../../services/notification_sync.dart';

/// شاشة إضافة/تعديل موعد.
class EventFormScreen extends StatefulWidget {
  final AppEvent? event;
  const EventFormScreen({super.key, this.event});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _service = EventsService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _title;
  late TextEditingController _location;
  late TextEditingController _hospital;
  late TextEditingController _clinic;
  late TextEditingController _apptNumber;
  late TextEditingController _doctor;
  late TextEditingController _building;
  late TextEditingController _room;
  late TextEditingController _notes;
  DateTime? _date;
  TimeOfDay? _time;
  int _notifyBefore = 60;
  String _apptType = 'in_person';
  bool _saving = false;
  List<String> _hospitalOptions = [];

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _title = TextEditingController(text: e?.title ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _hospital = TextEditingController(text: e?.hospital ?? '');
    _clinic = TextEditingController(text: e?.clinic ?? '');
    _apptNumber = TextEditingController(text: e?.apptNumber ?? '');
    _doctor = TextEditingController(text: e?.doctorName ?? '');
    _building = TextEditingController(text: e?.buildingNo ?? '');
    _room = TextEditingController(text: e?.roomNo ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _notifyBefore = e?.notifyBefore ?? 60;
    _apptType = e?.apptType ?? 'in_person';
    if (e?.eventDate != null) {
      _date = DateTime.tryParse(e!.eventDate!);
    }
    if (e?.eventTime != null) {
      final parts = e!.eventTime!.split(':');
      if (parts.length == 2) {
        _time = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
      }
    }
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    final list = await _service.hospitals();
    if (mounted) setState(() => _hospitalOptions = list);
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

  String? get _dateStr => _date == null
      ? null
      : '${_date!.year.toString().padLeft(4, '0')}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}';

  String? get _timeStr =>
      _time == null ? null : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';

  static String _reminderLabel(int m) {
    if (m == 0) return 'بدون تذكير';
    if (m == 1440) return 'قبل يوم';
    if (m == 2880) return 'قبل يومين';
    if (m == 4320) return 'قبل ٣ أيام';
    if (m >= 60 && m % 60 == 0) return 'قبل ${m ~/ 60} ساعة';
    return 'قبل $m دقيقة';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final event = AppEvent(
      id: widget.event?.id,
      title: _title.text.trim(),
      eventDate: _dateStr,
      eventTime: _timeStr,
      location: _location.text.trim(),
      notifyBefore: _notifyBefore,
      doctorName: _doctor.text.trim(),
      buildingNo: _building.text.trim(),
      roomNo: _room.text.trim(),
      notes: _notes.text.trim(),
      apptType: _apptType,
      hospital: _hospital.text.trim(),
      clinic: _clinic.text.trim(),
      apptNumber: _apptNumber.text.trim(),
    );
    try {
      if (_isEdit) {
        await _service.update(widget.event!.id!, event);
      } else {
        await _service.create(event);
      }
      NotificationSync.run(); // أعد جدولة التنبيهات لتشمل هذا الموعد فوراً
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ الموعد')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل الموعد' : 'موعد جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'عنوان الموعد', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_dateStr ?? 'اختر التاريخ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_timeStr ?? 'اختر الوقت'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _apptType,
              decoration: const InputDecoration(labelText: 'نوع الموعد', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'in_person', child: Text('🏥 حضوري')),
                DropdownMenuItem(value: 'remote', child: Text('📞 عن بُعد')),
              ],
              onChanged: (v) => setState(() => _apptType = v ?? 'in_person'),
            ),
            const SizedBox(height: 12),
            // المستشفى/المجمع مع اقتراحات من قائمة جاهزة (وتُضاف تلقائياً لو جديد)
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _hospital.text),
              optionsBuilder: (v) {
                final q = v.text.trim();
                if (q.isEmpty) return _hospitalOptions;
                return _hospitalOptions.where((h) => h.contains(q));
              },
              onSelected: (s) => _hospital.text = s,
              fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                return TextFormField(
                  controller: ctrl,
                  focusNode: focus,
                  onChanged: (t) => _hospital.text = t,
                  decoration: const InputDecoration(
                    labelText: 'المستشفى / المجمع',
                    hintText: 'اكتب أو اختر من القائمة',
                    prefixIcon: Icon(Icons.local_hospital_outlined),
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clinic,
              decoration: const InputDecoration(labelText: 'العيادة / القسم', prefixIcon: Icon(Icons.medical_services_outlined), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _apptNumber,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(labelText: 'رقم الموعد', prefixIcon: Icon(Icons.confirmation_number_outlined), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'المكان / رابط الموقع', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _building,
                    decoration: const InputDecoration(labelText: 'رقم المبنى', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _room,
                    decoration: const InputDecoration(labelText: 'رقم الغرفة/العيادة', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _doctor,
              decoration: const InputDecoration(labelText: 'اسم الطبيب (اختياري)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: const [0, 15, 30, 60, 120, 1440, 2880, 4320].contains(_notifyBefore) ? _notifyBefore : 60,
              decoration: const InputDecoration(labelText: 'التذكير قبل الموعد', border: OutlineInputBorder()),
              items: const [0, 15, 30, 60, 120, 1440, 2880, 4320]
                  .map((m) => DropdownMenuItem(value: m, child: Text(_reminderLabel(m))))
                  .toList(),
              onChanged: (v) => setState(() => _notifyBefore = v ?? 60),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'حفظ التعديلات' : 'إضافة الموعد'),
            ),
          ],
        ),
      ),
    );
  }
}
