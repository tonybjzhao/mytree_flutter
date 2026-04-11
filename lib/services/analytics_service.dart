import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsService {
  static const String _eventCountsKey = 'analytics_event_counts_v1';

  Future<void> logEvent(
    String eventName, {
    Map<String, dynamic>? params,
  }) async {
    final safeParams = params ?? <String, dynamic>{};

    debugPrint('[analytics] $eventName ${jsonEncode(safeParams)}');
    await _incrementLocalCount(eventName, safeParams);
  }

  Future<void> _incrementLocalCount(
    String eventName,
    Map<String, dynamic> params,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_eventCountsKey);

    Map<String, dynamic> store = <String, dynamic>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        store = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        store = <String, dynamic>{};
      }
    }

    final variant = (params['variant'] ?? 'unknown').toString();
    final key = '$eventName::$variant';

    final current = (store[key] as int?) ?? 0;
    store[key] = current + 1;

    await prefs.setString(_eventCountsKey, jsonEncode(store));
  }

  Future<Map<String, dynamic>> getLocalCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_eventCountsKey);

    if (raw == null || raw.isEmpty) return <String, dynamic>{};

    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> clearLocalCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eventCountsKey);
  }
}
