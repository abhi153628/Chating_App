// ignore_for_file: avoid_print

import 'package:chating_app/screens/chat/chat_list.dart';
import 'package:chating_app/screens/home/profile_page.dart';
import 'package:chating_app/screens/home/user_list.dart';

import 'package:chating_app/models/user.dart';
import 'package:chating_app/services/auth_services.dart';
import 'package:chating_app/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeState createState() => _HomeState();
}

// Update the Home class in lib/screens/home/home.dart
class _HomeState extends State<Home> {
   final DatabaseService _database = DatabaseService();
  int _selectedIndex = 0;
  UserModel? _userCache;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  // Use a separate method for loading user data
  Future<void> _loadUserData() async {
    if (!mounted) return;
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserBasic = authService.currentUser;
      
      // Set the basic user data immediately to avoid null checks
      if (currentUserBasic != null) {
        setState(() {
          _userCache = currentUserBasic;
        });
      }
      
      // Then fetch complete data
      final completeUser = await authService.fetchCompleteUserData();
      
      // Only update if mounted and data is available
      if (mounted && completeUser != null) {
        setState(() {
          _userCache = completeUser;
          _isLoading = false;
        });
        
        // Update data in Firestore without waiting for it
        _database.updateUserData(completeUser).catchError((e) {
          print('Error updating user data: $e');
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in _loadUserData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = _userCache ?? authService.currentUser;
    
    if (_isLoading || currentUser == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return StreamProvider<List<UserModel>>.value(
      initialData: [],
      value: authService.users,
      catchError: (_, __) => [],
      child: Scaffold(
        backgroundColor: Colors.white,
     
        body: _buildBody(currentUser),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }
  
  Widget _buildBody(UserModel currentUser) {
    switch (_selectedIndex) {
      case 0:
        return ChatList(); // Our new chat list
      case 1:
        return UserList(); // Original user/contacts list
      case 2:
        return ProfilePage(user: currentUser);
      default:
        return ChatList();
    }
  }
 
  
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFfffee7),
       
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Color(0xFFfffee7),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}


