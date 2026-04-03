// Data model + derived state rules for the virtual tree (no I/O).
// Health and growth are derived from persisted dates and streak on each load.

enum TreeHealthState {
  healthy,
  thirsty,
  wilting,
  dead,
}

enum TreeGrowthStage {
  seed,
  sprout,
  small,
  young,
  mature,
}

class TreeModel {
  final String createdAtIso;

  /// Last watered calendar date in local time as `yyyy-mm-dd`.
  /// Null means the user never watered yet (fresh seed).
  final String? lastWateredDateIso;

  /// Current growth streak in days since the last watering reset.
  final int streakDays;

  /// Total number of watering actions ever (not used for rules, only stats).
  final int totalDaysCared;

  /// Stored dead flag (redundant with missedDays >= 7, but keeps UI stable).
  final bool isDead;

  const TreeModel({
    required this.createdAtIso,
    required this.lastWateredDateIso,
    required this.streakDays,
    required this.totalDaysCared,
    required this.isDead,
  });

  factory TreeModel.initial() {
    final today = _dateOnly(DateTime.now());
    return TreeModel(
      createdAtIso: today.toIso8601String(),
      lastWateredDateIso: null,
      streakDays: 0,
      totalDaysCared: 0,
      isDead: false,
    );
  }

  TreeModel copyWith({
    String? createdAtIso,
    String? lastWateredDateIso,
    int? streakDays,
    int? totalDaysCared,
    bool? isDead,
  }) {
    return TreeModel(
      createdAtIso: createdAtIso ?? this.createdAtIso,
      lastWateredDateIso: lastWateredDateIso ?? this.lastWateredDateIso,
      streakDays: streakDays ?? this.streakDays,
      totalDaysCared: totalDaysCared ?? this.totalDaysCared,
      isDead: isDead ?? this.isDead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdAtIso': createdAtIso,
      'lastWateredDateIso': lastWateredDateIso,
      'streakDays': streakDays,
      'totalDaysCared': totalDaysCared,
      'isDead': isDead,
    };
  }

  factory TreeModel.fromJson(Map<String, dynamic> json) {
    return TreeModel(
      createdAtIso: json['createdAtIso'] as String,
      lastWateredDateIso: json['lastWateredDateIso'] as String?,
      streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
      totalDaysCared: (json['totalDaysCared'] as num?)?.toInt() ?? 0,
      isDead: json['isDead'] as bool? ?? false,
    );
  }

  /// True if the user already watered during the current calendar day.
  bool get hasWateredToday {
    if (lastWateredDateIso == null) return false;
    final today = _dateOnly(DateTime.now());
    final last = _parseLocalDateOnly(lastWateredDateIso!);
    if (last == null) return false;
    return _dateOnly(last) == today;
  }

  /// Calendar days missed since last watering.
  ///
  /// Rules:
  /// - missedDays = 0 => healthy
  /// - missedDays = 1-2 => thirsty
  /// - missedDays = 3-6 => wilting
  /// - missedDays >= 7 => dead
  int get missedDays {
    if (lastWateredDateIso == null) return 0;
    final today = _dateOnly(DateTime.now());
    final last = _parseLocalDateOnly(lastWateredDateIso!);
    if (last == null) return 0;
    final diff = today.difference(_dateOnly(last)).inDays;
    return diff <= 0 ? 0 : diff;
  }

  TreeHealthState get healthState {
    if (isDead || missedDays >= 7) return TreeHealthState.dead;
    if (missedDays >= 3) return TreeHealthState.wilting;
    if (missedDays >= 1) return TreeHealthState.thirsty;
    return TreeHealthState.healthy;
  }

  TreeGrowthStage get growthStage {
    if (streakDays <= 2) return TreeGrowthStage.seed;
    if (streakDays <= 6) return TreeGrowthStage.sprout;
    if (streakDays <= 13) return TreeGrowthStage.small;
    if (streakDays <= 29) return TreeGrowthStage.young;
    return TreeGrowthStage.mature;
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Parses a local date-only string `yyyy-mm-dd` (or the first 10 chars of an
  /// ISO string) into a local [DateTime] at midnight.
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
