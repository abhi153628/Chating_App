import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:chating_app/screens/chat/chat_screen.dart';
import 'package:chating_app/models/user.dart';
import 'package:chating_app/models/chat.dart';
import 'package:chating_app/services/auth_services.dart';
import 'package:chating_app/services/database_service.dart';

//! C H A T - L I S T - S C R E E N
class ChatList extends StatelessWidget {
  final DatabaseService _database = DatabaseService();

  ChatList({super.key});

  @override
  Widget build(BuildContext context) {
    //! U S E R - D A T A
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    final allUsers = Provider.of<List<UserModel>>(context);
    
    if (currentUser == null) {
      return Center(child: CircularProgressIndicator());
    }
    
    //! F I L T E R - U S E R S
    final otherUsers = allUsers.where((user) => user.uid != currentUser.uid).toList();
    
    return StreamBuilder<List<Chat>>(
      stream: _database.getUserChats(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final chats = snapshot.data ?? [];
        
        return Container(
          //! M A I N - C O N T A I N E R
          color: Color(0xFF7BAC6C), // Green background color
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20,),
              //! H E A D E R
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: Text(
                  '🛡️ Chats',
                  style: GoogleFonts.aBeeZee(
                    fontSize: 33,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
           
              //! R E C E N T - P R O F I L E S - T I T L E
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Profiles',
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        // ignore: deprecated_member_use
                        color: Colors.black.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              
              //! H O R I Z O N T A L - P R O F I L E S
              Container(
                height: 117,
                padding: EdgeInsets.only(left: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: otherUsers.length > 5 ? 5 : otherUsers.length,
                  itemBuilder: (context, index) {
                    final user = otherUsers[index];
                    return _buildRecentMatchAvatar(context, user, currentUser);
                  },
                ),
              ),
              
              SizedBox(height: 10),
              
              //! C H A T - L I S T - C O N T A I N E R
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFfffff4),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: chats.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: EdgeInsets.only(top: 10),
                          itemCount: chats.length,
                          separatorBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Divider(
                              // ignore: deprecated_member_use
                              color: Colors.grey.withOpacity(0.2),
                              height: 1,
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            final otherUser = chat.otherUser;
                            
                            if (otherUser == null) {
                              return SizedBox.shrink();
                            }
                            
                            return _buildChatTile(context, chat, otherUser, currentUser);
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  //! R E C E N T - A V A T A R - B U I L D E R
  Widget _buildRecentMatchAvatar(BuildContext context, UserModel user, UserModel currentUser) {
    //! C O L O R - M A P P I N G
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
    
    return GestureDetector(
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
      //! P R O F I L E - I T E M
      child: Container(
        width: 95,
        margin: EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              height: 95,
              width: 85,
              decoration: BoxDecoration(
                color: defaultColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: user.profileImage != null && user.profileImage!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.memory(
                        base64Decode(user.profileImage!),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Text(
                        firstLetter,
                        style: GoogleFonts.aBeeZee(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
            SizedBox(height: 5),
            Text(
              user.name ?? 'Unknown',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.8),
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  //! C H A T - T I L E - B U I L D E R
  Widget _buildChatTile(BuildContext context, Chat chat, UserModel otherUser, UserModel currentUser) {
    //! T I M E - F O R M A T T I N G
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      chat.lastUpdated.year,
      chat.lastUpdated.month,
      chat.lastUpdated.day,
    );
    
    String formattedTime;
    if (messageDate == today) {
      formattedTime = DateFormat('HH:mm').format(chat.lastUpdated); // 24-hour format
    } else {
      formattedTime = DateFormat('MM.dd').format(chat.lastUpdated); // MM.dd format
    }
    
    //! U S E R - A V A T A R - D A T A
    final firstLetter = otherUser.name != null && otherUser.name!.isNotEmpty ? otherUser.name![0].toUpperCase() : '?';
    
    //! C O L O R - M A P P I N G
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
    
    final defaultColor = colorMap[firstLetter] ?? Colors.blue.shade400;
    
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      //! U S E R - A V A T A R
      leading: CircleAvatar(
        radius: 25.0,
        backgroundColor: defaultColor,
        backgroundImage: otherUser.profileImage != null && otherUser.profileImage!.isNotEmpty
          ? MemoryImage(base64Decode(otherUser.profileImage!))
          : null,
        child: (otherUser.profileImage == null || otherUser.profileImage!.isEmpty) 
          ? Text(
              firstLetter,
              style: TextStyle(
                fontSize: 20.0,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
      ),
      //! C H A T - H E A D E R
      title: Padding(
        padding: EdgeInsets.only(bottom: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              otherUser.name ?? 'Unknown',
              style: GoogleFonts.aBeeZee(
                fontWeight: chat.hasUnreadMessages ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
                color: chat.hasUnreadMessages ? Colors.black : Colors.black87,
              ),
            ),
            Text(
              formattedTime,
              style: TextStyle(
                fontSize: 12,
                color: chat.hasUnreadMessages ? Colors.black87 : Colors.grey,
                fontWeight: chat.hasUnreadMessages ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      //! L A S T - M E S S A G E
      subtitle: Text(
        chat.latestMessageText ?? 'Start a conversation',
        style: TextStyle(
          color: chat.hasUnreadMessages ? Colors.black87 : Colors.grey.shade600,
          fontWeight: chat.hasUnreadMessages ? FontWeight.w500 : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      //! N A V I G A T I O N
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              currentUser: currentUser,
              otherUser: otherUser,
            ),
          ),
        );
      },
    );
  }
  
  //! E M P T Y - S T A T E - V I E W
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          //! E M P T Y - I C O N
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 20),
          //! E M P T Y - T I T L E
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7BAC6C),
            ),
          ),
          SizedBox(height: 10),
          //! E M P T Y - M E S S A G E
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start a new chat by tapping on a contact in the contacts tab',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(height: 30),
          //! C O N T A C T S - B U T T O N
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF7BAC6C),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            icon: Icon(Icons.people_outline),
            label: Text(
              'View Contacts', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
            onPressed: () {
              // Implementation to switch to contacts tab
            },
          ),
        ],
      ),
    );
  }
}