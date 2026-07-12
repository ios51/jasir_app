import 'package:flutter/material.dart';
import '../../services/module_service.dart';
import '../../services/notification_sync.dart';

/// شاشة إضافة/تعديل دواء — بواجهة ذكية:
/// قائمة منسدلة (أوقات ثابتة / كل عدد ساعات / كل عدد أيام)،
/// ويظهر الحقل المناسب حسب الاختيار.
class MedsFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const MedsFormScreen({super.key, this.existing});

  @override
  State<MedsFormScreen> createState() => _MedsFormScreenState();
}

class _MedsFormScreenState extends State<MedsFormScreen> {
  final _svc = ModuleService('/api/v1/meds');
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _name;
  late TextEditingController _dose;
  late TextEditingController _person;
  late TextEditingController _timeSlots;   // للأوقات الثابتة
  late TextEditingController _interval;    // عدد الساعات/الأيام بين الجرعات
  late TextEditingController _duration;    // مدة العلاج بالأيام
  late TextEditingController _totalPills;
  late TextEditingController _confirmAfter;
  TimeOfDay? _firstDose;                    // وقت أول جرعة (لوضع التكرار)
  DateTime? _startDate;
  String _mode = 'fixed';                   // fixed | hours | days
  bool _saving = false;

  bool get _isEdit => widget.existing != null && widget.existing!['id'] != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing ?? {};
    _name = TextEditingController(text: (m['name'] ?? '').toString());
    _dose = TextEditingController(text: (m['dose'] ?? '').toString());
    _person = TextEditingController(text: (m['person_name'] ?? '').toString());
    _timeSlots = TextEditingController(text: (m['time_slots'] ?? '').toString());
    _duration = TextEditingController(text: (m['duration_days'] ?? '').toString());
    _totalPills = TextEditingController(text: (m['total_pills'] ?? '').toString());
    _confirmAfter = TextEditingController(text: (m['confirm_after'] ?? '').toString());

    // استنتاج الوضع الحالي من البيانات
    final tm = (m['time_mode'] ?? 'fixed').toString();
    final ih = int.tryParse((m['interval_hours'] ?? '').toString());
    if (tm == 'interval' && ih != null && ih > 0) {
      if (ih % 24 == 0) {
        _mode = 'days';
        _interval = TextEditingController(text: (ih ~/ 24).toString());
      } else {
        _mode = 'hours';
        _interval = TextEditingController(text: ih.toString());
      }
    } else {
      _mode = 'fixed';
      _interval = TextEditingController();
    }

    final fd = (m['first_dose_time'] ?? '').toString();
    if (fd.contains(':')) {
      final p = fd.split(':');
      _firstDose = TimeOfDay(hour: int.tryParse(p[0]) ?? 8, minute: int.tryParse(p[1]) ?? 0);
    }
    final sd = (m['start_date'] ?? '').toString();
    _startDate = DateTime.tryParse(sd);
  }

  @override
  void dispose() {
    for (final c in [_name, _dose, _person, _timeSlots, _interval, _duration, _totalPills, _confirmAfter]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _fmtTime(TimeOfDay? t) =>
      t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String? _fmtDate(DateTime? d) =>
      d == null ? null : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // تحقق إضافي حسب الوضع
    if (_mode == 'fixed' && _timeSlots.text.trim().isEmpty) {
      _snack('اكتب أوقات الجرعات (مثال 08:00,20:00)');
      return;
    }
    if (_mode != 'fixed') {
      if ((int.tryParse(_interval.text.trim()) ?? 0) <= 0) {
        _snack(_mode == 'hours' ? 'اكتب عدد الساعات بين الجرعات' : 'اكتب عدد الأيام بين الجرعات');
        return;
      }
      if (_firstDose == null) {
        _snack('اختر وقت أول جرعة');
        return;
      }
    }

    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'dose': _dose.text.trim(),
      'personName': _person.text.trim(),
      'durationDays': int.tryParse(_duration.text.trim()) ?? 0,
    };
    if (_totalPills.text.trim().isNotEmpty) body['totalPills'] = int.tryParse(_totalPills.text.trim());
    if (_confirmAfter.text.trim().isNotEmpty) body['confirmAfter'] = int.tryParse(_confirmAfter.text.trim());
    if (_startDate != null) body['startDate'] = _fmtDate(_startDate);

    if (_mode == 'fixed') {
      body['timeMode'] = 'fixed';
      body['timeSlots'] = _timeSlots.text.trim();
    } else {
      body['timeMode'] = 'interval';
      final n = int.parse(_interval.text.trim());
      body['intervalHours'] = _mode == 'days' ? n * 24 : n;
      body['firstDoseTime'] = _fmtTime(_firstDose);
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _svc.update(widget.existing!['id'] as int, body);
      } else {
        await _svc.create(body);
      }
      NotificationSync.run();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('تعذر الحفظ: $e');
      }
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'تعديل الدواء' : 'دواء جديد')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الدواء', prefixIcon: Icon(Icons.medication_outlined), border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم الدواء مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dose,
                decoration: const InputDecoration(labelText: 'الجرعة', hintText: 'حبة، 5مل...', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _person,
                decoration: const InputDecoration(labelText: 'المريض / لمن؟', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _mode,
                decoration: const InputDecoration(labelText: 'طريقة الجرعات', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'fixed', child: Text('أوقات ثابتة')),
                  DropdownMenuItem(value: 'hours', child: Text('كل عدد ساعات')),
                  DropdownMenuItem(value: 'days', child: Text('كل عدد أيام')),
                ],
                onChanged: (v) => setState(() => _mode = v ?? 'fixed'),
              ),
              const SizedBox(height: 12),
              // الحقل المتغيّر حسب الاختيار
              if (_mode == 'fixed')
                TextFormField(
                  controller: _timeSlots,
                  decoration: const InputDecoration(
                    labelText: 'أوقات الجرعات',
                    hintText: '08:00,14:00,21:00',
                    prefixIcon: Icon(Icons.schedule_outlined),
                    border: OutlineInputBorder(),
                  ),
                )
              else ...[
                TextFormField(
                  controller: _interval,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _mode == 'hours' ? 'عدد الساعات بين الجرعات' : 'عدد الأيام بين الجرعات',
                    hintText: _mode == 'hours' ? 'مثال: 8' : 'مثال: 1',
                    prefixIcon: const Icon(Icons.repeat),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: _firstDose ?? const TimeOfDay(hour: 8, minute: 0));
                    if (t != null) setState(() => _firstDose = t);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'وقت أول جرعة',
                      prefixIcon: Icon(Icons.access_time),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_fmtTime(_firstDose) ?? 'اختر...'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'مدة العلاج بالأيام (0 = مستمر)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _totalPills,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'عدد الحبات الكلي (اختياري)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (d != null) setState(() => _startDate = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ البدء',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_fmtDate(_startDate) ?? 'اليوم'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmAfter,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'تنبيه المتابِع بعد (دقيقة)',
                  hintText: '30',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'جاري الحفظ...' : (_isEdit ? 'حفظ التعديلات' : 'إضافة الدواء')),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
