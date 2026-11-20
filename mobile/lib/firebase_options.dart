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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBllc-Xiy95Ohsuy8xvUu4qNGvFShoQ63o',
    appId: '1:650948498734:web:60ca08513482f3efb1d6bf',
    messagingSenderId: '650948498734',
    projectId: 'savorsync-a9b06',
    authDomain: 'savorsync-a9b06.firebaseapp.com',
    storageBucket: 'savorsync-a9b06.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBllc-Xiy95Ohsuy8xvUu4qNGvFShoQ63o',
    appId: '1:650948498734:android:60ca08513482f3efb1d6bf',
    messagingSenderId: '650948498734',
    projectId: 'savorsync-a9b06',
    storageBucket: 'savorsync-a9b06.firebasestorage.app',
  );
}
