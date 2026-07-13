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
      // إصلاح: كانت cancelAll تمسح أيضاً تنبيه «أعطني ١٠ دقائق» (الغفوة)
      // لو رجع المستخدم للتطبيق خلال العشر دقائق — الآن نلغي فقط ما تملكه
      // المزامنة (id < 50000) ونُبقي الغفوات.
      await NotificationService.cancelSyncOwned();

      // نجمع كل المرشّحين أولاً ثم نجدول الأقرب زمنياً — iOS يسمح بـ64
      // تنبيهاً معلّقاً فقط ويُسقط الزائد بصمت، فالترتيب يضمن ألا تضيع
      // الجرعات القريبة لصالح مواعيد بعيدة.
      final items = <_Sched>[];

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
          items.add(_Sched(
            '🔔 تذكير موعد',
            '$who — ${e.title} الساعة ${e.eventTime}',
            dt.subtract(Duration(minutes: lead)),
          ));
          final near = e.apptType == 'remote'
              ? 'فعّل جوالك — بيتصلون على ${e.personName ?? "المريض"}'
              : 'جهّز الهوية ورقم الملف الطبي للاستقبال';
          items.add(_Sched(
            '📍 ${e.title} بعد ٣٠ دقيقة',
            near,
            dt.subtract(const Duration(minutes: 30)),
          ));
        }
      } catch (_) {}

      // ── المهام: تذكير يوم التسليم ──
      try {
        final r = await TasksService().list();
        for (final t in [...r.owned, ...r.shared]) {
          if (t.completed || t.dueDate == null) continue;
          final dt = _parse(t.dueDate!, '09:00');
          if (dt == null) continue;
          items.add(_Sched(
            '📋 مهمة اليوم',
            '${t.title} — موعد التسليم اليوم',
            dt,
          ));
        }
      } catch (_) {}

      // ── الأدوية: جرعات الـ48 ساعة القادمة (أوقات ثابتة أو كل N ساعة/يوم) ──
      try {
        final meds = await ModuleService('/api/v1/meds').list();
        final now = DateTime.now();
        final horizon = now.add(const Duration(hours: 48));
        for (final m in meds) {
          final name = (m['name'] ?? 'دواء').toString();
          final person = (m['person_name'] ?? '').toString();
          final who = person.isNotEmpty ? ' لـ$person' : '';
          final medId = int.tryParse((m['id'] ?? '').toString()) ?? 0;
          for (final when in _doseDateTimes(m, now, horizon)) {
            final hm = '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
            items.add(_Sched(
              '💊 موعد دواء$who',
              '$name — الساعة $hm',
              when,
              payload: 'med|$medId|$name',
            ));
          }
        }
      } catch (_) {}

      // الأقرب أولاً، وبحد أقصى 59 (+ رسالة الصباح 9000 = 60 ضمن حد iOS)
      items.sort((a, b) => a.when.compareTo(b.when));
      int id = 1;
      for (final it in items.take(59)) {
        await NotificationService.scheduleAt(
          id++, it.title, it.body, it.when, payload: it.payload,
        );
      }

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
            payload: 'morning',
          );
        }
      } catch (_) {}
    } catch (_) {}
  }

  /// أوقات الجرعات الفعلية بين [now] و[horizon]:
  /// - interval: يبدأ من first_dose_time ويخطو كل interval_hours (يدعم أي فترة،
  ///   بالساعات أو أيام×24)، ويلتقط كل الجرعات المستقبلية ضمن النافذة بدقّة.
  /// - fixed: كل وقت في time_slots لليوم والغد وبعده.
  static List<DateTime> _doseDateTimes(Map<String, dynamic> m, DateTime now, DateTime horizon) {
    final mode = (m['time_mode'] ?? 'fixed').toString();
    final out = <DateTime>[];
    if (mode == 'interval') {
      final ih = int.tryParse((m['interval_hours'] ?? '').toString()) ?? 0;
      final first = (m['first_dose_time'] ?? '').toString();
      if (ih > 0 && first.contains(':')) {
        final p = first.split(':');
        final fh = int.tryParse(p[0]) ?? 8;
        final fm = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
        // ابدأ من جرعة اليوم الأولى، ثم ارجع للخلف حتى ما قبل الآن، ثم اخطُ للأمام
        var t = DateTime(now.year, now.month, now.day, fh, fm);
        final step = Duration(hours: ih);
        while (t.isAfter(now)) {
          t = t.subtract(step);
        }
        while (t.isBefore(horizon)) {
          if (t.isAfter(now)) out.add(t);
          t = t.add(step);
        }
      }
    } else {
      final slots = (m['time_slots'] ?? '').toString();
      for (final s in slots.split(',')) {
        final v = s.trim();
        if (!v.contains(':')) continue;
        final p = v.split(':');
        final h = int.tryParse(p[0]) ?? 0;
        final mi = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
        for (final addDay in [0, 1, 2]) {
          final when = DateTime(now.year, now.month, now.day, h, mi).add(Duration(days: addDay));
          if (when.isAfter(now) && when.isBefore(horizon)) out.add(when);
        }
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

/// تنبيه مرشّح للجدولة (يُرتَّب زمنياً قبل الجدولة الفعلية).
class _Sched {
  final String title;
  final String body;
  final DateTime when;
  final String? payload;
  _Sched(this.title, this.body, this.when, {this.payload});
}
