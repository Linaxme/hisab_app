import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_preferences_provider.dart';

/// Handles app language switching and persists preference.
class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier(this._prefs) : super(_loadInitialLocale(_prefs));

  final SharedPreferences _prefs;

  static Locale _loadInitialLocale(SharedPreferences prefs) {
    final code = prefs.getString('app_language') ?? 'bn';
    Intl.defaultLocale = code;
    return Locale(code);
  }

  Future<void> setLanguage(String code) async {
    await _prefs.setString('app_language', code);
    Intl.defaultLocale = code;
    state = Locale(code);
  }

  Future<void> toggle() {
    final next = state.languageCode == 'bn' ? 'en' : 'bn';
    return setLanguage(next);
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LanguageNotifier(prefs);
});
