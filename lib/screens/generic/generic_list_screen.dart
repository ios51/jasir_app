import 'package:flutter/material.dart';
import '../../services/module_service.dart';
import 'field_def.dart';
import 'generic_form_screen.dart';

/// شاشة قائمة عامة لأي موديول: تعرض العناصر، وتدعم الإضافة/التعديل/الحذف
/// والأفعال المخصصة (أخذت الجرعة، سدد الدين...).
class GenericListScreen extends StatefulWidget {
  final ModuleDef def;
  const GenericListScreen({super.key, required this.def});

  @override
  State<GenericListScreen> createState() => _GenericListScreenState();
}

class _GenericListScreenState extends State<GenericListScreen> {
  late final ModuleService _svc = ModuleService(widget.def.path);
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    // نبني الـ Future أولاً ثم نسنده داخل setState بجسم block (يرجع void، لا Future)
    final f = _svc.list();
    setState(() {
      _future = f;
    });
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => GenericFormScreen(def: widget.def, existing: existing)),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف "${widget.def.titleOf(item)}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _svc.delete(item['id'] as int);
        _reload();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحذف: $e')));
      }
    }
  }

  Future<void> _runAction(Map<String, dynamic> item, ModuleAction a) async {
    try {
      await _svc.action(item['id'] as int, a.verb);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(a.successMsg)));
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر التنفيذ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    return Scaffold(
      appBar: AppBar(title: Text(def.title)),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                const SizedBox(height: 100),
                Center(child: Text('تعذر التحميل: ${snap.error}')),
              ]);
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 120),
                Center(child: Text(def.emptyText, textAlign: TextAlign.center)),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                final sub = def.subtitleOf?.call(item);
                return Card(
                  child: ListTile(
                    leading: Icon(def.icon),
                    title: Text(def.titleOf(item), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: sub != null && sub.isNotEmpty ? Text(sub) : null,
                    onTap: def.fields.isNotEmpty ? () => _openForm(existing: item) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (def.itemAction != null)
                          IconButton(
                            icon: Icon(def.itemActionIcon ?? Icons.open_in_new, color: Colors.teal),
                            tooltip: def.itemActionTooltip ?? 'فتح',
                            onPressed: () => def.itemAction!(context, item),
                          ),
                        if (def.itemScreen != null)
                          IconButton(
                            icon: Icon(def.itemScreenIcon ?? Icons.build_outlined, color: Colors.teal),
                            tooltip: def.itemScreenTooltip ?? 'سجل',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (ctx) => def.itemScreen!(ctx, item)),
                            ),
                          ),
                        ...def.actions.map((a) => IconButton(
                              icon: Icon(a.icon, color: Colors.teal),
                              tooltip: a.label,
                              onPressed: () => _runAction(item, a),
                            )),
                        if (def.canDelete)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _delete(item),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: def.canAdd
          ? FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add))
          : null,
    );
  }
}
