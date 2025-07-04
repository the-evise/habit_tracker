enum Difficulty { easy, medium, hard }

class Habit {
  final String name;
  final Difficulty difficulty;
  bool done;
  DateTime lastUpdated; // for streak tracking

  Habit(this.name, this.difficulty, {this.done = false, DateTime? lastUpdated})
    : lastUpdated = lastUpdated ?? DateTime.now();

  void markDone() {
    done = true;
    lastUpdated = DateTime.now();
  }

  void markUndone() => done = false;

  // --- JSON Serialization ---
  Map<String, dynamic> toJson() => {
    'name': name,
    'difficulty': difficulty.name,
    'done': done,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(json['name'], _parseDifficulty(json['lastUpdated']));
  }
}

Difficulty _parseDifficulty(String str) {
  switch (str.toLowerCase()) {
    case 'medium':
      return Difficulty.medium;
    case 'hard':
      return Difficulty.hard;
    default:
      return Difficulty.easy;
  }
}
