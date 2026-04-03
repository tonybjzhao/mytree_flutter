import 'package:shared_preferences/shared_preferences.dart';

/// Local-only premium flag for V2 scaffold.
/// (Later replace `unlockPremium()` with real IAP.)
class PremiumService {
  static const _premiumKey = 'mytree_premium_unlocked_v1';

  Future<bool> isPremiumUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumKey) ?? false;
  }

  Future<void> unlockPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, true);
  }

  /// Debug/testing convenience.
  Future<void> resetPremiumForDebug() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_premiumKey);
  }
}

