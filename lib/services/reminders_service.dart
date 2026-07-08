import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/reminder.dart';

class RemindersService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<AppReminder>> list() async {
    final res = await _dio.get('/api/v1/reminders');
    return (res.data as List).map((e) => AppReminder.fromJson(e)).toList();
  }

  Future<int> create(AppReminder reminder) async {
    final res = await _dio.post('/api/v1/reminders', data: reminder.toJson());
    return res.data['id'] as int;
  }

  Future<void> update(int id, AppReminder reminder) async {
    await _dio.put('/api/v1/reminders/$id', data: reminder.toJson());
  }

  Future<void> delete(int id) async {
    await _dio.delete('/api/v1/reminders/$id');
  }
}
