import 'dart:convert';

import 'package:chating_app/models/chat.dart';
import 'package:chating_app/models/message.dart';
import 'package:chating_app/models/user.dart';
import 'package:chating_app/services/encryption_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

 Future<void> sendImageMessage({
  required String senderId,
  required String receiverId,
  required String base64Image,
}) async {
  try {
    // Create a unique chat ID
    String chatId = senderId.compareTo(receiverId) < 0 
      ? '$senderId-$receiverId' 
      : '$receiverId-$senderId';
    
    // Validate the base64 image first
    try {
      base64Decode(base64Image);
    } catch (e) {
      print("Invalid base64 image data: $e");
      return;
    }
    
    // First ensure the chat document exists with participants
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [senderId, receiverId],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    // Encrypt the image content
    final encryptedContent = await EncryptionService.encryptMessage(base64Image, chatId);
    
    // Get reference to the messages collection
    final messagesRef = _firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages');
    
    // Create the message with encrypted image content
    final message = Message(
      id: '',  // Firestore will generate ID
      senderId: senderId,
      receiverId: receiverId,
      content: encryptedContent,
      timestamp: DateTime.now(),
      isEncrypted: true,
      isImage: true,
      isRead: false, // New message is unread
    );
    
    // Add to Firestore
    await messagesRef.add(message.toMap());
    
    // Update latest message in chat document
    await _firestore.collection('chats').doc(chatId).set({
      'latestMessage': '[Image]', // Show [Image] in latest message preview
      'timestamp': DateTime.now(),
      'participants': [senderId, receiverId],
      'lastUpdated': FieldValue.serverTimestamp(),
      'hasUnread_$receiverId': true, // Set unread flag for receiver
      // Increment unread counter for receiver
      'unreadCount_$receiverId': FieldValue.increment(1),
    }, SetOptions(merge: true));
    
    if (kDebugMode) {
      print('Encrypted image message sent successfully to chat $chatId');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error sending image message: ${e.toString()}');
    }
  }
}
  Stream<List<Chat>> getUserChats(String userId) {
  return _firestore.collection('chats')
    .where('participants', arrayContains: userId)
    .orderBy('lastUpdated', descending: true)
    .snapshots()
    .asyncMap((snapshot) async {
      print('Retrieved ${snapshot.docs.length} chats');
      if (snapshot.docs.isEmpty) {
        return [];
      }

      List<Chat> chats = [];
      
      for (var doc in snapshot.docs) {
        try {
          // Create basic chat without other user details
          Chat chat = Chat.fromMap(doc.data(), doc.id, userId);
          
          // Find the ID of the other participant
          String? otherUserId;
          for (String participantId in chat.participants) {
            if (participantId != userId) {
              otherUserId = participantId;
              break;
            }
          }
          
          if (otherUserId != null) {
            // Fetch other user details
            UserModel? otherUser = await getUserById(otherUserId);
            if (otherUser != null) {
              chat.otherUser = otherUser;
            }
          }
          
          chats.add(chat);
        } catch (e) {
          print('Error parsing chat ${doc.id}: $e');
        }
      }
      
      return chats;
    });
}
Future<void> markChatAsRead(String chatId, String userId) async {
  try {
    // Update the chat document to clear unread indicator for this user
    await _firestore.collection('chats').doc(chatId).update({
      'hasUnread_$userId': false,
      'unreadCount_$userId': 0,
    });
    
    // Find all unread messages sent to this user and mark them as read
    final messagesRef = _firestore.collection('chats').doc(chatId).collection('messages');
    final unreadMessages = await messagesRef
      .where('receiverId', isEqualTo: userId)
      .where('isRead', isEqualTo: false)
      .get();
    
    // Use batch to update multiple messages efficiently
    final batch = _firestore.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    
    await batch.commit();
    
    if (kDebugMode) {
      print('Marked ${unreadMessages.docs.length} messages as read in chat $chatId');
    }
    
  } catch (e) {
    if (kDebugMode) {
      print('Error marking chat as read: $e');
    }
  }
}
  // Get all users
  Stream<List<UserModel>> get users {
    return _firestore.collection('users')
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) {
          print('No users found in Firestore');
          return <UserModel>[];
        }
        
        print('Found ${snapshot.docs.length} users in Firestore');
        return snapshot.docs.map((doc) {
          try {
            Map<String, dynamic> data = doc.data();
            print('User data for ${doc.id}: ${data.toString()}');
            return UserModel(
              uid: doc.id,
              name: data['name'] ?? '',
              email: data['email'] ?? '',
            );
          } catch (e) {
            print('Error parsing user ${doc.id}: $e');
            return UserModel(uid: doc.id);
          }
        }).toList();
      });
  }
  
  // Create or update user data method
