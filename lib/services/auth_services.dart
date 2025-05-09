
import 'package:chating_app/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
UserModel? _userFromFirebaseUser(User? user) {
  if (user == null) return null;
  
  // Get a basic user model from Firebase Auth
  // We'll fetch Firestore data separately for complete user details
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
          
          // Support both field name variations
          String? name = data['name'] ?? data['displayName'] ?? '';
          String? profileImage = data['profileImage'] ?? data['photoUrl'] ?? '';
          
          UserModel user = UserModel(
            uid: doc.id,
            name: name,
            email: data['email'] ?? '',
            profileImage: profileImage,
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
// In AuthService class, modify the currentUser getter:
UserModel? get currentUser {
  User? firebaseUser = _auth.currentUser;
  if (firebaseUser == null) return null;
  
  // Create and return a basic user model from Firebase Auth without triggering Firestore fetch in the getter
  return UserModel(
    uid: firebaseUser.uid,
    email: firebaseUser.email,
    name: firebaseUser.displayName,
    profileImage: null
  );
}

// Add a new method to fetch complete user data
Future<UserModel?> fetchCompleteUserData() async {
  User? firebaseUser = _auth.currentUser;
  if (firebaseUser == null) return null;
  
  try {
    DocumentSnapshot doc = await firestore.collection('users').doc(firebaseUser.uid).get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      // Support both profileImage and photoUrl fields
      String? profileImage = data['profileImage'] ?? data['photoUrl'] ?? '';
      
      UserModel user = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email,
        name: data['name'] ?? data['displayName'] ?? firebaseUser.displayName,
        profileImage: profileImage
      );
      
      return user;
    }
  } catch (e) {
    print('Error fetching user data: $e');
  }
  
  // Return basic user if Firestore fetch fails
  return UserModel(
    uid: firebaseUser.uid,
    email: firebaseUser.email,
    name: firebaseUser.displayName,
    profileImage: null
  );
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
