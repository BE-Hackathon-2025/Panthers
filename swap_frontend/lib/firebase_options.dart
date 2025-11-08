import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAMUoJoc2NfuaGeIh4Iw93VbgCOdVFcXoo',
    appId: '1:663805210025:web:3aa600097496bd81bfe8b8',
    messagingSenderId: '663805210025',
    projectId: 'besmart2025-d6c3f',
    authDomain: 'besmart2025-d6c3f.firebaseapp.com',
    storageBucket: 'besmart2025-d6c3f.firebasestorage.app',
    measurementId: 'G-Q9K6JJF4KJ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAMUoJoc2NfuaGeIh4Iw93VbgCOdVFcXoo',
    appId: '1:663805210025:web:3aa600097496bd81bfe8b8',
    messagingSenderId: '663805210025',
    projectId: 'besmart2025-d6c3f',
    storageBucket: 'besmart2025-d6c3f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAMUoJoc2NfuaGeIh4Iw93VbgCOdVFcXoo',
    appId: '1:663805210025:web:3aa600097496bd81bfe8b8',
    messagingSenderId: '663805210025',
    projectId: 'besmart2025-d6c3f',
    storageBucket: 'besmart2025-d6c3f.firebasestorage.app',
    iosClientId:
        '663805210025-xxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com',
    iosBundleId: 'com.example.yourapp',
  );
}
