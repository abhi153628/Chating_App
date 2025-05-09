
import 'package:chating_app/utils/authentication_manager.dart';
import 'package:flutter/material.dart';

class ChatLockScreen extends StatefulWidget {
  final Function onAuthenticated;

  const ChatLockScreen({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<ChatLockScreen> createState() => _ChatLockScreenState();
}

class _ChatLockScreenState extends State<ChatLockScreen> {
  bool _isAuthenticating = false;
  bool _isBiometricAvailable = false;
  final AuthenticationManager _authManager = AuthenticationManager();
  
  @override
  void initState() {
    super.initState();
    _authenticate();
  }
  
  Future<void> _authenticate() async {
    if (!mounted) return;
    
    setState(() {
      _isAuthenticating = true;
    });
    
    try {
      _isBiometricAvailable = await _authManager.isBiometricAvailable();
      
      if (_isBiometricAvailable) {
        // Slight delay to ensure UI is ready
        await Future.delayed(Duration(milliseconds: 300));
        
        if (!mounted) return;
        
        bool authenticated = await _authManager.authenticate(
          context: context,
          reason: 'Verify your identity to access this chat',
        );
        
        if (authenticated && mounted) {
          widget.onAuthenticated();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Color(0xFF6A11CB),
            ),
            SizedBox(height: 20),
            Text(
              "Chat Locked",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6A11CB),
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Use fingerprint authentication to access this conversation",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
            SizedBox(height: 40),
            
            _isAuthenticating
              ? CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A11CB)),
                )
              : ElevatedButton.icon(
                  onPressed: _isBiometricAvailable ? _authenticate : null,
                  icon: Icon(Icons.fingerprint),
                  label: Text("Unlock Chat"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6A11CB),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
            
            if (!_isBiometricAvailable) ...[
              SizedBox(height: 15),
              Text(
                "Biometric authentication is not available on this device.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
