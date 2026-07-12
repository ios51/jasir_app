import 'package:flutter/material.dart';
import '../../services/module_service.dart';
import '../../services/notification_service.dart';

/// شاشة تأكيد أخذ الجرعة — تُفتح عند الضغط على إشعار الدواء.
/// جاسر يسأل: أخذت الدواء؟ مع خيارات: نعم / أعطني ١٠ دقائق (يرجّع ينبّه).
class DoseConfirmScreen extends StatefulWidget {
  final int medId;
  final String medName;
  const DoseConfirmScreen({super.key, required this.medId, required this.medName});

  @override
  State<DoseConfirmScreen> createState() => _DoseConfirmScreenState();
}

class _DoseConfirmScreenState extends State<DoseConfirmScreen> {
  final _svc = ModuleService('/api/v1/meds');
  bool _busy = false;
  String? _done; // نص النتيجة بعد الإجراء

  Future<void> _taken() async {
    setState(() => _busy = true);
    try {
      await _svc.action(widget.medId, 'taken');
      if (mounted) setState(() { _done = 'تمام، سجّلت إنك أخذت *${widget.medName}* ✅\nصحّة وعافية 🌿'; _busy = false; });
    } catch (e) {
      if (mounted) setState(() { _busy = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر التسجيل — جرّب مرة ثانية')));
    }
  }

  Future<void> _snooze() async {
    setState(() => _busy = true);
    try {
      // تذكير محلي بعد ١٠ دقائق لنفس الدواء (يرجّع ينبّهك)
      await NotificationService.scheduleAt(
        50000 + widget.medId,
        '💊 تذكير دواء',
        '${widget.medName} — تكرّم أكّد إنك أخذته',
        DateTime.now().add(const Duration(minutes: 10)),
        payload: 'med|${widget.medId}|${widget.medName}',
      );
      if (mounted) setState(() { _done = 'طيب، بذكّرك بعد ١٠ دقائق ⏰\nلا تنسى دواء *${widget.medName}*'; _busy = false; });
    } catch (e) {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('جاسر')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.primary.withOpacity(0.15),
                    child: Icon(Icons.auto_awesome, color: cs.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _done ?? 'حان وقت دواء *${widget.medName}* 💊\nأخذته؟',
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (_done == null) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : _taken,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('نعم، أخذته'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _snooze,
                  icon: const Icon(Icons.snooze),
                  label: const Text('أعطني ١٠ دقائق'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                ),
              ] else
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text('تمام'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
