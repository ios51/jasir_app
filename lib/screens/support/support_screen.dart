import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/support_service.dart';
import '../../theme/jasir_theme.dart';
import '../../widgets/jasir_spinner.dart';

/// «تواصل معنا»: نمط رسالة رسمية — المستخدم يكتب موضوعاً ومضموناً
/// (اقتراح/شكوى/استفسار)، وبعد الإرسال ينتظر ٢٤ ساعة قبل رسالة جديدة.
/// تظهر ردود الإدارة والإعلانات ورسائل الإدارة العامة بشكل مميز.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _service = SupportService();
  final _scroll = ScrollController();
  List<SupportMessage> _messages = [];
  bool _loading = true;
  bool _error = false;
  bool _sending = false;

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
    _scroll.dispose();
    super.dispose();
  }

  /// المتبقي على السماح بالإرسال (٢٤ ساعة من آخر رسالة للمستخدم) —
  /// null يعني مسموح الآن. السيرفر يفرض الحد أيضاً (هذا للعرض فقط).
  Duration? get _cooldownRemaining {
    SupportMessage? lastMine;
    for (final m in _messages) {
      if (m.sender == 'user') lastMine = m;
    }
    if (lastMine == null) return null;
    try {
      final at = DateTime.parse(lastMine.createdAt.replaceFirst(' ', 'T') + 'Z');
      final elapsed = DateTime.now().toUtc().difference(at);
      const day = Duration(hours: 24);
      if (elapsed < day) return day - elapsed;
    } catch (_) {}
    return null;
  }

  String _fmtRemaining(Duration d) {
    if (d.inHours >= 1) return '${d.inHours} ساعة${d.inMinutes % 60 > 0 ? ' و${d.inMinutes % 60} دقيقة' : ''}';
    return '${d.inMinutes.clamp(1, 59)} دقيقة';
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

  /// نافذة إنشاء رسالة: موضوع + مضمون + نوع — تجربة «رسالة» لا محادثة.
  Future<void> _compose() async {
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String kind = 'inquiry';
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('رسالة إلى فريق جاسر', style: Theme.of(ctx).textTheme.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final (k, label) in _kinds)
                      ChoiceChip(
                        label: Text(label),
                        selected: kind == k,
                        onSelected: (_) => setSheet(() => kind = k),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: subjectCtrl,
                  textAlign: TextAlign.right,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'الموضوع', counterText: ''),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bodyCtrl,
                  textAlign: TextAlign.right,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'المضمون',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    if (subjectCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('إرسال'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (sent != true) {
      subjectCtrl.dispose();
      bodyCtrl.dispose();
      return;
    }
    final subject = subjectCtrl.text.trim();
    final body = bodyCtrl.text.trim();
    subjectCtrl.dispose();
    bodyCtrl.dispose();
    if (subject.isEmpty || body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final outcome = await _service.send(subject: subject, text: body, kind: kind);
      await _reload();
      if (!mounted) return;
      if (outcome.ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وصلت رسالتك — نرد عليك في أقرب وقت 🙏')));
      } else {
        final d = Duration(minutes: outcome.remainingMinutes);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تقدر ترسل رسالة جديدة بعد ${_fmtRemaining(d)}')));
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
              child: Builder(builder: (context) {
                final remaining = _cooldownRemaining;
                if (remaining != null) {
                  // حد الـ٢٤ ساعة: نعرض المتبقي بدل زر الإرسال
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_bottom, size: 18, color: cs.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'وصلتنا رسالتك 🙏 تقدر ترسل رسالة جديدة بعد ${_fmtRemaining(remaining)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return FilledButton.icon(
                  onPressed: _sending || _loading ? null : _compose,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('أرسل رسالة لفريق جاسر'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                );
              }),
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

  /// صورة البث (إن وجدت) — من base64 المخزن بالسيرفر.
  Widget? _broadcastImage(SupportMessage m) {
    if (m.image.isEmpty) return null;
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(base64Decode(m.image), fit: BoxFit.cover),
      );
    } catch (_) {
      return null;
    }
  }

  Widget _bubble(SupportMessage m) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;

    // بث عام (إعلان أو رسالة إدارة): فقاعة كامل العرض
    if (m.isBroadcast) {
      final isAnn = m.isAnnouncement;
      final img = _broadcastImage(m);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // الإعلان بالمعالجة الذهبية — رسالة الإدارة بمعالجة رسمية هادئة
          color: isAnn ? cs.tertiaryContainer : cs.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (isAnn ? cs.tertiary : cs.secondary).withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isAnn ? Icons.campaign_outlined : Icons.mark_email_read_outlined,
                    size: 20, color: isAnn ? g.warning : cs.secondary),
                const SizedBox(width: 6),
                Text(isAnn ? 'إعلان' : 'رسالة من الإدارة', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            if (img != null) ...[const SizedBox(height: 10), img],
            const SizedBox(height: 6),
            Text(m.text,
                style: TextStyle(color: isAnn ? cs.onTertiaryContainer : cs.onSecondaryContainer)),
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
          // موضوع الرسالة (نمط الرسالة الرسمية)
          if (m.subject.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(m.subject,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: fromAdmin ? cs.onSurface : cs.onPrimaryContainer,
                )),
          ],
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
