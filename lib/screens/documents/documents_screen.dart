import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_client.dart';

/// وثائقي — رفع وثيقة (صورة/PDF)، استعراضها، وحفظها في الجهاز عبر المشاركة.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _dio = ApiClient.instance.dio;
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/api/v1/documents');
      _docs = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<Map<String, dynamic>?> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.single;
    if (f.bytes == null) return null;
    final ext = (f.extension ?? '').toLowerCase();
    final mime = ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg');
    return {'name': f.name, 'mime': mime, 'data': base64Encode(f.bytes!)};
  }

  Future<void> _uploadNew() async {
    final picked = await _pick();
    if (picked == null) return;
    final name = await _prompt('اسم الوثيقة', picked['name'] as String);
    if (name == null) return;
    setState(() => _busy = true);
    try {
      final res = await _dio.post('/api/v1/documents', data: {'name': name.trim().isEmpty ? picked['name'] : name.trim(), 'type': 'custom'});
      final id = res.data['id'];
      await _dio.post('/api/v1/documents/$id/file', data: {'fileName': picked['name'], 'mime': picked['mime'], 'data': picked['data']});
      await _load();
    } catch (e) {
      _snack('تعذر رفع الوثيقة');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach(Map<String, dynamic> doc) async {
    final picked = await _pick();
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      await _dio.post('/api/v1/documents/${doc['id']}/file', data: {'fileName': picked['name'], 'mime': picked['mime'], 'data': picked['data']});
      await _load();
    } catch (e) {
      _snack('تعذر إرفاق الملف');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _view(Map<String, dynamic> doc) async {
    setState(() => _busy = true);
    try {
      final res = await _dio.get('/api/v1/documents/${doc['id']}/file');
      final data = res.data['data'] as String;
      final mime = (res.data['mime'] ?? 'application/octet-stream').toString();
      final uri = Uri.parse('data:$mime;base64,$data');
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack('تعذر فتح الملف');
    } catch (e) {
      _snack('تعذر فتح الوثيقة');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text('حذف "${doc['name'] ?? doc['type'] ?? 'الوثيقة'}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    await _dio.delete('/api/v1/documents/${doc['id']}');
    _load();
  }

  Future<String?> _prompt(String title, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('حفظ')),
        ],
      ),
    );
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('وثائقي'),
          bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator()) : null,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : _uploadNew,
          icon: const Icon(Icons.upload_file),
          label: const Text('رفع وثيقة'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _docs.isEmpty
                    ? ListView(children: [const SizedBox(height: 100), Center(child: Text('ارفع وثيقة (صورة/PDF) بالزر بالأسفل', style: TextStyle(color: cs.onSurfaceVariant)))])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final d = _docs[i];
                          final hasFile = d['has_file'] == 1;
                          final sub = <String>[];
                          if (d['type'] != null && d['type'] != 'custom') sub.add(d['type'].toString());
                          if (d['expiry_date'] != null && d['expiry_date'].toString().isNotEmpty) sub.add('ينتهي: ${d['expiry_date']}');
                          return Card(
                            child: ListTile(
                              leading: Icon(hasFile ? Icons.description : Icons.description_outlined, color: cs.primary),
                              title: Text(d['name']?.toString() ?? d['type']?.toString() ?? 'وثيقة', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: sub.isEmpty ? null : Text(sub.join('  •  ')),
                              onTap: hasFile ? () => _view(d) : () => _attach(d),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  icon: Icon(hasFile ? Icons.visibility_outlined : Icons.attach_file, color: cs.primary),
                                  tooltip: hasFile ? 'استعراض' : 'إرفاق ملف',
                                  onPressed: () => hasFile ? _view(d) : _attach(d),
                                ),
                                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _delete(d)),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
