import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../main.dart' show maybeOpenAdhkar;
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
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
      // ملاحظة: AuthService.pendingAppleToken (إن وُجد) يُترك عمداً —
      // هذا هو مسار «أول دخول بأبل → جوال مرة واحدة» والربط يتم مع الرمز.
      // التوكن قصير العمر (~١٠ دقائق) والسيرفر يتحقق منه، ففشله لا يضر.
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

  /// الدخول بحساب أبل: إن كان مربوطاً يدخل مباشرة؛ وإلا نوجهه لإدخال
  /// رقم جواله مرة واحدة (يُربط تلقائياً مع رمز التحقق) وبعدها أبل دائماً.
  Future<void> _appleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await SignInWithApple.getAppleIDCredential(scopes: const []);
      final token = cred.identityToken;
      if (token == null) throw Exception('no_identity_token');
      try {
        await _authService.appleLogin(token);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (r) => false);
        // نفس ضمانات مسار OTP: استعادة توجيه إشعار ضائع + أذكار وقتها
        final p = NotificationService.takePendingPayload();
        if (p != null) NotificationService.onSelectPayload?.call(p);
        maybeOpenAdhkar();
        return;
      } on AppleNotLinkedException {
        AuthService.pendingAppleToken = token;
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('أول دخول بحساب أبل'),
              content: const Text(
                  'أدخل رقم جوالك المسجّل في جاسر مرة واحدة فقط — بيرتبط حسابك '
                  'بأبل تلقائياً، ومن بعدها زر أبل يدخلك مباشرة بلا أي رمز.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('تمام')),
              ],
            ),
          ),
        );
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      if (e.code != AuthorizationErrorCode.canceled) {
        setState(() => _error = 'تعذر الدخول بحساب أبل، جرّب رقم الجوال');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر الدخول بحساب أبل، جرّب رقم الجوال');
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
                        color: cs.primary.withOpacity(0.30),
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
              if (Platform.isIOS) ...[
                const SizedBox(height: 18),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('أو', style: TextStyle(color: muted)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: SignInWithAppleButton(
                    text: 'الدخول بحساب أبل',
                    onPressed: _loading ? () {} : _appleLogin,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
