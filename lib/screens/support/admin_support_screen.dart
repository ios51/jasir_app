import 'package:flutter/material.dart';
import '../../services/support_service.dart';
import '../../theme/jasir_theme.dart';
import '../../widgets/jasir_spinner.dart';

/// «لوحة الدعم» — تظهر للمالك فقط:
/// قائمة محادثات المستخدمين (مع شارة غير مقروء) + الرد + بث إعلان للجميع.
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  final _service = SupportService();
  List<SupportThread> _threads = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final t = await _service.adminThreads();
      if (!mounted) return;
      setState(() {
        _threads = t;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _announce() async {
    final ctrl = TextEditingController();
    final cs = Theme.of(context).colorScheme;
    final send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('إعلان للجميع', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                autofocus: true,
                minLines: 2,
                maxLines: 6,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(hintText: 'نص الإعلان…'),
              ),
              const SizedBox(height: 12),
              // معاينة بالشكل الذي سيصل للمستخدمين
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.tertiary.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.campaign_outlined, size: 18, color: cs.onTertiaryContainer),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: ctrl,
                        builder: (_, v, __) => Text(
                          v.text.isEmpty ? 'معاينة الإعلان…' : v.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onTertiaryContainer),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('نشر'),
              ),
            ],
          ),
        ),
      ),
    );
    final text = ctrl.text.trim();
    if (send != true || text.isEmpty) return;
    if (!mounted) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد النشر'),
        content: const Text('سيصل هذا الإعلان لكل المستخدمين. متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نشر')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      final pushed = await _service.announce(text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('نُشر الإعلان ✅ (وصل إشعار لـ$pushed جهاز)')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر النشر — تحقق من الاتصال')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة الدعم')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _announce,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('إعلان للجميع'),
      ),
      body: _loading
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
              : _threads.isEmpty
                  ? _empty(context)
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                        itemCount: _threads.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _threadTile(_threads[i]),
                      ),
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
            child: Icon(Icons.inbox_outlined, size: 44, color: cs.onSurfaceVariant.withOpacity(0.6)),
          ),
          const SizedBox(height: 12),
          Text('لا رسائل واردة', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('ستظهر رسائل المستخدمين هنا فور وصولها',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _threadTile(SupportThread t) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    final hasUnseen = t.unseen > 0;
    return Container(
      decoration: BoxDecoration(
        color: g.tileSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: g.tileShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AdminThreadScreen(thread: t)),
            );
            _reload();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: g.dailyChip,
                  child: Icon(Icons.person_outline, color: g.dailyIcon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: hasUnseen ? FontWeight.w700 : FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(t.lastText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (hasUnseen)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
                    child: Text('${t.unseen}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onPrimary)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// محادثة مستخدم واحدة داخل لوحة الدعم — المالك يقرأ ويرد.
class AdminThreadScreen extends StatefulWidget {
  final SupportThread thread;
  const AdminThreadScreen({super.key, required this.thread});

  @override
  State<AdminThreadScreen> createState() => _AdminThreadScreenState();
}

class _AdminThreadScreenState extends State<AdminThreadScreen> {
  final _service = SupportService();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<SupportMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;

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
      final msgs = await _service.adminThread(widget.thread.userId);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reply() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.adminReply(widget.thread.userId, text);
      _ctrl.clear();
      await _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر الإرسال')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _kindLabel(String k) => switch (k) {
        'suggestion' => 'اقتراح',
        'complaint' => 'شكوى',
        'inquiry' => 'استفسار',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.thread.displayName)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: JasirSpinner())
                : GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                    child: ListView.builder(
                      controller: _scroll,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final mine = m.fromAdmin; // ردّ المالك
                        return Align(
                          alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: mine ? cs.primaryContainer : cs.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: mine ? null : Border.all(color: cs.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!mine && _kindLabel(m.kind).isNotEmpty)
                                  Text(_kindLabel(m.kind),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: cs.onSurfaceVariant)),
                                Text(m.text,
                                    style: TextStyle(color: mine ? cs.onPrimaryContainer : cs.onSurface)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textAlign: TextAlign.right,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(hintText: 'اكتب ردك…'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _sending ? null : _reply,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
