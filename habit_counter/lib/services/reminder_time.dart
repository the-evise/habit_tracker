class ReminderTime {
  final int hour;
  final int minute;

  ReminderTime(this.hour, this.minute);

  factory ReminderTime.fromJson(Map<String, dynamic> json) {
    return ReminderTime(json['hour'], json['minute']);
  }

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};
}
