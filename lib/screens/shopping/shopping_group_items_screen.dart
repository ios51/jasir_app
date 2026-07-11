import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';

/// أغراض مجموعة مشتريات — سعر متوقع (قبل الشراء) وسعر فعلي (بعد)، من أضاف،
/// شطب عند الشراء، وإجمالي متوقع/فعلي.
class ShoppingGroupItemsScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final String? code;
  const ShoppingGroupItemsScreen({super.key, required this.groupId, required this.groupName, this.code});
  @override
  State<ShoppingGroupItemsScreen> createState() => _ShoppingGroupItemsScreenState();
}

class _ShoppingGroupItemsScreenState extends State<ShoppingGroupItemsScreen> {
  final _dio = ApiClient.instance.dio;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/api/v1/shopping/groups/${widget.groupId}/items');
      _items = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  double _sum(String key, {bool? doneOnly}) {
    double t = 0;
    for (final it in _items) {
      if (doneOnly != null && (it['done'] == 1) != doneOnly) continue;
      final v = it[key];
      if (v is num) t += v.toDouble();
      else if (v != null) t += double.tryParse(v.toString()) ?? 0;
    }
    return t;
  }

  String _money(double v) => v == 0 ? '0' : v.toStringAsFixed(v % 1 == 0 ? 0 : 2);

  Future<void> _add() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ItemSheet(groupId: widget.groupId),
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _edit(Map<String, dynamic> it) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ItemSheet(groupId: widget.groupId, existing: it),
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _toggleDone(Map<String, dynamic> it, bool done) async {
    await _dio.put('/api/v1/shopping/items/${it['id']}', data: {'done': done});
    _load();
  }

  Future<void> _delete(Map<String, dynamic> it) async {
    await _dio.delete('/api/v1/shopping/items/${it['id']}');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.groupName),
          actions: [
            if (widget.code != null)
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: 'مشاركة الكود',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.code!));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('نُسخ كود الدعوة: ${widget.code}')));
                },
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('إضافة غرض')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: cs.primaryContainer,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat('المتوقع', '${_money(_sum('price_expected'))} ﷼', cs),
                        _stat('الفعلي (اشتُري)', '${_money(_sum('price_actual', doneOnly: true))} ﷼', cs),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: _items.isEmpty
                          ? ListView(children: [const SizedBox(height: 100), Center(child: Text('أضف غرضاً بالزر +', style: TextStyle(color: cs.onSurfaceVariant)))])
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (context, i) {
                                final it = _items[i];
                                final done = it['done'] == 1;
                                final exp = it['price_expected'];
                                final act = it['price_actual'];
                                final meta = <String>[];
                                if (it['quantity'] != null && it['quantity'].toString().isNotEmpty) meta.add('الكمية: ${it['quantity']}');
                                if (exp != null) meta.add('متوقع: $exp ﷼');
                                if (act != null) meta.add('فعلي: $act ﷼');
                                if (it['added_by_name'] != null && it['added_by_name'].toString().isNotEmpty) meta.add('أضافه: ${it['added_by_name']}');
                                return Card(
                                  child: ListTile(
                                    leading: Checkbox(value: done, onChanged: (v) => _toggleDone(it, v ?? false)),
                                    title: Text(it['name']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.bold, decoration: done ? TextDecoration.lineThrough : null, color: done ? cs.onSurfaceVariant : cs.onSurface)),
                                    subtitle: meta.isEmpty ? null : Text(meta.join('  •  '), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                                    onTap: () => _edit(it),
                                    trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _delete(it)),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _stat(String label, String value, ColorScheme cs) => Column(children: [
        Text(label, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 18, fontWeight: FontWeight.bold)),
      ]);
}

/// نموذج إضافة/تعديل غرض (اسم، كمية، سعر متوقع، سعر فعلي، مشتُرى).
class _ItemSheet extends StatefulWidget {
  final int groupId;
  final Map<String, dynamic>? existing;
  const _ItemSheet({required this.groupId, this.existing});
  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  final _name = TextEditingController();
  final _qty = TextEditingController();
  final _exp = TextEditingController();
  final _act = TextEditingController();
  final _notes = TextEditingController();
  bool _done = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e['name']?.toString() ?? '';
      _qty.text = e['quantity']?.toString() ?? '';
      _exp.text = e['price_expected']?.toString() ?? '';
      _act.text = e['price_actual']?.toString() ?? '';
      _notes.text = e['notes']?.toString() ?? '';
      _done = e['done'] == 1;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _qty, _exp, _act, _notes]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final dio = ApiClient.instance.dio;
      if (_isEdit) {
        await dio.put('/api/v1/shopping/items/${widget.existing!['id']}', data: {
          'name': _name.text.trim(),
          'quantity': _qty.text.trim(),
          'priceExpected': _exp.text.trim(),
          'priceActual': _act.text.trim(),
          'done': _done,
          'notes': _notes.text.trim(),
        });
      } else {
        await dio.post('/api/v1/shopping/groups/${widget.groupId}/items', data: {
          'name': _name.text.trim(),
          if (_qty.text.trim().isNotEmpty) 'quantity': _qty.text.trim(),
          if (_exp.text.trim().isNotEmpty) 'priceExpected': _exp.text.trim(),
          if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e'))); }
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
            Text(_isEdit ? 'تعديل الغرض' : 'إضافة غرض', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الغرض', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _qty, decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _exp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر متوقع ﷼', border: OutlineInputBorder()))),
            ]),
            if (_isEdit) ...[
              const SizedBox(height: 10),
              TextField(controller: _act, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر الفعلي (بعد الشراء) ﷼', border: OutlineInputBorder())),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('تم شراؤه'), value: _done, onChanged: (v) => setState(() => _done = v)),
            ],
            const SizedBox(height: 10),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder())),
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
