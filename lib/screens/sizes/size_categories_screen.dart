import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import 'size_conversions.dart';

/// شاشة المقاسات — تصنيفات متداخلة (بيت ← غرفة ← مقاسات).
/// parentId=null يعني الجذر (تصنيفات فقط). داخل تصنيف: تصنيفات فرعية + مقاسات.
class SizeCategoriesScreen extends StatefulWidget {
  final int? parentId;
  final String title;
  final String categoryType; // person | other
  const SizeCategoriesScreen({
    super.key,
    this.parentId,
    this.title = 'مقاساتي',
    this.categoryType = 'other',
  });

  @override
  State<SizeCategoriesScreen> createState() => _SizeCategoriesScreenState();
}

class _SizeCategoriesScreenState extends State<SizeCategoriesScreen> {
  final _dio = ApiClient.instance.dio;
  List<Map<String, dynamic>> _cats = [];
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  bool get _isRoot => widget.parentId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final catRes = await _dio.get('/api/v1/sizes/categories',
          queryParameters: {'parent': _isRoot ? 'root' : '${widget.parentId}'});
      final cats = (catRes.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      List<Map<String, dynamic>> items = [];
      if (!_isRoot) {
        final itRes = await _dio.get('/api/v1/sizes', queryParameters: {'categoryId': '${widget.parentId}'});
        items = (itRes.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (mounted) setState(() { _cats = cats; _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCategory() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AddCategorySheet(parentId: widget.parentId, defaultType: widget.categoryType, atRoot: _isRoot),
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _addItem() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AddItemSheet(categoryId: widget.parentId!, categoryType: widget.categoryType),
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _fab() async {
    if (_isRoot) return _addCategory();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('إضافة تصنيف فرعي'),
            onTap: () => Navigator.pop(context, 'cat'),
          ),
          ListTile(
            leading: const Icon(Icons.straighten_outlined),
            title: const Text('إضافة مقاس'),
            onTap: () => Navigator.pop(context, 'item'),
          ),
        ]),
      ),
    );
    if (choice == 'cat') _addCategory();
    if (choice == 'item') _addItem();
  }

  Future<void> _deleteCategory(Map<String, dynamic> c) async {
    final ok = await _confirm('حذف التصنيف "${c['name']}" وكل ما بداخله؟');
    if (ok != true) return;
    await _dio.delete('/api/v1/sizes/categories/${c['id']}');
    _load();
  }

  Future<void> _deleteItem(Map<String, dynamic> it) async {
    final ok = await _confirm('حذف هذا المقاس؟');
    if (ok != true) return;
    await _dio.delete('/api/v1/sizes/${it['id']}');
    _load();
  }

  Future<bool?> _confirm(String msg) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        floatingActionButton: FloatingActionButton(onPressed: _fab, child: const Icon(Icons.add)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    if (_cats.isEmpty && _items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Center(
                          child: Text(
                            _isRoot
                                ? 'أنشئ تصنيفاً (شخص مثل "الجوري"، أو مكان مثل "البيت")'
                                : 'أضف تصنيفاً فرعياً أو مقاساً بالزر +',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ),
                    // التصنيفات (مجلدات)
                    ..._cats.map((c) {
                      final isPerson = c['type'] == 'person';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(isPerson ? Icons.person_outline : Icons.folder_outlined,
                              color: cs.primary),
                          title: Text(c['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(isPerson ? 'شخص' : 'مكان/عام'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _deleteCategory(c),
                          ),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SizeCategoriesScreen(
                              parentId: c['id'] as int,
                              title: c['name']?.toString() ?? 'تصنيف',
                              categoryType: c['type']?.toString() ?? 'other',
                            ),
                          )),
                        ),
                      );
                    }),
                    // المقاسات (عناصر)
                    ..._items.map((it) => _itemCard(it, cs)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> it, ColorScheme cs) {
    final type = it['size_type']?.toString() ?? 'other';
    final label = (it['label']?.toString().isNotEmpty == true) ? it['label'].toString() : _typeName(type);
    final value = it['size_value']?.toString() ?? '';
    final unit = it['unit']?.toString();
    double? d(x) => x == null ? null : double.tryParse(x.toString());
    final conv = SizeConvert.line(
      type: type, value: value, unit: unit, gender: it['gender']?.toString(),
      width: d(it['width']), height: d(it['height']), depth: d(it['depth']),
    );
    final valDisplay = type == 'dimensions'
        ? [it['width'], it['height'], it['depth']].where((e) => e != null).join(' × ') + ' ${unit ?? ''}'
        : (value.isNotEmpty ? '$value ${unit ?? ''}' : '—');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_typeIcon(type), color: cs.secondary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valDisplay, style: TextStyle(color: cs.onSurface)),
            if (conv != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('≈ $conv', style: TextStyle(color: cs.primary, fontSize: 12.5)),
              ),
            if (it['notes'] != null && it['notes'].toString().isNotEmpty)
              Text('ملاحظة: ${it['notes']}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ],
        ),
        onTap: () => _editItem(it),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _deleteItem(it),
        ),
      ),
    );
  }

  Future<void> _editItem(Map<String, dynamic> it) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AddItemSheet(categoryId: widget.parentId!, categoryType: widget.categoryType, existing: it),
      ),
    );
    if (ok == true) _load();
  }

  static String _typeName(String t) => const {
        'height': 'الطول', 'weight': 'الوزن', 'waist': 'الخصر', 'bra': 'البرا',
        'shoe': 'الحذاء', 'clothing': 'الملابس', 'length': 'طول/بُعد', 'dimensions': 'الأبعاد',
      }[t] ?? 'مقاس';

  static IconData _typeIcon(String t) => const {
        'height': Icons.height, 'weight': Icons.monitor_weight_outlined,
        'waist': Icons.straighten, 'bra': Icons.checkroom_outlined,
        'shoe': Icons.ice_skating_outlined, 'clothing': Icons.checkroom_outlined,
        'length': Icons.straighten, 'dimensions': Icons.aspect_ratio_outlined,
      }[t] ?? Icons.straighten;
}

