import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/worship_content.dart';
import '../../theme/jasir_theme.dart';

/// «فائدة اليوم» — شاشة مستقلة يفتحها إشعار الفائدة مباشرة
/// (قرار المستخدم: الإشعار لا يفتح المحادثة). بالمعالجة الروحانية: أميري + ذهبي.
class FaidahScreen extends StatelessWidget {
  const FaidahScreen({super.key});

  Faidah get _today {
    final idx = DateTime.now().difference(DateTime(2020, 1, 1)).inDays % dailyFawaid.length;
    return dailyFawaid[idx];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    final f = _today;
    return Scaffold(
      appBar: AppBar(title: const Text('فائدة اليوم')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // نوع الفائدة (آية / حديث)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('💡 ${f.kind}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onTertiaryContainer)),
            ),
          ),
          const SizedBox(height: 16),
          // النص — أميري كبير (المعالجة الروحانية من نظام التصميم)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: g.spiritualContainer,
              borderRadius: BorderRadius.circular(18),
              boxShadow: g.tileShadow,
            ),
            child: Text(
              f.text,
              textAlign: TextAlign.center,
              style: GoogleFonts.amiri(
                fontSize: 22,
                height: 1.9,
                color: g.spiritualOnContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // الشرح
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: g.tileSurface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: g.tileShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الشرح', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.primary)),
                const SizedBox(height: 6),
                Text(f.explanation, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('المصدر: ${f.source}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
