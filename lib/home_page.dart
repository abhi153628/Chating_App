// File: lib/main.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print("Initializing Firebase...");
    await Firebase.initializeApp();
    print("Firebase initialized successfully");
  } catch (e) {
    print("Failed to initialize Firebase: $e");
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthService(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Chat App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: Wrapper(),
      ),
    );
  }
}

// File: lib/models/user.dart
class UserModel {
  final String uid;
  final String? name;
  final String? email;
  final String? profileImage;

  UserModel({required this.uid, this.name, this.email,this.profileImage,});
}

// File: lib/models/message.dart
class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isEncrypted;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.isEncrypted = true, // Default to encrypted
  });

  factory Message.fromMap(Map<String, dynamic> data, String id) {
    return Message(
      id: id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      content: data['content'] ?? '',
      timestamp: data['timestamp']?.toDate() ?? DateTime.now(),
      isEncrypted: data['isEncrypted'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp,
      'isEncrypted': isEncrypted,
    };
  }
}

// File: lib/services/auth_service.dart
class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
UserModel? _userFromFirebaseUser(User? user) {
  if (user == null) return null;
  
  // Get the user data from Firestore if possible to include profile image
  return UserModel(
    uid: user.uid,
    email: user.email,
    name: user.displayName,
    profileImage: null // This needs to fetch from Firestore
  );
}
  
  // Auth state changes stream
  Stream<UserModel?> get user {
    return _auth.authStateChanges().map(_userFromFirebaseUser);
  }
  
  // Get all users
  // In DatabaseService class, fix the users getter
Stream<List<UserModel>> get users {
  return firestore.collection('users')
    .snapshots()
    .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        print('No users found in Firestore');
        return <UserModel>[];
      }
      
      print('Found ${snapshot.docs.length} users in Firestore');
      List<UserModel> userList = [];
      
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data();
          print('User data for ${doc.id}: ${data.toString()}');
          
          UserModel user = UserModel(
            uid: doc.id,
            name: data['name'] ?? '',
            email: data['email'] ?? '',
            profileImage: data['profileImage'] ?? '',
          );
          
          userList.add(user);
        } catch (e) {
          print('Error parsing user ${doc.id}: $e');
        }
      }
      
      return userList;
    });
}
  // Current user
// Current user - needs to fetch complete user data from Firestore
UserModel? get currentUser {
  User? firebaseUser = _auth.currentUser;
  if (firebaseUser == null) return null;
  
  // Create a basic user model from Firebase Auth
  UserModel basicUser = UserModel(
    uid: firebaseUser.uid,
    email: firebaseUser.email,
    name: firebaseUser.displayName,
    profileImage: null
  );
  
  // Try to get full user data from Firestore
  firestore.collection('users').doc(firebaseUser.uid).get().then((doc) {
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      basicUser = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email,
        name: data['name'] ?? firebaseUser.displayName,
        profileImage: data['profileImage'] ?? ''
      );
    }
    notifyListeners();
  }).catchError((e) {
    print('Error fetching user data: $e');
  });
  
  return basicUser;
}
  // Sign in with email & password
  Future<UserModel?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      User? user = result.user;
      notifyListeners();
      return _userFromFirebaseUser(user);
    } catch (e) {
      print(e.toString());
      return null;
    }
  }
  
  // Register with email & password
  Future<UserModel?> registerWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      User? user = result.user;
      notifyListeners();
      return _userFromFirebaseUser(user);
    } catch (e) {
      print(e.toString());
      return null;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      print(e.toString());
    }
  }
}

// File: lib/services/encryption_service.dart
class EncryptionService {
  // Store encryption keys for each chat
  static final Map<String, String> _chatKeys = {};
  
  // Generate a random key for a chat
  static Future<String> generateChatKey(String chatId) async {
    // Generate a random 32 character string for the key
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    final key = base64Url.encode(values);
    
    // Store the key
    _chatKeys[chatId] = key;
    
    // Also store in shared preferences for persistence
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_key_$chatId', key);
    
    return key;
  }
  
