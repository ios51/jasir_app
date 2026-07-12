import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../services/events_service.dart';
import 'event_form_screen.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  final _service = EventsService();
  late Future<List<AppEvent>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _service.list(upcomingOnly: false);
    });
  }

  Widget _line(IconData ic, String t) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(children: [
        Icon(ic, size: 14, color: cs.primary),
        const SizedBox(width: 5),
        Expanded(child: Text(t, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
      ]),
    );
  }

  Widget _eventCard(AppEvent e) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.eventDate != null)
                _line(Icons.calendar_today, '${e.eventDate}${e.eventTime != null ? ' - ${e.eventTime}' : ''}'),
              if (e.hospital != null && e.hospital!.isNotEmpty) _line(Icons.local_hospital_outlined, e.hospital!),
              if (e.clinic != null && e.clinic!.isNotEmpty) _line(Icons.medical_services_outlined, e.clinic!),
              if (e.apptNumber != null && e.apptNumber!.isNotEmpty) _line(Icons.confirmation_number_outlined, 'رقم الموعد: ${e.apptNumber}'),
              if ((e.hospital == null || e.hospital!.isEmpty) && e.location != null && e.location!.isNotEmpty)
                _line(Icons.place_outlined, e.location!),
              if (e.doctorName != null && e.doctorName!.isNotEmpty) _line(Icons.person_outline, 'د. ${e.doctorName}'),
              if (e.locationUrl != null && e.locationUrl!.isNotEmpty)
                _line(Icons.map_outlined, 'الموقع على الخريطة'),
            ],
          ),
          onTap: () => _openForm(event: e),
          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _delete(e)),
        ),
      );

  Future<void> _openForm({AppEvent? event}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventFormScreen(event: event)),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(AppEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الموعد'),
        content: Text('هل تريد حذف "${event.title}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirm == true) {
      await _service.delete(event.id!);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<AppEvent>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('تعذر تحميل المواعيد: ${snapshot.error}'));
            }
            final items = snapshot.data ?? [];
            final now = DateTime.now();
            final todayStr =
                '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            bool isPast(AppEvent e) => e.eventDate != null && e.eventDate!.compareTo(todayStr) < 0;
            final upcoming = items.where((e) => !isPast(e)).toList();
            final past = items.where(isPast).toList();
            if (upcoming.isEmpty && past.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(child: Text('ما عندك مواعيد — اضغط + لإضافة موعد')),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ...upcoming.map(_eventCard),
                if (upcoming.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('ما عندك مواعيد قادمة'))),
                if (past.isNotEmpty)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 6),
                      leading: const Icon(Icons.history),
                      title: Text('المواعيد السابقة (${past.length})'),
                      childrenPadding: EdgeInsets.zero,
                      children: past.map(_eventCard).toList(),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
