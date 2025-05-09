class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isEncrypted;
  final bool isImage;
  final bool isRead; // New field for read status

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.isEncrypted = true,
    this.isImage = false,
    this.isRead = false, // Default to unread
  });

  factory Message.fromMap(Map<String, dynamic> data, String id) {
    return Message(
      id: id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      content: data['content'] ?? '',
      timestamp: data['timestamp']?.toDate() ?? DateTime.now(),
      isEncrypted: data['isEncrypted'] ?? true,
      isImage: data['isImage'] ?? false,
      isRead: data['isRead'] ?? false, // Add reading from Firestore
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp,
      'isEncrypted': isEncrypted,
      'isImage': isImage,
      'isRead': isRead, // Include in Firestore document
    };
  }
}
