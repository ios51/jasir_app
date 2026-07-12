import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_client.dart';
import '../generic/module_registry.dart';
import '../generic/generic_form_screen.dart';

/// روابطي — معروضة كمجلدات حسب التصنيف (يوتيوب، مواقع على الخريطة، مبيعات...).
/// جاسر يصنّف الرابط تلقائياً حسب النطاق عند الحفظ.
class LinksGroupedScreen extends StatefulWidget {
  const LinksGroupedScreen({super.key});
  @override
  State<LinksGroupedScreen> createState() => _LinksGroupedScreenState();
}

class _LinksGroupedScreenState extends State<LinksGroupedScreen> {
  final _dio = ApiClient.instance.dio;
  Map<String, List<Map<String, dynamic>>> _groups = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/api/v1/links');
      final list = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final g = <String, List<Map<String, dynamic>>>{};
      for (final l in list) {
        final cat = (l['category']?.toString().trim().isNotEmpty == true) ? l['category'].toString() : 'عام';
        (g[cat] ??= []).add(l);
      }
      _groups = g;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(Map<String, dynamic> l) async {
    final raw = (l['url'] ?? '').toString().trim();
    if (raw.isEmpty) return;
    final uri = Uri.parse(raw.startsWith('http') ? raw : 'https://$raw');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
    }
  }

  Future<void> _edit({Map<String, dynamic>? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => GenericFormScreen(def: ModuleRegistry.links, existing: existing)),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> l) async {
    await _dio.delete('/api/v1/links/${l['id']}');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cats = _groups.keys.toList()..sort((a, b) => a == 'عام' ? 1 : b == 'عام' ? -1 : a.compareTo(b));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('روابطي')),
        floatingActionButton: FloatingActionButton(onPressed: () => _edit(), child: const Icon(Icons.add)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: cats.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 100),
                        Center(child: Text('أضف روابطك وجاسر يصنّفها تلقائياً', style: TextStyle(color: cs.onSurfaceVariant))),
                      ])
                    : ListView(
                        padding: const EdgeInsets.all(10),
                        children: cats.map((cat) {
                          final items = _groups[cat]!;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: cats.length <= 3,
                                leading: Icon(_catIcon(cat), color: cs.primary),
                                title: Text('$cat  (${items.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                childrenPadding: EdgeInsets.zero,
                                children: items.map((l) => ListTile(
                                      title: Text(l['title']?.toString() ?? l['url']?.toString() ?? 'رابط'),
                                      subtitle: Text(l['url']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                      onTap: () => _open(l),
                                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                        IconButton(icon: Icon(Icons.open_in_new, color: cs.primary), tooltip: 'فتح', onPressed: () => _open(l)),
                                        IconButton(icon: Icon(Icons.edit_outlined, color: cs.secondary), tooltip: 'تعديل', onPressed: () => _edit(existing: l)),
                                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _delete(l)),
                                      ]),
                                    )).toList(),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
      ),
    );
  }

  IconData _catIcon(String cat) {
    if (cat.contains('يوتيوب')) return Icons.smart_display_outlined;
    if (cat.contains('خريطة') || cat.contains('موقع')) return Icons.place_outlined;
    if (cat.contains('مبيعات') || cat.contains('تسوق')) return Icons.shopping_bag_outlined;
    if (cat.contains('تواصل')) return Icons.chat_bubble_outline;
    return Icons.folder_outlined;
  }
}
