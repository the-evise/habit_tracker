import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import 'package:habit_counter/models/diary.dart';
import 'package:habit_counter/models/habit.dart';
import 'package:habit_counter/services/reminder_time.dart';
import 'package:habit_counter/models/challenge.dart';

class HabitTracker {
  HabitTracker();
  final List<Habit> habits = [];
  final List<Challenge> challenges = [];

  final String storageFile = 'habits.json'; // relative path

  final List<DiaryEntry> diary = [];
  final Map<String, DiaryEntry> diaryEnteries = {};

  int lifetimeXp = 0;

  final Map<Difficulty, int> xpTable = {
    Difficulty.easy: 5,
    Difficulty.medium: 10,
    Difficulty.hard: 15,
  };

  void addHabit(Habit habit) {
    habits.add(habit);
  }

  void removeHabit(int index) {
    if (index >= 0 && index < habits.length) {
      habits.removeAt(index);
    }
  }

  void editHabit(int index, Habit newHabit) {
    if (index >= 0 && index < habits.length) {
      final oldHabit = habits[index];
      newHabit.lastCompleted = oldHabit.lastCompleted;
      newHabit.completionLog = oldHabit.completionLog;
      newHabit.reminderTime = oldHabit.reminderTime;

      habits[index] = newHabit;
    }
  }

  void markHabitDone(int index) {
    final habit = habits[index];

    if (!habit.isDoneToday) {
      habit.completionLog.add(_dateOnly(_today()));

      // Ensure log only has last 7 unique days
      habit.completionLog = habit.completionLog.map(_dateOnly).toSet().toList()
        ..sort((a, b) => b.compareTo(a));

      // Update lifetime XP
      lifetimeXp += xpTable[habit.difficulty] ?? 0;

      // Challenge completion check
      _checkChallengesForHabit(habit);
    }
  }

  void unmarkHabitDone(int index) {
    final habit = habits[index];
    final today = _dateOnly(DateTime.now());

    habit.completionLog.removeWhere((d) => _isSameDay(d, today));

    // Keep log clean and sorted
    habit.completionLog = habit.completionLog.map(_dateOnly).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    // Update lifetime XP
    lifetimeXp -= xpTable[habit.difficulty] ?? 0;
  }

  /// Get total XP based on habits completed today
  int get todayXp => habits
      .where((h) => h.isDoneToday)
      .fold(0, (sum, h) => sum + (xpTable[h.difficulty] ?? 0));

  /// Get number of habits completed today
  int get totalCompleted => habits.where((h) => h.isDoneToday).length;

  /// Safe unmodifiable list of all habits
  List<Habit> get allHabits => List.unmodifiable(habits);

  /// Load habits from disk and normalize logs
  Future<void> loadFromFile() async {
    final file = File(storageFile);
    if (!await file.exists()) return;

    final content = await file.readAsString();
    if (content.trim().isEmpty) return;

    try {
      final Map<String, dynamic> data = jsonDecode(content);

      habits.clear();
      habits.addAll(
        (data['habits'] as List<dynamic>).map((json) => Habit.fromJson(json)),
      );

      lifetimeXp = data['lifetimeXp'] ?? 0;

      diary.clear();
      if (data.containsKey('diary')) {
        diary.addAll(
          (data['diary'] as List<dynamic>).map(
            (json) => DiaryEntry.fromJson(json),
          ),
        );
      }

      // Load Challenges
      challenges.clear();
      if (data['challenges'] != null) {
        challenges.addAll(
          (data['challenges'] as List<dynamic>).map(
            (c) => Challenge.fromJson(c),
          ),
        );
      }
      _removeExpiredChallenge();

      // debugging
      stdout.writeln('Loaded ${challenges.length} challenges.');
      for (final c in challenges) {
        stdout.writeln('Challenge: ${c.title} ${c.type}');
      }

      _pruneLogs(); // log cleanup, not daily reset anymore
      _pruneOldDiaries(); // diary monthly cleanup with 1 week grace
    } catch (e) {
      stderr.writeln('⚠️ Failed to parse habits.json: $e');
      habits.clear();
    }
  }

