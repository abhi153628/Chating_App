// ignore_for_file: use_key_in_widget_constructors

import 'package:chating_app/services/auth_services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

//! L O G I N - S C R E E N
class Login extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  //! F O R M - V A R I A B L E S
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
      constraints: BoxConstraints(minHeight: 380), 
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //! W E L C O M E - H E A D E R
            Text(
              "Welcome back",
              style: GoogleFonts.aBeeZee(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7BAC6C),
              ),
            ),
            Text(
              "Sign in to continue",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withOpacity(0.7),
                fontFamily: 'Montserrat',
              ),
            ),
            SizedBox(height: 30),
            
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
              validator: (val) => val!.isEmpty ? 'Please enter an email' : null,
              onChanged: (val) {
                setState(() => email = val);
              },
            ),
            SizedBox(height: 16),
            
            //! P A S S W O R D - F I E L D
            TextFormField(
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: "Password",
                hintText: "••••••••",
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF7BAC6C)),
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
                fillColor: Color(0xFFfffff4),
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
              validator: (val) => val!.length < 6 ? 'Password must be 6+ characters' : null,
              onChanged: (val) {
                setState(() => password = val);
              },
            ),
            SizedBox(height: 25),
            
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
            
            //! L O G I N - B U T T O N
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
                //! A U T H - P R O C E S S
                onPressed: loading ? null : () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => loading = true);
                    
                    try {
                      //! A U T H - S E R V I C E
                      final authService = Provider.of<AuthService>(context, listen: false);
                      final result = await authService.signInWithEmailAndPassword(email, password);
                      
                      //! A U T H - R E S U L T
                      if (result == null) {
                        setState(() {
                          error = 'Failed to sign in with those credentials.';
                          loading = false;
                        });
                      }
                      //! N A V I G A T I O N
                    } catch (e) {
                      //! E R R O R - H A N D L I N G
                      setState(() {
                        error = e.toString();
                        loading = false;
                      });
                    }
                  }
                },
                //! B U T T O N - S T A T E
                child: loading
                  ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                  : Text(
                      "SIGN IN",
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