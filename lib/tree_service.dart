import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_clock.dart';
import 'life_category.dart';
import 'tree_collection_model.dart';
import 'tree_model.dart';

class TreeService {
  static const _storageKey = 'mytree_collection_v2';

  /// Loads persisted tree collection and recalculates health/dead from "today".
  Future<TreeCollectionModel> loadCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      final initial = TreeCollectionModel.initial();
      await saveCollection(initial);
      return initial;
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final collection = TreeCollectionModel.fromJson(map);

      final recalculatedTrees = _normalizeCategories(
        collection.trees.map(_recalculateTree).toList(growable: false),
      );

      final safeIndex = collection.currentIndex.clamp(
        0,
        recalculatedTrees.length - 1,
      );

      final updated = collection.copyWith(
        trees: recalculatedTrees,
        currentIndex: safeIndex,
      );

      await saveCollection(updated);
      return updated;
    } catch (_) {
      final initial = TreeCollectionModel.initial();
      await saveCollection(initial);
      return initial;
    }
  }

  Future<void> saveCollection(TreeCollectionModel collection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(collection.toJson()));
  }

  Future<TreeCollectionModel> selectTree(int index) async {
    final collection = await loadCollection();
    final safeIndex = index.clamp(0, collection.trees.length - 1);
    final updated = collection.copyWith(currentIndex: safeIndex);
    await saveCollection(updated);
    return updated;
  }

  Future<TreeCollectionModel> addTree(LifeCategory category) async {
    final collection = await loadCollection();
    if (collection.trees.any((tree) => tree.category == category)) {
      return collection;
    }
    final updatedTrees = [
      ...collection.trees,
      TreeModel.initial(category: category),
    ];
    final updated = collection.copyWith(
      trees: updatedTrees,
      currentIndex: updatedTrees.length - 1,
    );
    await saveCollection(updated);
    return updated;
  }

  /// Waters the currently selected tree once per calendar day.
  Future<TreeCollectionModel> waterCurrentTree() async {
    final collection = await loadCollection();
    final current = _recalculateTree(collection.currentTree);

    // Dead trees cannot be watered.
    if (current.isDead || current.healthState == TreeHealthState.dead) {
      final updatedCollection = collection.copyWith(
        trees: _replaceAt(collection.trees, collection.currentIndex, current),
      );
      await saveCollection(updatedCollection);
      return updatedCollection;
    }

    // Already watered today.
    if (current.hasWateredToday) {
      final updatedCollection = collection.copyWith(
        trees: _replaceAt(collection.trees, collection.currentIndex, current),
      );
      await saveCollection(updatedCollection);
      return updatedCollection;
    }

    final today = _dateOnly(AppClock.now());

    // Compute next streak:
    // - gap=1 => streak + 1
    // - otherwise => streak resets to 1
    int newStreak = 1;
    if (current.lastWateredDateIso != null) {
      final last = _parseLocalDateOnly(current.lastWateredDateIso!);
      if (last != null) {
        final gap = today.difference(_dateOnly(last)).inDays;
        if (gap == 1) {
          newStreak = current.streakDays + 1;
        } else if (gap <= 0) {
          newStreak = current.streakDays;
        } else {
          newStreak = 1;
        }
      }
    }

    final updatedTree = current.copyWith(
      lastWateredDateIso: _formatLocalDateOnly(today),
      streakDays: newStreak,
      totalDaysCared: current.totalDaysCared + 1,
      isDead: false,
    );

    final updatedCollection = collection.copyWith(
      trees: _replaceAt(collection.trees, collection.currentIndex, updatedTree),
    );

    await saveCollection(updatedCollection);
    return updatedCollection;
  }

  /// Revives the currently selected dead tree: marks alive, resets to today,
  /// preserves streak (minimum 1), increments reviveCount.
  Future<TreeCollectionModel> reviveCurrentTree() async {
    final collection = await loadCollection();
    final current = collection.currentTree;
    final today = _dateOnly(AppClock.now());
    final revived = current.copyWith(
      isDead: false,
      lastWateredDateIso: _formatLocalDateOnly(today),
      streakDays: current.streakDays > 0 ? current.streakDays : 1,
      reviveCount: current.reviveCount + 1,
    );
    final updated = collection.copyWith(
      trees: _replaceAt(collection.trees, collection.currentIndex, revived),
    );
    await saveCollection(updated);
    return updated;
  }

  /// After death, user plants a new seed for the current tree.
  Future<TreeCollectionModel> restartCurrentTree() async {
    final collection = await loadCollection();
    final current = collection.currentTree;
    final updatedCollection = collection.copyWith(
      trees: _replaceAt(
        collection.trees,
        collection.currentIndex,
        TreeModel.initial(category: current.category, id: current.id),
      ),
    );
    await saveCollection(updatedCollection);
    return updatedCollection;
  }

  TreeModel _recalculateTree(TreeModel tree) {
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

  /// Parse a local date-only string `yyyy-mm-dd` into a local [DateTime] at midnight.
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

  static List<TreeModel> _replaceAt(
    List<TreeModel> trees,
    int index,
    TreeModel tree,
  ) {
    final copy = [...trees];
    copy[index] = tree;
    return copy;
  }

  static List<TreeModel> _normalizeCategories(List<TreeModel> trees) {
    final assigned = <LifeCategory>{};
    final result = <TreeModel>[];

    for (final tree in trees) {
      var category = tree.category;
      if (assigned.contains(category)) {
        category = LifeCategory.values.firstWhere(
          (candidate) => !assigned.contains(candidate),
          orElse: () => category,
        );
      }
      assigned.add(category);
      result.add(tree.copyWith(category: category));
    }

    return result;
  }
}
