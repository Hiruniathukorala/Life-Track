import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDIMfZh55t7g06J4FPeGnAw-F8rARJyGNo',
    authDomain: 'lifetrack-a06a6.firebaseapp.com',
    projectId: 'lifetrack-a06a6',
    storageBucket: 'lifetrack-a06a6.firebasestorage.app',
    messagingSenderId: '131732976244',
    appId: '1:131732976244:web:ea8b3f95af3e1e6176d721',
    measurementId: 'G-8MCN11T16F',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDIMfZh55t7g06J4FPeGnAw-F8rARJyGNo',
    authDomain: 'lifetrack-a06a6.firebaseapp.com',
    projectId: 'lifetrack-a06a6',
    storageBucket: 'lifetrack-a06a6.firebasestorage.app',
    messagingSenderId: '131732976244',
    appId: '1:131732976244:web:ea8b3f95af3e1e6176d721',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDIMfZh55t7g06J4FPeGnAw-F8rARJyGNo',
    authDomain: 'lifetrack-a06a6.firebaseapp.com',
    projectId: 'lifetrack-a06a6',
    storageBucket: 'lifetrack-a06a6.firebasestorage.app',
    messagingSenderId: '131732976244',
    appId: '1:131732976244:web:ea8b3f95af3e1e6176d721',
  );
}
