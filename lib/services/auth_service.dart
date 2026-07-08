import 'package:dio/dio.dart';
import 'api_client.dart';

class AuthService {
  final Dio _dio = ApiClient.instance.dio;

  /// يطلب من الخادم إرسال رمز تحقق عبر واتساب لرقم الجوال المُعطى.
  Future<void> requestOtp(String phone) async {
    await _dio.post('/api/v1/auth/request-otp', data: {'phone': phone});
  }

  /// يتحقق من الرمز، وعند النجاح يخزّن جلسة الدخول (JWT) محلياً.
  Future<void> verifyOtp(String phone, String code) async {
    final res = await _dio.post('/api/v1/auth/verify-otp', data: {
      'phone': phone,
      'code': code,
    });
    final token = res.data['token'] as String;
    final userId = res.data['userId'] as String;
    await ApiClient.instance.saveSession(token, userId);
  }

  Future<void> logout() => ApiClient.instance.logout();

  Future<bool> isLoggedIn() => ApiClient.instance.isLoggedIn();
}
