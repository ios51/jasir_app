import 'package:dio/dio.dart';
import 'api_client.dart';

/// خدمة إعدادات المستخدم — رسالة الصباح (تفعيل، وقت، مختصر/كامل، الأقسام، نص خاص)
/// ومعاينة الرسالة كما ستصل. تتصل بـ /api/v1/settings و /api/v1/morning/preview.
class SettingsService {
  final Dio _dio = ApiClient.instance.dio;

  /// يجلب إعدادات المستخدم (كائن user_settings كامل).
  Future<Map<String, dynamic>> getSettings() async {
    final res = await _dio.get('/api/v1/settings');
    final data = res.data as Map<String, dynamic>;
    return (data['settings'] as Map).cast<String, dynamic>();
  }

  /// يحدّث حقلاً واحداً أو أكثر (يُرسل فقط ما تغيّر).
  Future<void> update(Map<String, dynamic> fields) async {
    await _dio.put('/api/v1/settings', data: fields);
  }

  /// يجلب معاينة رسالة الصباح كنص (full=true تعرض النسخة الكاملة دائماً).
  Future<String> previewMorning({bool full = false}) async {
    final res = await _dio.get('/api/v1/morning/preview',
        queryParameters: full ? {'full': '1'} : null);
    return (res.data as Map)['text'] as String? ?? '';
  }
}
