import 'package:flutter/material.dart';
import '../services/services_prefs.dart';

/// عنصر قابل للترتيب (معرّف + عنوان + أيقونة + لون).
class ReorderItem {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  const ReorderItem(this.id, this.title, this.icon, this.color);
}

/// شاشة إعادة ترتيب الخدمات بالسحب.
class ReorderServicesScreen extends StatefulWidget {
  final List<ReorderItem> items;
  const ReorderServicesScreen({super.key, required this.items});

  @override
  State<ReorderServicesScreen> createState() => _ReorderServicesScreenState();
}

class _ReorderServicesScreenState extends State<ReorderServicesScreen> {
  late List<ReorderItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
  }

  Future<void> _save() async {
    await ServicesPrefs.save(_items.map((e) => e.id).toList());
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ترتيب الخدمات'),
          actions: [
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('حفظ'),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('اسحب الخدمة من المقبض ⣿ لتغيير ترتيبها',
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _items.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final it = _items.removeAt(oldIndex);
                    _items.insert(newIndex, it);
                  });
                },
                itemBuilder: (context, i) {
                  final it = _items[i];
                  return Card(
                    key: ValueKey(it.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: it.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(it.icon, color: it.color, size: 22),
                      ),
                      title: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
