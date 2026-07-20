import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../services/nav_prefs.dart';
import '../../services/tasks_service.dart';
import 'notes_tab.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

class TasksListScreen extends StatefulWidget {
  const TasksListScreen({super.key});

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> with SingleTickerProviderStateMixin {
  final _service = TasksService();
  late Future<TasksResult> _future;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // زرا المهام (إضافة/انضمام) يختفيان في تبويب الملاحظات — لها حقلها الخاص
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    // تحديث عند أي تبديل تبويب سفلي (الشاشة محفوظة في IndexedStack)
    tabSwitchSignal.addListener(_onTabSwitch);
    _reload();
  }

  void _onTabSwitch() {
    if (mounted) _reload();
  }

  @override
  void dispose() {
    tabSwitchSignal.removeListener(_onTabSwitch);
    _tabController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _service.list(includeCompleted: true);
    });
  }

  Future<void> _deleteTask(AppTask t) async {
    try {
      await _service.delete(t.id);
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر الحذف — تحقق من الاتصال')));
      }
    }
  }

  Future<void> _openDetail(AppTask task) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
    );
    if (changed == true) _reload();
  }

  Future<void> _openCreate() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TaskFormScreen()),
    );
    if (saved == true) _reload();
  }

  Future<void> _joinByCode() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('الانضمام بكود'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'كود المهمة', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('انضمام')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      try {
        await _service.joinByCode(ctrl.text.trim());
        _reload();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انضممت للمهمة ✅ — شوف "مشتركة معي"')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كود غير صحيح')));
      }
    }
  }

  /// بطاقة مهمة مع حذف بالسحب (طلب المستخدم)
  Widget _taskCard(AppTask t, {bool faded = false}) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('task_${t.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final sure = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('حذف «${t.title}»؟'),
            content: t.isShared ? const Text('المهمة مشتركة — ستُحذف عند الجميع.') : null,
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
        return sure == true;
      },
      onDismissed: (_) => _deleteTask(t),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.delete_outline, color: cs.onError),
      ),
      child: Opacity(
        opacity: faded ? 0.6 : 1,
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text(t.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: t.completed ? TextDecoration.lineThrough : null,
                )),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                LinearProgressIndicator(value: t.completed ? 1 : t.progress / 100),
                const SizedBox(height: 4),
                Text(t.completed
                    ? 'مكتملة ✅'
                    : '${t.progress}%' + (t.dueDate != null ? '  •  نهاية: ${t.dueDate}' : '  •  بدون موعد نهائي')),
              ],
            ),
            trailing: t.isShared ? const Icon(Icons.people_outline) : null,
            onTap: () => _openDetail(t),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<AppTask> items) {
    final active = items.where((t) => !t.completed).toList();
    final done = items.where((t) => t.completed).toList();
    if (active.isEmpty && done.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('لا توجد مهام')),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final t in active) ...[_taskCard(t), const SizedBox(height: 8)],
        // المكتملة — مطوية حتى الضغط (طلب المستخدم، نفس نمط الديون)
        if (done.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsetsDirectional.only(start: 6, end: 6),
              leading: const Icon(Icons.task_alt, size: 20),
              title: Text('المكتملة (${done.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              children: [
                for (final t in done)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _taskCard(t, faded: true),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'مهامي'), Tab(text: 'مشتركة معي'), Tab(text: 'ملاحظات')],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: FutureBuilder<TasksResult>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('تعذر تحميل المهام: ${snapshot.error}'));
                  }
                  final data = snapshot.data ?? TasksResult([], []);
                  return TabBarView(
                    controller: _tabController,
                    children: [_buildList(data.owned), _buildList(data.shared), const NotesTab()],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 2
          ? null // تبويب الملاحظات: الإضافة من الحقل العلوي — لا حاجة لأزرار
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'joinTask',
                  onPressed: _joinByCode,
                  tooltip: 'الانضمام بكود',
                  child: const Icon(Icons.vpn_key_outlined),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'addTask',
                  onPressed: _openCreate,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
    );
  }
}
