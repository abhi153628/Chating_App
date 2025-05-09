# SecureChat

A privacy-focused messaging application with end-to-end encryption and biometric authentication.



## Features

- 🔒 End-to-end message encryption
- 👆 Biometric authentication (fingerprint/face)
- 📱 Modern, intuitive user interface
- 📷 Secure image sharing
- 👤 Customizable user profiles
- 💬 Real-time messaging

## Getting Started

### Prerequisites

- Flutter SDK 2.5.0+
- Dart 2.14.0+
- Firebase account
- Android Studio / VS Code

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/securechat.git
   cd securechat
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication (Email/Password)
   - Setup Cloud Firestore
   - Add Firebase configuration files:
     - Android: Place `google-services.json` in `android/app/`
     - iOS: Place `GoogleService-Info.plist` in `ios/Runner/`

4. **Configure Biometric Authentication**
   - Android: Set `minSdkVersion` to 21+ in `android/app/build.gradle`
   - iOS: Add FaceID usage description to `Info.plist`

5. **Run the app**
   ```bash
   flutter run
   ```

## Architecture

The app follows a clean architecture approach with:

- **Models**: Data structures for users, chats, and messages
- **Services**: Authentication and database operations
- **Screens**: UI components following Material Design
- **Utils**: Helper functions for encryption and biometrics

## Dependencies

- `firebase_core`, `firebase_auth`, `cloud_firestore`: Firebase integration
- `provider`: State management
- `local_auth`: Biometric authentication
- `image_picker`: Image handling
- `google_fonts`: Typography enhancement
- `intl`: Date and time formatting

## Security Features

- Chat-level encryption toggle
- App-wide biometric lock
- Individual chat locks with fingerprint authentication
- Secure image transmission with compression and encoding

## Development Notes

- Use the provided comment style (`//! S E C T I O N - N A M E`) for code organization
- Follow Material Design guidelines for UI components
- Implement proper error handling for authentication and messaging
- Test all biometric features on physical devices

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

Your Name - your.email@example.com

Project Link: [https://github.com/yourusername/securechat](https://github.com/yourusername/securechat)