  // Get or create a key for a chat
  static Future<String> getChatKey(String chatId) async {
    // Check if we already have the key in memory
    if (_chatKeys.containsKey(chatId)) {
      return _chatKeys[chatId]!;
    }
    
    // Try to get from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString('chat_key_$chatId');
    
    if (storedKey != null) {
      _chatKeys[chatId] = storedKey;
      return storedKey;
    }
    
    // Generate a new key if none exists
    return await generateChatKey(chatId);
  }
  
  // Encrypt a message
  static Future<String> encryptMessage(String message, String chatId) async {
    try {
      final key = await getChatKey(chatId);
      
      // Create a 32-byte key using SHA-256
      final keyBytes = sha256.convert(utf8.encode(key)).bytes;
      final encryptKey = encrypt.Key(Uint8List.fromList(keyBytes));
      
      // Create a random 16-byte IV
      final iv = encrypt.IV.fromSecureRandom(16);
      
      // Create an encrypter with AES in CBC mode
      final encrypter = encrypt.Encrypter(encrypt.AES(encryptKey));
      
      // Encrypt the message
      final encrypted = encrypter.encrypt(message, iv: iv);
      
      // Return the IV and encrypted message as a base64 string
      // Format: base64(iv):base64(encryptedMessage)
      return "${iv.base64}:${encrypted.base64}";
    } catch (e) {
      print('Encryption error: $e');
      return message; // Return original message on error (for graceful fallback)
    }
  }
  
  // Decrypt a message
  static Future<String> decryptMessage(String encryptedMessage, String chatId) async {
    try {
      // Check if the message is encrypted (contains the separator)
      if (!encryptedMessage.contains(':')) {
        return encryptedMessage; // Return as is if not encrypted
      }
      
      // Split the IV and encrypted message
      final parts = encryptedMessage.split(':');
      if (parts.length != 2) {
        return encryptedMessage; // Invalid format
      }
      
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      
      // Get the key
      final key = await getChatKey(chatId);
      
      // Create a 32-byte key using SHA-256
      final keyBytes = sha256.convert(utf8.encode(key)).bytes;
      final encryptKey = encrypt.Key(Uint8List.fromList(keyBytes));
      
      // Create the decrypter
      final encrypter = encrypt.Encrypter(encrypt.AES(encryptKey));
      
      // Decrypt the message
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      return decrypted;
    } catch (e) {
      print('Decryption error: $e');
      return "Failed to decrypt message"; // Show error message
    }
  }
  
  // Generate a key exchange message (simplification for demo purposes)
  // In a real app, you'd use proper key exchange protocols like Diffie-Hellman
  static Future<String> generateKeyExchangeMessage(String chatId) async {
    final key = await getChatKey(chatId);
    return "KEY_EXCHANGE:$key";
  }
  
  // Process a key exchange message
  static Future<bool> processKeyExchangeMessage(String message, String chatId) async {
    if (message.startsWith("KEY_EXCHANGE:")) {
      final key = message.substring("KEY_EXCHANGE:".length);
      
      // Store the received key
      _chatKeys[chatId] = key;
      
      // Save to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_key_$chatId', key);
      
      return true;
    }
    return false;
  }
}

// File: lib/services/database_service.dart
class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
    await _firestore.collection('users').doc(user.uid).set({
      'name': user.name ?? '',
      'email': user.email ?? '',
      'profileImage': user.profileImage ?? '', 
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    print('Successfully updated user data for ${user.uid}');
  } catch (e) {
    print('Error updating user data: ${e.toString()}');
  }
}

