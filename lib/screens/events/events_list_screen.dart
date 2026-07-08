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
      _future = _service.list();
    });
  }

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
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('ما عندك مواعيد قادمة — اضغط + لإضافة موعد')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = items[i];
                return Card(
                  child: ListTile(
                    title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text([
                      if (e.eventDate != null) '📅 ${e.eventDate}${e.eventTime != null ? ' - ${e.eventTime}' : ''}',
                      if (e.location != null && e.location!.isNotEmpty) '📍 ${e.location}',
                      if (e.doctorName != null && e.doctorName!.isNotEmpty) '🩺 د. ${e.doctorName}',
                    ].join('\n')),
                    isThreeLine: true,
                    onTap: () => _openForm(event: e),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _delete(e),
                    ),
                  ),
                );
              },
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
