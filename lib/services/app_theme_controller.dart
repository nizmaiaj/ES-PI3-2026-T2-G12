// Persiste e divulga a preferência de tema escolhida pelo usuário.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modos exibidos pelo seletor de aparência.
enum AppThemeMode { light, dark, system }

/// Fonte única da preferência visual usada pelo `MaterialApp`.
class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();
  static const _prefsKey = 'appThemeMode';

  AppThemeMode _mode = AppThemeMode.light;

  AppThemeMode get mode => _mode;

  /// Traduz a opção da interface para o tipo compreendido pelo Flutter.
  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// Recupera do armazenamento local a preferência salva anteriormente.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = _modeFromName(prefs.getString(_prefsKey));
  }

  /// Atualiza imediatamente a interface e persiste a nova preferência.
  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;

    _mode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  AppThemeMode _modeFromName(String? value) {
    for (final mode in AppThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return AppThemeMode.light;
  }
}