/// نموذج إضافة تصنيف (شخص/مكان).
class _AddCategorySheet extends StatefulWidget {
  final int? parentId;
  final String defaultType;
  final bool atRoot;
  const _AddCategorySheet({this.parentId, required this.defaultType, required this.atRoot});
  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _name = TextEditingController();
  late String _type = widget.defaultType;
  bool _saving = false;

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiClient.instance.dio.post('/api/v1/sizes/categories', data: {
        'name': _name.text.trim(),
        'type': _type,
        if (widget.parentId != null) 'parentId': widget.parentId,
      });
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
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('إضافة تصنيف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم (مثل: البيت، الجوري)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: RadioListTile<String>(contentPadding: EdgeInsets.zero, value: 'person', groupValue: _type, onChanged: (v) => setState(() => _type = v!), title: const Text('شخص'))),
            Expanded(child: RadioListTile<String>(contentPadding: EdgeInsets.zero, value: 'other', groupValue: _type, onChanged: (v) => setState(() => _type = v!), title: const Text('مكان/عام'))),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            label: const Text('حفظ'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

/// نموذج إضافة مقاس — حقول حسب النوع + معاينة تحويل حيّة.
class _AddItemSheet extends StatefulWidget {
  final int categoryId;
  final String categoryType;
  final Map<String, dynamic>? existing;
  const _AddItemSheet({required this.categoryId, required this.categoryType, this.existing});
  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _value = TextEditingController();
  final _cup = TextEditingController();
  final _w = TextEditingController();
  final _h = TextEditingController();
  final _d = TextEditingController();
  final _notes = TextEditingController();
  final _label = TextEditingController();
  late String _type;
  String _unit = 'سم';
  String _gender = 'women';
  bool _saving = false;

  List<MapEntry<String, String>> get _types => widget.categoryType == 'person'
      ? const [
          MapEntry('height', 'الطول'), MapEntry('weight', 'الوزن'), MapEntry('waist', 'الخصر'),
          MapEntry('bra', 'البرا'), MapEntry('shoe', 'الحذاء'), MapEntry('clothing', 'الملابس'),
          MapEntry('other', 'أخرى'),
        ]
      : const [
          MapEntry('length', 'قياس واحد'),
          MapEntry('dimensions', 'طول × عرض (+ارتفاع)'),
          MapEntry('other', 'أخرى'),
        ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) { _type = _types.first.key; return; }
    final t = e['size_type']?.toString();
    _type = (t != null && _types.any((x) => x.key == t)) ? t : _types.first.key;
    _label.text = e['label']?.toString() ?? '';
    _notes.text = e['notes']?.toString() ?? '';
    if (e['unit'] != null) _unit = e['unit'].toString();
    if (e['gender'] != null) _gender = e['gender'].toString();
    _w.text = e['width']?.toString() ?? '';
    _h.text = e['height']?.toString() ?? '';
    _d.text = e['depth']?.toString() ?? '';
    final val = e['size_value']?.toString() ?? '';
    if (t == 'bra') {
      final m = RegExp(r'^(\d+)(.*)$').firstMatch(val);
      _value.text = m?.group(1) ?? val;
      _cup.text = m?.group(2) ?? '';
    } else {
      _value.text = val;
    }
  }

  @override
  void dispose() {
    for (final c in [_value, _cup, _w, _h, _d, _notes, _label]) { c.dispose(); }
    super.dispose();
  }

  void _rebuild() => setState(() {});

  String? get _preview {
    return SizeConvert.line(
      type: _type, value: _value.text, unit: _unit, gender: _gender,
      width: double.tryParse(_w.text), height: double.tryParse(_h.text), depth: double.tryParse(_d.text),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'categoryId': widget.categoryId,
        'sizeType': _type,
        if (_label.text.trim().isNotEmpty) 'label': _label.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      };
      if (_type == 'dimensions') {
        body['width'] = _w.text.trim();
        body['height'] = _h.text.trim();
        body['depth'] = _d.text.trim();
        body['unit'] = _unit;
      } else if (_type == 'bra') {
        body['sizeValue'] = '${_value.text.trim()}${_cup.text.trim()}';
      } else {
        body['sizeValue'] = _value.text.trim();
        if (_type == 'shoe') body['gender'] = _gender;
        if (['height', 'waist', 'length', 'weight'].contains(_type)) body['unit'] = _unit;
      }
      if (widget.existing != null) {
        await ApiClient.instance.dio.put('/api/v1/sizes/${widget.existing!['id']}', data: body);
      } else {
        await ApiClient.instance.dio.post('/api/v1/sizes', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unitOptions = _type == 'weight' ? const ['كجم', 'رطل'] : const ['سم', 'م', 'إنش'];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('إضافة مقاس', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 12),
            Wrap(spacing: 6, children: _types.map((t) => ChoiceChip(
              label: Text(t.value),
              selected: _type == t.key,
              onSelected: (_) => setState(() => _type = t.key),
            )).toList()),
            const SizedBox(height: 12),
            TextField(controller: _label, decoration: const InputDecoration(labelText: 'اسم مخصّص (اختياري)', border: OutlineInputBorder())),
            const SizedBox(height: 10),

            if (_type == 'dimensions') ...[
              Row(children: [
                Expanded(child: TextField(controller: _w, keyboardType: TextInputType.number, onChanged: (_) => _rebuild(), decoration: const InputDecoration(labelText: 'العرض', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _h, keyboardType: TextInputType.number, onChanged: (_) => _rebuild(), decoration: const InputDecoration(labelText: 'الطول', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _d, keyboardType: TextInputType.number, onChanged: (_) => _rebuild(), decoration: const InputDecoration(labelText: 'الارتفاع', border: OutlineInputBorder()))),
              ]),
            ] else if (_type == 'bra') ...[
              Row(children: [
                Expanded(flex: 2, child: TextField(controller: _value, keyboardType: TextInputType.number, onChanged: (_) => _rebuild(), decoration: const InputDecoration(labelText: 'الحزام (75, 80..)', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _cup, onChanged: (_) => _rebuild(), decoration: const InputDecoration(labelText: 'الكوب (B, C..)', border: OutlineInputBorder()))),
              ]),
            ] else if (_type == 'clothing' || _type == 'other') ...[
              TextField(controller: _value, onChanged: (_) => _rebuild(), decoration: const InputDecoration(labelText: 'القيمة (مثل: M، 42)', border: OutlineInputBorder())),
            ] else ...[
              TextField(controller: _value, keyboardType: TextInputType.number, onChanged: (_) => _rebuild(), decoration: const InputDecoration(labelText: 'القيمة', border: OutlineInputBorder())),
            ],

            if (_type == 'shoe') ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: const [
                MapEntry('women', 'نسائي'), MapEntry('men', 'رجالي'), MapEntry('kids', 'أطفال'),
              ].map((g) => ChoiceChip(label: Text(g.value), selected: _gender == g.key, onSelected: (_) => setState(() => _gender = g.key))).toList()),
            ],

            if (['height', 'waist', 'length', 'weight', 'dimensions'].contains(_type)) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: unitOptions.map((u) => ChoiceChip(label: Text(u), selected: _unit == u, onSelected: (_) => setState(() => _unit = u))).toList()),
            ],

            if (_preview != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
                child: Text('التحويل ≈ ${_preview!}', style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
              ),
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
