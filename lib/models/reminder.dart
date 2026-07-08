class AppReminder {
  final int? id;
  String title;
  String remindAt; // "YYYY-MM-DD HH:MM"
  String repeatType; // none | daily | weekly

  AppReminder({
    this.id,
    required this.title,
    required this.remindAt,
    this.repeatType = 'none',
  });

  factory AppReminder.fromJson(Map<String, dynamic> j) => AppReminder(
        id: j['id'] as int?,
        title: j['title'] ?? '',
        remindAt: j['remind_at'] ?? '',
        repeatType: j['repeat_type'] ?? 'none',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'remindAt': remindAt,
        'repeatType': repeatType,
      };
}
