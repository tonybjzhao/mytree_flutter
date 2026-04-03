import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'tree_model.dart';

class TreeService {
  static const _storageKey = 'mytree_state_v1';

  /// Loads persisted tree state and recalculates health/dead from "today".
  /// Also normalizes/repersists the recalc result.
  Future<TreeModel> loadTree() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      final initial = TreeModel.initial();
      await saveTree(initial);
      return initial;
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      var tree = TreeModel.fromJson(map);
      tree = _recalculate(tree);
      await saveTree(tree);
      return tree;
    } catch (_) {
      final initial = TreeModel.initial();
      await saveTree(initial);
      return initial;
    }
  }

  Future<void> saveTree(TreeModel tree) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(tree.toJson()));
  }

  /// One water per calendar day.
  /// No-op if already watered today or if the tree is dead.
  Future<TreeModel> waterToday() async {
    var tree = await loadTree();
    tree = _recalculate(tree);

    if (tree.isDead || tree.healthState == TreeHealthState.dead) {
      return tree;
    }

    if (tree.hasWateredToday) {
      return tree;
    }

    final today = _dateOnly(DateTime.now());

    // Compute next streak:
    // - If watered yesterday (gap=1): streak + 1
    // - Otherwise (gap>=2 or no history): streak resets to 1
    int newStreak = 1;
    if (tree.lastWateredDateIso != null) {
      final last = _parseLocalDateOnly(tree.lastWateredDateIso!);
      if (last != null) {
        final gap = today.difference(_dateOnly(last)).inDays;
        if (gap == 1) {
          newStreak = tree.streakDays + 1;
        } else if (gap <= 0) {
          newStreak = tree.streakDays;
        } else {
          newStreak = 1;
        }
      }
    }

    final updated = tree.copyWith(
      lastWateredDateIso: _formatLocalDateOnly(today),
      streakDays: newStreak,
      totalDaysCared: tree.totalDaysCared + 1,
      isDead: false,
    );

    await saveTree(updated);
    return updated;
  }

  /// After death, user plants a new seed: clears water history and streak.
  Future<TreeModel> restartTree() async {
    final fresh = TreeModel.initial();
    await saveTree(fresh);
    return fresh;
  }

  TreeModel _recalculate(TreeModel tree) {
    if (tree.lastWateredDateIso == null) {
      return tree.copyWith(isDead: false);
    }

    if (tree.missedDays >= 7) {
      return tree.copyWith(isDead: true);
    }

    return tree.copyWith(isDead: false);
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Format a local date into `yyyy-mm-dd` (avoids UTC midnight shifts).
  static String _formatLocalDateOnly(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parse a local date-only string `yyyy-mm-dd` into a local [DateTime]
  /// at midnight.
  static DateTime? _parseLocalDateOnly(String raw) {
    final datePart = raw.length >= 10 ? raw.substring(0, 10) : raw;
    final parts = datePart.split('-');
    if (parts.length != 3) return null;

    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;

    return DateTime(y, m, d);
  }
}
