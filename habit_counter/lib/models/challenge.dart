import 'package:collection/collection.dart';
import 'package:habit_counter/models/habit.dart';
import 'package:habit_counter/services/tracker.dart';

abstract class Challenge {
  final String id;
  final String title;
  final String habitName;
  final DateTime assignedOn;
  final DateTime expiresOn;
  final int rewardXp;
  bool isCompleted = false;

  Challenge({
    required this.id,
    required this.title,
    required this.habitName,
    required this.assignedOn,
    required this.expiresOn,
    required this.rewardXp,
  });

  bool checkIfMet(List<Habit> habits);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'habitName': habitName,
    'assignedOn': assignedOn.toIso8601String(),
    'expiresOn': expiresOn.toIso8601String(),
    'rewardXp': rewardXp,
    'isCompleted': isCompleted,
    'type': runtimeType.toString(), // dynamic dispatch for deserialization
  };

  String get type;

  factory Challenge.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'streak':
        return StreakChallenge.fromJson(json);
      case 'CountChallenge':
        return CountChallenge.fromJson(json);
      case 'ComboChallenge':
        return ComboChallenge.fromJson(json);
      default:
        throw UnimplementedError('Unknown challenge type ${json['type']}');
    }
  }
}

class StreakChallenge extends Challenge {
  final int requiredStreak;

  StreakChallenge({
    required super.id,
    required super.title,
    required super.habitName,
    required super.assignedOn,
    required super.expiresOn,
    required super.rewardXp,
    required this.requiredStreak,
  });

  @override
  bool checkIfMet(List<Habit> habits) {
    final habit = habits.firstWhereOrNull((h) => h.name == habitName);
    if (habit == null) return false;
    final validLogs = habit.completionLog
        .map((d) => DateTime(d.year, d.month, d.day))
        .where((d) => !d.isBefore(assignedOn) && !d.isAfter(expiresOn))
        .toSet();

    if (validLogs.length < requiredStreak) return false;

    final sorted = validLogs.toList()..sort();

    int currentStreak = 1;

    for (int i = 0; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];
      if (curr.difference(prev).inDays == 1) {
        currentStreak++;
        if (currentStreak >= requiredStreak) return true;
      } else {
        currentStreak = 1;
      }
    }
    return false;
  }

  @override
  String get type => ChallengeType.streak;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'requiredStreak': requiredStreak,
  };

  factory StreakChallenge.fromJson(Map<String, dynamic> json) {
    return StreakChallenge(
      id: json['id'],
      title: json['title'],
      habitName: json['habitName'],
      assignedOn: DateTime.parse(json['assignedOn']),
      expiresOn: DateTime.parse(json['expiresOn']),
      rewardXp: json['rewardXp'],
      requiredStreak: json['requiredStreak'],
    )..isCompleted = json['isCompleted'] ?? false;
  }
}

class CountChallenge extends Challenge {
  final int requiredCount;

  CountChallenge({
    required super.id,
    required super.title,
    required super.habitName,
    required super.rewardXp,
    required this.requiredCount,
    required super.assignedOn,
    required super.expiresOn,
  });

  @override
  bool checkIfMet(List<Habit> habits) {
    final habit = habits.firstWhereOrNull((h) => h.name == habitName);
    if (habit == null) return false;

    final count = habit.completionLog
        .where((d) => !d.isBefore(assignedOn) && !d.isAfter(expiresOn))
        .length;
    return count >= requiredCount;
  }

  @override
  String get type => ChallengeType.count;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'requiredCount': requiredCount,
  };

  factory CountChallenge.fromJson(Map<String, dynamic> json) {
    return CountChallenge(
      id: json['id'],
      title: json['title'],
      habitName: json['habitName'],
      rewardXp: json['rewardXp'],
      requiredCount: json['requiredCount'],
      assignedOn: DateTime.parse(json['assignedOn']),
      expiresOn: DateTime.parse(json['expiresOn']),
    )..isCompleted = json['isCompleted'] ?? false;
  }
}

class ComboChallenge extends Challenge {
  final String habitName2;
  final int requiredComboDays;

  ComboChallenge({
    required super.id,
    required super.title,
    required super.habitName,
    required this.habitName2,
    required super.rewardXp,
    required super.assignedOn,
    required super.expiresOn,
    required this.requiredComboDays,
  });

  @override
  bool checkIfMet(List<Habit> habits) {
    final h1 = habits.firstWhereOrNull((h) => h.name == habitName);
    final h2 = habits.firstWhereOrNull((h) => h.name == habitName2);
    if (h1 == null || h2 == null) return false;

    final start = assignedOn;
    final end = expiresOn;

    // Filter and normalize both logs to date-only
    final h1Dates = h1.completionLog
        .map((d) => DateTime(d.year, d.month, d.day))
        .where((d) => !d.isBefore(start) && !d.isAfter(end))
        .toSet();

    final h2Dates = h2.completionLog
        .map((d) => DateTime(d.year, d.month, d.day))
        .where((d) => !d.isBefore(start) && !d.isAfter(end))
        .toSet();

    // Find shared completion days
    final shared = h1Dates.intersection(h2Dates).toList()
      ..sort((a, b) => a.compareTo(b));

    // Count longest consecutive streak in shared days
    int maxStreak = 0;
    int current = 0;

    for (int i = 0; i < shared.length; i++) {
      if (i == 0 || shared[i].difference(shared[i - 1]).inDays == 1) {
        current += 1;
      } else {
        current = 1;
      }
      if (current > maxStreak) maxStreak = current;
    }

    return maxStreak >= requiredComboDays;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'habitName': habitName,
    'habitName2': habitName2,
    'requiredComboDays': requiredComboDays,
  };

  @override
  String get type => ChallengeType.combo;

  factory ComboChallenge.fromJson(Map<String, dynamic> json) {
    return ComboChallenge(
      id: json['id'],
      title: json['title'],
      rewardXp: json['rewardXp'],
      habitName: json['habitName'],
      habitName2: json['habitName2'],
      requiredComboDays: json['requiredComboDays'],
      assignedOn: DateTime.parse(json['assignedOn']),
      expiresOn: DateTime.parse(json['expiresOn']),
    )..isCompleted = json['isCompleted'] ?? false;
  }
}

class ChallengeType {
  static const String streak = 'streak';
  static const String count = 'count';
  static const String combo = 'combo';
}
