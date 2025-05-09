// ignore_for_file: deprecated_member_use

import 'package:chating_app/utils/authentication_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LockScreen extends StatefulWidget {
  final Function onAuthenticated;
  
  const LockScreen({Key? key, required this.onAuthenticated}) : super(key: key);

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  bool _isAuthenticating = false;
  bool _isBiometricAvailable = false;
  bool _authFailed = false;
  final AuthenticationManager _authManager = AuthenticationManager();
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    
    // Set up animation for the lock icon
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    
    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController.repeat(reverse: true);
    
    _checkBiometricAndAuthenticate();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _checkBiometricAndAuthenticate() async {
    if (!mounted) return;
    
    setState(() {
      _isAuthenticating = true;
      _authFailed = false;
    });
    
    try {
      _isBiometricAvailable = await _authManager.isBiometricAvailable();
      print("Biometric available: $_isBiometricAvailable");
      
      if (_isBiometricAvailable) {
        // Slight delay to ensure UI is ready
        await Future.delayed(Duration(milliseconds: 300));
        
        if (!mounted) return;
        
        bool authenticated = await _authManager.authenticate(
          context: context,
          reason: 'Verify your identity to access your messages',
        );
        
        print("Authentication result: $authenticated");
        
        if (authenticated && mounted) {
          widget.onAuthenticated();
        } else if (mounted) {
          setState(() {
            _authFailed = true;
          });
        }
      }
    } catch (e) {
      print("Error in _checkBiometricAndAuthenticate: $e");
      if (mounted) {
        setState(() {
          _authFailed = true;
        });
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
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7BAC6C),
              Color(0xFF7BAC6C).withOpacity(0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo and Icon
                    ScaleTransition(
                      scale: _animation,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 60,
                            color: Color(0xFF7BAC6C),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    
                    // App Title
                    Text(
                      "SecureChat",
                      style: GoogleFonts.aBeeZee(
                        fontSize: isSmallScreen ? 28 : 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 6,
                            color: Colors.black.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 10),
                    
                    // App Subtitle
                    Text(
                      "Private messaging made simple",
                      style: GoogleFonts.notoSans(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    SizedBox(height: 50),
                    
                    // Auth Container
                    Container(
                      width: screenSize.width > 600 ? 400 : double.infinity,
                      padding: EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "App Locked",
                            style: GoogleFonts.aBeeZee(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7BAC6C),
                            ),
                          ),
                          
                          SizedBox(height: 16),
                          
                          Text(
                            "Use fingerprint authentication to access your messages",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.notoSans(
                              fontSize: 15,
                              height: 1.4,
                              color: Colors.grey[700],
                            ),
                          ),
                          
                          SizedBox(height: 30),
                          
                          // Authentication State
                          if (_isAuthenticating) 
                            // Loading State
                            Container(
                              width: 60,
                              height: 60,
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7BAC6C)),
                                strokeWidth: 3,
                              ),
                            )
                          else
                            // Authentication Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isBiometricAvailable 
                                  ? () => _checkBiometricAndAuthenticate() 
                                  : null,
                                icon: Icon(
                                  Icons.fingerprint_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  _authFailed ? "Try Again" : "Verify Identity",
                                  style: GoogleFonts.notoSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF7BAC6C),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          
                          // Authentication Feedback
                          if (_authFailed && !_isAuthenticating) ...[
                            SizedBox(height: 20),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.shade100,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Authentication failed. Please try again.",
                                      style: GoogleFonts.notoSans(
                                        fontSize: 13,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          if (!_isBiometricAvailable && !_isAuthenticating) ...[
                            SizedBox(height: 20),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Biometric authentication is not available on this device. Please check your device settings.",
                                      style: GoogleFonts.notoSans(
                                        fontSize: 13,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}