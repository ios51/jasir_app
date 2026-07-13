import 'package:flutter/material.dart';
import '../../services/worship_prefs.dart';
import '../../services/notification_sync.dart';
import '../../utils/prayer_times.dart';
import '../../data/worship_content.dart';
import 'adhkar_reader_screen.dart';

/// شاشة العبادة: مواقيت الصلاة (أذان/إقامة)، أذكار الصباح/المساء،
/// الذكر المتكرر، وفائدة اليوم — كلها بتنبيهات على الجهاز (بلا إنترنت).
class WorshipScreen extends StatefulWidget {
  /// وجهة أولية: 'm' أذكار الصباح، 'e' أذكار المساء، 'faidah' فائدة اليوم.
  final String? openTarget;
  const WorshipScreen({super.key, this.openTarget});

  @override
  State<WorshipScreen> createState() => _WorshipScreenState();
}

class _WorshipScreenState extends State<WorshipScreen> {
  @override
  void initState() {
    super.initState();
    // فتح مباشر من الإشعار
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (widget.openTarget) {
        case 'm':
          _openAdhkar('أذكار الصباح', morningAdhkar);
          break;
        case 'e':
          _openAdhkar('أذكار المساء', eveningAdhkar);
          break;
        case 'faidah':
          _showFaidah();
          break;
      }
    });
  }

  Future<void> _persist() async {
    await WorshipPrefs.save();
    NotificationSync.run(); // أعد جدولة التنبيهات فوراً
    if (mounted) setState(() {});
  }

  void _openAdhkar(String title, List<Dhikr> items) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => AdhkarReaderScreen(title: title, items: items)));
  }

  Faidah get _todayFaidah {
    final idx = DateTime.now().difference(DateTime(2020, 1, 1)).inDays % dailyFawaid.length;
    return dailyFawaid[idx];
  }

  void _showFaidah() {
    final f = _todayFaidah;
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('💡 فائدة اليوم — ${f.kind}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.text, style: const TextStyle(fontSize: 16, height: 1.9, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(f.explanation, style: const TextStyle(fontSize: 14.5, height: 1.8)),
              const SizedBox(height: 12),
              Text('المصدر: ${f.source}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
        ),
      ),
    );
  }

  Future<void> _pickTime(String current, ValueChanged<String> onSet) async {
    final p = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(p[0]) ?? 6, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0),
    );
    if (picked != null) {
      onSet('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
      _persist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final city = saudiCities[WorshipPrefs.cityIndex.clamp(0, saudiCities.length - 1)];
    final pt = PrayerTimes.forDate(DateTime.now(), city.lat, city.lng, 3.0);
    final prayers = {
      'الفجر': pt.fajr, 'الشروق': pt.sunrise, 'الظهر': pt.dhuhr,
      'العصر': pt.asr, 'المغرب': pt.maghrib, 'العشاء': pt.isha,
    };
    String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('العبادة')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // اختيار المدينة
            DropdownButtonFormField<int>(
              value: WorshipPrefs.cityIndex.clamp(0, saudiCities.length - 1),
              decoration: const InputDecoration(labelText: 'المدينة', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city)),
              items: [
                for (int i = 0; i < saudiCities.length; i++)
                  DropdownMenuItem(value: i, child: Text(saudiCities[i].name)),
              ],
              onChanged: (v) { if (v != null) { WorshipPrefs.cityIndex = v; _persist(); } },
            ),
            const SizedBox(height: 14),
            // مواقيت اليوم
            Card(
              color: cs.primaryContainer.withOpacity(0.25),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Row(children: [
                    Icon(Icons.mosque, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('مواقيت اليوم — ${city.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const Divider(),
                  ...prayers.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(e.key, style: const TextStyle(fontSize: 15)),
                          Text(hm(e.value), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ]),
                      )),
                  const SizedBox(height: 4),
                  Text('طريقة أم القرى — تقدر تضبط الدقائق لو اختلف مسجدك',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            const Text('التنبيهات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SwitchListTile(
              value: WorshipPrefs.prayerEnabled,
              onChanged: (v) { WorshipPrefs.prayerEnabled = v; _persist(); },
              title: const Text('تنبيه الصلوات'),
              contentPadding: EdgeInsets.zero,
            ),
            if (WorshipPrefs.prayerEnabled) ...[
              CheckboxListTile(
                value: WorshipPrefs.adhanEnabled,
                onChanged: (v) { WorshipPrefs.adhanEnabled = v ?? true; _persist(); },
                title: const Text('تنبيه الأذان'),
                contentPadding: const EdgeInsets.only(right: 16),
              ),
              CheckboxListTile(
                value: WorshipPrefs.iqamaEnabled,
                onChanged: (v) { WorshipPrefs.iqamaEnabled = v ?? true; _persist(); },
                title: Text('تنبيه الإقامة (بعد ${WorshipPrefs.iqamaDelay} دقيقة)'),
                contentPadding: const EdgeInsets.only(right: 16),
              ),
              if (WorshipPrefs.iqamaEnabled)
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 8),
                  child: Row(children: [
                    const Text('مدة الإقامة: '),
                    DropdownButton<int>(
                      value: WorshipPrefs.iqamaDelay,
                      items: const [5, 10, 15, 20, 25, 30]
                          .map((m) => DropdownMenuItem(value: m, child: Text('$m دقيقة'))).toList(),
                      onChanged: (v) { WorshipPrefs.iqamaDelay = v ?? 15; _persist(); },
                    ),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 8),
                child: Row(children: [
                  const Text('صوت تنبيه الأذان: '),
                  DropdownButton<String>(
                    value: WorshipPrefs.sound,
                    items: const [
                      DropdownMenuItem(value: 'default', child: Text('النغمة الافتراضية')),
                      DropdownMenuItem(value: 'adhan', child: Text('صوت الأذان 🕌')),
                    ],
                    onChanged: (v) { WorshipPrefs.sound = v ?? 'default'; _persist(); },
                  ),
                ]),
              ),
            ],
            const Divider(height: 28),
            // الأذكار
            SwitchListTile(
              value: WorshipPrefs.adhkarEnabled,
              onChanged: (v) { WorshipPrefs.adhkarEnabled = v; _persist(); },
              title: const Text('أذكار الصباح والمساء'),
              contentPadding: EdgeInsets.zero,
            ),
            if (WorshipPrefs.adhkarEnabled)
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _pickTime(WorshipPrefs.morningTime, (v) => WorshipPrefs.morningTime = v),
                  icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                  label: Text('الصباح ${WorshipPrefs.morningTime}'),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _pickTime(WorshipPrefs.eveningTime, (v) => WorshipPrefs.eveningTime = v),
                  icon: const Icon(Icons.nightlight_outlined, size: 18),
                  label: Text('المساء ${WorshipPrefs.eveningTime}'),
                )),
              ]),
            Row(children: [
              Expanded(child: TextButton(onPressed: () => _openAdhkar('أذكار الصباح', morningAdhkar), child: const Text('افتح أذكار الصباح'))),
              Expanded(child: TextButton(onPressed: () => _openAdhkar('أذكار المساء', eveningAdhkar), child: const Text('افتح أذكار المساء'))),
            ]),
            const Divider(height: 28),
            // ذكر متكرر
            SwitchListTile(
              value: WorshipPrefs.dhikrEnabled,
              onChanged: (v) { WorshipPrefs.dhikrEnabled = v; _persist(); },
              title: const Text('ذِكر متكرر'),
              subtitle: Text('كل ${WorshipPrefs.dhikrIntervalHours} ساعة'),
              contentPadding: EdgeInsets.zero,
            ),
            if (WorshipPrefs.dhikrEnabled)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: Row(children: [
                  const Text('كل: '),
                  DropdownButton<int>(
                    value: WorshipPrefs.dhikrIntervalHours,
                    items: const [1, 2, 3, 4, 6]
                        .map((h) => DropdownMenuItem(value: h, child: Text('$h ساعة'))).toList(),
                    onChanged: (v) { WorshipPrefs.dhikrIntervalHours = v ?? 1; _persist(); },
                  ),
                ]),
              ),
            const Divider(height: 28),
            // فائدة اليوم
            SwitchListTile(
              value: WorshipPrefs.faidahEnabled,
              onChanged: (v) { WorshipPrefs.faidahEnabled = v; _persist(); },
              title: const Text('فائدة اليوم (آية/حديث بشرحه)'),
              contentPadding: EdgeInsets.zero,
            ),
            if (WorshipPrefs.faidahEnabled)
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _pickTime(WorshipPrefs.faidahTime, (v) => WorshipPrefs.faidahTime = v),
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text('وقت الفائدة ${WorshipPrefs.faidahTime}'),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextButton(onPressed: _showFaidah, child: const Text('اقرأ فائدة اليوم'))),
              ]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
