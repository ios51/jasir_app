import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/task.dart';

class TasksResult {
  final List<AppTask> owned;
  final List<AppTask> shared;
  TasksResult(this.owned, this.shared);
}

class TasksService {
  final Dio _dio = ApiClient.instance.dio;

  Future<TasksResult> list({bool includeCompleted = false}) async {
    final res = await _dio.get('/api/v1/tasks',
        queryParameters: includeCompleted ? {'all': '1'} : null);
    final owned = (res.data['owned'] as List).map((e) => AppTask.fromJson(e)).toList();
    final shared = (res.data['shared'] as List).map((e) => AppTask.fromJson(e)).toList();
    return TasksResult(owned, shared);
  }

  Future<AppTask> getDetail(int id) async {
    final res = await _dio.get('/api/v1/tasks/$id');
    return AppTask.fromJson(res.data);
  }

  Future<int> create({
    required String title,
    String startType = 'immediate',
    String? startDate,
    String endType = 'open',
    String? dueDate,
  }) async {
    final res = await _dio.post('/api/v1/tasks', data: {
      'title': title,
      'startType': startType,
      'startDate': startDate,
      'endType': endType,
      'dueDate': dueDate,
    });
    return res.data['id'] as int;
  }

  Future<void> complete(int id) => _dio.post('/api/v1/tasks/$id/complete');

  Future<void> delete(int id) => _dio.delete('/api/v1/tasks/$id');

  Future<void> setProgress(int id, int pct) =>
      _dio.post('/api/v1/tasks/$id/progress', data: {'pct': pct});

  Future<int> addSubtask(int taskId, String title, {String? assigneeName}) async {
    final res = await _dio.post('/api/v1/tasks/$taskId/subtasks', data: {
      'title': title,
      'assigneeName': assigneeName,
    });
    return res.data['id'] as int;
  }

  Future<void> completeSubtask(int subtaskId) =>
      _dio.post('/api/v1/subtasks/$subtaskId/complete');

  Future<void> share(int taskId, String contactName) =>
      _dio.post('/api/v1/tasks/$taskId/share', data: {'name': contactName});

  /// يطلّع كود دعوة للمهمة (لربط الفريق بدون اشتراط جهة اتصال مرتبطة).
  Future<String> invite(int taskId) async {
    final res = await _dio.post('/api/v1/tasks/$taskId/invite');
    return res.data['code'] as String;
  }

  /// الانضمام لمهمة بكود.
  Future<void> joinByCode(String code) =>
      _dio.post('/api/v1/tasks/join', data: {'code': code});
}
