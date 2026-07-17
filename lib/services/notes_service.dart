import 'package:dio/dio.dart';
import 'api_client.dart';

/// ملاحظة ذكية: بلا تواريخ — تثبيت + لون دلالي، والفرز من السيرفر
/// (المثبّت أولاً ثم الأحدث تعديلاً).
class Note {
  final int id;
  final String text;
  final String color;
  final bool pinned;
  final String updatedAt;

  Note({required this.id, required this.text, required this.color, required this.pinned, required this.updatedAt});

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: (j['id'] as num).toInt(),
        text: (j['text'] ?? '').toString(),
        color: (j['color'] ?? 'default').toString(),
        pinned: j['pinned'] == 1 || j['pinned'] == true,
        updatedAt: (j['updated_at'] ?? '').toString(),
      );
}

class NotesService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<Note>> list() async {
    final res = await _dio.get('/api/v1/notes');
    return (res.data as List).map((e) => Note.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<int> add(String text, {String color = 'default'}) async {
    final res = await _dio.post('/api/v1/notes', data: {'text': text, 'color': color});
    return (res.data['id'] as num).toInt();
  }

  Future<void> update(int id, {String? text, String? color, bool? pinned}) => _dio.put('/api/v1/notes/$id', data: {
        if (text != null) 'text': text,
        if (color != null) 'color': color,
        if (pinned != null) 'pinned': pinned,
      });

  Future<void> delete(int id) => _dio.delete('/api/v1/notes/$id');
}
