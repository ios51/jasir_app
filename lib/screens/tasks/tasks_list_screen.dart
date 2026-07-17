import 'package:flutter/material.dart';
import '../../models/task.dart';
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
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _service.list();
    });
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

  Widget _buildList(List<AppTask> items) {
    if (items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('لا توجد مهام')),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = items[i];
        return Card(
          child: ListTile(
            title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                LinearProgressIndicator(value: t.progress / 100),
                const SizedBox(height: 4),
                Text('${t.progress}%' + (t.dueDate != null ? '  •  نهاية: ${t.dueDate}' : '  •  بدون موعد نهائي')),
              ],
            ),
            trailing: t.isShared ? const Icon(Icons.people_outline) : null,
            onTap: () => _openDetail(t),
          ),
        );
      },
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