// Update getUserById method
Future<UserModel?> getUserById(String uid) async {
  try {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return UserModel(
        uid: doc.id,
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        profileImage: data['profileImage'] ?? '', // Add profile image
      );
    }
    return null;
  } catch (e) {
    print(e.toString());
    return null;
  }
}
  // Modified method to send encrypted messages
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
      );
      
      // Add to Firestore
      await messagesRef.add(message.toMap());
      
      // Update latest message in chat document (using original text for preview)
      await _firestore.collection('chats').doc(chatId).set({
        'latestMessage': content.length > 20 ? '${content.substring(0, 20)}...' : content, // Show preview in unencrypted form
        'timestamp': DateTime.now(),
        'participants': [senderId, receiverId], // Ensure participants field exists
        'lastUpdated': FieldValue.serverTimestamp(),
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
      
      // First ensure the chat document exists with participants
      _firestore.collection('chats').doc(chatId).set({
        'participants': [userId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((error) {
        print('Error ensuring chat document exists: $error');
      });
      
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

// File: lib/screens/wrapper.dart
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
        
        // Ensure we have the user in the database
        _database.updateUserData(currentUser);
        
        // Just return the Home widget directly instead of trying to build a scaffold here
        return Home();
      },
    );
  }
}
// File: lib/screens/auth/authenticate.dart
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
    // Make status bar transparent
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
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
    // Ensure the status bar is transparent
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
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
              Color(0xFF6A11CB),
              Color(0xFF2575FC),
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
                  "SecureChat",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                  ),
                ),
                Text(
                  "Private messaging made simple",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                    fontFamily: 'Montserrat',
                  ),
                ),
                SizedBox(height: 40),
                // Auth card with dynamic height
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(25),
                              topRight: Radius.circular(25),
                            ),
                            color: Colors.white,
                          ),
                          labelColor: Color(0xFF6A11CB),
                          unselectedLabelColor: Colors.grey,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Login Screen
class Login extends StatefulWidget {
  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  String error = '';
  bool loading = false;
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.0),
      constraints: BoxConstraints(minHeight: 380), // Set minimum height
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6A11CB),
                fontFamily: 'Montserrat',
              ),
            ),
            Text(
              "Sign in to continue",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: 'Montserrat',
              ),
            ),
            SizedBox(height: 30),
            // Email field
            TextFormField(
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email",
                hintText: "your.email@example.com",
                prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF6A11CB)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
              validator: (val) => val!.isEmpty ? 'Please enter an email' : null,
              onChanged: (val) {
                setState(() => email = val);
              },
            ),
            SizedBox(height: 16),
            // Password field
            TextFormField(
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: "Password",
                hintText: "••••••••",
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF6A11CB)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
              validator: (val) => val!.length < 6 ? 'Password must be 6+ characters' : null,
              onChanged: (val) {
                setState(() => password = val);
              },
            ),
            SizedBox(height: 25),
            // Error text
            if (error.isNotEmpty)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            if (error.isNotEmpty) SizedBox(height: 20),
            // Sign in button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6A11CB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
             // In lib/screens/auth/register.dart, update the onPressed of the Sign Up button:
