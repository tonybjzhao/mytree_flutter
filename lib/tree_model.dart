// Pure data model and rules for the virtual tree (no I/O).
// Health and growth are derived from persisted dates and streak on each load.

/// User-facing vitality derived from how many calendar days since last water.
enum TreeHealth {
  /// Last watered today, or brand-new seed not yet thirsty.
  healthy,

  /// 1–2 calendar days without water (includes “due today” after yesterday).
  thirsty,

  /// 3–6 days without water — yellow / struggling.
  wilting,

  /// 7+ days without water.
  dead,
}

/// Visual size of the tree from consecutive daily watering streak.
enum GrowthStage {
  seed, // 0–2
  sprout, // 3–6
  smallTree, // 7–13
  youngTree, // 14–29
  matureTree, // 30+
}

/// Immutable snapshot used by the UI after recalculation from storage + “today”.
class TreeState {
  const TreeState({
    required this.health,
    required this.growthStage,
    required this.streak,
    required this.wateredToday,
    required this.lastWateredDate,
  });

  final TreeHealth health;
  final GrowthStage growthStage;
  final int streak;

  /// True if the user already used their once-per-calendar-day water action.
  final bool wateredToday;

  /// Last calendar day watered, or null if never watered (e.g. after restart).
  final DateTime? lastWateredDate;

  bool get isDead => health == TreeHealth.dead;

  /// Short label for the status line (matches product copy).
  String get statusLabel {
    switch (health) {
      case TreeHealth.healthy:
        return 'Healthy';
      case TreeHealth.thirsty:
        return 'Needs water';
      case TreeHealth.wilting:
        return 'Wilting';
      case TreeHealth.dead:
        return 'Dead';
    }
  }

  /// Human-readable growth label for optional UI / debugging.
  String get growthLabel {
    switch (growthStage) {
      case GrowthStage.seed:
        return 'Seed';
      case GrowthStage.sprout:
        return 'Sprout';
      case GrowthStage.smallTree:
        return 'Small tree';
      case GrowthStage.youngTree:
        return 'Young tree';
      case GrowthStage.matureTree:
        return 'Mature tree';
    }
  }
}

/// Maps “calendar days from last water to today” into [TreeHealth].
///
/// [daysSinceLastWater] is 0 when last watered today, 1 when last watered
/// yesterday, etc. When [hasNeverWatered] is true, we treat the tree as
/// needing its first water (not dead).
TreeHealth healthForDaysSince({
  required int daysSinceLastWater,
  required bool hasNeverWatered,
}) {
  // No water history yet: no full days missed → healthy seed waiting for first care.
  if (hasNeverWatered) {
    return TreeHealth.healthy;
  }
  if (daysSinceLastWater <= 0) {
    return TreeHealth.healthy;
  }
  if (daysSinceLastWater <= 2) {
    return TreeHealth.thirsty;
  }
  if (daysSinceLastWater <= 6) {
    return TreeHealth.wilting;
  }
  return TreeHealth.dead;
}

/// Maps current streak to growth stage (streak is 0 until first water).
GrowthStage growthStageForStreak(int streak) {
  if (streak <= 2) return GrowthStage.seed;
  if (streak <= 6) return GrowthStage.sprout;
  if (streak <= 13) return GrowthStage.smallTree;
  if (streak <= 29) return GrowthStage.youngTree;
  return GrowthStage.matureTree;
}
