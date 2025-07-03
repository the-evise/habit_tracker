enum Difficulty { easy, medium, hard }

class Habit {
  final String name;
  final Difficulty difficulty;
  bool done;

  Habit(this.name, this.difficulty, {this.done = false});

  void markDone() => done = true;
  void markUndone() => done = false;
}
