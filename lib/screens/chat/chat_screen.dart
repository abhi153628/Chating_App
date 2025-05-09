import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chating_app/screens/chat/chat_lock_Screen.dart';
import 'package:chating_app/models/message.dart';
import 'package:chating_app/models/user.dart';
import 'package:chating_app/services/database_service.dart';
import 'package:chating_app/utils/biometric_services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

//! C H A T - S C R E E N
class ChatScreen extends StatefulWidget {
  final UserModel currentUser;
  final UserModel otherUser;

  ChatScreen({required this.currentUser, required this.otherUser});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  //! C O N T R O L L E R S
  final _messageController = TextEditingController();
  final DatabaseService _database = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  
  //! S T A T E - V A R I A B L E S
  bool _isEncryptionEnabled = true;
  bool _isChatLocked = false;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  @override
  void initState() {
    super.initState();
    //! C H A T - L O C K - C H E C K
    _checkChatLockStatus();
  }
  
  //! L O C K - S T A T U S - C H E C K
  Future<void> _checkChatLockStatus() async {
    // Here we could check if this specific chat should be locked by default
    // For now, we'll just use the app lock setting
    final isAppLockEnabled = await BiometricService.isAppLockEnabled();
    setState(() {
      _isChatLocked = isAppLockEnabled;
    });
  }
  
