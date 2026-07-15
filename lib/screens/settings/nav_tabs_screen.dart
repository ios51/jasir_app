import 'package:flutter/material.dart';
import '../../services/nav_prefs.dart';
import '../home_screen.dart' show kNavCatalog;

/// تخصيص الشريط السفلي: المستخدم يختار ٣ خدمات تظهر بجانب «الرئيسية».
class NavTabsScreen extends StatefulWidget {
  const NavTabsScreen({super.key});

  @override
  State<NavTabsScreen> createState() => _NavTabsScreenState();
}

class _NavTabsScreenState extends State<NavTabsScreen> {
  // بترتيب الاختيار — أول المختار يظهر أولاً في الشريط.
  late List<String> _selected = List.of(NavPrefs.current);

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < 3) {
        _selected.add(id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('الحد ٣ خدمات — أزل وحدة أول ثم أضف غيرها')));
      }
    });
  }

  Future<void> _save() async {
    if (_selected.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر ٣ خدمات بالضبط')));
      return;
    }
    await NavPrefs.save(_selected);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تخصيص الشريط السفلي')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'اختر ٣ خدمات تظهر في الشريط السفلي بجانب «الرئيسية» — '
                'بترتيب اختيارك (${_selected.length}/٣)',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                children: [
                  for (final o in kNavCatalog)
                    CheckboxListTile(
                      value: _selected.contains(o.id),
                      onChanged: (_) => _toggle(o.id),
                      secondary: Icon(o.icon),
                      title: Text(o.label),
                      // رقم ترتيبه في الشريط إن كان مختاراً
                      subtitle: _selected.contains(o.id)
                          ? Text('الموقع ${_selected.indexOf(o.id) + 1}',
                              style: TextStyle(color: cs.primary, fontSize: 12))
                          : null,
                    ),
                ],
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('حفظ'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
