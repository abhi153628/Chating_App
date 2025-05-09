

import 'package:chating_app/models/user.dart';

class Chat {
  final String id;
  final List<String> participants;
  final DateTime lastUpdated;
  final String? latestMessageText;
  final bool hasUnreadMessages;
  final int unreadCount;
  UserModel? otherUser; 
  Chat({
    required this.id,
    required this.participants,
    required this.lastUpdated,
    this.latestMessageText,
    this.hasUnreadMessages = false,
    this.unreadCount = 0,
    this.otherUser,
  });

  factory Chat.fromMap(Map<String, dynamic> data, String id, String currentUserId) {
    final List<String> participants = List<String>.from(data['participants'] ?? []);
    
    return Chat(
      id: id,
      participants: participants,
      lastUpdated: data['lastUpdated']?.toDate() ?? DateTime.now(),
      latestMessageText: data['latestMessage'],
      hasUnreadMessages: data['hasUnread_$currentUserId'] ?? false,
      unreadCount: data['unreadCount_$currentUserId'] ?? 0,
    );
  }
}
