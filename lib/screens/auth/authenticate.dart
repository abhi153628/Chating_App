import 'package:chating_app/screens/auth/login.dart';
import 'package:chating_app/screens/auth/register.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class Authenticate extends StatefulWidget {
  const Authenticate({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AuthenticateState createState() => _AuthenticateState();
}

class _AuthenticateState extends State<Authenticate> with SingleTickerProviderStateMixin {
  bool showSignIn = true;
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
  
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Changed to dark for better contrast with green
    ));
    
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        showSignIn = _tabController.index == 0;
      });
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
  
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Changed to dark for better contrast with green
    ));
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7BAC6C), // Primary green
              Color(0xFF5D8A4E), // Darker shade of green
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 40),
                // Logo or app name
                Text(
                  "🛡️ SecureChat",
                  style: GoogleFonts.aBeeZee(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "Private messaging made simple",
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 40),
                // Auth card with dynamic height
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Color(0xFFfffff4), // Cream background from chat list
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Tab bar
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: Color(0xFF7BAC6C),
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Color(0xFF7BAC6C),
                          indicatorWeight: 3,
                          labelStyle: GoogleFonts.aBeeZee(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          unselectedLabelStyle: GoogleFonts.aBeeZee(
                            fontWeight: FontWeight.normal,
                            fontSize: 14,
                          ),
                          tabs: [
                            Tab(text: "SIGN IN"),
                            Tab(text: "SIGN UP"),
                          ],
                        ),
                      ),
                      // Tab content with AnimatedCrossFade for smooth transitions
                      AnimatedCrossFade(
                        firstChild: Login(),
                        secondChild: Register(),
                        crossFadeState: showSignIn 
                          ? CrossFadeState.showFirst 
                          : CrossFadeState.showSecond,
                        duration: Duration(milliseconds: 300),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                // App attribution at the bottom
                Text(
                  "Secured with end-to-end encryption",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}