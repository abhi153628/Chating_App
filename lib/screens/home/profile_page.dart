// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chating_app/models/user.dart';
import 'package:chating_app/services/database_service.dart';
import 'package:chating_app/services/storage_service.dart';
import 'package:chating_app/utils/biometric_services.dart';
import 'package:chating_app/services/auth_services.dart';
import 'package:provider/provider.dart'; // Import auth service for logout

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
  bool _isAppLockEnabled = false;
  bool _isBiometricAvailable = false;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  // Add a local user model to track changes
  late UserModel _currentUser;
  
  @override
  void initState() {
    super.initState();
    // Initialize local user model with the provided user data
    _currentUser = UserModel(
      uid: widget.user?.uid ?? '',
      name: widget.user?.name ?? '',
      email: widget.user?.email ?? '',
      profileImage: widget.user?.profileImage,
    );
    
    _nameController = TextEditingController(text: _currentUser.name);
    _updatedProfileImage = _currentUser.profileImage;
    
    // Fetch the latest user data from Firestore
    if (widget.user != null) {
      database.getUserById(widget.user!.uid).then((updatedUser) {
        if (updatedUser != null && mounted) {
          setState(() {
            _currentUser = updatedUser;
            _nameController.text = updatedUser.name ?? '';
            _updatedProfileImage = updatedUser.profileImage;
          });
        }
      });
    }
    
    _checkAppLockStatus();
    _checkBiometricAvailability();
  }
  
  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      // First create an updated user model
      final updatedUser = UserModel(
        uid: _currentUser.uid,
        name: _nameController.text,
        email: _currentUser.email,
        profileImage: _updatedProfileImage,
      );
      
      // Show loading indicator
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
        // Save the updated profile to database
        await database.updateUserData(updatedUser);
        
        // Update local state with the new user data
        setState(() {
          _currentUser = updatedUser;
          _isEditing = false;
        });
        
        // Close loading dialog
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Color(0xFF7BAC6C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } catch (e) {
        // Close loading dialog
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
  
  Future<void> _pickImage() async {
    try {
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  // Check if app lock is enabled
  Future<void> _checkAppLockStatus() async {
    final isEnabled = await StorageService.isAppLockEnabled();
    if (mounted) {
      setState(() {
        _isAppLockEnabled = isEnabled;
      });
    }
  }
  
  // Check if biometric authentication is available
  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await BiometricService.isBiometricAvailable();
    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable;
      });
    }
  }
  
  // Toggle app lock
  Future<void> _toggleAppLock(bool newValue) async {
    // If trying to enable app lock, check biometric availability first
    if (newValue && !_isBiometricAvailable) {
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
    
    // If enabling, verify biometric first
    if (newValue) {
      final authenticated = await BiometricService.authenticateWithBiometrics(
        reason: 'Verify your identity to enable app lock', navigatorKey: null,
      );
      
      if (!authenticated) {
        return; // Do not enable if authentication failed
      }
    }
    
    // Save the new app lock status
    await StorageService.setAppLockEnabled(newValue);
    
    if (mounted) {
      setState(() {
        _isAppLockEnabled = newValue;
      });
      
      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newValue 
            ? 'App lock enabled. App will require fingerprint authentication.' 
            : 'App lock disabled'),
          backgroundColor: Color(0xFF7BAC6C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
  
  // Add new method to show logout confirmation
  Future<void> _showLogoutConfirmation() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF7BAC6C).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(15),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Color(0xFF7BAC6C),
                    size: 30,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Log Out',
                  style: GoogleFonts.aBeeZee(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  'Are you sure you want to log out of your account?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                        },
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF7BAC6C),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop(); // Close dialog
                          
                          // Show loading indicator
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
                            // Get the auth service and sign out
                            final authService = Provider.of<AuthService>(context, listen: false);
                            await authService.signOut();
                            
                            // Close loading dialog
                            Navigator.of(context).pop();
                            
                            // Navigator will handle redirecting to login screen
                          } catch (e) {
                            // Close loading dialog
                            Navigator.of(context).pop();
                            
                            // Show error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to log out: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Log Out',
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Get a color based on user's name first letter
  Color _getUserColor() {
    if (_currentUser.name == null || _currentUser.name!.isEmpty) {
      return Color(0xFF7BAC6C);
    }
    
    final firstLetter = _currentUser.name![0].toUpperCase();
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
  
  // Method to build the app security section
  Widget _buildSecuritySection() {
    return Container(
      margin: EdgeInsets.only(top: 30, bottom: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_rounded,
                color: Color(0xFF7BAC6C),
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                "Security",
                style: GoogleFonts.aBeeZee(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
          SizedBox(height: 20),
          
          // App Lock Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "App Lock",
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Require fingerprint authentication to open the app",
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isAppLockEnabled,
                onChanged: _toggleAppLock,
                activeColor: Color(0xFF7BAC6C),
              ),
            ],
          ),
          
          // Show warning if biometrics not available
          if (!_isBiometricAvailable) ...[
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Biometric authentication is not available on this device",
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final userColor = _getUserColor();
    
    return Scaffold(
      body: Container(
        color: Color(0xFF7BAC6C),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 60, 18, 30),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Profile",
                  style: GoogleFonts.aBeeZee(
                    fontSize: 33,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            
            // Content Section
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 30),
                        
                        // Profile Image
                        GestureDetector(
                          onTap: _isEditing ? _pickImage : null,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Hero(
                                tag: 'profile-${_currentUser.uid}',
                                child: Container(
                                  height: 120,
                                  width: 120,
                                  decoration: BoxDecoration(
                                    color: _updatedProfileImage == null || _updatedProfileImage!.isEmpty 
                                        ? userColor 
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 15,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: _updatedProfileImage != null && _updatedProfileImage!.isNotEmpty
                                    ? CircleAvatar(
                                        radius: 60,
                                        backgroundImage: MemoryImage(base64Decode(_updatedProfileImage!)),
                                      )
                                    : Center(
                                        child: Text(
                                          _currentUser.name != null && _currentUser.name!.isNotEmpty
                                            ? _currentUser.name![0].toUpperCase()
                                            : '?',
                                          style: GoogleFonts.aBeeZee(
                                            fontSize: 50,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                              if (_isEditing)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF7BAC6C),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 5,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 25),
                        
                        // User information (non-editing mode)
                        if (!_isEditing) ...[
                          Text(
                            _currentUser.name ?? 'No Name',
                            style: GoogleFonts.aBeeZee(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _currentUser.email ?? '',
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 30),
                          
                          // Action Buttons (Edit & Logout)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Edit Button
                              Container(
                                width: 150,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF7BAC6C),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    elevation: 2,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = true;
                                      // Initialize the editing with current values
                                      _nameController.text = _currentUser.name ?? '';
                                      _updatedProfileImage = _currentUser.profileImage;
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.edit_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Edit',
                                        style: GoogleFonts.notoSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              SizedBox(width: 15),
                              
                              // Logout Button
                              Container(
                                width: 150,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.redAccent,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                      side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: _showLogoutConfirmation,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.logout_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Logout',
                                        style: GoogleFonts.notoSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          // Security Section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildSecuritySection(),
                          ),
                        ],
                        
                        // Edit form
                        if (_isEditing) ...[
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  style: GoogleFonts.notoSans(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Full Name',
                                    labelStyle: GoogleFonts.notoSans(
                                      color: Color(0xFF7BAC6C),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(color: Color(0xFF7BAC6C), width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    prefixIcon: Icon(Icons.person_outline, color: Color(0xFF7BAC6C)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (val) => val!.isEmpty ? 'Please enter your name' : null,
                                ),
                                SizedBox(height: 30),
                                
                                // Information text
                                Container(
                                  padding: EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF7BAC6C).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Color(0xFF7BAC6C).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Color(0xFF7BAC6C),
                                        size: 22,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "Your email cannot be changed after registration.",
                                          style: GoogleFonts.notoSans(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 30),
                                
                                // Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey.shade200,
                                          foregroundColor: Colors.black87,
                                          padding: EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isEditing = false;
                                            // Reset the form values to current user data
                                            _nameController.text = _currentUser.name ?? '';
                                            _updatedProfileImage = _currentUser.profileImage;
                                          });
                                        },
                                        child: Text(
                                          'Cancel',
                                          style: GoogleFonts.notoSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 15),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF7BAC6C),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed: _updateProfile,
                                        child: Text(
                                          'Save Changes',
                                          style: GoogleFonts.notoSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
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