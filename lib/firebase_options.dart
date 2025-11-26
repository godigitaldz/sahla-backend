// Firebase configuration for Sahla app
// Generated from Firebase Console configuration files

import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isAndroid) return android;
    if (Platform.isIOS) return ios;
    // Fallback to Android options
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDyfAGHlDwXDHm1aYd6tvSuoUi9VJKMkbE',
    appId: '1:571974829727:android:9a9cd08936a4ad227984aa',
    messagingSenderId: '571974829727',
    projectId: 'sahla-353bd',
    storageBucket: 'sahla-353bd.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBY57DGlw2_f1IC_-8tRN4Q3C-0_x9UKVg',
    appId: '1:571974829727:ios:6ce45d135dafda7d7984aa',
    messagingSenderId: '571974829727',
    projectId: 'sahla-353bd',
    storageBucket: 'sahla-353bd.firebasestorage.app',
    iosBundleId: 'com.godigital.sahla',
  );
}
