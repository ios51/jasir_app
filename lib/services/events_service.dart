import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/event.dart';

class EventsService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<AppEvent>> list({bool upcomingOnly = true}) async {
    final res = await _dio.get('/api/v1/events', queryParameters: {
      'upcoming': upcomingOnly ? '1' : '0',
    });
    return (res.data as List).map((e) => AppEvent.fromJson(e)).toList();
  }

  Future<int> create(AppEvent event) async {
    final res = await _dio.post('/api/v1/events', data: event.toJson());
    return res.data['id'] as int;
  }

  Future<void> update(int id, AppEvent event) async {
    await _dio.put('/api/v1/events/$id', data: event.toJson());
  }

  Future<void> delete(int id) async {
    await _dio.delete('/api/v1/events/$id');
  }

  /// قائمة أسماء المستشفيات/المجمعات (عامة + خاصة بالمستخدم) لقائمة الاختيار.
  Future<List<String>> hospitals() async {
    try {
      final res = await _dio.get('/api/v1/hospitals');
      return (res.data as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }
}
