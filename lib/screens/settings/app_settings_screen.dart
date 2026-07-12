import 'package:flutter/material.dart';
import '../../theme/theme_controller.dart';
import '../../services/settings_service.dart';

/// إعدادات عامة: بياناتك (الكنية) + التنبيه الافتراضي، المظهر، وحجم الخط.
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _tc = ThemeController.instance;
  final _svc = SettingsService();
  final _kunya = TextEditingController();
  int _defaultReminder = 60;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _kunya.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await _svc.getSettings();
      _kunya.text = (s['nickname'] as String?) ?? '';
      final r = s['default_reminder'];
      if (r is int) _defaultReminder = r; else if (r != null) _defaultReminder = int.tryParse(r.toString()) ?? 60;
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _saveKunya() async {
    try {
      await _svc.update({'nickname': _kunya.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
    } catch (_) {}
  }

  Future<void> _saveReminder(int v) async {
    setState(() => _defaultReminder = v);
    try { await _svc.update({'default_reminder': v}); } catch (_) {}
  }

  String _remLabel(int m) => m == 0 ? 'بدون' : m == 1440 ? 'قبل يوم' : m == 60 ? 'قبل ساعة' : 'قبل $m دقيقة';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: AnimatedBuilder(
          animation: _tc,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text('بياناتي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              TextField(
                controller: _kunya,
                decoration: InputDecoration(
                  labelText: 'شنو تحب جاسر يناديك؟',
                  hintText: 'أبو جاسر',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.check), onPressed: _loaded ? _saveKunya : null),
                ),
                onSubmitted: (_) => _saveKunya(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _defaultReminder,
                decoration: const InputDecoration(labelText: 'التنبيه الافتراضي للمواعيد', border: OutlineInputBorder()),
                items: const [0, 15, 30, 60, 120, 1440]
                    .map((m) => DropdownMenuItem(value: m, child: Text(_labelFor(m))))
                    .toList(),
                onChanged: (v) => _saveReminder(v ?? 60),
              ),
              const Divider(height: 32),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text('المظهر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('تلقائي (حسب الجهاز)'),
                value: ThemeMode.system,
                groupValue: _tc.mode,
                onChanged: (v) => _tc.setMode(v!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('فاتح'),
                value: ThemeMode.light,
                groupValue: _tc.mode,
                onChanged: (v) => _tc.setMode(v!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('داكن'),
                value: ThemeMode.dark,
                groupValue: _tc.mode,
                onChanged: (v) => _tc.setMode(v!),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
                child: Text('حجم الخط', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Row(
                children: [
                  const Text('أ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Slider(
                      min: 0.85,
                      max: 1.4,
                      divisions: 11,
                      value: _tc.fontScale.clamp(0.85, 1.4),
                      label: '${(_tc.fontScale * 100).round()}%',
                      onChanged: (v) => _tc.setFontScale(v),
                    ),
                  ),
                  const Text('أ', style: TextStyle(fontSize: 26)),
                ],
              ),
              Center(
                child: Text('معاينة: صباح الخير، عندك موعد بكرة',
                    style: TextStyle(fontSize: 16 * _tc.fontScale)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _labelFor(int m) =>
      m == 0 ? 'بدون' : m == 1440 ? 'قبل يوم' : m == 60 ? 'قبل ساعة' : 'قبل $m دقيقة';
}
