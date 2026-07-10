import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../services/notification_service.dart';
import '../../services/notification_sync.dart';

/// شاشة إعدادات رسالة الصباح — تفعيل/إيقاف، وقت الإرسال، مختصر/كامل،
/// مفاتيح الأقسام الثمانية، نص خاص، ومعاينة مباشرة.
class MorningSettingsScreen extends StatefulWidget {
  const MorningSettingsScreen({super.key});

  @override
  State<MorningSettingsScreen> createState() => _MorningSettingsScreenState();
}

class _MorningSettingsScreenState extends State<MorningSettingsScreen> {
  final _svc = SettingsService();

  bool _loading = true;
  String? _error;
  bool _saving = false;

  // القيم
  bool _enabled = true;
  bool _brief = false;
  String _time = '07:00';
  final _customCtrl = TextEditingController();

  // الأقسام (مفتاح العمود → مفعّل)
  final Map<String, bool> _sections = {
    'show_events': true,
    'show_football': true,
    'show_tasks': true,
    'show_schedule': true,
    'show_meds': true,
    'show_dhikr': true,
    'show_measures': true,
    'show_car': true,
  };

  // التسميات العربية بالترتيب المعروض
  static const List<MapEntry<String, String>> _sectionLabels = [
    MapEntry('show_events', 'المواعيد'),
    MapEntry('show_football', 'مباريات اليوم'),
    MapEntry('show_tasks', 'المهام'),
    MapEntry('show_schedule', 'الجدول والمحاضرات'),
    MapEntry('show_meds', 'متابعة الدواء'),
    MapEntry('show_dhikr', 'ذكر اليوم'),
    MapEntry('show_measures', 'قياسات أمس'),
    MapEntry('show_car', 'السيارة'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  bool _asBool(dynamic v, {bool def = true}) {
    if (v == null) return def;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return v.toString() == '1' || v.toString() == 'true';
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final s = await _svc.getSettings();
      setState(() {
        _enabled = _asBool(s['morning_enabled']);
        _brief = _asBool(s['morning_brief'], def: false);
        _time = (s['morning_time'] as String?)?.isNotEmpty == true ? s['morning_time'] : '07:00';
        _customCtrl.text = (s['morning_custom'] as String?) ?? '';
        for (final k in _sections.keys) {
          _sections[k] = _asBool(s[k]);
        }
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'تعذّر تحميل الإعدادات'; _loading = false; });
    }
  }

  Future<void> _save(Map<String, dynamic> fields) async {
    setState(() => _saving = true);
    try {
      await _svc.update(fields);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر الحفظ — تأكد من الاتصال')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '7') ?? 7,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final t = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() { _time = t; _enabled = true; });
      await _save({'morning_time': t, 'morning_enabled': true});
    }
  }

  Future<void> _preview() async {
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      final txt = await _svc.previewMorning(full: !_brief ? true : false);
      if (!mounted) return;
      Navigator.of(context).pop(); // close loader
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('معاينة رسالة الصباح'),
          content: SingleChildScrollView(
            child: Text(txt.isEmpty ? '(لا يوجد محتوى بعد)' : txt),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّرت المعاينة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('رسالة الصباح'),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                    ]),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      SwitchListTile(
                        title: const Text('تفعيل رسالة الصباح'),
                        subtitle: const Text('تصلك كل يوم في الوقت المحدد'),
                        value: _enabled,
                        onChanged: (v) {
                          setState(() => _enabled = v);
                          _save({'morning_enabled': v});
                        },
                      ),
                      const Divider(),
                      ListTile(
                        enabled: _enabled,
                        leading: const Icon(Icons.access_time),
                        title: const Text('وقت الإرسال'),
                        trailing: Text(_time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onTap: _enabled ? _pickTime : null,
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('الوضع المختصر'),
                        subtitle: const Text('لمحة سريعة: تصبيح + دعاء + صحة + لمحة مواعيد ومهام'),
                        value: _brief,
                        onChanged: _enabled
                            ? (v) {
                                setState(() => _brief = v);
                                _save({'morning_brief': v});
                              }
                            : null,
                      ),
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
                        child: Text('الأقسام التي تظهر في الرسالة',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      ..._sectionLabels.map((e) => SwitchListTile(
                            dense: true,
                            title: Text(e.value),
                            value: _sections[e.key] ?? true,
                            onChanged: _enabled
                                ? (v) {
                                    setState(() => _sections[e.key] = v);
                                    _save({e.key: v});
                                  }
                                : null,
                          )),
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
                        child: Text('نص خاص يظهر في رسالتك',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: _customCtrl,
                          maxLines: 3,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            hintText: 'مثال: لا تنسَ الاتصال بوالدتك',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('حفظ النص'),
                          onPressed: () => _save({'morning_custom': _customCtrl.text.trim()}),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('معاينة رسالة الصباح الآن'),
                        onPressed: _preview,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('فعّل التنبيهات وجرّب تنبيهاً الآن'),
                        onPressed: () async {
                          await NotificationService.requestPermission();
                          await NotificationService.showNow(
                            777,
                            '🌅 جاسر',
                            'التنبيهات تعمل — بتوصلك مواعيدك ومهامك ورسالة الصباح.',
                          );
                          NotificationSync.run();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('أرسلت تنبيهاً تجريبياً وحدّثت التذكيرات')),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),
    );
  }
}
