import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/paywall_variant.dart';

class ExperimentService {
  static const String _revivePaywallVariantKey = 'revive_paywall_variant_v1';

  Future<PaywallVariant> getRevivePaywallVariant() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_revivePaywallVariantKey);

    if (stored != null) {
      return _fromCode(stored);
    }

    final variants = PaywallVariant.values;
    final picked = variants[Random().nextInt(variants.length)];

    await prefs.setString(_revivePaywallVariantKey, picked.code);
    return picked;
  }

  Future<void> forceVariantForDebug(PaywallVariant variant) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_revivePaywallVariantKey, variant.code);
  }

  Future<void> clearVariantForDebug() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_revivePaywallVariantKey);
  }

  PaywallVariant _fromCode(String code) {
    for (final variant in PaywallVariant.values) {
      if (variant.code == code) return variant;
    }
    return PaywallVariant.emotional;
  }
}