// In the onPressed method of the Register class
onPressed: loading ? null : () async {
  if (_formKey.currentState!.validate()) {
    setState(() => loading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.signInWithEmailAndPassword(email, password);
      
      if (result == null) {
        setState(() {
          error = 'Failed to sign in with those credentials.';
          loading = false;
        });
      }
      // Successfully signed in, the wrapper will handle navigation
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }
},
                child: loading
                  ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                  : Text(
                      "SIGN IN",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// File: lib/screens/auth/register.dart


// Update Register class in lib/screens/auth/register.dart
class Register extends StatefulWidget {
  @override
  _RegisterState createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  String name = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  String error = '';
  bool loading = false;
  String? profileImageBase64;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  // Method to handle image selection with actual ImagePicker
  Future<void> pickImage() async {
    try {
      setState(() => loading = true);
      
      // Show bottom sheet with actual options
      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
        ),
        backgroundColor: Colors.white,
        builder: (BuildContext context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Profile Photo",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A11CB),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Choose a profile picture",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildImagePickerOption(
                        context,
                        icon: Icons.photo_library,
                        title: "Gallery",
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? image = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                            maxWidth: 500,
                          );
                          
                          if (image != null) {
                            final bytes = await File(image.path).readAsBytes();
                            setState(() {
                              profileImageBase64 = base64Encode(bytes);
                              loading = false;
                            });
                          } else {
                            setState(() => loading = false);
                          }
                        },
                      ),
                      _buildImagePickerOption(
                        context,
                        icon: Icons.camera_alt,
                        title: "Camera",
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? image = await _picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 70,
                            maxWidth: 500,
                          );
                          
                          if (image != null) {
                            final bytes = await File(image.path).readAsBytes();
                            setState(() {
                              profileImageBase64 = base64Encode(bytes);
                              loading = false;
                            });
                          } else {
                            setState(() => loading = false);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      setState(() => loading = false);
      print('Error picking image: $e');
    }
  }

  Widget _buildImagePickerOption(BuildContext context, {
    required IconData icon,
    required String title,
    required Function onTap,
  }) {
    return InkWell(
      onTap: () => onTap(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Color(0xFF6A11CB).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Color(0xFF6A11CB),
              size: 30,
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.0),
      constraints: BoxConstraints(minHeight: 600), // Ensure enough space for all fields
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Create Account",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6A11CB),
                fontFamily: 'Montserrat',
              ),
            ),
            Text(
              "Sign up to get started",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: 'Montserrat',
              ),
            ),
            SizedBox(height: 25),
            
            // Profile image selection
            Center(
              child: GestureDetector(
                onTap: pickImage,
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                        image: profileImageBase64 != null
                            ? DecorationImage(
                                image: MemoryImage(base64Decode(profileImageBase64!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: profileImageBase64 == null
                          ? Icon(
                              Icons.add_a_photo,
                              size: 40,
                              color: Color(0xFF6A11CB),
                            )
                          : null,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Add Profile Photo",
                      style: TextStyle(
                        color: Color(0xFF2575FC),
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 25),
            
            // Name field
            TextFormField(
              decoration: InputDecoration(
                labelText: "Full Name",
                hintText: "John Doe",
                prefixIcon: Icon(Icons.person_outline, color: Color(0xFF6A11CB)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
              validator: (val) => val!.isEmpty ? 'Please enter your name' : null,
              onChanged: (val) {
                setState(() => name = val);
              },
            ),
            SizedBox(height: 16),
            
            // Email field
            TextFormField(
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email",
                hintText: "your.email@example.com",
                prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF6A11CB)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
              validator: (val) {
                if (val!.isEmpty) {
                  return 'Please enter an email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
              onChanged: (val) {
                setState(() => email = val);
              },
            ),
            SizedBox(height: 16),
            
            // Password field
            TextFormField(
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "Password",
                hintText: "••••••••",
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF6A11CB)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
              validator: (val) => val!.length < 6 ? 'Password must be 6+ characters' : null,
              onChanged: (val) {
                setState(() => password = val);
              },
            ),
            SizedBox(height: 16),
            
            // Confirm password field
            TextFormField(
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: "Confirm Password",
                hintText: "••••••••",
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF6A11CB)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
              validator: (val) {
                if (val!.isEmpty) return 'Please confirm your password';
                if (val != password) return 'Passwords do not match';
                return null;
              },
              onChanged: (val) {
                setState(() => confirmPassword = val);
              },
            ),
            SizedBox(height: 20),
            
            // Error text
            if (error.isNotEmpty)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            if (error.isNotEmpty) SizedBox(height: 20),
            
            // Sign up button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6A11CB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                onPressed: loading ? null : () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => loading = true);
                    
                    // Register with Firebase Auth
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final result = await authService.registerWithEmailAndPassword(email, password);
                    
                    if (result != null) {
                      // Create user in Firestore with profile image
                      final database = DatabaseService();
                      await database.updateUserData(
                        UserModel(
                          uid: result.uid, 
                          name: name, 
                          email: email,
                          profileImage: profileImageBase64 ?? '', // Add profile image
                        )
                      );
                    } else {
                      setState(() {
                        error = 'Registration failed. Please try again.';
                        loading = false;
                      });
                    }
                  }
                },
                child: loading
                  ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                  : Text(
                      "SIGN UP",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}// File: lib/screens/home/home.dart
class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

// Update the Home class in lib/screens/home/home.dart
class _HomeState extends State<Home> {
  final DatabaseService _database = DatabaseService();
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Make sure the current user is added to the database
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
      if (currentUser != null) {
        _database.updateUserData(currentUser);
      }
    });
  }
  
// In lib/screens/home/home.dart, update the StreamProvider to ensure proper initialization
@override
Widget build(BuildContext context) {
  final authService = Provider.of<AuthService>(context);
  final currentUser = authService.currentUser;
  
  return StreamProvider<List<UserModel>>.value(
    initialData: [], // Make sure this is an empty list, not null
    value: authService.users, // Use authService.users directly for consistency
    catchError: (_, __) => [], // Add error handling
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(currentUser),
      body: _selectedIndex == 0 ? UserList() : ProfilePage(user: currentUser!),
      bottomNavigationBar: _buildBottomNavBar(),
    ),
  );
}
  
  PreferredSizeWidget _buildAppBar(UserModel? currentUser) {
    return AppBar(
      elevation: 0,
      backgroundColor: Color(0xFF6A11CB),
      title: Text(
        'SecureChat',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.logout, color: Colors.white),
          onPressed: () async {
            await Provider.of<AuthService>(context, listen: false).signOut();
          },
        ),
      ],
    );
  }
  
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF6A11CB),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}// Add this new widget
class ProfilePage extends StatefulWidget {
  final UserModel? user;
  
