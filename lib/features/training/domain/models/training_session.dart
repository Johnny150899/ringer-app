class TrainingSession {
  const TrainingSession({
    this.id,
    required this.weekday,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.group,
    required this.locationName,
    required this.locationQuery,
    this.coach,
    this.note,
  });

  final int? id;
  final int weekday;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String group;
  final String locationName;
  final String locationQuery;
  final String? coach;
  final String? note;

  TrainingSession copyWith({
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
  }) {
    return TrainingSession(
      id: id,
      weekday: weekday,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      group: group,
      locationName: locationName,
      locationQuery: locationQuery,
      coach: coach,
      note: note,
    );
  }

  String get timeLabel =>
      '${_time(startHour, startMinute)}–${_time(endHour, endMinute)}';

  DateTime nextOccurrence(DateTime now) {
    var daysAhead = (weekday - now.weekday) % 7;
    var date = DateTime(
      now.year,
      now.month,
      now.day + daysAhead,
      startHour,
      startMinute,
    );
    if (!date.isAfter(now)) {
      daysAhead += 7;
      date = DateTime(
        now.year,
        now.month,
        now.day + daysAhead,
        startHour,
        startMinute,
      );
    }
    return date;
  }

  static String _time(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
