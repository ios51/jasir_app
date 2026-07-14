import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/api_client.dart';

/// وثائقي — رفع (كاميرا/معرض/ملفات)، استعراض، تعديل، وحفظ الوثائق.
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

  /// يعرض خيارات المصدر ويرجّع {name, mime, data(base64)} أو null.
  Future<Map<String, dynamic>?> _pickSource() async {
    final src = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('التقاط صورة'), onTap: () => Navigator.pop(context, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('من معرض الصور'), onTap: () => Navigator.pop(context, 'gallery')),
          ListTile(leading: const Icon(Icons.folder_outlined), title: const Text('من الملفات (PDF/صور)'), onTap: () => Navigator.pop(context, 'files')),
        ]),
      ),
    );
    if (src == null) return null;
    try {
      if (src == 'files') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'], withData: true);
        if (result == null || result.files.isEmpty || result.files.single.bytes == null) return null;
        final f = result.files.single;
        final ext = (f.extension ?? '').toLowerCase();
        final mime = ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg');
        return {'name': f.name, 'mime': mime, 'data': base64Encode(f.bytes!)};
      } else {
        final img = await ImagePicker().pickImage(
          source: src == 'camera' ? ImageSource.camera : ImageSource.gallery, imageQuality: 85);
        if (img == null) return null;
        final bytes = await img.readAsBytes();
        return {'name': img.name, 'mime': 'image/jpeg', 'data': base64Encode(bytes)};
      }
    } catch (e) {
      _snack('تعذر اختيار الملف');
      return null;
    }
  }

  Future<void> _uploadNew() async {
    final picked = await _pickSource();
    if (picked == null) return;
    final name = await _prompt('اسم الوثيقة', picked['name'] as String);
    if (name == null) return;
    setState(() => _busy = true);
    try {
      final res = await _dio.post('/api/v1/documents',
          data: {'name': name.trim().isEmpty ? picked['name'] : name.trim(), 'type': 'custom'});
      final id = res.data['id'];
      await _dio.post('/api/v1/documents/$id/file',
          data: {'fileName': picked['name'], 'mime': picked['mime'], 'data': picked['data']});
      await _load();
    } catch (e) {
      _snack('تعذر رفع الوثيقة');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach(Map<String, dynamic> doc) async {
    final picked = await _pickSource();
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      await _dio.post('/api/v1/documents/${doc['id']}/file',
          data: {'fileName': picked['name'], 'mime': picked['mime'], 'data': picked['data']});
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
      final bytes = base64Decode(data);
      final ext = mime.contains('pdf') ? 'pdf' : (mime.contains('png') ? 'png' : 'jpg');
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/jasir_doc_${doc['id']}.$ext';
      await File(path).writeAsBytes(bytes);
      final r = await OpenFilex.open(path);
      if (r.type != ResultType.done) _snack('تعذر فتح الملف على الجهاز');
    } catch (e) {
      _snack('تعذر فتح الوثيقة');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> doc) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _EditSheet(doc: doc),
      ),
    );
    if (ok == true) _load();
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
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('رفع وثيقة'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _docs.isEmpty
                    ? ListView(children: [const SizedBox(height: 100), Center(child: Text('ارفع وثيقة (كاميرا/معرض/ملف) بالزر بالأسفل', style: TextStyle(color: cs.onSurfaceVariant)))])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final d = _docs[i];
                          final hasFile = d['has_file'] == 1;
                          final sub = <String>[];
                          if (d['type'] != null && d['type'] != 'custom') sub.add(d['type'].toString());
                          if (d['doc_number'] != null && d['doc_number'].toString().isNotEmpty) sub.add('رقم: ${d['doc_number']}');
                          if (d['expiry_date'] != null && d['expiry_date'].toString().isNotEmpty) sub.add('ينتهي: ${d['expiry_date']}');
                          return Card(
                            child: ListTile(
                              leading: Icon(hasFile ? Icons.description : Icons.attachment_outlined, color: cs.primary),
                              title: Text(d['name']?.toString() ?? d['type']?.toString() ?? 'وثيقة', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: sub.isEmpty ? null : Text(sub.join('  •  ')),
                              onTap: hasFile ? () => _view(d) : () => _attach(d),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  icon: Icon(hasFile ? Icons.visibility_outlined : Icons.attach_file, color: cs.primary),
                                  tooltip: hasFile ? 'استعراض/حفظ' : 'إرفاق ملف',
                                  onPressed: () => hasFile ? _view(d) : _attach(d),
                                ),
                                IconButton(icon: Icon(Icons.edit_outlined, color: cs.secondary), tooltip: 'تعديل', onPressed: () => _edit(d)),
                                IconButton(icon: Icon(Icons.delete_outline, color: cs.error), onPressed: () => _delete(d)),
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

/// نموذج تعديل بيانات الوثيقة (اسم/رقم/تاريخ انتهاء/تذكير/ملاحظات).
class _EditSheet extends StatefulWidget {
  final Map<String, dynamic> doc;
  const _EditSheet({required this.doc});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.doc['name']?.toString() ?? '');
  late final _number = TextEditingController(text: widget.doc['doc_number']?.toString() ?? '');
  late final _notes = TextEditingController(text: widget.doc['notes']?.toString() ?? '');
  String? _expiry;
  int _remind = 30;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _expiry = widget.doc['expiry_date']?.toString();
    final r = widget.doc['remind_before_days'];
    if (r is int) _remind = r; else if (r != null) _remind = int.tryParse(r.toString()) ?? 30;
  }

  @override
  void dispose() {
    _name.dispose(); _number.dispose(); _notes.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final init = _expiry != null ? (DateTime.tryParse(_expiry!) ?? now) : now;
    final p = await showDatePicker(context: context, initialDate: init, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 20));
    if (p != null) {
      setState(() => _expiry = '${p.year}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.instance.dio.put('/api/v1/documents/${widget.doc['id']}', data: {
        'name': _name.text.trim(),
        'docNumber': _number.text.trim(),
        'notes': _notes.text.trim(),
        'expiryDate': _expiry ?? '',
        'remindBefore': _remind,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر الحفظ'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('تعديل الوثيقة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _number, decoration: const InputDecoration(labelText: 'رقم الوثيقة', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickExpiry,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'تاريخ الانتهاء', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                child: Text(_expiry ?? 'اختر التاريخ'),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _remind,
              decoration: const InputDecoration(labelText: 'التذكير قبل الانتهاء', border: OutlineInputBorder()),
              items: const [7, 14, 30, 60, 90]
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d يوم')))
                  .toList(),
              onChanged: (v) => setState(() => _remind = v ?? 30),
            ),
            const SizedBox(height: 10),
            TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
              label: const Text('حفظ'),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
