// File: lib/main.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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

  UserModel({required this.uid, this.name, this.email});
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
  
  // Create UserModel from Firebase User
  UserModel? _userFromFirebaseUser(User? user) {
    return user != null ? UserModel(uid: user.uid, email: user.email) : null;
  }
  
  // Auth state changes stream
  Stream<UserModel?> get user {
    return _auth.authStateChanges().map(_userFromFirebaseUser);
  }
  
  // Get all users
  Stream<List<UserModel>> get users {
    return firestore.collection('users')
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
  
  // Current user
  UserModel? get currentUser {
    return _userFromFirebaseUser(_auth.currentUser);
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
      print('Updating user data for ${user.uid}, name: ${user.name}, email: ${user.email}');
      await _firestore.collection('users').doc(user.uid).set({
        'name': user.name ?? '',
        'email': user.email ?? '',
        'lastActive': DateTime.now(),
      }, SetOptions(merge: true));
      print('Successfully updated user data for ${user.uid}');
    } catch (e) {
      print('Error updating user data: ${e.toString()}');
    }
  }
  
  // Get user by id
  Future<UserModel?> getUserById(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return UserModel(
          uid: doc.id,
          name: data['name'] ?? '',
          email: data['email'] ?? '',
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
        'latestMessage': content.length > 20 ? content.substring(0, 20) + '...' : content, // Show preview in unencrypted form
        'timestamp': DateTime.now(),
        'participants': [senderId, receiverId], // Ensure participants field exists
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('Encrypted message sent successfully to chat $chatId');
    } catch (e) {
      print('Error sending message: ${e.toString()}');
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
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return StreamBuilder<UserModel?>(
      stream: authService.user, // Use the user stream instead of users
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final UserModel? user = snapshot.data;
          
          // Update user data in Firestore when logged in
          if (user != null) {
            print('User authenticated: ${user.uid}');
            // Add a small delay to ensure Firebase is ready
            Future.delayed(Duration(milliseconds: 500), () {
              _database.updateUserData(user);
            });
            
            return Home();
          } else {
            return Authenticate();
          }
        } else {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
    );
  }
}

// File: lib/screens/auth/authenticate.dart
class Authenticate extends StatefulWidget {
  @override
  _AuthenticateState createState() => _AuthenticateState();
}

class _AuthenticateState extends State<Authenticate> {
  bool showSignIn = true;
  
  void toggleView() {
    setState(() => showSignIn = !showSignIn);
  }
  
  @override
  Widget build(BuildContext context) {
    if (showSignIn) {
      return Login(toggleView: toggleView);
    } else {
      return Register(toggleView: toggleView);
    }
  }
}

// File: lib/screens/auth/login.dart
class Login extends StatefulWidget {
  final Function toggleView;
  Login({required this.toggleView});

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  String error = '';
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign In'),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.person, color: Colors.white),
            label: Text('Register', style: TextStyle(color: Colors.white)),
            onPressed: () => widget.toggleView(),
          )
        ],
      ),
      body: Container(
        padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 50.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SizedBox(height: 20.0),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Email',
                  fillColor: Colors.white,
                  filled: true,
                ),
                validator: (val) => val!.isEmpty ? 'Enter an email' : null,
                onChanged: (val) {
                  setState(() => email = val);
                },
              ),
              SizedBox(height: 20.0),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Password',
                  fillColor: Colors.white,
                  filled: true,
                ),
                obscureText: true,
                validator: (val) => val!.length < 6 ? 'Password must be 6+ chars long' : null,
                onChanged: (val) {
                  setState(() => password = val);
                },
              ),
              SizedBox(height: 20.0),
              ElevatedButton(
                child: Text('Sign In'),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => loading = true);
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final result = await authService.signInWithEmailAndPassword(email, password);
                    if (result == null) {
                      setState(() {
                        error = 'Could not sign in with those credentials';
                        loading = false;
                      });
                    }
                  }
                },
              ),
              SizedBox(height: 12.0),
              Text(
                error,
                style: TextStyle(color: Colors.red, fontSize: 14.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// File: lib/screens/auth/register.dart
class Register extends StatefulWidget {
  final Function toggleView;
  Register({required this.toggleView});

  @override
  _RegisterState createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String email = '';
  String password = '';
  String error = '';
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register'),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.person, color: Colors.white),
            label: Text('Sign In', style: TextStyle(color: Colors.white)),
            onPressed: () => widget.toggleView(),
          )
        ],
      ),
      body: Container(
        padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 50.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SizedBox(height: 20.0),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Name',
                  fillColor: Colors.white,
                  filled: true,
                ),
                validator: (val) => val!.isEmpty ? 'Enter your name' : null,
                onChanged: (val) {
                  setState(() => name = val);
                },
              ),
              SizedBox(height: 20.0),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Email',
                  fillColor: Colors.white,
                  filled: true,
                ),
                validator: (val) => val!.isEmpty ? 'Enter an email' : null,
                onChanged: (val) {
                  setState(() => email = val);
                },
              ),
              SizedBox(height: 20.0),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Password',
                  fillColor: Colors.white,
                  filled: true,
                ),
                obscureText: true,
                validator: (val) => val!.length < 6 ? 'Password must be 6+ chars long' : null,
                onChanged: (val) {
                  setState(() => password = val);
                },
              ),
              SizedBox(height: 20.0),
              ElevatedButton(
                child: Text('Register'),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => loading = true);
                    
                    // Register with Firebase Auth
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final result = await authService.registerWithEmailAndPassword(email, password);
                    
                    if (result != null) {
                      // Create user in Firestore
                      final database = DatabaseService();
                      await database.updateUserData(
                        UserModel(uid: result.uid, name: name, email: email)
                      );
                    } else {
                      setState(() {
                        error = 'Please supply a valid email';
                        loading = false;
                      });
                    }
                  }
                },
              ),
              SizedBox(height: 12.0),
              Text(
                error,
                style: TextStyle(color: Colors.red, fontSize: 14.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// File: lib/screens/home/home.dart
class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final DatabaseService _database = DatabaseService();
  
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
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return StreamProvider<List<UserModel>>.value(
      initialData: [],
      value: _database.users,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Chat App'),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.person, color: Colors.white),
              label: Text('Logout', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                await authService.signOut();
              },
            )
          ],
        ),
        body: UserList(),
      ),
    );
  }
}

