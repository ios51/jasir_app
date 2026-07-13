import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../services/chat_prefs.dart';

/// صفحة المحادثة الكاملة (تُفتح من الرئيسية) — شريط علوي فيه مسح المحادثة وتغيير الخلفية.
class ChatPage extends StatelessWidget {
  /// عند فتحها من إشعار الصباح: تعرض رسالة الصباح فوراً.
  final bool forceMorning;

  /// عند فتحها من إشعار دواء: جاسر يسأل عن الجرعة داخل المحادثة
  /// مع زري «أخذته» و«أعطني ١٠ دقائق».
  final int? pendingMedId;
  final String? pendingMedName;

  /// عند فتحها من إشعار «فائدة اليوم»: تُعرض الفائدة داخل المحادثة.
  final bool showFaidah;

  const ChatPage({super.key, this.forceMorning = false, this.pendingMedId, this.pendingMedName, this.showFaidah = false});

  Future<void> _menu(BuildContext context, String v) async {
    if (v == 'clear') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: const Text('مسح كل المحادثة مع جاسر؟ (بيبقى بس ترحيب جاسر)'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('مسح')),
          ],
        ),
      );
      if (ok == true) ChatPrefs.requestClear();
    } else if (v == 'bg') {
      _pickBackground(context);
    }
  }

  void _pickBackground(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('خلفية المحادثة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
              children: chatBackgrounds.map((b) {
                final dec = ChatPrefs.decoration(b.id);
                return GestureDetector(
                  onTap: () { ChatPrefs.setBackground(b.id); Navigator.pop(context); },
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 62, height: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outline),
                        gradient: dec?.gradient,
                        color: dec?.gradient == null ? (dec?.color ?? Theme.of(context).scaffoldBackgroundColor) : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(b.name, style: const TextStyle(fontSize: 11.5)),
                  ]),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محادثة جاسر'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => _menu(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('مسح المحادثة')),
              PopupMenuItem(value: 'bg', child: Text('خلفية المحادثة')),
            ],
          ),
        ],
      ),
      body: ChatScreen(forceMorning: forceMorning, pendingMedId: pendingMedId, pendingMedName: pendingMedName, showFaidah: showFaidah),
    );
  }
}
