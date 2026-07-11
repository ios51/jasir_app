import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'otp_screen.dart';

/// شاشة إدخال رقم الجوال لبدء تسجيل الدخول (يُرسل رمز التحقق عبر واتساب).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'اكتب رقم جوالك أولاً');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.requestOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpScreen(phone: phone)),
      );
    } catch (e) {
      debugPrint('OTP request error: $e');
      setState(() => _error = 'تعذر إرسال رمز التحقق، تأكد من الرقم وحاول مرة ثانية');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // شعار جاسر الرسمي (الأيقونة التقنية) — مقصوص بحواف مستديرة لإخفاء زوايا الصورة
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.teal.withOpacity(0.30),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/icon/jasir_icon.png',
                      width: 116,
                      height: 116,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'جاسر',
                textAlign: TextAlign.center,
                style: GoogleFonts.amiri(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'سكرتيرك الخاص، في خدمتك',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: cs.primary),
              ),
              const SizedBox(height: 18),
              Text(
                'يسعد أوقاتك 🌅\nالتفاصيل اللي تشغل بالك — مواعيدك، أدويتك، ومهامك — أنا أمسكها وأذكّرك فيها في وقتها، وأنت مرتاح البال.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15.5, height: 1.8, color: muted),
              ),
              const SizedBox(height: 32),
              Text(
                'ابدأ برقم جوالك المسجّل في جاسر',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: muted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface, fontSize: 18, letterSpacing: 1.5),
                decoration: const InputDecoration(
                  hintText: '05xxxxxxxx',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'يوصلك رمز تحقّق على واتساب خلال ثوانٍ. 🔒 بياناتك تبقى لك وحدك.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: muted),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: TextStyle(color: cs.error),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('ابدأ — أرسل رمز التحقق',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
