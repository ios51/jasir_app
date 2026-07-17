import 'package:flutter/material.dart';
import '../../services/support_service.dart';
import '../../theme/jasir_theme.dart';
import '../../widgets/jasir_spinner.dart';

/// «تواصل معنا»: محادثة المستخدم مع فريق الدعم — اقتراح/شكوى/استفسار،
/// وتظهر فيها ردود الإدارة والإعلانات العامة بشكل مميز.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _service = SupportService();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<SupportMessage> _messages = [];
  bool _loading = true;
  bool _error = false;
  bool _sending = false;
  String _kind = 'inquiry';

  static const _kinds = [
    ('suggestion', 'اقتراح'),
    ('complaint', 'شكوى'),
    ('inquiry', 'استفسار'),
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final msgs = await _service.myMessages();
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
        _error = false;
      });
      _toEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.send(text, kind: _kind);
      _ctrl.clear();
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وصلت رسالتك — نرد عليك في أقرب وقت 🙏')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر الإرسال — تحقق من الاتصال')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('تواصل معنا')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: JasirSpinner())
                : _error
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('تعذر التحميل', style: TextStyle(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            OutlinedButton(
                                onPressed: () {
                                  setState(() => _loading = true);
                                  _reload();
                                },
                                child: const Text('إعادة المحاولة')),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? _empty(context)
                        : GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                            child: ListView.builder(
                              controller: _scroll,
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              itemCount: _messages.length,
                              itemBuilder: (context, i) => _bubble(_messages[i]),
                            ),
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // شريحة نوع الرسالة
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final (k, label) in _kinds)
                          ChoiceChip(
                            label: Text(label),
                            selected: _kind == k,
                            onSelected: (_) => setState(() => _kind = k),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          textAlign: TextAlign.right,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(hintText: 'اكتب رسالتك لفريق جاسر…'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send),
                        style: IconButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: g.dailyContainer, shape: BoxShape.circle),
            child: Icon(Icons.forum_outlined, size: 44, color: cs.onSurfaceVariant.withOpacity(0.6)),
          ),
          const SizedBox(height: 12),
          Text('ابدأ محادثة مع فريق جاسر', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'اختر نوع رسالتك واكتب لنا — نرد في أقرب وقت',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  String _kindLabel(String k) => switch (k) {
        'suggestion' => 'اقتراح',
        'complaint' => 'شكوى',
        'inquiry' => 'استفسار',
        _ => '',
      };

  Widget _bubble(SupportMessage m) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;

    // إعلان عام: فقاعة كامل العرض بالمعالجة الذهبية
    if (m.isAnnouncement) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.tertiary.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_outlined, size: 20, color: g.warning),
                const SizedBox(width: 6),
                Text('إعلان', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(m.text, style: TextStyle(color: cs.onTertiaryContainer)),
          ],
        ),
      );
    }

    final fromAdmin = m.fromAdmin;
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      decoration: BoxDecoration(
        color: fromAdmin ? cs.surface : cs.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: fromAdmin ? Border.all(color: cs.outlineVariant) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fromAdmin)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined, size: 14, color: cs.primary),
                const SizedBox(width: 4),
                Text('فريق جاسر', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.primary)),
              ],
            )
          else if (_kindLabel(m.kind).isNotEmpty)
            Text(_kindLabel(m.kind),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onPrimaryContainer.withOpacity(0.7))),
          const SizedBox(height: 2),
          Text(m.text, style: TextStyle(color: fromAdmin ? cs.onSurface : cs.onPrimaryContainer)),
        ],
      ),
    );
    return Align(
      alignment: fromAdmin ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: bubble,
    );
  }
}