Future<void> updateUserData(UserModel user) async {
  try {
    print('Updating user data for ${user.uid}, name: ${user.name}, email: ${user.email}, profileImage length: ${user.profileImage?.length ?? 0}');
    
    Map<String, dynamic> userData = {
      'name': user.name ?? '',
      'displayName': user.name ?? '', // For backward compatibility
      'email': user.email ?? '',
      'profileImage': user.profileImage ?? '',
      'photoUrl': user.profileImage ?? '', // For backward compatibility
      'lastActive': FieldValue.serverTimestamp(),
    };
    
    await _firestore.collection('users').doc(user.uid).set(
      userData, 
      SetOptions(merge: true)
    );
    
    print('Successfully updated user data for ${user.uid}');
  } catch (e) {
    print('Error updating user data: ${e.toString()}');
  }
}

// Update getUserById method
// In DatabaseService, update getUserById method
Future<UserModel?> getUserById(String uid) async {
  try {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      // Support both profileImage and photoUrl fields
      String? profileImage = data['profileImage'] ?? data['photoUrl'] ?? '';
      // Support both name and displayName fields
      String? name = data['name'] ?? data['displayName'] ?? '';
      
      return UserModel(
        uid: doc.id,
        name: name,
        email: data['email'] ?? '',
        profileImage: profileImage,
      );
    }
    return null;
  } catch (e) {
    print(e.toString());
    return null;
  }
}  // Modified method to send encrypted messages
  Future<void> sendMessage({
  required String senderId,
  required String receiverId,
  required String content,
}) async {
  try {
    // Create a unique chat ID
    String chatId = senderId.compareTo(receiverId) < 0 
      ? '$senderId-$receiverId' 
      : '$receiverId-$senderId';
    
    // First ensure the chat document exists with participants
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [senderId, receiverId],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    // Encrypt the message content
    final encryptedContent = await EncryptionService.encryptMessage(content, chatId);
    
    // Get reference to the messages collection
    final messagesRef = _firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages');
    
    // Create the message with encrypted content
    final message = Message(
      id: '',  // Firestore will generate ID
      senderId: senderId,
      receiverId: receiverId,
      content: encryptedContent,
      timestamp: DateTime.now(),
      isEncrypted: true,
      isRead: false, // New message is unread
    );
    
    // Add to Firestore
    await messagesRef.add(message.toMap());
    
    // Update latest message and unread status in chat document
    await _firestore.collection('chats').doc(chatId).set({
      'latestMessage': content.length > 20 ? '${content.substring(0, 20)}...' : content,
      'timestamp': DateTime.now(),
      'participants': [senderId, receiverId],
      'lastUpdated': FieldValue.serverTimestamp(),
      'hasUnread_$receiverId': true, // Set unread flag for receiver
      // Increment unread counter for receiver
      'unreadCount_$receiverId': FieldValue.increment(1),
    }, SetOptions(merge: true));
    
    if (kDebugMode) {
      print('Encrypted message sent successfully to chat $chatId');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error sending message: ${e.toString()}');
    }
  }
}

  // Modified method to get and decrypt chat messages
 Stream<List<Message>> getChatMessages(String userId, String otherUserId) {
  try {
    // Create a unique chat ID by sorting and concatenating user IDs
    String chatId = userId.compareTo(otherUserId) < 0 
      ? '$userId-$otherUserId' 
      : '$otherUserId-$userId';
    
    print('Fetching messages for chat: $chatId');
    
    // Mark messages as read whenever this stream is opened (chat screen opened)
    markChatAsRead(chatId, userId);
    
    // Get the stream of messages
    return _firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .asyncMap((snapshot) async {
        print('Retrieved ${snapshot.docs.length} messages');
        
        // Create a list to hold decrypted messages
        List<Message> decryptedMessages = [];
        
        // Process each message
        for (var doc in snapshot.docs) {
          Message message = Message.fromMap(doc.data(), doc.id);
          
          // Decrypt the message content if it's encrypted
          if (message.isEncrypted) {
            String decryptedContent = await EncryptionService.decryptMessage(
              message.content, 
              chatId
            );
            
            // Create a new message object with the decrypted content
            message = Message(
              id: message.id,
              senderId: message.senderId,
              receiverId: message.receiverId,
              content: decryptedContent,
              timestamp: message.timestamp,
              isEncrypted: false, // Mark as decrypted
              isImage: message.isImage,
              isRead: message.isRead, // Preserve read status
            );
          }
          
          decryptedMessages.add(message);
        }
        
        return decryptedMessages;
      });
  } catch (e) {
    print('Error setting up message stream: $e');
    // Return empty stream on error
    return Stream.value([]);
  }
}
}
