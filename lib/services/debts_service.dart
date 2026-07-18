import 'package:dio/dio.dart';
import 'api_client.dart';

/// دفعة سداد واحدة.
class DebtPayment {
  final num amount;
  final String notes;
  final String paidAt;

  DebtPayment({required this.amount, required this.notes, required this.paidAt});

  factory DebtPayment.fromJson(Map<String, dynamic> j) => DebtPayment(
        amount: (j['amount_paid'] ?? 0) as num,
        notes: j['notes']?.toString() ?? '',
        paidAt: (j['paid_at'] ?? '').toString(),
      );
}

/// دين واحد مع دفعاته.
class Debt {
  final int id;
  final String direction; // 'لي' | 'علي'
  final String personName;
  final num amount;
  final num remaining;
  final String debtDate;
  final String dueDate;
  final String notes;
  final String status; // active | paid
  final bool remind;
  final List<DebtPayment> payments;

  Debt({required this.id, required this.direction, required this.personName, required this.amount, required this.remaining, required this.debtDate, required this.dueDate, required this.notes, required this.status, required this.remind, required this.payments});

  bool get isMine => direction == 'لي'; // لي عند الشخص
  bool get settled => status == 'paid';

  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
        id: (j['id'] as num).toInt(),
        direction: (j['direction'] ?? 'علي').toString(),
        personName: (j['person_name'] ?? '').toString(),
        amount: (j['amount'] ?? 0) as num,
        remaining: (j['remaining'] ?? j['amount'] ?? 0) as num,
        debtDate: j['debt_date']?.toString() ?? '',
        dueDate: j['due_date']?.toString() ?? '',
        notes: j['notes']?.toString() ?? '',
        status: (j['status'] ?? 'active').toString(),
        remind: j['remind'] == 1 || j['remind'] == true,
        payments: ((j['payments'] ?? []) as List)
            .map((e) => DebtPayment.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// ملخص شخص واحد.
class PersonSummary {
  final String person;
  final num activeOnMe; // عليّ له
  final num activeToMe; // لي عنده
  final num totalBorrowed; // كم تسلفت منه تاريخياً
  final num totalLent; // كم أقرضته تاريخياً
  final int activeCount;
  final int settledCount;

  PersonSummary({required this.person, required this.activeOnMe, required this.activeToMe, required this.totalBorrowed, required this.totalLent, required this.activeCount, required this.settledCount});

  factory PersonSummary.fromJson(Map<String, dynamic> j) => PersonSummary(
        person: (j['person'] ?? '').toString(),
        activeOnMe: (j['activeOnMe'] ?? 0) as num,
        activeToMe: (j['activeToMe'] ?? 0) as num,
        totalBorrowed: (j['totalBorrowed'] ?? 0) as num,
        totalLent: (j['totalLent'] ?? 0) as num,
        activeCount: ((j['activeCount'] ?? 0) as num).toInt(),
        settledCount: ((j['settledCount'] ?? 0) as num).toInt(),
      );
}

class DebtsSummary {
  final num owedByMe;
  final num owedToMe;
  final List<PersonSummary> persons;
  DebtsSummary({required this.owedByMe, required this.owedToMe, required this.persons});
}

class DebtsService {
  final Dio _dio = ApiClient.instance.dio;

  Future<DebtsSummary> summary() async {
    final res = await _dio.get('/api/v1/debts/summary');
    return DebtsSummary(
      owedByMe: (res.data['owedByMe'] ?? 0) as num,
      owedToMe: (res.data['owedToMe'] ?? 0) as num,
      persons: ((res.data['persons'] ?? []) as List)
          .map((e) => PersonSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<List<Debt>> personHistory(String name) async {
    final res = await _dio.get('/api/v1/debts/person/${Uri.encodeComponent(name)}');
    return ((res.data ?? []) as List)
        .map((e) => Debt.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> add({
    required String direction,
    required String personName,
    required num amount,
    String? debtDate,
    String? dueDate,
    String? notes,
    bool remind = true,
  }) =>
      _dio.post('/api/v1/debts', data: {
        'direction': direction,
        'personName': personName,
        'amount': amount,
        if (debtDate != null && debtDate.isNotEmpty) 'debtDate': debtDate,
        if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'remind': remind,
      });

  Future<void> pay(int id, {required num amount, String? notes, String? paidAt}) =>
      _dio.post('/api/v1/debts/$id/pay', data: {
        'amount': amount,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (paidAt != null && paidAt.isNotEmpty) 'paidAt': paidAt,
      });

  Future<void> delete(int id) => _dio.delete('/api/v1/debts/$id');
}
