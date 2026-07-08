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
  });

  factory AppEvent.fromJson(Map<String, dynamic> j) => AppEvent(
        id: j['id'] as int?,
        title: j['title'] ?? '',
        eventDate: j['event_date'],
        eventTime: j['event_time'],
        location: j['location'],
        locationUrl: j['location_url'],
        notifyBefore: j['notify_before'] ?? 60,
        personName: j['person_name'],
        doctorName: j['doctor_name'],
        buildingNo: j['building_no'],
        roomNo: j['room_no'],
        notes: j['notes'],
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
      };
}
