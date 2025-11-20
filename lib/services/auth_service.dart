import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyIsGuest = 'is_guest';
  static const String _keyAuthMethod = 'auth_method'; // 'google', 'email', or 'guest'

  /// Check if user is already logged in (via any method)
  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    final isGuest = prefs.getBool(_keyIsGuest) ?? false;
    
    // Return true if user has logged in or used guest mode before
    return isLoggedIn || isGuest;
  }

  /// Save login state when user successfully logs in
  static Future<void> saveLoginState(String authMethod, {bool isGuest = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, !isGuest);
    await prefs.setBool(_keyIsGuest, isGuest);
    await prefs.setString(_keyAuthMethod, authMethod);
  }

  /// Save login state (internal method)
  static Future<void> _saveLoginState(String authMethod, {bool isGuest = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, !isGuest);
    await prefs.setBool(_keyIsGuest, isGuest);
    await prefs.setString(_keyAuthMethod, authMethod);
  }

  /// Save guest mode preference
  static Future<void> saveGuestMode() async {
    await saveLoginState('guest', isGuest: true);
  }

  /// Clear authentication state (logout)
  static Future<void> clearAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyIsGuest);
    await prefs.remove(_keyAuthMethod);
  }

  /// Get current auth method
  static Future<String?> getAuthMethod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAuthMethod);
  }
}

