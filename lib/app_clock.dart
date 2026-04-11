import 'package:flutter/foundation.dart';

class AppClock {
  static int _debugDayOffset = 0;

  static DateTime now() {
    final base = DateTime.now();
    if (!kDebugMode) return base;
    return base.add(Duration(days: _debugDayOffset));
  }

  static int get debugDayOffset => _debugDayOffset;

  static void setDebugDayOffset(int days) {
    if (!kDebugMode) return;
    _debugDayOffset = days;
  }

  static void resetDayOffset() {
    if (!kDebugMode) return;
    _debugDayOffset = 0;
  }
}

class TreeDebugOverrides {
  static int? fakeTreeAgeDays;
  static int? fakeDaysSinceLastWater;
  static int? fakeStreak;

  static bool get hasOverrides =>
      fakeTreeAgeDays != null ||
      fakeDaysSinceLastWater != null ||
      fakeStreak != null;

  static void reset() {
    fakeTreeAgeDays = null;
    fakeDaysSinceLastWater = null;
    fakeStreak = null;
  }
}
