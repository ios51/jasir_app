import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/task.dart';
import '../../services/tasks_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final int taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _service = TasksService();
  late Future<AppTask> _future;
  bool _changed = false;
  double? _dragProgress; // قيمة السحّاب أثناء السحب

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _service.getDetail(widget.taskId);
    });
  }

  Future<void> _addSubtask() async {
    final titleController = TextEditingController();
    final assigneeController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة مهمة فرعية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'العنوان')),
            TextField(controller: assigneeController, decoration: const InputDecoration(labelText: 'إسناد إلى (اختياري)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة')),
        ],
      ),
    );
    if (result == true && titleController.text.trim().isNotEmpty) {
      await _service.addSubtask(
        widget.taskId,
        titleController.text.trim(),
        assigneeName: assigneeController.text.trim().isEmpty ? null : assigneeController.text.trim(),
      );
      _changed = true;
      _reload();
    }
  }

  Future<void> _completeSubtask(int id) async {
    await _service.completeSubtask(id);
    _changed = true;
    _reload();
  }

  Future<void> _setProgress(int pct) async {
    try {
      await _service.setProgress(widget.taskId, pct);
      _changed = true;
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحديث النسبة')));
    }
  }

  Future<void> _share() async {
    try {
      final code = await _service.invite(widget.taskId);
      _changed = true;
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('مشاركة المهمة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('أعطِ هذا الكود لأعضاء فريقك — يدخلونه من "الانضمام بكود" في المهام:',
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            SelectableText(code,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 4)),
          ]),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('نُسخ الكود: $code')));
              },
              child: const Text('نسخ'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذرت المشاركة')));
    }
  }

  Future<void> _complete() async {
    await _service.complete(widget.taskId);
    _changed = true;
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المهمة'),
        content: const Text('هل تريد حذف هذه المهمة نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirm == true) {
      await _service.delete(widget.taskId);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل المهمة'),
          actions: [
            IconButton(icon: const Icon(Icons.people_alt_outlined), tooltip: 'مشاركة', onPressed: _share),
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'حذف', onPressed: _delete),
          ],
        ),
        body: FutureBuilder<AppTask>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('تعذر تحميل المهمة: ${snapshot.error}'));
            }
            final t = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(t.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: t.progress / 100, minHeight: 8),
                const SizedBox(height: 8),
                Text('التقدم: ${_dragProgress?.round() ?? t.progress}%',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (t.subtasks.isEmpty) ...[
                  Slider(
                    value: (_dragProgress ?? t.progress.toDouble()).clamp(0, 100),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${(_dragProgress ?? t.progress.toDouble()).round()}%',
                    onChanged: (v) => setState(() => _dragProgress = v),
                    onChangeEnd: (v) {
                      _dragProgress = null;
                      _setProgress(v.round());
                    },
                  ),
                  Wrap(
                    spacing: 6,
                    children: [0, 25, 50, 75, 100]
                        .map((p) => ActionChip(label: Text('$p%'), onPressed: () => _setProgress(p)))
                        .toList(),
                  ),
                ] else
                  Text('النسبة محسوبة تلقائياً من المهام الفرعية',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 4),
                Text(t.startType == 'scheduled' && t.startDate != null ? 'يبدأ: ${t.startDate}' : 'يبدأ: فوري'),
                Text(t.endType == 'deadline' && t.dueDate != null ? '⏳ الموعد النهائي: ${t.dueDate}' : '⏳ بدون موعد نهائي'),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المهام الفرعية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(onPressed: _addSubtask, icon: const Icon(Icons.add), label: const Text('إضافة')),
                  ],
                ),
                if (t.subtasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('بدون مهام فرعية — النسبة تُحدَّث يدوياً'),
                  )
                else
                  ...t.subtasks.map((s) => CheckboxListTile(
                        value: s.completed,
                        onChanged: s.completed ? null : (_) => _completeSubtask(s.id),
                        title: Text(s.title, style: TextStyle(decoration: s.completed ? TextDecoration.lineThrough : null)),
                        subtitle: s.assigneeName != null ? Text(s.assigneeName!) : null,
                      )),
                const SizedBox(height: 24),
                if (!t.completed)
                  ElevatedButton.icon(
                    onPressed: _complete,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('إنهاء المهمة بالكامل'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
