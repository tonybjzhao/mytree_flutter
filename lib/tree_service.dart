import 'package:shared_preferences/shared_preferences.dart';

import 'tree_model.dart';

/// Keys for [SharedPreferences]. Keep stable so upgrades do not lose data.
abstract final class TreePrefsKeys {
  static const lastWateredIso = 'tree_last_watered_iso';
  static const streak = 'tree_streak';
}

/// Loads and saves tree data locally; recomputes [TreeState] from “today” on each read.
class TreeService {
  TreeService(this._prefs);

  final SharedPreferences _prefs;

  /// Factory for app startup.
  static Future<TreeService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return TreeService(prefs);
  }

  /// Calendar “today” in local timezone (time stripped).
  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Parses `yyyy-MM-dd` as a local calendar date (avoids UTC midnight shifts).
  static DateTime? _parseLocalDate(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  DateTime? _readLastWatered() {
    final raw = _prefs.getString(TreePrefsKeys.lastWateredIso);
    if (raw == null || raw.isEmpty) return null;
    return _parseLocalDate(raw);
  }

  int _readStreak() => _prefs.getInt(TreePrefsKeys.streak) ?? 0;

  /// Full recompute from disk + current date. Call on launch and after mutations.
  TreeState loadState() {
    final today = _today;
    final last = _readLastWatered();
    var streak = _readStreak();

    final hasNeverWatered = last == null;
    final daysSince = hasNeverWatered
        ? 0
        : today.difference(last).inDays;

    final health = healthForDaysSince(
      daysSinceLastWater: daysSince,
      hasNeverWatered: hasNeverWatered,
    );

    if (hasNeverWatered) {
      streak = 0;
    }

    final wateredToday = !hasNeverWatered && last == today;

    return TreeState(
      health: health,
      growthStage: growthStageForStreak(streak),
      streak: streak,
      wateredToday: wateredToday,
      lastWateredDate: last,
    );
  }

  /// One water per calendar day; no-op if already watered today or if dead.
  Future<TreeState> waterToday() async {
    final today = _today;
    final last = _readLastWatered();

    if (last == today) {
      return loadState();
    }

    final current = loadState();
    if (current.isDead) {
      return current;
    }

    int newStreak;
    if (last == null) {
      newStreak = 1;
    } else {
      final gap = today.difference(last).inDays;
      if (gap == 1) {
        newStreak = _readStreak() + 1;
      } else {
        // Missed one or more days: start a new streak from this water.
        newStreak = 1;
      }
    }

    await _prefs.setString(
      TreePrefsKeys.lastWateredIso,
      today.toIso8601String().split('T').first,
    );
    await _prefs.setInt(TreePrefsKeys.streak, newStreak);

    return loadState();
  }

  /// After death, user plants a new seed: clears water history and streak.
  Future<TreeState> restartFromSeed() async {
    await _prefs.remove(TreePrefsKeys.lastWateredIso);
    await _prefs.setInt(TreePrefsKeys.streak, 0);
    return loadState();
  }
}
