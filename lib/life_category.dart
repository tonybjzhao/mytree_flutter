enum LifeCategory { health, family, work, rest }

extension LifeCategoryX on LifeCategory {
  String get storageKey => name;

  String get title {
    switch (this) {
      case LifeCategory.health:
        return 'Health';
      case LifeCategory.family:
        return 'Family';
      case LifeCategory.work:
        return 'Work';
      case LifeCategory.rest:
        return 'Rest';
    }
  }

  String get subtitle {
    switch (this) {
      case LifeCategory.health:
        return 'Care for your body and wellbeing';
      case LifeCategory.family:
        return 'Care for the people closest to you';
      case LifeCategory.work:
        return 'Care for what you are building';
      case LifeCategory.rest:
        return 'Care for stillness and recovery';
    }
  }

  String get emoji {
    switch (this) {
      case LifeCategory.health:
        return '🌿';
      case LifeCategory.family:
        return '🏡';
      case LifeCategory.work:
        return '🛠️';
      case LifeCategory.rest:
        return '🌙';
    }
  }

  static LifeCategory? fromStorageKey(String? raw) {
    if (raw == null) return null;
    for (final category in LifeCategory.values) {
      if (category.storageKey == raw) return category;
    }
    return null;
  }
}
