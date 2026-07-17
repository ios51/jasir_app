import 'package:flutter/material.dart';
import '../../services/notes_service.dart';
import '../../theme/jasir_theme.dart';
import '../../widgets/jasir_spinner.dart';

/// تبويب «ملاحظات» بجانب المهام: بلا تواريخ إطلاقاً.
/// الذكاء البسيط: إضافة فورية من حقل أعلى القائمة، تثبيت، لون دلالي،
/// بحث فوري، والفرز تلقائي (المثبّت أولاً ثم الأحدث تعديلاً).
class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  final _service = NotesService();
  final _addCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<Note> _notes = [];
  bool _loading = true;
  bool _error = false;
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final notes = await _service.list();
      if (!mounted) return;
      setState(() {
        _notes = notes;
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

  Future<void> _add() async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    _addCtrl.clear();
    try {
      await _service.add(text);
      await _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ الملاحظة — تحقق من الاتصال')));
      }
    }
  }

  Future<void> _togglePin(Note n) async {
    try {
      await _service.update(n.id, pinned: !n.pinned);
      await _reload();
    } catch (_) {}
  }

  Future<void> _delete(Note n) async {
    // حذف متفائل مع تراجع
    final idx = _notes.indexOf(n);
    setState(() => _notes.remove(n));
    try {
      await _service.delete(n.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('حُذفت الملاحظة'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () async {
            try {
              await _service.add(n.text, color: n.color);
              _reload();
            } catch (_) {}
          },
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _notes.insert(idx.clamp(0, _notes.length), n));
    }
  }

  Future<void> _edit(Note n) async {
    final ctrl = TextEditingController(text: n.text);
    String color = n.color;
    final saved = await showModalBottomSheet<bool>(
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
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 8,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(hintText: 'نص الملاحظة'),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in const ['default', 'health', 'family', 'warning', 'gold'])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => setSheet(() => color = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _colorOf(ctx, c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c ? Theme.of(ctx).colorScheme.primary : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true && ctrl.text.trim().isNotEmpty) {
      try {
        await _service.update(n.id, text: ctrl.text.trim(), color: color);
        _reload();
      } catch (_) {}
    }
  }

  Color _colorOf(BuildContext context, String c) {
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    final cs = Theme.of(context).colorScheme;
    return switch (c) {
      'health' => g.healthChip,
      'family' => g.familyChip,
      'warning' => g.warning.withOpacity(0.35),
      'gold' => cs.tertiaryContainer,
      _ => g.dailyChip,
    };
  }

  /// «قبل ٥ دقائق» — بدون أي تواريخ ظاهرة.
  String _relative(String iso) {
    try {
      final dt = DateTime.parse(iso.replaceFirst(' ', 'T') + 'Z').toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
      if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
      if (diff.inDays < 30) return 'قبل ${diff.inDays} يوم';
      return 'قبل مدة';
    } catch (_) {
      return '';
    }
  }

  List<Note> get _filtered => _query.isEmpty
      ? _notes
      : _notes.where((n) => n.text.contains(_query)).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    final items = _filtered;
    final pinned = items.where((n) => n.pinned).toList();
    final rest = items.where((n) => !n.pinned).toList();

    return Column(
      children: [
        // حقل الإضافة السريعة — ملتصق بأعلى القائمة
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _addCtrl,
            textAlign: TextAlign.right,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: 'اكتب ملاحظة سريعة…',
              prefixIcon: Icon(Icons.edit_note_outlined, color: g.dailyIcon),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _addCtrl,
                builder: (_, v, __) => v.text.trim().isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(icon: Icon(Icons.arrow_upward, color: cs.primary), onPressed: _add),
              ),
            ),
          ),
        ),
        // بحث قابل للطي
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              textAlign: TextAlign.right,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'ابحث في ملاحظاتك…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _searching = false;
                    _searchCtrl.clear();
                    _query = '';
                  }),
                ),
              ),
            ),
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _searching = true),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('بحث'),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: JasirSpinner())
              : _error
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('تعذر تحميل الملاحظات', style: TextStyle(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 8),
                          OutlinedButton(onPressed: () { setState(() => _loading = true); _reload(); }, child: const Text('إعادة المحاولة')),
                        ],
                      ),
                    )
                  : items.isEmpty
                      ? _empty(context)
                      : RefreshIndicator(
                          onRefresh: _reload,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            children: [
                              if (pinned.isNotEmpty) ...[
                                _sectionTitle(context, 'مثبّتة'),
                                for (final n in pinned) _noteCard(n),
                              ],
                              if (rest.isNotEmpty) ...[
                                if (pinned.isNotEmpty) _sectionTitle(context, 'الملاحظات'),
                                for (final n in rest) _noteCard(n),
                              ],
                            ],
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String t) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 6, top: 8, bottom: 4),
        child: Text(t,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

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
            child: Icon(Icons.sticky_note_2_outlined, size: 44, color: cs.onSurfaceVariant.withOpacity(0.6)),
          ),
          const SizedBox(height: 12),
          Text(_query.isEmpty ? 'لا ملاحظات بعد' : 'لا نتائج مطابقة', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            _query.isEmpty ? 'اكتب أول ملاحظة من الحقل بالأعلى' : 'جرّب كلمة أخرى',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _noteCard(Note n) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    return Dismissible(
      key: ValueKey('note_${n.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.4},
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(18)),
        child: Icon(Icons.delete_outline, color: cs.onError),
      ),
      onDismissed: (_) => _delete(n),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: g.tileSurface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: g.tileShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _edit(n),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // شريط اللون الدلالي
                Container(
                  width: 4,
                  margin: const EdgeInsetsDirectional.only(start: 0),
                  decoration: BoxDecoration(
                    color: _colorOf(context, n.color),
                    borderRadius: const BorderRadiusDirectional.horizontal(start: Radius.circular(18)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 6),
                        Text(_relative(n.updatedAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      child: Icon(
                        n.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                        key: ValueKey(n.pinned),
                        size: 20,
                        color: n.pinned ? cs.tertiary : cs.onSurfaceVariant,
                      ),
                    ),
                    onPressed: () => _togglePin(n),
                    tooltip: n.pinned ? 'إلغاء التثبيت' : 'تثبيت',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
