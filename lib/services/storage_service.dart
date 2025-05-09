import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _appLockEnabledKey = 'app_lock_enabled';
  
  // Check if app lock is enabled
  static Future<bool> isAppLockEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_appLockEnabledKey) ?? false;
    } catch (e) {
      print('Error reading app lock status: $e');
      return false;
    }
  }
  
  // Set app lock status
  static Future<void> setAppLockEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_appLockEnabledKey, enabled);
    } catch (e) {
      print('Error setting app lock status: $e');
    }
  }
  
  // For chat-specific locks
  static Future<bool> isChatLocked(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('chat_lock_$chatId') ?? false;
    } catch (e) {
      print('Error reading chat lock status: $e');
      return false;
    }
  }
  
  static Future<void> setChatLocked(String chatId, bool locked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('chat_lock_$chatId', locked);
    } catch (e) {
      print('Error setting chat lock status: $e');
    }
  }
  
  // For encryption keys
  static Future<void> saveChatKey(String chatId, String keyValue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_key_$chatId', keyValue);
    } catch (e) {
      print('Error saving chat key: $e');
    }
  }
  
  static Future<String?> getChatKey(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('chat_key_$chatId');
    } catch (e) {
      print('Error getting chat key: $e');
      return null;
    }
  }
}
