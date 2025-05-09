import 'dart:convert';
import 'dart:io';

import 'package:chating_app/models/user.dart';
import 'package:chating_app/services/auth_services.dart';
import 'package:chating_app/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

//! R E G I S T E R - S C R E E N
// ignore: use_key_in_widget_constructors
class Register extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _RegisterState createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  //! F O R M - V A R I A B L E S
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
  
  //! I M A G E - P I C K E R
  Future<void> pickImage() async {
    try {
      setState(() => loading = true);
      
      //! B O T T O M - S H E E T
      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
        ),
        backgroundColor: Color(0xFFfffff4),
        builder: (BuildContext context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //! S H E E T - H E A D E R
                  Text(
                    "Profile Photo",
                    style: GoogleFonts.aBeeZee(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7BAC6C),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Choose a profile picture",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 20),
                  //! I M A G E - O P T I O N S
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
      if (kDebugMode) {
        print('Error picking image: $e');
      }
    }
  }

  //! O P T I O N - B U I L D E R
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
              // ignore: deprecated_member_use
              color: Color(0xFF7BAC6C).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Color(0xFF7BAC6C),
              size: 30,
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.8),
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
      constraints: BoxConstraints(minHeight: 600),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //! F O R M - H E A D E R
            Text(
              "Create Account",
              style: GoogleFonts.aBeeZee(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7BAC6C),
              ),
            ),
            Text(
              "Sign up to get started",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 25),
            
            //! P R O F I L E - I M A G E
            Center(
              child: GestureDetector(
                onTap: pickImage,
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Color(0xFFfffff4),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
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
                              color: Color(0xFF7BAC6C),
                            )
                          : null,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Add Profile Photo",
                      style: TextStyle(
                        color: Color(0xFF7BAC6C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 25),
            
            //! N A M E - F I E L D
            TextFormField(
              decoration: InputDecoration(
                labelText: "Full Name",
                hintText: "Abhishek R",
                prefixIcon: Icon(Icons.person_outline, color: Color(0xFF7BAC6C)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Color(0xFFfffff4),
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
              validator: (val) => val!.isEmpty ? 'Please enter your name' : null,
              onChanged: (val) {
                setState(() => name = val);
              },
            ),
            SizedBox(height: 16),
            
            //! E M A I L - F I E L D
            TextFormField(
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email",
                hintText: "your.email@example.com",
                prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF7BAC6C)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Color(0xFFfffff4),
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
            
            //! P A S S W O R D - F I E L D
            TextFormField(
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "Password",
                hintText: "••••••••",
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF7BAC6C)),
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
                fillColor: Color(0xFFfffff4),
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
              validator: (val) => val!.length < 6 ? 'Password must be 6+ characters' : null,
              onChanged: (val) {
                setState(() => password = val);
              },
            ),
            SizedBox(height: 16),
            
            //! C O N F I R M - P A S S W O R D
            TextFormField(
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: "Confirm Password",
                hintText: "••••••••",
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF7BAC6C)),
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
                fillColor: Color(0xFFfffff4),
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
            
            //! E R R O R - D I S P L A Y
            if (error.isNotEmpty)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(15),
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
            
            //! S I G N - U P - B U T T O N
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF7BAC6C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                //! R E G I S T E R - L O G I C
                onPressed: loading ? null : () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => loading = true);
                    
                    //! F I R E B A S E - A U T H
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final result = await authService.registerWithEmailAndPassword(email, password);
                    
                    if (result != null) {
                      //! U S E R - C R E A T I O N
                      final database = DatabaseService();
                      await database.updateUserData(
                        UserModel(
                          uid: result.uid, 
                          name: name, 
                          email: email,
                          profileImage: profileImageBase64 ?? '',
                        )
                      );
                    } else {
                      //! R E G I S T R A T I O N - E R R O R
                      setState(() {
                        error = 'Registration failed. Please try again.';
                        loading = false;
                      });
                    }
                  }
                },
                //! B U T T O N - S T A T E
                child: loading
                  ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                  : Text(
                      "SIGN UP",
                      style: GoogleFonts.aBeeZee(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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