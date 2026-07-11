import 'package:flutter/material.dart';
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

  Future<void> _share() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مشاركة المهمة'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'اسم جهة الاتصال')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('مشاركة')),
        ],
      ),
    );
    if (result == true && controller.text.trim().isNotEmpty) {
      try {
        await _service.share(widget.taskId, controller.text.trim());
        _changed = true;
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت المشاركة')));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('تعذرت المشاركة — تأكد أن الشخص جهة اتصال مرتبطة بحسابه')));
        }
      }
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
                Text('التقدم: ${t.progress}%'),
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
