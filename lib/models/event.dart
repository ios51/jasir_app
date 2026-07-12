class AppEvent {
  final int? id;
  String title;
  String? eventDate; // YYYY-MM-DD
  String? eventTime; // HH:MM
  String? location;
  String? locationUrl;
  int notifyBefore;
  String? personName;
  String? doctorName;
  String? buildingNo;
  String? roomNo;
  String? notes;
  String apptType; // in_person | remote
  String? hospital;
  String? clinic;
  String? apptNumber;

  AppEvent({
    this.id,
    required this.title,
    this.eventDate,
    this.eventTime,
    this.location,
    this.locationUrl,
    this.notifyBefore = 60,
    this.personName,
    this.doctorName,
    this.buildingNo,
    this.roomNo,
    this.notes,
    this.apptType = 'in_person',
    this.hospital,
    this.clinic,
    this.apptNumber,
  });

  static int? _int(dynamic v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));
  static String? _str(dynamic v) => v == null ? null : v.toString();

  // قراءة مرنة: تتحمّل أي اختلاف في نوع القيمة القادمة من القاعدة (نص/رقم).
  factory AppEvent.fromJson(Map<String, dynamic> j) => AppEvent(
        id: _int(j['id']),
        title: _str(j['title']) ?? '',
        eventDate: _str(j['event_date']),
        eventTime: _str(j['event_time']),
        location: _str(j['location']),
        locationUrl: _str(j['location_url']),
        notifyBefore: _int(j['notify_before']) ?? 60,
        personName: _str(j['person_name']),
        doctorName: _str(j['doctor_name']),
        buildingNo: _str(j['building_no']),
        roomNo: _str(j['room_no']),
        notes: _str(j['notes']),
        apptType: _str(j['appt_type']) ?? 'in_person',
        hospital: _str(j['hospital']),
        clinic: _str(j['clinic']),
        apptNumber: _str(j['appt_number']),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'eventDate': eventDate,
        'eventTime': eventTime,
        'location': location,
        'locationUrl': locationUrl,
        'notifyBefore': notifyBefore,
        'personName': personName,
        'doctorName': doctorName,
        'buildingNo': buildingNo,
        'roomNo': roomNo,
        'notes': notes,
        'apptType': apptType,
        'hospital': hospital,
        'clinic': clinic,
        'apptNumber': apptNumber,
      };
}
