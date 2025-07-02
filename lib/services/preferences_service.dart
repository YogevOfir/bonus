import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _backgroundVolumeKey = 'background_volume';
  static const _effectsVolumeKey = 'effects_volume';
  static const _isHebrewKey = 'is_hebrew';

  Future<void> saveVolumeSettings(double backgroundVolume, double effectsVolume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_backgroundVolumeKey, backgroundVolume);
    await prefs.setDouble(_effectsVolumeKey, effectsVolume);
  }

  Future<Map<String, double>> loadVolumeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final backgroundVolume = prefs.getDouble(_backgroundVolumeKey) ?? 0.3;
    final effectsVolume = prefs.getDouble(_effectsVolumeKey) ?? 0.5;
    return {
      'background': backgroundVolume,
      'effects': effectsVolume,
    };
  }

  Future<void> saveLanguageSetting(bool isHebrew) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isHebrewKey, isHebrew);
  }

  Future<bool?> loadLanguageSetting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isHebrewKey);
  }
} 