import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

/// عميل HTTP مشترك لكل الخدمات — يضيف التوكن تلقائياً لكل طلب،
/// ويخزّنه بشكل آمن على الجهاز.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      // مهلة أطول لأن قراءة الصور/PDF عبر الذكاء الاصطناعي قد تاخذ وقت
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      // انتهاء توكن السيرفر (٩٠ يوماً من الإصدار — لا يتجدد): أول 401 على
      // مسار محمي → خروج نظيف لشاشة الدخول بدل تطبيق «شكله داخل» وكل
      // طلباته تفشل بصمت.
      onError: (e, handler) async {
        final path = e.requestOptions.path;
        if (e.response?.statusCode == 401 &&
            !path.startsWith('/api/v1/auth/')) {
          if (!_handling401) {
            _handling401 = true;
            try {
              await logout();
              onUnauthorized?.call();
            } finally {
              _handling401 = false;
            }
          }
        }
        handler.next(e);
      },
    ));
  }

  /// يُضبط من main.dart: يوجّه لشاشة الدخول عند انتهاء صلاحية التوكن.
  static void Function()? onUnauthorized;
  static bool _handling401 = false;

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'jasir_token';
  static const String _userIdKey = 'jasir_user_id';
  static const String _lastActiveKey = 'jasir_last_active';

  /// مهلة الخمول: ٩٠ يوماً (أقصى عمر لتوكن السيرفر JWT_EXPIRES='90d') —
  /// كانت ٦ ساعات فكانت تطرد المستخدم يومياً وتُضيع توجيه الإشعارات.
  /// مع الاستخدام اليومي تتجدد تلقائياً فلا يُطلب الرمز عملياً أبداً.
  static const Duration sessionIdleTimeout = Duration(days: 90);

  Dio get dio => _dio;

  Future<void> saveSession(String token, String userId) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    await touch();
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  /// يسجّل آخر لحظة استخدام (يُستدعى عند فتح/استئناف التطبيق والتفاعل معه).
  Future<void> touch() => _storage.write(
        key: _lastActiveKey,
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );

  /// هل مضى أكثر من مهلة الخمول على آخر استخدام؟
  Future<bool> isSessionExpired() async {
    final raw = await _storage.read(key: _lastActiveKey);
    if (raw == null) return false; // ما في ختم بعد → لا نُخرِج
    final last = int.tryParse(raw);
    if (last == null) return false;
    final gap = DateTime.now().millisecondsSinceEpoch - last;
    return gap > sessionIdleTimeout.inMilliseconds;
  }

  /// مُسجّل الدخول = يملك توكن ولم تنتهِ مهلة الخمول. عند صلاحيته نجدّد الختم.
  Future<bool> isLoggedIn() async {
    if ((await getToken()) == null) return false;
    if (await isSessionExpired()) {
      await logout();
      return false;
    }
    await touch();
    return true;
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _lastActiveKey);
  }
}
