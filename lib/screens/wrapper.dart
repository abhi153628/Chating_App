import 'package:chating_app/screens/home/home_page.dart';
import 'package:chating_app/models/user.dart';
import 'package:chating_app/screens/auth/authenticate.dart';
import 'package:chating_app/services/auth_services.dart';
import 'package:chating_app/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Wrapper extends StatelessWidget {
  final DatabaseService _database = DatabaseService();

  Wrapper({super.key});
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return StreamBuilder<UserModel?>(
      stream: authService.user,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final currentUser = userSnapshot.data ?? authService.currentUser;
        
        if (currentUser == null) {
          return Authenticate();
        }
        
        // Fetch complete user data once after authentication
        authService.fetchCompleteUserData().then((completeUser) {
          if (completeUser != null) {
            // Update the user in database only if needed
            _database.updateUserData(completeUser);
          }
        });
        
        return Home();
      },
    );
  }
}