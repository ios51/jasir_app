import 'notification_service.dart';
import 'events_service.dart';
import 'tasks_service.dart';
import 'settings_service.dart';
import 'module_service.dart';

/// يزامن التنبيهات المحلية مع بيانات جاسر: يجلب المواعيد والمهام
/// ووقت رسالة الصباح، ويجدولها كتنبيهات على الجهاز.
class NotificationSync {
  static Future<void> run() async {
    try {
      await NotificationService.requestPermission();
      await NotificationService.cancelAll();
      int id = 1;

      // ── المواعيد: تذكير مبكّر + تنبيه قريب قبل ٣٠ دقيقة ──
      try {
        final events = await EventsService().list(upcomingOnly: true);
        for (final e in events) {
          if (e.eventDate == null ||
              e.eventTime == null ||
              e.eventTime!.isEmpty) continue;
          final dt = _parse(e.eventDate!, e.eventTime!);
          if (dt == null) continue;
          final lead = e.notifyBefore <= 0 ? 60 : e.notifyBefore;
          final who = (e.personName != null && e.personName!.isNotEmpty)
              ? e.personName
              : 'موعدك';
          await NotificationService.scheduleAt(
            id++,
            '🔔 تذكير موعد',
            '$who — ${e.title} الساعة ${e.eventTime}',
            dt.subtract(Duration(minutes: lead)),
          );
          final near = e.apptType == 'remote'
              ? 'فعّل جوالك — بيتصلون على ${e.personName ?? "المريض"}'
              : 'جهّز الهوية ورقم الملف الطبي للاستقبال';
          await NotificationService.scheduleAt(
            id++,
            '📍 ${e.title} بعد ٣٠ دقيقة',
            near,
            dt.subtract(const Duration(minutes: 30)),
          );
        }
      } catch (_) {}

      // ── المهام: تذكير يوم التسليم ──
      try {
        final r = await TasksService().list();
        for (final t in [...r.owned, ...r.shared]) {
          if (t.completed || t.dueDate == null) continue;
          final dt = _parse(t.dueDate!, '09:00');
          if (dt == null) continue;
          await NotificationService.scheduleAt(
            id++,
            '📋 مهمة اليوم',
            '${t.title} — موعد التسليم اليوم',
            dt,
          );
        }
      } catch (_) {}

      // ── الأدوية: جرعات اليوم والغد (أوقات ثابتة أو كل N ساعة) ──
      try {
        final meds = await ModuleService('/api/v1/meds').list();
        final now = DateTime.now();
        for (final m in meds) {
          final name = (m['name'] ?? 'دواء').toString();
          final person = (m['person_name'] ?? '').toString();
          final who = person.isNotEmpty ? ' لـ$person' : '';
          final times = _doseTimes(m); // قائمة "HH:MM"
          for (final hm in times) {
            final p = hm.split(':');
            final h = int.tryParse(p[0]) ?? 0;
            final mi = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
            // جدول لليوم والغد لضمان تغطية الجرعات القادمة
            for (final addDay in [0, 1]) {
              var when = DateTime(now.year, now.month, now.day, h, mi).add(Duration(days: addDay));
              if (when.isBefore(now)) continue;
              await NotificationService.scheduleAt(
                id++,
                '💊 موعد دواء$who',
                '$name — الساعة $hm',
                when,
              );
            }
          }
        }
      } catch (_) {}

      // ── رسالة الصباح اليومية ──
      try {
        final s = await SettingsService().getSettings();
        final enabled = (s['morning_enabled'] ?? 1).toString() != '0';
        if (enabled) {
          final time = (s['morning_time'] as String?) ?? '07:00';
          final parts = time.split(':');
          final h = int.tryParse(parts.isNotEmpty ? parts[0] : '7') ?? 7;
          final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
          final now = DateTime.now();
          var when = DateTime(now.year, now.month, now.day, h, m);
          if (when.isBefore(now)) when = when.add(const Duration(days: 1));
          await NotificationService.scheduleAt(
            9000,
            '🌅 صباح الخير',
            'رسالتك الصباحية جاهزة — افتح جاسر',
            when,
            daily: true,
          );
        }
      } catch (_) {}
    } catch (_) {}
  }

  /// أوقات جرعات اليوم من تعريف الدواء: أوقات ثابتة (time_slots) أو
  /// كل عدد ساعات (interval_hours + first_dose_time). يُرجع قائمة "HH:MM".
  static List<String> _doseTimes(Map<String, dynamic> m) {
    final mode = (m['time_mode'] ?? 'fixed').toString();
    final out = <String>[];
    if (mode == 'interval') {
      final ih = int.tryParse((m['interval_hours'] ?? '').toString()) ?? 0;
      final first = (m['first_dose_time'] ?? '').toString();
      if (ih > 0 && first.contains(':')) {
        final p = first.split(':');
        var h = int.tryParse(p[0]) ?? 8;
        final mi = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
        // ولّد جرعات اليوم من أول جرعة حتى نهاية اليوم
        for (int t = h; t < 24; t += ih) {
          out.add('${t.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}');
        }
      }
    } else {
      final slots = (m['time_slots'] ?? '').toString();
      for (final s in slots.split(',')) {
        final v = s.trim();
        if (v.contains(':')) out.add(v);
      }
    }
    return out;
  }

  static DateTime? _parse(String date, String time) {
    try {
      final d = date.split('-');
      final t = time.split(':');
      return DateTime(
        int.parse(d[0]),
        int.parse(d[1]),
        int.parse(d[2]),
        int.parse(t[0]),
        int.parse(t.length > 1 ? t[1] : '0'),
      );
    } catch (_) {
      return null;
    }
  }
}
