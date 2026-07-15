import 'package:dio/dio.dart';
import 'api_client.dart';

/// حساب أبل غير مربوط بعد بأي حساب جاسر — يلزم دخول برقم الجوال مرة
/// واحدة (يُربط تلقائياً) وبعدها الدخول بزر أبل مباشرة.
class AppleNotLinkedException implements Exception {}

class AuthService {
  final Dio _dio = ApiClient.instance.dio;

  /// توكن أبل معلّق: التقطه زر أبل لكن الحساب غير مربوط — يُمرَّر مع
  /// رمز التحقق ليتم الربط تلقائياً في نفس الدخول.
  static String? pendingAppleToken;

  /// يطلب من الخادم إرسال رمز تحقق عبر واتساب لرقم الجوال المُعطى.
  Future<void> requestOtp(String phone) async {
    await _dio.post('/api/v1/auth/request-otp', data: {'phone': phone});
  }

  /// يتحقق من الرمز، وعند النجاح يخزّن جلسة الدخول (JWT) محلياً.
  /// [appleIdentityToken] اختياري: يربط حساب أبل بهذا الحساب تلقائياً.
  Future<void> verifyOtp(String phone, String code,
      {String? appleIdentityToken}) async {
    final res = await _dio.post('/api/v1/auth/verify-otp', data: {
      'phone': phone,
      'code': code,
      if (appleIdentityToken != null) 'appleIdentityToken': appleIdentityToken,
    });
    final token = res.data['token'] as String;
    final userId = res.data['userId'] as String;
    await ApiClient.instance.saveSession(token, userId);
  }

  /// الدخول بحساب أبل: إن كان مربوطاً يدخل مباشرة، وإلا يرمي
  /// [AppleNotLinkedException].
  Future<void> appleLogin(String identityToken) async {
    try {
      final res = await _dio.post('/api/v1/auth/apple',
          data: {'identityToken': identityToken});
      await ApiClient.instance.saveSession(
          res.data['token'] as String, res.data['userId'] as String);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 404 &&
          data is Map &&
          data['error'] == 'not_linked') {
        throw AppleNotLinkedException();
      }
      rethrow;
    }
  }

  /// ربط حساب أبل بالحساب الحالي (من الإعدادات، يتطلب جلسة صالحة).
  Future<void> linkApple(String identityToken) async {
    await _dio.post('/api/v1/auth/apple/link',
        data: {'identityToken': identityToken});
  }

  Future<void> logout() => ApiClient.instance.logout();

  Future<bool> isLoggedIn() => ApiClient.instance.isLoggedIn();
}
