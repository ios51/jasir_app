import 'package:flutter/material.dart';
import '../../services/api_client.dart';

/// سجل صيانة سيارة واحدة: يعرض كل عمليات الصيانة (زيت محرك، زيت قير، أقمشة،
/// قطع غيار...) مع التكلفة والتاريخ والورشة، ومجموع الصرف، ويسمح بالإضافة.
class CarServiceLogScreen extends StatefulWidget {
  final int carId;
  final String carName;
  const CarServiceLogScreen({super.key, required this.carId, required this.carName});

  @override
  State<CarServiceLogScreen> createState() => _CarServiceLogScreenState();
}

class _CarServiceLogScreenState extends State<CarServiceLogScreen> {
  final _dio = ApiClient.instance.dio;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _load();
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await _dio.get('/api/v1/cars/${widget.carId}/services');
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  double _total(List<Map<String, dynamic>> items) {
    double t = 0;
    for (final it in items) {
      final c = it['cost'];
      if (c is num) t += c.toDouble();
      else if (c != null) t += double.tryParse(c.toString()) ?? 0;
    }
    return t;
  }

  Future<void> _add() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AddServiceSheet(carId: widget.carId),
      ),
    );
    if (ok == true) _reload();
  }

  String _fmtCost(dynamic c) {
    final n = c is num ? c : double.tryParse('${c ?? ''}') ?? 0;
    return n == 0 ? '—' : '${n.toStringAsFixed(n % 1 == 0 ? 0 : 2)} ⃀';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('سجل صيانة — ${widget.carName}')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('إضافة صيانة'),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('تعذر التحميل: ${snap.error}'));
            }
            final items = snap.data ?? [];
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  color: cs.primaryContainer,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إجمالي الصرف على الصيانة',
                          style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('${_total(items).toStringAsFixed(_total(items) % 1 == 0 ? 0 : 2)} ⃀',
                          style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Text('${items.length} عملية صيانة',
                          style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('لا يوجد سجل صيانة بعد — اضغط "إضافة صيانة"'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final it = items[i];
                            final wshop = [it['workshop'], it['workshop_location']]
                                .where((e) => e != null && e.toString().isNotEmpty)
                                .join(' — ');
                            final sub = <String>[];
                            if (it['service_date'] != null) sub.add('التاريخ: ${it['service_date']}');
                            if (it['odometer'] != null && it['odometer'] != 0) sub.add('🛣 ${it['odometer']} كم');
                            if (wshop.isNotEmpty) sub.add('🔧 $wshop');
                            if (it['oil_type'] != null && it['oil_type'].toString().isNotEmpty) {
                              sub.add('🛢 ${it['oil_type']}${(it['with_filter'] == 1) ? ' + فلتر' : ''}');
                            }
                            if (it['notes'] != null && it['notes'].toString().isNotEmpty) sub.add('📝 ${it['notes']}');
                            return Card(
                              child: ListTile(
                                leading: Icon(Icons.build_circle_outlined, color: Theme.of(context).colorScheme.primary),
                                title: Text(it['service_type']?.toString() ?? 'صيانة',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: sub.isEmpty ? null : Text(sub.join('\n')),
                                isThreeLine: sub.length > 1,
                                trailing: Text(_fmtCost(it['cost']),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// نموذج إضافة عملية صيانة (bottom sheet).
class _AddServiceSheet extends StatefulWidget {
  final int carId;
  const _AddServiceSheet({required this.carId});

  @override
  State<_AddServiceSheet> createState() => _AddServiceSheetState();
}

class _AddServiceSheetState extends State<_AddServiceSheet> {
  final _dio = ApiClient.instance.dio;
  final _type = TextEditingController();
  final _odometer = TextEditingController();
  final _cost = TextEditingController();
  final _workshop = TextEditingController();
  final _workshopLoc = TextEditingController();
  final _oilType = TextEditingController();
  final _notes = TextEditingController();
  bool _withFilter = false;
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _common = [
    'زيت المحرك', 'زيت القير', 'فلتر', 'إطارات', 'بطارية', 'تنجيد/أقمشة', 'فرامل', 'قطعة أخرى'
  ];

  @override
  void dispose() {
    for (final c in [_type, _odometer, _cost, _workshop, _workshopLoc, _oilType, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_type.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب نوع الصيانة أو القطعة')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _dio.post('/api/v1/cars/${widget.carId}/services', data: {
        'serviceType': _type.text.trim(),
        'serviceDate': _dateStr,
        if (_odometer.text.trim().isNotEmpty) 'odometer': _odometer.text.trim(),
        if (_cost.text.trim().isNotEmpty) 'cost': _cost.text.trim(),
        if (_workshop.text.trim().isNotEmpty) 'workshop': _workshop.text.trim(),
        if (_workshopLoc.text.trim().isNotEmpty) 'workshopLocation': _workshopLoc.text.trim(),
        if (_oilType.text.trim().isNotEmpty) 'oilType': _oilType.text.trim(),
        'withFilter': _withFilter,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إضافة عملية صيانة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: _common
                    .map((t) => ActionChip(label: Text(t), onPressed: () => setState(() => _type.text = t)))
                    .toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _type,
                decoration: const InputDecoration(
                    labelText: 'نوع الصيانة / القطعة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(_date.year - 6),
                        lastDate: DateTime(_date.year + 1),
                      );
                      if (p != null) setState(() => _date = p);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'التاريخ', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                      child: Text(_dateStr),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _cost,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'التكلفة (ريال)', border: OutlineInputBorder()),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _odometer,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'قراءة العداد (كم)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _workshop,
                decoration: const InputDecoration(labelText: 'اسم الورشة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _workshopLoc,
                decoration: const InputDecoration(labelText: 'موقع الورشة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _oilType,
                decoration: const InputDecoration(
                    labelText: 'نوع الزيت (إن وُجد)', border: OutlineInputBorder()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('مع تغيير الفلتر'),
                value: _withFilter,
                onChanged: (v) => setState(() => _withFilter = v),
              ),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
