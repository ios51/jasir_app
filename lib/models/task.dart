class AppSubtask {
  final int id;
  final String title;
  final bool completed;
  final String? assigneeName;

  AppSubtask({
    required this.id,
    required this.title,
    required this.completed,
    this.assigneeName,
  });

  factory AppSubtask.fromJson(Map<String, dynamic> j) => AppSubtask(
        id: j['id'],
        title: j['title'] ?? '',
        completed: (j['completed'] ?? 0) == 1,
        assigneeName: j['assignee_name'],
      );
}

class AppTask {
  final int id;
  String title;
  String startType; // immediate | scheduled
  String? startDate;
  String endType; // deadline | open
  String? dueDate;
  int progress;
  bool completed;
  bool isShared;
  List<AppSubtask> subtasks;
  bool hasSubtasks;

  AppTask({
    required this.id,
    required this.title,
    this.startType = 'immediate',
    this.startDate,
    this.endType = 'open',
    this.dueDate,
    this.progress = 0,
    this.completed = false,
    this.isShared = false,
    this.subtasks = const [],
    this.hasSubtasks = false,
  });

  factory AppTask.fromJson(Map<String, dynamic> j) => AppTask(
        id: j['id'],
        title: j['title'] ?? '',
        startType: j['start_type'] ?? 'immediate',
        startDate: j['start_date'],
        endType: j['end_type'] ?? 'open',
        dueDate: j['due_date'],
        progress: j['progress'] ?? j['progress_pct'] ?? 0,
        completed: (j['completed'] ?? 0) == 1,
        isShared: (j['is_shared'] ?? 0) == 1,
        hasSubtasks: j['hasSubtasks'] ?? false,
        subtasks: (j['subtasks'] as List<dynamic>? ?? [])
            .map((s) => AppSubtask.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
