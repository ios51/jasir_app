import 'package:flutter/material.dart';
import '../../data/worship_content.dart';

/// عارض أذكار: يعرض قائمة أذكار مع عدّاد تكرار لكل ذكر.
class AdhkarReaderScreen extends StatefulWidget {
  final String title;
  final List<Dhikr> items;
  const AdhkarReaderScreen({super.key, required this.title, required this.items});

  @override
  State<AdhkarReaderScreen> createState() => _AdhkarReaderScreenState();
}

class _AdhkarReaderScreenState extends State<AdhkarReaderScreen> {
  late final List<int> _counts;

  @override
  void initState() {
    super.initState();
    _counts = List<int>.filled(widget.items.length, 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: widget.items.length,
          itemBuilder: (context, i) {
            final d = widget.items[i];
            final done = _counts[i] >= d.repeat;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: done ? cs.primaryContainer.withOpacity(0.25) : null,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    if (_counts[i] < d.repeat) _counts[i]++;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.text,
                          style: const TextStyle(fontSize: 17, height: 1.9)),
                      if (d.note != null) ...[
                        const SizedBox(height: 8),
                        Text(d.note!,
                            style: TextStyle(fontSize: 12.5, color: cs.primary)),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: done ? cs.primary : cs.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              done ? 'تم ✓' : '${_counts[i]} / ${d.repeat}',
                              style: TextStyle(
                                color: done ? cs.onPrimary : cs.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text('اضغط للعدّ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