  Map<String, dynamic> toJson() => {
    'habits': habits.map((h) => h.toJson()).toList(),
    'lifetimeXp': lifetimeXp,
    'diary': diary.map((d) => d.toJson()).toList(),
    'challenges': challenges.map((c) => c.toJson()).toList(),
  };

  factory HabitTracker.fromJson(Map<String, dynamic> json) {
    final tracker = HabitTracker();
    final loadedHabits = (json['habits'] as List<dynamic>)
        .map((h) => Habit.fromJson(h))
        .toList();

    tracker.habits.addAll(loadedHabits);
    tracker.lifetimeXp = json['lifetimeXp'] ?? 0;

    return tracker;
  }

  /// Persist habits to disk
  Future<void> saveToFile() async {
    final file = File(storageFile);
    final content = jsonEncode(toJson());
    await file.writeAsString(content);
  }

  /// Remove duplicates, trim to 7-day history, sort by recency
  void _pruneLogs() {
    for (final habit in habits) {
      habit.completionLog =
          habit.completionLog
              .whereType<DateTime>()
              .map(_dateOnly)
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a));

      if (habit.completionLog.length > 7) {
        habit.completionLog = habit.completionLog.sublist(0, 7);
      }

      if (habit.completionLog.isNotEmpty) {
        habit.lastCompleted = habit.completionLog.first;
      }
    }
  }

  // reminder logic
  void setReminderTime(int index, int hour, int minute) {
    if (index >= 0 && index < habits.length) {
      habits[index].reminderTime = ReminderTime(hour, minute);
    }
  }

  void removeReminderTime(int index) {
    if (index >= 0 && index < habits.length) {
      habits[index].reminderTime = null;
    }
  }

  bool shouldRemind(Habit habit) {
    final now = DateTime.now();
    final time = habit.reminderTime;

    if (time == null || habit.isDoneToday) return false;
    return now.hour < time.hour ||
        (now.hour == time.hour && now.minute <= time.minute);
  }

  List<Habit> checkDueReminders() {
    return habits.where(shouldRemind).toList();
  }

  /// diary logic
  void _pruneOldDiaries() {
    final now = _today();
    final oneWeekAfterLastMonth = DateTime(
      now.year,
      now.month - 1,
      1,
    ).add(Duration(days: 37));
    diary.removeWhere((entry) => entry.date.isBefore(oneWeekAfterLastMonth));
  }

  dynamic addNoteForHabitToday(String habitName, String note) {
    final today = _today();
    final existing = diary.firstWhere(
      (entry) => entry.isSameDay(today),
      orElse: () => DiaryEntry(date: today),
    );

    existing.habitNotes[habitName] = note;
    if (!diary.contains(existing)) diary.add(existing);
  }

  Map<String, String> getNotesForDate(DateTime date) {
    final entry = diary.firstWhere(
      (d) => d.isSameDay(date),
      orElse: () => DiaryEntry(date: date),
    );
    return entry.habitNotes;
  }

  void addHabitNote(String habitName, String note) {
    final todayKey = _dateOnly(DateTime.now()).toIso8601String();

    final entry = diaryEnteries.putIfAbsent(
      todayKey,
      () => DiaryEntry(date: _dateOnly(DateTime.now())),
    );

    entry.addNote(habitName, note);
  }

  /// weekly summary logic
  String generateWeeklySummary({bool asMarkdown = true}) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));
    final df = DateFormat('yyyy-MM-dd');

    final buffer = StringBuffer();

    // Header
    if (asMarkdown) {
      buffer.writeln(
        '# 🧭 Weekly Hero\'s Log: ${DateFormat('MMM d').format(startOfWeek)} – ${DateFormat('MMM d, yyyy').format(endOfWeek)}\n',
      );
      buffer.writeln('> "Victory is forged one day at a time."\n');
    } else {
      buffer.writeln('=== WEEKLY HERO\'S LOG ===');
      buffer.writeln(
        'Range: ${df.format(startOfWeek)} to ${df.format(endOfWeek)}\n',
      );
    }

    // Top streaks
    buffer.writeln(
      asMarkdown ? '## 🔥 Top Streaks This Week' : '\nTop Streaks:',
    );
    for (final habit in habits) {
      final count = _countInRange(habit, startOfWeek, endOfWeek);
      if (count > 0) {
        final streakLine =
            // ignore: prefer_interpolation_to_compose_strings
            '${_icon(habit)} ${habit.name} — $count day(s)' +
            (habit.streak >= 7 ? ' 🧱 *Unbroken!*' : '');
        buffer.writeln(asMarkdown ? '- $streakLine' : streakLine);
      }
    }

    buffer.writeln(
      asMarkdown ? '\n## 📅 Daily Breakdown' : "\nDaily Completion:",
    );

    // Daily Breakdown, Notes included
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final dayHeader = '${DateFormat.EEEE().format(day)}, ${df.format(day)}';
      final habitsDoneToday = habits.where(
        (h) => h.completionLog.any((d) => _isSameDay(d, day)),
      );
      final notes = getNotesForDate(day);

      buffer.writeln(asMarkdown ? '\n### $dayHeader' : '\n$dayHeader');

      if (habitsDoneToday.isEmpty) {
        buffer.writeln(
          asMarkdown ? '*No habits completed.*' : 'No habits completed.',
        );
      } else {
        for (final h in habitsDoneToday) {
          buffer.writeln(asMarkdown ? '✅ ${h.name}' : '- ${h.name}');
        }
      }

      if (notes.isNotEmpty) {
        buffer.writeln(asMarkdown ? '#### 📝 Notes:' : '\nNotes:');
        notes.forEach((habitName, note) {
          buffer.writeln(
            asMarkdown ? '- **$habitName**: $note' : '- $habitName: $note',
          );
        });
      }
    }

    // XP Summary
    final xpSummary = _calculateXpByCount(startOfWeek, endOfWeek);
    buffer.writeln(asMarkdown ? '\n## 🧠 XP Earned' : '\nXP Breakdown:');
    for (final entry in xpSummary.entries) {
      buffer.writeln(
        asMarkdown
            ? '- ${entry.key} = **${entry.value} XP**'
            : '- ${entry.key}: ${entry.value} XP',
      );
    }

    final totalXp = xpSummary.values.fold(0, (a, b) => a + b);
    buffer.writeln(
      asMarkdown
          ? '\n**🎯 Total: $totalXp XP**'
          : '\nTotal XP Earned: $totalXp',
    );

    return buffer.toString();
  }

  Future<void> exportWeeklySummaryToFile() async {
    final today = _today();
    final start = today.subtract(const Duration(days: 6));
    final filename =
        'weekly_summary_${start.year}-${_pad(start.month)}-${_pad(start.day)}_to_${today.year}-${_pad(today.month)}-${_pad(today.day)}.md';

    final content = generateWeeklySummary();
    final file = File(filename);
    await file.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Challenges Logic
  void generateRandomChallenges({int maxActive = 3}) {
    final activeCount = challenges.where((c) => !c.isCompleted).length;
    final toGenerate = maxActive - activeCount;
    if (toGenerate <= 0) return;

    final rand = Random();
    final available = habits.toList()..shuffle();

    int generated = 0;
    final usedHabits = <String>{};

    while (generated < toGenerate && available.isNotEmpty) {
      final typeRoll = rand.nextInt(3); // 0 = streak, 1 = count, 2 = combo

      if (typeRoll == 0 && available.isNotEmpty) {
        final habit = available.removeLast();
        if (_hasChallenge(habit.name)) continue;

        _generateStreakChallengeForHabit(habit);
        usedHabits.add(habit.name);
        generated++;
      } else if (typeRoll == 1 && available.isNotEmpty) {
        final habit = available.removeLast();
        if (_hasChallenge(habit.name)) continue;

        _generateCountChallengeForHabit(habit);
        usedHabits.add(habit.name);
        generated++;
      } else if (typeRoll == 2 && available.length >= 2) {
        final h1 = available.removeLast();
        Habit? h2;
        for (final h in available) {
          if (!_hasChallenge(h.name) &&
              !_hasChallenge(h1.name) &&
              h.name != h1.name) {
            h2 = h;
            break;
          }
        }
        if (h2 == null) continue;

        available.remove(h2);

        _generateComboChallengeForHabits(h1, h2);
        usedHabits.addAll([h1.name, h2.name]);
        generated++;
      }
    }
  }

  List<Challenge> checkAndCompleteChallenges() {
    final List<Challenge> completedChallenges = [];
    for (final challenge in challenges) {
      if (challenge.isCompleted) continue;

      final habit = habits.firstWhereOrNull(
        (h) => h.name == challenge.habitName,
      );

      if (habit != null && challenge.checkIfMet(habits)) {
        challenge.isCompleted = true;
        completedChallenges.add(challenge);
        lifetimeXp += challenge.rewardXp;

        stdout.writeln(
          '🏆 Challenge Completed: ${challenge.title} (+${challenge.rewardXp} XP)',
        );
      }
    }
    return completedChallenges;
  }

  void generateManualStreakChallenge(
    Habit habit, {
    required int streak,
    required int durationDays,
  }) {
    final now = _today();
    final expires = now.add(Duration(days: durationDays));

    final baseReward = xpTable[habit.difficulty] ?? 5;
    final reward = baseReward * (streak ~/ 2);

    final challenge = StreakChallenge(
      id: '${habit.name}_${now.toIso8601String()}',
      title: '🔥 Keep ${habit.name} for $streak days',
      habitName: habit.name,
      assignedOn: now,
      expiresOn: expires,
      rewardXp: reward,
      requiredStreak: streak,
    );

    challenges.add(challenge);
  }

  void generateManualCountChallenge(
    Habit habit, {
    required int count,
    required int durationDays,
  }) {
    final now = _today();
    final expires = now.add(Duration(days: durationDays));

    final baseReward = xpTable[habit.difficulty] ?? 5;
    final reward = baseReward * (count ~/ 2);

    final challenge = CountChallenge(
      id: '${habit.name}_count_${now.toIso8601String()}',
      title: '📊 Do ${habit.name} $count times',
      habitName: habit.name,
      assignedOn: now,
      expiresOn: expires,
      rewardXp: reward,
      requiredCount: count,
    );

    challenges.add(challenge);
  }

  void generateManualComboChallenge(
    Habit habit1,
    Habit habit2, {
    required int comboDays,
    required int durationDays,
  }) {
    final now = _today();
    final expires = now.add(Duration(days: durationDays));

    final baseReward1 = xpTable[habit1.difficulty] ?? 5;
    final baseReward2 = xpTable[habit2.difficulty] ?? 5;

    final reward = ((baseReward1 + baseReward2) ~/ 2) * comboDays;

    final challenge = ComboChallenge(
      id: '${habit1.name}_${habit2.name}_combo_${now.toIso8601String()}',
      title: '🔗 Do ${habit1.name} + ${habit2.name} $comboDays days in a row',
      habitName: habit1.name,
      habitName2: habit2.name,
      assignedOn: now,
      expiresOn: expires,
      rewardXp: reward,
      requiredComboDays: comboDays,
    );

    challenges.add(challenge);
  }

  /// Helpers (internal)
  DateTime _today() => _dateOnly(DateTime.now());

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekdayName(int weekday) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return days[(weekday - 1) % 7];
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  String _formatDate(DateTime date) =>
      '${date.year}-${_pad(date.month)}-${_pad(date.day)}';

  int _countInRange(Habit habit, DateTime start, DateTime end) {
    return habit.completionLog
        .where((d) => !d.isBefore(start) && !d.isAfter(end))
        .length;
  }

  String _icon(Habit habit) {
    switch (habit.difficulty) {
      case Difficulty.easy:
        return '🥉';
      case Difficulty.medium:
        return '🥈';
      case Difficulty.hard:
        return '🥇';
    }
  }

  Map<String, int> _calculateXpByCount(DateTime start, DateTime end) {
    final map = <String, int>{
      'Easy (5 XP)': 0,
      'Medium (10 XP)': 0,
      'Hard (15 XP)': 0,
    };

    for (final habit in habits) {
      final count = habit.completionLog
          .where((d) => !d.isBefore(start) && !d.isAfter(end))
          .length;
      final xp = (xpTable[habit.difficulty] ?? 0) * count;

      switch (habit.difficulty) {
        case Difficulty.easy:
          map['Easy (5 XP)'] = map['Easy (5 XP)']! + xp;
          break;
        case Difficulty.medium:
          map['Medium (10 XP)'] = map['Medium (10 XP)']! + xp;
          break;
        case Difficulty.hard:
          map['Hard (15 XP)'] = map['Hard (15 XP)']! + xp;
          break;
      }
    }

    return map;
  }

  void _checkChallengesForHabit(Habit habit) {
    for (final challenge in challenges) {
      if (!challenge.isCompleted &&
          challenge.habitName == habit.name &&
          challenge.checkIfMet(habits)) {
        challenge.isCompleted = true;
        lifetimeXp += challenge.rewardXp;

        stdout.writeln(
          '\n🎉 Challenge Completed! "${challenge.title}" (+${challenge.rewardXp} XP)',
        );
      }
    }
  }

  void _removeExpiredChallenge() {
    final now = _today();
    challenges.removeWhere((c) {
      if (c.isCompleted) return false;

      if (c.expiresOn.isBefore(now)) return true;

      // If StreakChallenge: check if it's still possible to complete
      if (c is StreakChallenge) {
        final daysLeft = c.expiresOn.difference(now).inDays + 1;
        return daysLeft < c.requiredStreak;
      }
      return false;
    });
  }

  void _generateStreakChallengeForHabit(
    Habit habit, {
    int minStreak = 3,
    int maxStreak = 7,
    int durationDays = 7,
  }) {
    final random = Random();
    final streakTarget = minStreak + random.nextInt(maxStreak - minStreak + 1);

    final now = _today();
    final expires = now.add(Duration(days: durationDays));

    final baseReward = xpTable[habit.difficulty] ?? 5;
    final reward = baseReward * (streakTarget ~/ 2);

    final Challenge challenge = StreakChallenge(
      id: '${habit.name}_${now.toIso8601String()}',
      title: '🔥 Keep ${habit.name} for $streakTarget days',
      habitName: habit.name,
      assignedOn: now,
      expiresOn: expires,
      rewardXp: reward,
      requiredStreak: streakTarget,
    );

    challenges.add(challenge);
  }

  bool _hasChallenge(String habitName) {
    return challenges.any((c) => c.habitName == habitName && !c.isCompleted);
  }

  void _generateCountChallengeForHabit(Habit habit) {
    final now = _today();
    final expires = now.add(Duration(days: 7));
    final random = Random();
    final count = 3 + random.nextInt(5); // 3 to 7

    final baseReward = xpTable[habit.difficulty] ?? 5;
    final reward = baseReward * count;

    challenges.add(
      CountChallenge(
        id: '${habit.name}_count_${now.toIso8601String()}',
        title: '📊 Do ${habit.name} $count times',
        habitName: habit.name,
        assignedOn: now,
        expiresOn: expires,
        rewardXp: reward,
        requiredCount: count,
      ),
    );
  }

  void _generateComboChallengeForHabits(Habit h1, Habit h2) {
    final now = _today();
    final expires = now.add(Duration(days: 10));
    final random = Random();
    final comboDays = 3 + random.nextInt(3); // 3 to 5

    final baseReward =
        ((xpTable[h1.difficulty] ?? 5) + (xpTable[h2.difficulty] ?? 5)) ~/ 2;
    final reward = baseReward * comboDays;

    challenges.add(
      ComboChallenge(
        id: '${h1.name}_${h2.name}_combo_${now.toIso8601String()}',
        title: '🔗 Do ${h1.name} + ${h2.name} for $comboDays days in a row',
        habitName: h1.name,
        habitName2: h2.name,
        assignedOn: now,
        expiresOn: expires,
        rewardXp: reward,
        requiredComboDays: comboDays,
      ),
    );
  }
}
