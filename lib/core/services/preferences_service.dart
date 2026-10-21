import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyOnboardingCompleted = 'is_onboarding_completed';

  static String _profilePhotoKey(String userKey) =>
      'profile_photo_${userKey.toLowerCase()}';

  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  static Future<void> setOnboardingCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, value);
  }

  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOnboardingCompleted);
  }

  static Future<String?> getProfilePhoto(String userKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_profilePhotoKey(userKey));
  }

  static Future<void> setProfilePhoto(
    String userKey,
    String photoBase64,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilePhotoKey(userKey), photoBase64);
  }
}
