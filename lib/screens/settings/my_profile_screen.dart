import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/settings_service.dart';

/// شاشة «بياناتي» — بيانات المستخدم نفسه (لا العائلة).
/// تضم «اللقب المفضّل (كيف تحب أناديك)» — يُحفظ في إعدادات المستخدم،
/// منفصلاً عن «اسم العائلة/اللقب». وباقي حقول الهوية.
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final _dio = ApiClient.instance.dio;
  final _settings = SettingsService();
  final _formKey = GlobalKey<FormState>();

  int? _memberId;
  bool _loading = true;
  bool _saving = false;

  final _preferredNick = TextEditingController(); // كيف تحب أناديك → user_settings.nickname
  final _first = TextEditingController();
  final _second = TextEditingController();
  final _third = TextEditingController();
  final _familyName = TextEditingController(); // اسم العائلة/اللقب → family_members.nickname
  final _nationalId = TextEditingController();
  final _nameEn = TextEditingController();
  final _dobHijri = TextEditingController();
  final _passport = TextEditingController();
  String? _dobGreg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_preferredNick, _first, _second, _third, _familyName, _nationalId, _nameEn, _dobHijri, _passport]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = await _dio.get('/api/v1/family/me');
      final m = Map<String, dynamic>.from(me.data as Map);
      _memberId = m['id'] as int?;
      _first.text = (m['first_name'] ?? '').toString();
      _second.text = (m['second_name'] ?? '').toString();
      _third.text = (m['third_name'] ?? '').toString();
      _familyName.text = (m['nickname'] ?? '').toString();
      _nationalId.text = (m['national_id'] ?? '').toString();
      _nameEn.text = (m['name_en'] ?? '').toString();
      _dobHijri.text = (m['dob_hijri'] ?? '').toString();
      _passport.text = (m['passport_no'] ?? '').toString();
      final dg = (m['dob_greg'] ?? '').toString();
      if (dg.isNotEmpty) _dobGreg = dg;
    } catch (_) {}
    try {
      final s = await _settings.getSettings();
      _preferredNick.text = ((s['nickname'] as String?) ?? '').trim();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // 1) بيانات الهوية → family_members (سجل «أنا») — أولاً
      if (_memberId != null) {
        await _dio.put('/api/v1/family/$_memberId', data: {
          'firstName': _first.text.trim(),
          'secondName': _second.text.trim(),
          'thirdName': _third.text.trim(),
          'nickname': _familyName.text.trim(),
          'nationalId': _nationalId.text.trim(),
          'nameEn': _nameEn.text.trim(),
          'dobGreg': _dobGreg ?? '',
          'dobHijri': _dobHijri.text.trim(),
          'passportNo': _passport.text.trim(),
        });
      }
      // 2) اللقب المفضّل → إعدادات المستخدم — آخر خطوة حتى لا يدهسه أي شي
      await _settings.update({'nickname': _preferredNick.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ بياناتك ✅')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
      }
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final cur = DateTime.tryParse(_dobGreg ?? '');
    final d = await showDatePicker(
      context: context,
      initialDate: cur ?? DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (d != null) {
      setState(() => _dobGreg =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
  }

  InputDecoration _dec(String label, {IconData? icon, String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('بياناتي')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // اللقب المفضّل — أبرز حقل
                    Card(
                      color: cs.primaryContainer.withOpacity(0.35),
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(Icons.favorite_outline, size: 18, color: cs.primary),
                            const SizedBox(width: 6),
                            const Text('كيف تحب أناديك؟', style: TextStyle(fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _preferredNick,
                            decoration: _dec('اللقب المفضّل', hint: 'أبو جاسر، أبو عبدالله...'),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _first,
                      decoration: _dec('الاسم الأول', icon: Icons.person_outline),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: _second, decoration: _dec('الاسم الثاني')),
                    const SizedBox(height: 12),
                    TextFormField(controller: _third, decoration: _dec('الاسم الثالث')),
                    const SizedBox(height: 12),
                    TextFormField(controller: _familyName, decoration: _dec('اسم العائلة / اللقب', hint: 'العسيري...')),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nationalId,
                      keyboardType: TextInputType.number,
                      decoration: _dec('رقم الهوية', icon: Icons.badge_outlined),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: _nameEn, decoration: _dec('الاسم بالإنجليزي', hint: 'Ali Jaber')),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDob,
                      child: InputDecorator(
                        decoration: _dec('تاريخ الميلاد (ميلادي)', icon: Icons.calendar_today),
                        child: Text(_dobGreg ?? 'اختر...'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: _dobHijri, decoration: _dec('تاريخ الميلاد (هجري)', hint: '1401-07-14')),
                    const SizedBox(height: 12),
                    TextFormField(controller: _passport, decoration: _dec('رقم الجواز')),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
