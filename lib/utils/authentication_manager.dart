import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class AuthenticationManager {
  // Singleton pattern
  static final AuthenticationManager _instance = AuthenticationManager._internal();
  factory AuthenticationManager() => _instance;
  AuthenticationManager._internal();
  
  // State tracking
  bool _isAuthenticating = false;
  bool _hasAuthenticatedOnce = false;
  DateTime? _lastAuthTime;
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  // Reset authentication state when needed
  void resetAuthentication() {
    // Don't reset if we just authenticated within the last 3 seconds
    if (_lastAuthTime != null && 
        DateTime.now().difference(_lastAuthTime!).inSeconds < 3) {
      print("Authentication reset called but ignoring - recently authenticated");
      return;
    }
    
    print("Resetting authentication state");
    _hasAuthenticatedOnce = false;
  }
  
  // Check if biometrics is available
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }
  
  // Single authenticate method to be used throughout the app
  Future<bool> authenticate({required BuildContext context, required String reason}) async {
    // If already authenticated once and not reset, return true immediately
    if (_hasAuthenticatedOnce) {
      print("Already authenticated, returning true without prompting");
      return true;
    }
    
    // Ensure we're not currently authenticating to avoid concurrent auth attempts
    if (_isAuthenticating) {
      print("Authentication already in progress, returning false");
      return false;
    }
    
    _isAuthenticating = true;
    bool authenticated = false;
    
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        print("Biometric authentication not available");
        _isAuthenticating = false;
        return false;
      }
      
      authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true, // Changed to true to maintain authentication between app switches
          biometricOnly: false, // Allow device PIN/pattern as fallback
        ),
      );
      
      // Mark as authenticated for this session if successful
      if (authenticated) {
        _hasAuthenticatedOnce = true;
        _lastAuthTime = DateTime.now();
        print("Authentication successful, _hasAuthenticatedOnce set to true at $_lastAuthTime");
      } else {
        print("Authentication failed");
      }
    } catch (e) {
      print('Error during authentication: $e');
      authenticated = false;
    } finally {
      _isAuthenticating = false;
    }
    
    return authenticated;
  }
}
// 2. Now, completely rewrite the AppLockWrapper to use the new manager:

// 3. Update the LockScreen for better handling:
