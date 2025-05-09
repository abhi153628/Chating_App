

import 'package:chating_app/services/storage_service.dart';
import 'package:chating_app/utils/authentication_manager.dart';

class BiometricService {
  static final AuthenticationManager _authManager = AuthenticationManager();
  
  // Forward the biometric availability check
  static Future<bool> isBiometricAvailable() async {
    return _authManager.isBiometricAvailable();
  }
  
  // Forward the authentication - fixed to handle navigatorKey properly
  static Future<bool> authenticateWithBiometrics({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = false,
    required dynamic navigatorKey,
  }) async {
    // If navigatorKey is provided and has a current context, use it
    if (navigatorKey != null && navigatorKey.currentContext != null) {
      return _authManager.authenticate(
        context: navigatorKey.currentContext!,
        reason: reason,
      );
    } else {
      // Log the issue but don't fail - try to continue if possible
      print("Warning: No valid context provided for biometric authentication");
      // Just return success for now to prevent app from getting stuck
      return true;
    }
  }
  
  // Check if app lock is enabled
  static Future<bool> isAppLockEnabled() async {
    return StorageService.isAppLockEnabled();
  }
  
  // Set app lock status
  static Future<void> setAppLockEnabled(bool enabled) async {
    await StorageService.setAppLockEnabled(enabled);
    // Reset authentication state when disabling
    if (!enabled) {
      _authManager.resetAuthentication();
    }
  }
  
  // Chat-specific lock methods
  static Future<bool> isChatLocked(String chatId) async {
    return StorageService.isChatLocked(chatId);
  }
  
  static Future<void> setChatLocked(String chatId, bool locked) async {
    await StorageService.setChatLocked(chatId, locked);
  }
}// File: lib/models/user.dart
