import 'package:shared_preferences/shared_preferences.dart';

/// Local entitlement cache. Source of truth is the IAP purchase stream.
class PremiumService {
  static const _premiumKey = 'mytree_premium_unlocked_v1';

  Future<bool> isPremiumUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumKey) ?? false;
  }

  Future<void> setPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, value);
  }

  /// Debug/testing convenience.
  Future<void> resetPremiumForDebug() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_premiumKey);
  }
}

