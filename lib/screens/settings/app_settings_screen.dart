import 'package:flutter/material.dart';
import '../../theme/theme_controller.dart';
import '../../services/settings_service.dart';
import '../../services/api_client.dart';
import '../generic/module_registry.dart';
import '../generic/generic_form_screen.dart';
import '../family/medical_files_screen.dart';

/// إعدادات عامة: بياناتك (الكنية) + التنبيه الافتراضي، المظهر، وحجم الخط.
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _tc = ThemeController.instance;
  final _svc = SettingsService();
  int _defaultReminder = 60;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _svc.getSettings();
      final r = s['default_reminder'];
      if (r is int) _defaultReminder = r; else if (r != null) _defaultReminder = int.tryParse(r.toString()) ?? 60;
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _saveReminder(int v) async {
    setState(() => _defaultReminder = v);
    try { await _svc.update({'default_reminder': v}); } catch (_) {}
  }

  /// يفتح ملف بيانات المستخدم الكامل (نفس نموذج العائلة) أو ملفاته الطبية.
  Future<void> _openMyProfile({required bool medical}) async {
    try {
      final res = await ApiClient.instance.dio.get('/api/v1/family/me');
      final self = Map<String, dynamic>.from(res.data as Map);
      if (!mounted) return;
      if (medical) {
        Navigator.push(context, MaterialPageRoute(builder: (_) =>
            MedicalFilesScreen(memberId: self['id'] as int, memberName: 'بياناتي')));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) =>
            GenericFormScreen(def: ModuleRegistry.family, existing: self)));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح بياناتي')));
    }
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
                padding: EdgeInsets.fromLTRB(4, 4, 4, 4),
                child: Text('بياناتي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text('اسمك، لقبك (كيف تحب أناديك)، وبياناتك — كلها داخل ملفك.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey)),
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('ملف بياناتي الكامل'),
                    subtitle: const Text('اللقب، الاسم، الهوية، الميلاد، الجواز...'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => _openMyProfile(medical: false),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.folder_shared_outlined),
                    title: const Text('ملفاتي الطبية'),
                    subtitle: const Text('رقم الملف لكل مستشفى'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => _openMyProfile(medical: true),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: const [0, 15, 30, 60, 120, 1440, 2880, 4320].contains(_defaultReminder) ? _defaultReminder : 60,
                decoration: const InputDecoration(labelText: 'التنبيه الافتراضي للمواعيد', border: OutlineInputBorder()),
                items: const [0, 15, 30, 60, 120, 1440, 2880, 4320]
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

  static String _labelFor(int m) {
    if (m == 0) return 'بدون';
    if (m == 1440) return 'قبل يوم';
    if (m == 2880) return 'قبل يومين';
    if (m == 4320) return 'قبل ٣ أيام';
    if (m >= 60 && m % 60 == 0) return 'قبل ${m ~/ 60} ساعة';
    return 'قبل $m دقيقة';
  }
}
