import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';
import 'shopping_group_items_screen.dart';

/// قوائم/مجموعات المشتريات — تنشئ مجموعة (السوبرماركت)، تدعو أشخاص بكود،
/// أو تنضم لمجموعة، أو تكون وحدك.
class ShoppingGroupsScreen extends StatefulWidget {
  const ShoppingGroupsScreen({super.key});
  @override
  State<ShoppingGroupsScreen> createState() => _ShoppingGroupsScreenState();
}

class _ShoppingGroupsScreenState extends State<ShoppingGroupsScreen> {
  final _dio = ApiClient.instance.dio;
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/api/v1/shopping/groups');
      _groups = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final name = await _prompt('إنشاء مجموعة', 'اسم المجموعة (مثل: السوبرماركت)');
    if (name == null || name.trim().isEmpty) return;
    await _dio.post('/api/v1/shopping/groups', data: {'name': name.trim()});
    _load();
  }

  Future<void> _join() async {
    final code = await _prompt('الانضمام بكود', 'أدخل كود الدعوة');
    if (code == null || code.trim().isEmpty) return;
    try {
      await _dio.post('/api/v1/shopping/groups/join', data: {'code': code.trim()});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كود غير صحيح')));
    }
  }

  Future<String?> _prompt(String title, String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('حفظ')),
        ],
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> g) async {
    final owner = g['is_owner'] == 1 || g['is_owner'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(owner ? 'حذف مجموعة "${g['name']}" وكل أغراضها؟' : 'مغادرة مجموعة "${g['name']}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(owner ? 'حذف' : 'مغادرة')),
        ],
      ),
    );
    if (ok != true) return;
    await _dio.delete('/api/v1/shopping/groups/${g['id']}');
    _load();
  }

  void _fabMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.add_shopping_cart), title: const Text('إنشاء مجموعة'), onTap: () { Navigator.pop(context); _create(); }),
          ListTile(leading: const Icon(Icons.group_add_outlined), title: const Text('الانضمام بكود'), onTap: () { Navigator.pop(context); _join(); }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مشترياتي')),
        floatingActionButton: FloatingActionButton(onPressed: _fabMenu, child: const Icon(Icons.add)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _groups.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 100),
                        Center(child: Text('أنشئ مجموعة مشتريات (السوبرماركت…) بالزر +', style: TextStyle(color: cs.onSurfaceVariant))),
                      ])
                    : ListView(
                        padding: const EdgeInsets.all(14),
                        children: _groups.map((g) {
                          final owner = g['is_owner'] == 1 || g['is_owner'] == true;
                          final members = g['members_count'] ?? 1;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: cs.primaryContainer, child: Icon(Icons.shopping_cart_outlined, color: cs.primary)),
                              title: Text(g['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Row(children: [
                                Icon(Icons.group_outlined, size: 14, color: cs.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text('$members', style: TextStyle(color: cs.onSurfaceVariant)),
                                const SizedBox(width: 10),
                                if (g['code'] != null)
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: g['code'].toString()));
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('نُسخ الكود: ${g['code']}')));
                                    },
                                    child: Row(children: [
                                      Icon(Icons.key_outlined, size: 14, color: cs.primary),
                                      const SizedBox(width: 3),
                                      Text('${g['code']}', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                                    ]),
                                  ),
                              ]),
                              trailing: IconButton(
                                icon: Icon(owner ? Icons.delete_outline : Icons.logout, color: Colors.redAccent),
                                onPressed: () => _delete(g),
                              ),
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ShoppingGroupItemsScreen(groupId: g['id'] as int, groupName: g['name']?.toString() ?? '', code: g['code']?.toString()),
                              )).then((_) => _load()),
                            ),
                          );
                        }).toList(),
                      ),
              ),
      ),
    );
  }
}