// File: lib/screens/home/user_list.dart
class UserList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final users = Provider.of<List<UserModel>>(context);
    final currentUser = Provider.of<AuthService>(context).currentUser;
    
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No users found',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              'Start by inviting friends to join the app',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            // Create a dummy user for testing
            ElevatedButton(
              child: Text('Create Test User'),
              onPressed: () {
                // This is just for testing - remove in production
                final DatabaseService database = DatabaseService();
                database.updateUserData(
                  UserModel(
                    uid: 'test-user-${DateTime.now().millisecondsSinceEpoch}',
                    name: 'Test User',
                    email: 'test@example.com',
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
    
    // Filter out current user
    final filteredUsers = users.where((user) => user.uid != currentUser?.uid).toList();
    
    if (filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No other users found',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              'Start by inviting friends to join the app',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        
        return Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Card(
            margin: EdgeInsets.fromLTRB(20.0, 6.0, 20.0, 0.0),
            child: ListTile(
              leading: CircleAvatar(
                radius: 25.0,
                backgroundColor: Colors.blue[100],
                child: Text(
                  user.name != null && user.name!.isNotEmpty 
                    ? user.name![0].toUpperCase()
                    : '?',
                  style: TextStyle(fontSize: 20.0),
                ),
              ),
              title: Text(user.name ?? 'Anonymous'),
              subtitle: Text(user.email ?? ''),
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
          ),
        );
      },
    );
  }
}

// File: lib/screens/home/chat_screen.dart
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
  bool _isEncryptionEnabled = true;

  @override
  Widget build(BuildContext context) {
    // Get chat ID
    String chatId = widget.currentUser.uid.compareTo(widget.otherUser.uid) < 0 
      ? '${widget.currentUser.uid}-${widget.otherUser.uid}' 
      : '${widget.otherUser.uid}-${widget.currentUser.uid}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUser.name ?? 'Chat'),
        actions: [
          // Encryption status indicator
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
              
              // Show toast
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
      body: Column(
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
                  return Center(child: Text('No messages yet'));
                }
                
                return ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.all(10.0),
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
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            height: 70.0,
            color: Colors.white,
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
                      hintText: 'Send a message...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                
                // Send button
                IconButton(
                  icon: Icon(Icons.send),
                  color: Colors.blue,
                  onPressed: () {
                    if (_messageController.text.trim().isNotEmpty) {
                      _sendMessage();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Message message, bool isMe) {
    final time = DateFormat.Hm().format(message.timestamp);
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) _buildAvatar(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue : Colors.grey[300],
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black,
                    fontSize: 16.0,
                  ),
                ),
                SizedBox(height: 5.0),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.black54,
                        fontSize: 12.0,
                      ),
                    ),
                    SizedBox(width: 5),
                    // Small lock icon to indicate encryption
                    Icon(
                      Icons.lock_outline,
                      size: 10,
                      color: isMe ? Colors.white70 : Colors.black54,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isMe) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: CircleAvatar(
        backgroundColor: Colors.transparent,
      ),
    );
  }

  void _sendMessage() async {
    String content = _messageController.text.trim();
    
    // Get chat ID
    String chatId = widget.currentUser.uid.compareTo(widget.otherUser.uid) < 0 
      ? '${widget.currentUser.uid}-${widget.otherUser.uid}' 
      : '${widget.otherUser.uid}-${widget.currentUser.uid}';
      
    // Clear the input field first for better UX
    _messageController.clear();
    
    // If sending a special key exchange message (for demo purposes)
    if (content.startsWith("/key ")) {
      // Generate and send a key exchange message
      String keyMessage = await EncryptionService.generateKeyExchangeMessage(chatId);
      await _database.sendMessage(
        senderId: widget.currentUser.uid,
        receiverId: widget.otherUser.uid,
        content: keyMessage,
      );
      return;
    }
    
    // Use the encryption setting from the UI
    if (!_isEncryptionEnabled) {
      // Send plaintext message (without encryption)
      await _database.sendMessage(
        senderId: widget.currentUser.uid,
        receiverId: widget.otherUser.uid,
        content: content,
      );
    } else {
      // Send encrypted message
      await _database.sendMessage(
        senderId: widget.currentUser.uid,
        receiverId: widget.otherUser.uid,
        content: content,
      );
    }
  }
}