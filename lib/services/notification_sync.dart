import 'notification_service.dart';
import 'events_service.dart';
import 'tasks_service.dart';
import 'module_service.dart';
import 'worship_prefs.dart';
import '../utils/prayer_times.dart';
import '../data/worship_content.dart';

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

      // ── الجدول والمحاضرات: تنبيه قبل بداية المحاضرة/الحصة ──
      // كانت المحاضرات تصل واتساب فقط (من السيرفر) بلا تنبيه على التطبيق.
      // الآن نجدول تنبيهاً محلياً لكل حصة قادمة خلال ٤٨ ساعة حسب تكرارها.
      try {
        final sched = await ModuleService('/api/v1/schedule').list();
        final now = DateTime.now();
        for (final s in sched) {
          final start = (s['start_time'] ?? '').toString();
          if (!start.contains(':')) continue;
          final title = (s['title'] ?? 'محاضرة').toString();
          final loc = (s['location'] ?? '').toString();
          final bno = (s['building_no'] ?? '').toString();
          final lead = int.tryParse((s['notify_before'] ?? '').toString()) ?? 15;
          final where = [
            if (loc.isNotEmpty) loc,
            if (bno.isNotEmpty) 'مبنى $bno',
          ].join(' • ');
          for (final when in _scheduleDateTimes(s, now)) {
            items.add(_Sched(
              '📚 $title',
              where.isNotEmpty ? '$where — الساعة $start' : 'تبدأ الساعة $start',
              when.subtract(Duration(minutes: lead <= 0 ? 15 : lead)),
            ));
          }
        }
      } catch (_) {}

      // ── العبادة: صلوات (أذان/إقامة) + أذكار الصباح/المساء + ذكر متكرر + فائدة ──
      try {
        items.addAll(_worshipItems());
      } catch (_) {}

      // الأقرب أولاً، وبحد أقصى 59 (+ رسالة الصباح 9000 = 60 ضمن حد iOS)
      items.sort((a, b) => a.when.compareTo(b.when));
      int id = 1;
      for (final it in items.take(59)) {
        await NotificationService.scheduleAt(
          id++, it.title, it.body, it.when, payload: it.payload, sound: it.sound,
        );
      }

      // ── رسالة الصباح ──
      // صار إشعارها يصل من السيرفر مباشرة (Push عبر APNs) لحظة إرسالها —
      // يصل حتى لو كان الجوال مطفأً وقتها (يتسلمه فور التشغيل). الإشعار
      // المحلي القديم (id 9000) أُزيل حتى لا يصلك إشعاران كل صباح،
      // وننظف أي نسخة قديمة مجدولة منه:
      try { await NotificationService.cancelId(9000); } catch (_) {}
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

  /// تنبيهات وحدة العبادة (صلوات + أذكار + ذكر متكرر + فائدة) لليوم والغد.
  static List<_Sched> _worshipItems() {
    final out = <_Sched>[];
    final now = DateTime.now();
    final city = saudiCities[
        (WorshipPrefs.cityIndex >= 0 && WorshipPrefs.cityIndex < saudiCities.length)
            ? WorshipPrefs.cityIndex
            : 0];

    // ── الصلوات: أذان لكل صلاة + إقامة بعده ──
    if (WorshipPrefs.prayerEnabled) {
      for (int addDay = 0; addDay <= 1; addDay++) {
        final day = DateTime(now.year, now.month, now.day + addDay);
        final pt = PrayerTimes.forDate(day, city.lat, city.lng, 3.0);
        final prayers = <String, DateTime>{
          'الفجر': pt.fajr,
          'الظهر': pt.dhuhr,
          'العصر': pt.asr,
          'المغرب': pt.maghrib,
          'العشاء': pt.isha,
        };
        prayers.forEach((name, t) {
          if (WorshipPrefs.adhanEnabled && t.isAfter(now)) {
            out.add(_Sched('🕌 حان الآن وقت أذان $name',
                'حيّ على الصلاة — ${_hm(t)}', t, payload: 'worship', sound: WorshipPrefs.sound));
          }
          if (WorshipPrefs.iqamaEnabled) {
            final iq = t.add(Duration(minutes: WorshipPrefs.iqamaDelay));
            if (iq.isAfter(now)) {
              out.add(_Sched('🧎 إقامة صلاة $name',
                  'قامت الصلاة — استعد', iq, payload: 'worship'));
            }
          }
        });
      }
    }

    // ── أذكار الصباح والمساء ──
    if (WorshipPrefs.adhkarEnabled) {
      final m = _todayOrTomorrow(WorshipPrefs.morningTime, now);
      if (m != null) out.add(_Sched('🌅 أذكار الصباح', 'حصّن يومك بأذكار الصباح', m, payload: 'adhkar|m'));
      final e = _todayOrTomorrow(WorshipPrefs.eveningTime, now);
      if (e != null) out.add(_Sched('🌆 أذكار المساء', 'حصّن ليلتك بأذكار المساء', e, payload: 'adhkar|e'));
    }

    // ── فائدة اليوم (آية/حديث بشرحه) ──
    if (WorshipPrefs.faidahEnabled) {
      final f = _todayOrTomorrow(WorshipPrefs.faidahTime, now);
      if (f != null) out.add(_Sched('💡 فائدة اليوم', 'اضغط لقراءة فائدة اليوم', f, payload: 'faidah'));
    }

    // ── ذكر متكرر (بحد أقصى 6 لتفادي إغراق حد iOS) ──
    // صمت ليلي: لا يُرسل ذكر من ١٠ مساءً (22:00) حتى ٦ صباحاً (06:00).
    if (WorshipPrefs.dhikrEnabled && WorshipPrefs.dhikrIntervalHours > 0) {
      var t = now.add(Duration(hours: WorshipPrefs.dhikrIntervalHours));
      final limit = now.add(const Duration(hours: 36)); // نطاق أوسع لتعويض ساعات الصمت
      int i = 0, added = 0;
      while (added < 6 && t.isBefore(limit)) {
        if (t.hour >= 6 && t.hour < 22) { // ضمن ساعات النهار المسموحة
          out.add(_Sched('📿 ذِكر', hourlyDhikr[i % hourlyDhikr.length].text, t, payload: 'worship'));
          added++;
          i++;
        }
        t = t.add(Duration(hours: WorshipPrefs.dhikrIntervalHours));
      }
    }
    return out;
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// يحوّل "HH:MM" لأقرب حدوث قادم (اليوم إن لم يفت، وإلا الغد).
  static DateTime? _todayOrTomorrow(String hhmm, DateTime now) {
    if (!hhmm.contains(':')) return null;
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
    var when = DateTime(now.year, now.month, now.day, h, m);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    return when;
  }

  /// مواعيد حصص الجدول القادمة (اليوم + الغد) حسب التكرار — يطابق منطق
  /// السيرفر (schedule.js itemAppliesToDate). أيام الأسبوع بصيغة السيرفر:
  /// 0=الأحد ... 6=السبت.
  static List<DateTime> _scheduleDateTimes(Map<String, dynamic> s, DateTime now) {
    final out = <DateTime>[];
    final start = (s['start_time'] ?? '').toString();
    if (!start.contains(':')) return out;
    final sp = start.split(':');
    final sh = int.tryParse(sp[0]) ?? 0;
    final sm = int.tryParse(sp.length > 1 ? sp[1] : '0') ?? 0;
    final type = (s['recurrence_type'] ?? '').toString();
    final daysRaw = (s['recurrence_days'] ?? '').toString();
    final startDate = (s['start_date'] ?? '').toString();

    for (int addDay = 0; addDay <= 1; addDay++) {
      final day = DateTime(now.year, now.month, now.day + addDay);
      final jsDay = day.weekday % 7; // Dart: الأحد=7→0، الاثنين=1..السبت=6
      if (startDate.isNotEmpty) {
        final ds = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        if (ds.compareTo(startDate) < 0) continue;
      }
      bool applies = false;
      switch (type) {
        case 'daily':
          applies = true;
          break;
        case 'weekly':
          applies = daysRaw.split(',').map((x) => int.tryParse(x.trim())).contains(jsDay);
          break;
        case 'biweekly':
          if (daysRaw.split(',').map((x) => int.tryParse(x.trim())).contains(jsDay) && startDate.isNotEmpty) {
            final st = DateTime.tryParse(startDate);
            if (st != null) {
              final weeks = (day.difference(DateTime(st.year, st.month, st.day)).inDays / 7).round();
              applies = weeks % 2 == 0;
            }
          }
          break;
        case 'monthly':
          applies = (int.tryParse(daysRaw) ?? 1) == day.day;
          break;
        case 'yearly':
          final mmdd = '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          applies = daysRaw == mmdd;
          break;
      }
      if (!applies) continue;
      final when = DateTime(day.year, day.month, day.day, sh, sm);
      if (when.isAfter(now)) out.add(when);
    }
    return out;
  }
}

/// تنبيه مرشّح للجدولة (يُرتَّب زمنياً قبل الجدولة الفعلية).
class _Sched {
  final String title;
  final String body;
  final DateTime when;
  final String? payload;
  final String? sound; // 'adhan' لتنبيه الأذان بصوته
  _Sched(this.title, this.body, this.when, {this.payload, this.sound});
}