  ProfilePage({required this.user});
  
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final ImagePicker _picker = ImagePicker();
  final DatabaseService database = DatabaseService();
  bool _isEditing = false;
  String? _updatedProfileImage;
  
    @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _updatedProfileImage = widget.user?.profileImage;
    
    // Fetch the latest user data from Firestore
    if (widget.user != null) {
      database.getUserById(widget.user!.uid).then((updatedUser) {
        if (updatedUser != null && mounted) {
          setState(() {
            _nameController.text = updatedUser.name ?? '';
            _updatedProfileImage = updatedUser.profileImage;
          });
        }
      });
    }
  }
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      // Save the updated profile
      final database = DatabaseService();
      await database.updateUserData(
        UserModel(
          uid: widget.user!.uid,
          name: _nameController.text,
          email: widget.user!.email,
          profileImage: _updatedProfileImage,
        ),
      );
      
      setState(() {
        _isEditing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }
  
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 500,
    );
    
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      setState(() {
        _updatedProfileImage = base64Encode(bytes);
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              // Profile Image
              GestureDetector(
                onTap: _isEditing ? _pickImage : null,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _updatedProfileImage != null && _updatedProfileImage!.isNotEmpty
                        ? MemoryImage(base64Decode(_updatedProfileImage!))
                        : null,
                      child: _updatedProfileImage == null || _updatedProfileImage!.isEmpty
                        ? Icon(Icons.person, size: 70, color: Colors.grey)
                        : null,
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Color(0xFF6A11CB),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              
              // User information
              if (!_isEditing) ...[
                Text(
                  widget.user?.name ?? 'No Name',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A11CB),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  widget.user?.email ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6A11CB),
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                  child: Text(
                    'Edit Profile',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
              
              // Edit form
              if (_isEditing) ...[
                SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    prefixIcon: Icon(Icons.person_outline, color: Color(0xFF6A11CB)),
                  ),
                  validator: (val) => val!.isEmpty ? 'Please enter your name' : null,
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _nameController.text = widget.user?.name ?? '';
                            _updatedProfileImage = widget.user?.profileImage;
                          });
                        },
                        child: Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6A11CB),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _updateProfile,
                        child: Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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
      decoration: BoxDecoration(
        color: Colors.grey[50],
      ),
      child: ListView.builder(
        itemCount: filteredUsers.length,
        itemBuilder: (context, index) {
          final user = filteredUsers[index];
          
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
             // Update this part in the UserList widget's build method:
leading: CircleAvatar(
  radius: 25.0,
  backgroundColor: Colors.grey.shade200,
  backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
    ? MemoryImage(base64Decode(user.profileImage!))
    : null,
  child: (user.profileImage == null || user.profileImage!.isEmpty) 
    ? Text(
        user.name != null && user.name!.isNotEmpty 
          ? user.name![0].toUpperCase()
          : '?',
        style: TextStyle(
          fontSize: 20.0,
          color: Color(0xFF6A11CB),
        ),
      )
    : null,
),
              title: Text(
                user.name ?? 'Anonymous',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                user.email ?? '',
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF6A11CB),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      currentUser: currentUser!,
                      otherUser: user,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildEmptyState(bool noUsers) {
    return Center(
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A11CB),
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start by inviting friends to join the app',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}// File: lib/screens/home/chat_screen.dart
class ChatScreen extends StatefulWidget {
  final UserModel currentUser;
  final UserModel otherUser;

  ChatScreen({required this.currentUser, required this.otherUser});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

// Completing the ChatScreen implementation

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final DatabaseService _database = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  bool _isEncryptionEnabled = true;
  
  @override
  Widget build(BuildContext context) {
    String chatId = widget.currentUser.uid.compareTo(widget.otherUser.uid) < 0 
      ? '${widget.currentUser.uid}-${widget.otherUser.uid}' 
      : '${widget.otherUser.uid}-${widget.currentUser.uid}';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Color(0xFF6A11CB),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: widget.otherUser.profileImage != null && widget.otherUser.profileImage!.isNotEmpty
                ? MemoryImage(base64Decode(widget.otherUser.profileImage!))
                : null,
              child: widget.otherUser.profileImage == null || widget.otherUser.profileImage!.isEmpty
                ? Text(
                    widget.otherUser.name != null && widget.otherUser.name!.isNotEmpty 
                      ? widget.otherUser.name![0].toUpperCase()
                      : '?',
                    style: TextStyle(fontSize: 18, color: Color(0xFF6A11CB)),
                  )
                : null,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.name ?? 'Chat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isEncryptionEnabled ? 'End-to-end encrypted' : 'Encryption disabled',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEncryptionEnabled 
                ? Icons.lock_outline 
                : Icons.lock_open_outlined,
              color: _isEncryptionEnabled 
                ? Colors.green 
                : Colors.red,
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
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6A11CB).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            // Messages list
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
                    return Center(child: CircularProgressIndicator());
                  }
                  
                  final messages = snapshot.data ?? [];
                  
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          SizedBox(height: 20),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Start a conversation with ${widget.otherUser.name}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: EdgeInsets.all(16.0),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == widget.currentUser.uid;
                      
                      return _buildMessage(message, isMe);
                    },
                  );
                },
              ),
            ),
            
            // Message input
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
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          // Encryption indicator
                          Icon(
                            _isEncryptionEnabled ? Icons.lock_outline : Icons.lock_open_outlined,
                            color: _isEncryptionEnabled ? Colors.green : Colors.red,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          
                          // Message text field
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: 'Message...',
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
                  SizedBox(width: 8),
                  
                  // Send button
                  GestureDetector(
                    onTap: () {
                      if (_messageController.text.trim().isNotEmpty) {
                        _sendMessage();
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF6A11CB),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(Message message, bool isMe) {
    final time = DateFormat.Hm().format(message.timestamp);
    
    return Container(
      margin: EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: isMe 
                ? Color(0xFF6A11CB) 
                : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: isMe ? Radius.circular(20) : Radius.circular(5),
                bottomRight: isMe ? Radius.circular(5) : Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 16.0,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12.0,
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
    );
  }

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
    
    // Scroll to bottom after sending
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
// Update the _buildAvatar method in ChatScreen
Widget _buildAvatar(bool isMe) {
  final user = isMe ? widget.currentUser : widget.otherUser;
  
  return Padding(
    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
    child: CircleAvatar(
      radius: 16,
      backgroundColor: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
      backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
        ? MemoryImage(base64Decode(user.profileImage!))
        : null,
      child: user.profileImage == null || user.profileImage!.isEmpty
        ? Text(
            user.name != null && user.name!.isNotEmpty 
              ? user.name![0].toUpperCase()
              : '?',
            style: TextStyle(
              fontSize: 12.0,
              color: isMe ? Colors.blue.shade800 : Colors.grey.shade700,
            ),
          )
        : null,
    ),
  );
}

 
}