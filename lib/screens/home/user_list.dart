// ignore_for_file: use_key_in_widget_constructors, deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chating_app/screens/chat/chat_screen.dart';
import 'package:chating_app/models/user.dart';
import 'package:chating_app/services/auth_services.dart';
import 'package:provider/provider.dart';

class UserList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final users = Provider.of<List<UserModel>>(context);
    final currentUser = Provider.of<AuthService>(context).currentUser;
    
    if (users.isEmpty) {
      return _buildEmptyState(true);
    }
    
    // Filter out current user
    final filteredUsers = users.where((user) => user.uid != currentUser?.uid).toList();
    
    if (filteredUsers.isEmpty) {
      return _buildEmptyState(false);
    }
    
    return Container(
      color: Color(0xFF7BAC6C), // Green background color to match ChatList
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          // Header section
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Text(
              'Contacts',
              style: GoogleFonts.aBeeZee(
                fontSize: 33,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          
          // Subtitle
          Padding(
            padding: const EdgeInsets.only(left: 18, bottom: 15),
            child: Text(
              'All Contacts',
              style: GoogleFonts.notoSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black.withOpacity(0.7),
              ),
            ),
          ),
          
          // User List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: ListView.separated(
                padding: EdgeInsets.only(top: 15, bottom: 15),
                itemCount: filteredUsers.length,
                separatorBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    color: Colors.grey.withOpacity(0.2),
                    height: 1,
                  ),
                ),
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  return _buildUserTile(context, user, currentUser!);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUserTile(BuildContext context, UserModel user, UserModel currentUser) {
    // Get a consistent color based on user's name
    final Map<String, Color> colorMap = {
      'A': Colors.red.shade400,
      'B': Colors.blue.shade300,
      'C': Colors.green.shade400,
      'D': Colors.orange.shade400,
      'E': Colors.purple.shade400,
      'F': Colors.teal.shade400,
      'G': Colors.pink.shade400,
      'H': Colors.indigo.shade400,
      'I': Colors.amber.shade400,
      'J': Colors.cyan.shade400,
      'K': Colors.red.shade400,
      'L': Colors.deepPurple.shade400,
      'M': Colors.lightBlue.shade400,
      'N': Colors.lime.shade600,
      'O': Colors.brown.shade400,
      'P': Colors.deepOrange.shade400,
      'Q': Colors.blue.shade600,
      'R': Colors.lightGreen.shade600,
      'S': Colors.pink.shade600,
      'T': Colors.teal.shade600,
      'U': Colors.amber.shade600,
      'V': Colors.indigo.shade600,
      'W': Colors.red.shade600,
      'X': Colors.purple.shade600,
      'Y': Colors.green.shade600,
      'Z': Colors.orange.shade600,
    };
    
    final firstLetter = user.name != null && user.name!.isNotEmpty ? user.name![0].toUpperCase() : '?';
    final defaultColor = colorMap[firstLetter] ?? Colors.blue.shade400;
    
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 25.0,
        backgroundColor: defaultColor,
        backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
          ? MemoryImage(base64Decode(user.profileImage!))
          : null,
        child: (user.profileImage == null || user.profileImage!.isEmpty) 
          ? Text(
              firstLetter,
              style: GoogleFonts.aBeeZee(
                fontSize: 20.0,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
      ),
      title: Text(
        user.name ?? 'Anonymous',
        style: GoogleFonts.notoSans(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        user.email ?? '',
        style: GoogleFonts.notoSans(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: Color(0xFF7BAC6C).withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Color(0xFF7BAC6C),
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              currentUser: currentUser,
              otherUser: user,
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildEmptyState(bool noUsers) {
    return Container(
      color: Color(0xFF7BAC6C),
      child: Column(
        children: [
          SizedBox(height: 20),
          // Header
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Contacts',
                style: GoogleFonts.aBeeZee(
                  fontSize: 33,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 20),
                    Text(
                      noUsers ? 'No users found' : 'No other users found',
                      style: GoogleFonts.aBeeZee(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7BAC6C),
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Start by inviting friends to join the app',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF7BAC6C),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: Icon(Icons.person_add_outlined),
                      label: Text(
                        'Invite Friends', 
                        style: TextStyle(fontSize: 16)
                      ),
                      onPressed: () {
                        // Implementation for invite functionality
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}