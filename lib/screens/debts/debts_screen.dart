import 'package:flutter/material.dart';
import '../../services/debts_service.dart';
import '../../theme/jasir_theme.dart';
import '../../widgets/jasir_spinner.dart';
import '../../widgets/riyal.dart';

/// «الديون» — إعادة بناء كاملة (قرارات المستخدم):
/// ملخص عليّ/لي بالأعلى، تجميع بالشخص، المسدّدون في قائمة قابلة للطي،
/// شاشة شخص بسجل كامل (ديون + دفعات بتواريخ وملاحظات)، وسداد جزئي.
class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  final _service = DebtsService();
  DebtsSummary? _summary;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final s = await _service.summary();
      if (!mounted) return;
      setState(() {
        _summary = s;
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

  Future<void> _openAdd() async {
    final persons = _summary?.persons.map((p) => p.person).toList() ?? [];
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DebtFormScreen(knownPersons: persons)),
    );
    if (saved == true) _reload();
  }

  Future<void> _openPerson(String name) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PersonDebtsScreen(personName: name)),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    final s = _summary;
    // النشطون بالقائمة الرئيسية، والمسدد بالكامل في قائمة قابلة للطي (قرار المستخدم)
    final active = s?.persons.where((p) => p.activeOnMe + p.activeToMe > 0).toList() ?? [];
    final settled = s?.persons.where((p) => p.activeOnMe + p.activeToMe == 0).toList() ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('الديون')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        child: const Icon(Icons.add),
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
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    children: [
                      // بطاقتا الملخص
                      Row(
                        children: [
                          Expanded(
                              child: _summaryCard(
                                  'عليّ', s?.owedByMe ?? 0, g.warning.withOpacity(0.15), g.warning)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _summaryCard('لي', s?.owedToMe ?? 0, g.healthChip, g.success)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (active.isEmpty && settled.isEmpty)
                        _empty(context)
                      else ...[
                        for (final p in active) _personCard(p),
                        if (settled.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          // المسدّدون — مخفيون حتى الضغط (قرار المستخدم)
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsetsDirectional.only(start: 6, end: 6),
                              leading: Icon(Icons.task_alt, color: g.success, size: 20),
                              title: Text('المسدّدة بالكامل (${settled.length})',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(color: cs.onSurfaceVariant)),
                              children: [for (final p in settled) _personCard(p, faded: true)],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _summaryCard(String label, num amount, Color bg, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          RiyalAmount(amount,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700, color: accent)),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: g.dailyContainer, shape: BoxShape.circle),
            child: Icon(Icons.account_balance_wallet_outlined,
                size: 44, color: cs.onSurfaceVariant.withOpacity(0.6)),
          ),
          const SizedBox(height: 12),
          Text('لا ديون مسجلة', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('أضف ديناً بزر + بالأسفل',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _personCard(PersonSummary p, {bool faded = false}) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    return Opacity(
      opacity: faded ? 0.6 : 1,
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
            onTap: () => _openPerson(p.person),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: g.dailyChip,
                    child: Text(p.person.isNotEmpty ? p.person.substring(0, 1) : '؟',
                        style: TextStyle(color: g.dailyIcon, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.person, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        if (faded)
                          Text('السجل مسدد بالكامل',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant))
                        else
                          Wrap(
                            spacing: 10,
                            children: [
                              if (p.activeOnMe > 0)
                                _miniAmount('عليّ له', p.activeOnMe, g.warning),
                              if (p.activeToMe > 0)
                                _miniAmount('لي عنده', p.activeToMe, g.success),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniAmount(String label, num amount, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
        RiyalAmount(amount,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─────────────────────── شاشة سجل الشخص ───────────────────────

class PersonDebtsScreen extends StatefulWidget {
  final String personName;
  const PersonDebtsScreen({super.key, required this.personName});

  @override
  State<PersonDebtsScreen> createState() => _PersonDebtsScreenState();
}

class _PersonDebtsScreenState extends State<PersonDebtsScreen> {
  final _service = DebtsService();
  List<Debt> _debts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final d = await _service.personHistory(widget.personName);
      if (!mounted) return;
      setState(() {
        _debts = d;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// نافذة السداد: المبلغ (معبأ بالمتبقي — عدّله للجزئي) + التاريخ + ملاحظة
  Future<void> _paySheet(Debt d) async {
    final amountCtrl = TextEditingController(text: d.remaining % 1 == 0 ? d.remaining.toInt().toString() : d.remaining.toString());
    final noteCtrl = TextEditingController();
    DateTime paidDate = DateTime.now();
    final ok = await showModalBottomSheet<bool>(
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
                Text('سداد — ${d.personName}',
                    textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 4),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('المتبقي: ', style: Theme.of(ctx).textTheme.bodySmall),
                      RiyalAmount(d.remaining, style: Theme.of(ctx).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'المبلغ المسدد'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: const Text('تاريخ السداد'),
                  subtitle: Text('${paidDate.year}-${paidDate.month.toString().padLeft(2, '0')}-${paidDate.day.toString().padLeft(2, '0')}'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: paidDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSheet(() => paidDate = picked);
                  },
                ),
                TextField(
                  controller: noteCtrl,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    final v = num.tryParse(amountCtrl.text.trim());
                    if (v == null || v <= 0) return;
                    Navigator.pop(ctx, true);
                  },
                  icon: const Icon(Icons.paid_outlined),
                  label: const Text('تسجيل السداد'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final amount = num.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    try {
      await _service.pay(
        d.id,
        amount: amount,
        notes: noteCtrl.text.trim(),
        paidAt:
            '${paidDate.year}-${paidDate.month.toString().padLeft(2, '0')}-${paidDate.day.toString().padLeft(2, '0')} 12:00:00',
      );
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('سُجّل السداد ✅')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر التسجيل — تحقق من الاتصال')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    // الإحصائيات التاريخية (كم تسلفت منه إجمالاً... — قرار المستخدم)
    num borrowed = 0, lent = 0;
    for (final d in _debts) {
      if (d.isMine) {
        lent += d.amount;
      } else {
        borrowed += d.amount;
      }
    }
    final activeDebts = _debts.where((d) => !d.settled).toList();
    final settledDebts = _debts.where((d) => d.settled).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.personName)),
      body: _loading
          ? const Center(child: JasirSpinner())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // الملخص التاريخي
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: g.dailyContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (borrowed > 0)
                          _histLine('تسلفت منه إجمالاً', borrowed, cs.onSurface),
                        if (lent > 0) _histLine('أقرضته إجمالاً', lent, cs.onSurface),
                        Text(
                            '${_debts.length} دين — ${settledDebts.length} مسدد بالكامل',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final d in activeDebts) _debtCard(d),
                  if (settledDebts.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6, top: 12, bottom: 4),
                      child: Text('المسدّدة',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                    for (final d in settledDebts) Opacity(opacity: 0.6, child: _debtCard(d)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _histLine(String label, num v, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            RiyalAmount(v,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700, color: c)),
          ],
        ),
      );

  Widget _debtCard(Debt d) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    final dirColor = d.isMine ? g.success : g.warning;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: g.tileSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: g.tileShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: dirColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(d.isMine ? 'لي عنده' : 'عليّ له',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: dirColor)),
              ),
              const Spacer(),
              RiyalAmount(d.amount,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (d.debtDate.isNotEmpty) 'التاريخ: ${d.debtDate}',
              if (d.dueDate.isNotEmpty) 'الاستحقاق: ${d.dueDate}',
            ].join('  •  '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (d.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('📝 ${d.notes}', style: Theme.of(context).textTheme.bodySmall),
            ),
          // الدفعات — خط زمني
          if (d.payments.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final p in d.payments)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, bottom: 3),
                child: Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_left, size: 14, color: g.success),
                    const SizedBox(width: 4),
                    RiyalAmount(p.amount,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: g.success, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${p.paidAt.split(' ').first}${p.notes.isNotEmpty ? ' — ${p.notes}' : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (!d.settled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Row(
                  children: [
                    Text('المتبقي: ', style: Theme.of(context).textTheme.bodySmall),
                    RiyalAmount(d.remaining,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _paySheet(d),
                  icon: const Icon(Icons.paid_outlined, size: 18),
                  label: const Text('سداد'),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.task_alt, size: 16, color: g.success),
                  const SizedBox(width: 4),
                  Text('مسدد بالكامل',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: g.success)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────── نموذج إضافة دين ───────────────────────

class DebtFormScreen extends StatefulWidget {
  final List<String> knownPersons;
  const DebtFormScreen({super.key, this.knownPersons = const []});

  @override
  State<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends State<DebtFormScreen> {
  final _service = DebtsService();
  final _personCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _direction = 'علي';
  DateTime _debtDate = DateTime.now();
  DateTime? _dueDate;
  bool _remind = true;
  bool _saving = false;

  @override
  void dispose() {
    _personCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final person = _personCtrl.text.trim();
    final amount = num.tryParse(_amountCtrl.text.trim());
    if (person.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اكتب اسم الشخص ومبلغاً صحيحاً')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.add(
        direction: _direction,
        personName: person,
        amount: amount,
        debtDate: _fmt(_debtDate),
        dueDate: _dueDate != null ? _fmt(_dueDate!) : null,
        notes: _noteCtrl.text.trim(),
        remind: _remind,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر الحفظ — تحقق من الاتصال')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دين جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'علي', label: Text('عليّ (تسلفت)'), icon: Icon(Icons.call_received)),
              ButtonSegment(value: 'لي', label: Text('لي (أقرضت)'), icon: Icon(Icons.call_made)),
            ],
            selected: {_direction},
            onSelectionChanged: (s) => setState(() => _direction = s.first),
          ),
          const SizedBox(height: 14),
          // الشخص مع إكمال تلقائي من الأسماء السابقة
          Autocomplete<String>(
            optionsBuilder: (v) => v.text.isEmpty
                ? const Iterable<String>.empty()
                : widget.knownPersons.where((p) => p.contains(v.text)),
            onSelected: (v) => _personCtrl.text = v,
            fieldViewBuilder: (ctx, ctrl, focus, _) {
              ctrl.addListener(() => _personCtrl.text = ctrl.text);
              return TextField(
                controller: ctrl,
                focusNode: focus,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'الشخص'),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'المبلغ (ريال)'),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('تاريخ الدين'),
            subtitle: Text(_fmt(_debtDate)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _debtDate,
                firstDate: DateTime(2015),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _debtDate = picked);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_available),
            title: const Text('تاريخ الاستحقاق (اختياري)'),
            subtitle: Text(_dueDate != null ? _fmt(_dueDate!) : 'بدون'),
            trailing: _dueDate != null
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _dueDate = null))
                : null,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('تذكير قبل الاستحقاق بـ٣ أيام'),
            subtitle: const Text('إشعار + رسالة في محادثة جاسر'),
            value: _remind,
            onChanged: _dueDate == null ? null : (v) => setState(() => _remind = v),
          ),
          TextField(
            controller: _noteCtrl,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ الدين'),
          ),
        ],
      ),
    );
  }
}
