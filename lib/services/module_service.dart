import 'package:dio/dio.dart';
import 'api_client.dart';

/// خدمة CRUD عامة لكل موديولات جاسر (أدوية، وثائق، عائلة، سيارات...).
/// تتعامل مع البيانات كـ Map مرنة بدل نماذج صارمة، فتغطي 12 خدمة بكود واحد.
class ModuleService {
  final Dio _dio = ApiClient.instance.dio;
  final String path; // e.g. '/api/v1/meds'

  ModuleService(this.path);

  Future<List<Map<String, dynamic>>> list({Map<String, dynamic>? query}) async {
    final res = await _dio.get(path, queryParameters: query);
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    // بعض النقاط ترجع كائناً يلفّ عدة قوائم (مثل follows / settings)
    if (data is Map) return [Map<String, dynamic>.from(data)];
    return [];
  }

  Future<Map<String, dynamic>> raw({Map<String, dynamic>? query, String? sub}) async {
    final res = await _dio.get(sub == null ? path : '$path$sub', queryParameters: query);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<int?> create(Map<String, dynamic> body) async {
    final res = await _dio.post(path, data: body);
    final d = res.data;
    return (d is Map && d['id'] != null) ? d['id'] as int : null;
  }

  Future<void> update(int id, Map<String, dynamic> body) =>
      _dio.put('$path/$id', data: body);

  Future<void> delete(int id) => _dio.delete('$path/$id');

  Future<Map<String, dynamic>> action(int id, String verb, {Map<String, dynamic>? body}) async {
    final res = await _dio.post('$path/$id/$verb', data: body ?? {});
    return (res.data is Map) ? Map<String, dynamic>.from(res.data as Map) : {'ok': true};
  }

  /// PUT بدون معرّف (لنقاط مثل /settings و /quran)
  Future<void> put(Map<String, dynamic> body) => _dio.put(path, data: body);
}
