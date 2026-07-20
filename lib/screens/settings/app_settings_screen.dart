import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../theme/theme_controller.dart';
import '../../services/settings_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/bio_lock.dart';
import '../../services/chat_store.dart';
import '../login_screen.dart';
import '../family/medical_files_screen.dart';
import 'my_profile_screen.dart';
import 'nav_tabs_screen.dart';

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
  bool _bioEnabled = false;

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
    await BioLock.load();
    _bioEnabled = BioLock.enabled;
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _toggleBio(bool v) async {
    if (v) {
      if (!await BioLock.deviceSupported()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('جهازك لا يدعم الوجه/البصمة')));
        }
        return;
      }
      // تأكيد بالمصادقة نفسها قبل التفعيل (حتى لا ينقفل عليك بالغلط)
      final ok = await BioLock.authenticate();
      if (!ok) return;
    }
    await BioLock.setEnabled(v);
    if (mounted) setState(() => _bioEnabled = v);
  }

  Future<void> _linkApple() async {
    try {
      final cred = await SignInWithApple.getAppleIDCredential(scopes: const []);
      final t = cred.identityToken;
      if (t == null) throw Exception('no_token');
      await AuthService().linkApple(t);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم الربط ✅ — دخولك الجاي بزر أبل مباشرة')));
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر الربط، حاول مرة ثانية')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر الربط، حاول مرة ثانية')));
      }
    }
  }

  Future<void> _saveReminder(int v) async {
    setState(() => _defaultReminder = v);
    try { await _svc.update({'default_reminder': v}); } catch (_) {}
  }

  /// يفتح شاشة «بياناتي» المخصّصة، أو الملفات الطبية.
  Future<void> _openMyProfile({required bool medical}) async {
    if (!medical) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen()));
      return;
    }
    try {
      final res = await ApiClient.instance.dio.get('/api/v1/family/me');
      final self = Map<String, dynamic>.from(res.data as Map);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) =>
          MedicalFilesScreen(memberId: self['id'] as int, memberName: 'ملفاتي')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح ملفاتي الطبية')));
    }
  }

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
                padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
                child: Text('حسابي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('بياناتي'),
                    subtitle: const Text('الاسم، الهوية، الميلاد، الجواز'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => _openMyProfile(medical: false),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.folder_shared_outlined),
                    title: const Text('رقم الملف الطبي'),
                    subtitle: const Text('رقمك في كل مستشفى'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => _openMyProfile(medical: true),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.dashboard_customize_outlined),
                    title: const Text('تخصيص الشريط السفلي'),
                    subtitle: const Text('اختر الخدمات الثلاث للوصول السريع'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const NavTabsScreen())),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('قفل جاسر بالوجه/البصمة'),
                    subtitle: const Text('طبقة حماية إضافية عند فتح التطبيق'),
                    value: _bioEnabled,
                    onChanged: _loaded ? _toggleBio : null,
                  ),
                  if (Platform.isIOS) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.apple),
                      title: const Text('ربط حساب أبل'),
                      subtitle: const Text('بعده تدخل بزر أبل بلا رمز تحقق'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: _linkApple,
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
                child: Text('المواعيد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
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
              // ── منطقة الخطر: حذف الحساب نهائياً (متطلب أبل + حق المستخدم) ──
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.35),
                child: ListTile(
                  leading: Icon(Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error),
                  title: Text('حذف الحساب نهائياً',
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  subtitle: const Text('تُحذف كل بياناتك من خوادمنا ولا يمكن التراجع'),
                  onTap: _deleteAccount,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// حذف الحساب: تأكيد مزدوج → حذف كل البيانات من السيرفر → خروج لشاشة الدخول
  Future<void> _deleteAccount() async {
    final sure1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب نهائياً؟'),
        content: const Text(
            'سيُحذف كل شيء من خوادمنا بشكل نهائي:\n\n'
            '• مواعيدك وتذكيراتك وأدويتك\n'
            '• مهامك وملاحظاتك وديونك ووثائقك\n'
            '• بيانات عائلتك وجهات اتصالك\n'
            '• حسابك بالكامل\n\n'
            'لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('متابعة الحذف', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (sure1 != true || !mounted) return;
    final sure2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد أخير'),
        content: const Text('متأكد تماماً؟ بياناتك ستُحذف الآن ولن نستطيع استرجاعها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('احذف حسابي نهائياً'),
          ),
        ],
      ),
    );
    if (sure2 != true || !mounted) return;
    try {
      await ApiClient.instance.dio.delete('/api/v1/account');
      try { await ChatStore.clear(); } catch (_) {}
      try { await AuthService().logout(); } catch (_) {}
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حُذف حسابك وبياناتك نهائياً. نتمنى نشوفك مرة ثانية 🌹')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر الحذف — تحقق من الاتصال وحاول مجدداً')));
      }
    }
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
