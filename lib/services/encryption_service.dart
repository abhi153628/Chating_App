import 'dart:convert';

// File: lib/main.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:chating_app/main.dart';
import 'package:chating_app/services/storage_service.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

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
    
    // Store it using the StorageService
    await StorageService.saveChatKey(chatId, key);
    
    return key;
  }
  
  // Get or create a key for a chat
  static Future<String> getChatKey(String chatId) async {
    // Check if we already have the key in memory
    if (_chatKeys.containsKey(chatId)) {
      return _chatKeys[chatId]!;
    }
    
    // Try to get from storage
    final storedKey = await StorageService.getChatKey(chatId);
    
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
      
      // Save to storage
      await StorageService.saveChatKey(chatId, key);
      
      return true;
    }
    return false;
  }
}
