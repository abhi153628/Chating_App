// ignore_for_file: avoid_print, use_key_in_widget_constructors

import 'package:chating_app/services/auth_services.dart';
import 'package:chating_app/utils/app_lock_wrapper.dart';
import 'package:chating_app/screens/wrapper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';


void main() async {
  //! F L U T T E R - I N I T
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    //! F I R E B A S E - I N I T
    print("Initializing Firebase...");
    await Firebase.initializeApp();
    print("Firebase initialized successfully");
  } catch (e) {
    print("Failed to initialize Firebase: $e");
  }
  
  runApp(MyApp());
}

//! A P P - R O O T
class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      //! A U T H - P R O V I D E R
      create: (context) => AuthService(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'SecureChat',
        //! A P P - T H E M E
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          // Add some transition animations to make navigation smoother
          pageTransitionsTheme: PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        //! R O O T - W I D G E T
        home: AppLockWrapper(
          key: UniqueKey(),
          navigatorKey: navigatorKey,
          child: Wrapper(),
        ),
      ),
    );
  }
}