
import 'package:chating_app/services/storage_service.dart';
import 'package:chating_app/utils/authentication_manager.dart';
import 'package:chating_app/utils/lock_screen.dart';
import 'package:flutter/material.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const AppLockWrapper({
    Key? key,
    required this.child,
    this.navigatorKey,
  }) : super(key: key);

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isLoading = true;
  bool _isAuthenticating = false;
  final AuthenticationManager _authManager = AuthenticationManager();
  DateTime? _lastUnlockTime;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLockStatus();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("App lifecycle state changed to: $state");
    
    if (state == AppLifecycleState.resumed) {
      // Don't reset auth if we just authenticated (within the last 3 seconds)
      final now = DateTime.now();
      final canSkipResumeLock = _lastUnlockTime != null && 
                        now.difference(_lastUnlockTime!).inSeconds < 3;
      
      if (canSkipResumeLock) {
        print("Recently authenticated, skipping resume lock");
        return;
      }
      
      // Check if app lock is enabled and only lock if it is
      StorageService.isAppLockEnabled().then((isEnabled) {
        if (isEnabled) {
          print("App resumed, resetting authentication");
          _authManager.resetAuthentication();
          if (mounted) {
            setState(() {
              _isLocked = true;
            });
          }
        }
      });
    }
  }
  
  Future<void> _checkInitialLockStatus() async {
    try {
      final isAppLockEnabled = await StorageService.isAppLockEnabled();
      
      if (mounted) {
        setState(() {
          _isLocked = isAppLockEnabled;
          _isLoading = false;
        });
        
        // If locked, trigger authentication immediately
        if (_isLocked) {
          _authenticateUser();
        }
      }
    } catch (e) {
      print('Error checking initial lock status: $e');
      if (mounted) {
        setState(() {
          _isLocked = false;
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _authenticateUser() async {
    if (_isAuthenticating || !mounted) return;
    
    setState(() {
      _isAuthenticating = true;
    });
    
    try {
      final authenticated = await _authManager.authenticate(
        context: context,
        reason: 'Verify your identity to access SecureChat',
      );
      
      if (mounted) {
        setState(() {
          if (authenticated) {
            _isLocked = false;
            _lastUnlockTime = DateTime.now();
            print("Authentication successful, unlocking app. Time: $_lastUnlockTime");
          }
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      print('Error in _authenticateUser: $e');
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_isLocked) {
      return LockScreen(
        onAuthenticated: () {
          if (mounted) {
            setState(() {
              _isLocked = false;
              _lastUnlockTime = DateTime.now();
              print("LockScreen callback: unlocking app. Time: $_lastUnlockTime");
            });
          }
        },
      );
    }
    
    return widget.child;
  }
}