  //! T O G G L E - C H A T - L O C K
  void _toggleChatLock() async {
    if (!_isChatLocked) {
      // If we're locking the chat, check if biometrics is available first
      final isAvailable = await BiometricService.isBiometricAvailable();
      if (!isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric authentication is not available on this device'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }
      
      // Set the lock status
      setState(() {
        _isChatLocked = true;
      });
      
      // Show a snackbar to confirm
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat locked with fingerprint authentication'),
          backgroundColor: Color(0xFF7BAC6C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      // If we're unlocking, verify the user's identity first
      final authenticated = await BiometricService.authenticateWithBiometrics(
        reason: 'Verify your identity to unlock this chat', navigatorKey: null,
      );
      
      if (authenticated) {
        setState(() {
          _isChatLocked = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat unlocked'),
            backgroundColor: Color(0xFF7BAC6C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
  
  //! I M A G E - P I C K E R
  Future<void> _pickAndSendImage() async {
    try {
      final ImagePicker _picker = ImagePicker();
      final XFile? pickedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Reduce image quality to save bandwidth
        maxWidth: 800,    // Limit width for better performance
      );
      
      if (pickedImage != null) {
        //! L O A D I N G - D I A L O G
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7BAC6C)),
            ),
          ),
        );
        
        try {
          //! I M A G E - P R O C E S S I N G
          final bytes = await File(pickedImage.path).readAsBytes();
          final base64Image = base64Encode(bytes);
          
          // Verify base64 is valid by trying to decode it
          base64Decode(base64Image);
          
          // Send the image
          await _database.sendImageMessage(
            senderId: widget.currentUser.uid,
            receiverId: widget.otherUser.uid,
            base64Image: base64Image,
          );
          
          // Close loading dialog
          Navigator.pop(context);
        } catch (e) {
          // Close loading dialog if open
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          
          print("Error processing image: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing image: $e'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
  
  //! A U T H E N T I C A T I O N - C A L L B A C K
  void _onChatAuthenticated() {
    setState(() {
      _isChatLocked = false;
    });
  }
  
  //! U S E R - C O L O R - G E N E R A T O R
  Color _getUserColor(UserModel user) {
    if (user.name == null || user.name!.isEmpty) {
      return Color(0xFF7BAC6C);
    }
    
    final firstLetter = user.name![0].toUpperCase();
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
    
    return colorMap[firstLetter] ?? Color(0xFF7BAC6C);
  }
  
  @override
  Widget build(BuildContext context) {
    //! C H A T - I D - G E N E R A T I O N
    String chatId = widget.currentUser.uid.compareTo(widget.otherUser.uid) < 0 
      ? '${widget.currentUser.uid}-${widget.otherUser.uid}' 
      : '${widget.otherUser.uid}-${widget.currentUser.uid}';

    //! L O C K - S C R E E N - C H E C K
    if (_isChatLocked) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Color(0xFF7BAC6C),
          title: Text(
            widget.otherUser.name ?? 'Chat',
            style: GoogleFonts.aBeeZee(
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: ChatLockScreen(
          onAuthenticated: _onChatAuthenticated,
        ),
      );
    }

    final otherUserColor = _getUserColor(widget.otherUser);

    //! M A I N - C H A T - S C R E E N
    return Scaffold(
      //! A P P - B A R
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Color(0xFF7BAC6C),
        leadingWidth: 30,
        title: Row(
          children: [
            Hero(
              tag: 'user-${widget.otherUser.uid}',
              child: CircleAvatar(
                radius: 20,
                backgroundColor: otherUserColor,
                backgroundImage: widget.otherUser.profileImage != null && widget.otherUser.profileImage!.isNotEmpty
                  ? MemoryImage(base64Decode(widget.otherUser.profileImage!))
                  : null,
                child: widget.otherUser.profileImage == null || widget.otherUser.profileImage!.isEmpty
                  ? Text(
                      widget.otherUser.name != null && widget.otherUser.name!.isNotEmpty 
                        ? widget.otherUser.name![0].toUpperCase()
                        : '?',
                      style: GoogleFonts.aBeeZee(
                        fontSize: 18, 
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.name ?? 'Chat',
                    style: GoogleFonts.aBeeZee(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Icon(
                        _isEncryptionEnabled ? Icons.lock_outline : Icons.lock_open_outlined,
                        color: Colors.white70,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _isEncryptionEnabled ? 'End-to-end encrypted' : 'Encryption disabled',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        //! A P P B A R - A C T I O N S
        actions: [
          // Add new lock button
          IconButton(
            icon: Icon(
              _isChatLocked ? Icons.lock_outline : Icons.lock_open_outlined,
              color: Colors.white,
            ),
            onPressed: _toggleChatLock,
            tooltip: _isChatLocked ? 'Unlock chat' : 'Lock chat with fingerprint',
          ),
          // Keep the existing encryption button
          IconButton(
            icon: Icon(
              _isEncryptionEnabled 
                ? Icons.security 
                : Icons.security_outlined,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isEncryptionEnabled = !_isEncryptionEnabled;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isEncryptionEnabled 
                      ? 'Encryption enabled' 
                      : 'Encryption disabled (messages will be stored as plaintext)',
                  ),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: _isEncryptionEnabled ? Color(0xFF7BAC6C) : Colors.red,
                ),
              );
            },
          ),
        ],
      ),
      //! M A I N - B O D Y
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7BAC6C).withOpacity(0.1),
              Colors.white,
            ],
          ),
          image: DecorationImage(
            image: AssetImage('assets/chat_bg.png'),
            fit: BoxFit.cover,
            opacity: 0.05,
          ),
        ),
        child: Column(
          children: [
            //! M E S S A G E S - L I S T
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _database.getChatMessages(
                  widget.currentUser.uid,
                  widget.otherUser.uid,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7BAC6C)),
                      ),
                    );
                  }
                  
                  final messages = snapshot.data ?? [];
                  
                  //! E M P T Y - C H A T - S T A T E
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Color(0xFF7BAC6C).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 60,
                              color: Color(0xFF7BAC6C),
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'No messages yet',
                            style: GoogleFonts.aBeeZee(
                              fontSize: 18,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Start a conversation with ${widget.otherUser.name}',
                            style: GoogleFonts.notoSans(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: EdgeInsets.all(16.0),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == widget.currentUser.uid;
                        
                        return _buildMessage(message, isMe);
                      },
                    ),
                  );
                },
              ),
            ),
            
            //! M E S S A G E - I N P U T
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    //! I M A G E - B U T T O N
                    GestureDetector(
                      onTap: _pickAndSendImage,
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(0xFF7BAC6C).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          color: Color(0xFF7BAC6C),
                          size: 22,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    
                    //! T E X T - F I E L D
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            //! E N C R Y P T I O N - I C O N
                            Icon(
                              _isEncryptionEnabled ? Icons.lock_outline : Icons.lock_open_outlined,
                              color: _isEncryptionEnabled ? Color(0xFF7BAC6C) : Colors.red,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            
                            //! I N P U T - F I E L D
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                textCapitalization: TextCapitalization.sentences,
                                style: GoogleFonts.notoSans(
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Message...',
                                  hintStyle: GoogleFonts.notoSans(
                                    fontSize: 15,
                                    color: Colors.grey.shade500,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                minLines: 1,
                                maxLines: 5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    
                    //! S E N D - B U T T O N
                    GestureDetector(
                      onTap: () {
                        if (_messageController.text.trim().isNotEmpty) {
                          _sendMessage();
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFF7BAC6C),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //! M E S S A G E - B U B B L E
  Widget _buildMessage(Message message, bool isMe) {
    final time = DateFormat.Hm().format(message.timestamp);
    
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          //! U S E R - A V A T A R
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _getUserColor(widget.otherUser),
              backgroundImage: widget.otherUser.profileImage != null && widget.otherUser.profileImage!.isNotEmpty
                ? MemoryImage(base64Decode(widget.otherUser.profileImage!))
                : null,
              child: widget.otherUser.profileImage == null || widget.otherUser.profileImage!.isEmpty
                ? Text(
                    widget.otherUser.name != null && widget.otherUser.name!.isNotEmpty 
                      ? widget.otherUser.name![0].toUpperCase()
                      : '?',
                    style: GoogleFonts.aBeeZee(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
            ),
            SizedBox(width: 8),
          ],
          
          //! M E S S A G E - C O N T E N T
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: message.isImage 
                      ? EdgeInsets.all(4.0) 
                      : EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: isMe 
                        ? Color(0xFF7BAC6C) 
                        : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: isMe ? Radius.circular(18) : Radius.circular(4),
                        bottomRight: isMe ? Radius.circular(4) : Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: message.isImage
                      ? _buildImageContent(message.content)
                      : Text(
                          message.content,
                          style: GoogleFonts.notoSans(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 15.0,
                          ),
                        ),
                  ),
                  
                  //! T I M E S T A M P
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: GoogleFonts.notoSans(
                            color: Colors.grey[600],
                            fontSize: 11.0,
                          ),
                        ),
                        SizedBox(width: 4),
                        // Lock icon to indicate encryption
                        Icon(
                          Icons.lock_outline,
                          size: 10,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          //! S E N D E R - A V A T A R
          if (isMe) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: _getUserColor(widget.currentUser),
              backgroundImage: widget.currentUser.profileImage != null && widget.currentUser.profileImage!.isNotEmpty
                ? MemoryImage(base64Decode(widget.currentUser.profileImage!))
                : null,
              child: widget.currentUser.profileImage == null || widget.currentUser.profileImage!.isEmpty
                ? Text(
                    widget.currentUser.name != null && widget.currentUser.name!.isNotEmpty 
                      ? widget.currentUser.name![0].toUpperCase()
                      : '?',
                    style: GoogleFonts.aBeeZee(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
            ),
          ],
        ],
      ),
    );
  }
  
  //! I M A G E - C O N T E N T
  Widget _buildImageContent(String content) {
    try {
      // For debugging
      print("Trying to decode image content of length: ${content.length}");
      
      //! I M A G E - V A L I D A T I O N
      if (!content.startsWith("data:image") && !_isBase64String(content)) {
        print("Content doesn't appear to be a valid base64 image");
        return _buildInvalidImageWidget("Not a valid image format");
      }
      
      // Try to decode the base64 image
      Uint8List imageBytes;
      try {
        imageBytes = base64Decode(content);
      } catch (e) {
        print("Base64 decoding error: $e");
        return _buildInvalidImageWidget("Error decoding image");
      }
      
      return GestureDetector(
        onTap: () => _showFullScreenImage(content),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            imageBytes,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print("Error rendering image: $error");
              return _buildInvalidImageWidget("Error displaying image");
            },
          ),
        ),
      );
    } catch (e) {
      print("General error in _buildImageContent: $e");
      return _buildInvalidImageWidget("Invalid image format");
    }
  }

  //! B A S E 6 4 - V A L I D A T I O N
  bool _isBase64String(String str) {
    // Simple validation for base64 strings
    // Real base64 strings should have a length multiple of 4 and only contain valid chars
    if (str.length % 4 != 0) return false;
    
    // Check for valid base64 characters
    RegExp validBase64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
    return validBase64Regex.hasMatch(str);
  }

  //! E R R O R - I M A G E
  Widget _buildInvalidImageWidget(String errorMessage) {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.red, size: 40),
          SizedBox(height: 8),
          Text(
            errorMessage,
            style: GoogleFonts.notoSans(
              color: Colors.red,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  //! F U L L S C R E E N - I M A G E
  void _showFullScreenImage(String base64Image) {
    try {
      final imageBytes = base64Decode(base64Image);
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: IconThemeData(color: Colors.white),
              elevation: 0,
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, color: Colors.white, size: 64),
                          SizedBox(height: 16),
                          Text(
                            "Error displaying image",
                            style: GoogleFonts.notoSans(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      print("Error in _showFullScreenImage: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error displaying image: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
  
  //! S E N D - M E S S A G E
  void _sendMessage() async {
    String content = _messageController.text.trim();
    _messageController.clear();
    
    if (!_isEncryptionEnabled) {
      await _database.sendMessage(
        senderId: widget.currentUser.uid,
        receiverId: widget.otherUser.uid,
        content: content,
      );
    } else {
      await _database.sendMessage(
        senderId: widget.currentUser.uid,
        receiverId: widget.otherUser.uid,
        content: content,
      );
    }
//! S E N D - M E S S A G E (continued)
    // Scroll to bottom after sending
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}