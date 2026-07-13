import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/api_client.dart';
import '../../services/medical_reports_store.dart';

/// الملفات الطبية لفرد العائلة — رقم الملف لكل مستشفى (يُستخدم في تنبيه وصول
/// الموعد)، مع إمكانية إرفاق تقارير (PDF/صور) تُحفظ **على الجهاز** (حد تقريرين).
class MedicalFilesScreen extends StatefulWidget {
  final int memberId;
  final String memberName;
  const MedicalFilesScreen({super.key, required this.memberId, required this.memberName});

  @override
  State<MedicalFilesScreen> createState() => _MedicalFilesScreenState();
}

class _MedicalFilesScreenState extends State<MedicalFilesScreen> {
  final _dio = ApiClient.instance.dio;
  List<Map<String, dynamic>> _files = [];
  final Map<String, List<MedicalReport>> _reports = {}; // key → تقارير
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _key(Map<String, dynamic> f) => 'm${widget.memberId}_f${f['id']}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/api/v1/family/${widget.memberId}/files');
      _files = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      for (final f in _files) {
        _reports[_key(f)] = await MedicalReportsStore.list(_key(f));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final hospital = TextEditingController();
    final fileNum = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة ملف طبي'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: hospital, autofocus: true, decoration: const InputDecoration(labelText: 'المستشفى', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: fileNum, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رقم الملف الطبي', border: OutlineInputBorder())),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok == true && hospital.text.trim().isNotEmpty && fileNum.text.trim().isNotEmpty) {
      try {
        await _dio.post('/api/v1/family/${widget.memberId}/files',
            data: {'hospital': hospital.text.trim(), 'fileNumber': fileNum.text.trim()});
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر الحفظ')));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> f) async {
    // احذف تقاريرها المحلية أيضاً
    for (final r in (_reports[_key(f)] ?? const <MedicalReport>[])) {
      await MedicalReportsStore.remove(_key(f), r);
    }
    await _dio.delete('/api/v1/family/files/${f['id']}');
    _load();
  }

  Future<void> _attach(Map<String, dynamic> f) async {
    final key = _key(f);
    if ((_reports[key]?.length ?? 0) >= MedicalReportsStore.maxPerFile) {
      _snack('الحد الأقصى تقريران لكل ملف');
      return;
    }
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      final picked = res?.files.single;
      if (picked?.path == null) return;
      final err = await MedicalReportsStore.add(key, picked!.path!, picked.name);
      if (err != null) { _snack(err); return; }
      _reports[key] = await MedicalReportsStore.list(key);
      if (mounted) setState(() {});
    } catch (_) {
      _snack('تعذّر إرفاق التقرير');
    }
  }

  Future<void> _open(MedicalReport r) async {
    try { await OpenFilex.open(r.path); } catch (_) { _snack('تعذّر فتح الملف'); }
  }

  Future<void> _removeReport(String key, MedicalReport r) async {
    await MedicalReportsStore.remove(key, r);
    _reports[key] = await MedicalReportsStore.list(key);
    if (mounted) setState(() {});
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
        appBar: AppBar(title: Text('الملفات الطبية — ${widget.memberName}')),
        floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('إضافة ملف')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _files.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 100),
                        Center(child: Text('أضف رقم الملف الطبي لكل مستشفى', style: TextStyle(color: cs.onSurfaceVariant))),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _files.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final f = _files[i];
                          final key = _key(f);
                          final reports = _reports[key] ?? const <MedicalReport>[];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(children: [
                                ListTile(
                                  leading: Icon(Icons.local_hospital_outlined, color: cs.primary),
                                  title: Text(f['hospital']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('رقم الملف: ${f['file_number'] ?? ''}'),
                                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _delete(f)),
                                ),
                                // التقارير المرفقة (على الجهاز)
                                ...reports.map((r) => ListTile(
                                      dense: true,
                                      leading: Icon(
                                        r.name.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                                        color: cs.secondary,
                                      ),
                                      title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                      onTap: () => _open(r),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () => _removeReport(key, r),
                                      ),
                                    )),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(children: [
                                    Text('التقارير ${reports.length}/${MedicalReportsStore.maxPerFile}',
                                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                    const Spacer(),
                                    if (reports.length < MedicalReportsStore.maxPerFile)
                                      TextButton.icon(
                                        onPressed: () => _attach(f),
                                        icon: const Icon(Icons.attach_file, size: 18),
                                        label: const Text('أرفق تقرير'),
                                      ),
                                  ]),
                                ),
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
