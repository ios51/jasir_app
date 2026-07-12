import 'package:flutter/material.dart';
import '../../services/api_client.dart';

/// الملفات الطبية لفرد العائلة — رقم الملف لكل مستشفى (يُستخدم في تنبيه وصول الموعد).
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/api/v1/family/${widget.memberId}/files');
      _files = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final hospital = TextEditingController();
    final fileNum = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
    await _dio.delete('/api/v1/family/files/${f['id']}');
    _load();
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
                          return Card(
                            child: ListTile(
                              leading: Icon(Icons.local_hospital_outlined, color: cs.primary),
                              title: Text(f['hospital']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('رقم الملف: ${f['file_number'] ?? ''}'),
                              trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _delete(f)),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
