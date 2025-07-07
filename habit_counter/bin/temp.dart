class DiaryEntry {
  final DateTime date;
  final Map<String, String> habitNotes; // habit name → note

  DiaryEntry({required this.date, Map<String, String>? notes})
    : habitNotes = notes ?? {};

  void addNote(String habitName, String note) {
    habitNotes[habitName] = note;
  }

  String? getNoteForHabit(String habitName) {
    return habitNotes[habitName];
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'habitNotes': habitNotes,
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      date: DateTime.parse(json['date']),
      notes: Map<String, String>.from(json['habitNotes'] ?? {}),
    );
  }
}
