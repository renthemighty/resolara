// Generated from GoogleService-Info.plist and google-services.json
// Project: resolara-1

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for ${defaultTargetPlatform.name}',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyCsFhdm3RKvLNsulOiWXChYRwEGbbCnmIo',
    appId:             '1:165654333832:ios:9e6cdb4be057e34275923d',
    messagingSenderId: '165654333832',
    projectId:         'resolara-1',
    storageBucket:     'resolara-1.firebasestorage.app',
    iosBundleId:       'ai.resolara.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyATrXbI8YevW1a9V3aDjwt9hMFYWAvvbJQ',
    appId:             '1:165654333832:android:c7dadfb3a08f9fec75923d',
    messagingSenderId: '165654333832',
    projectId:         'resolara-1',
    storageBucket:     'resolara-1.firebasestorage.app',
  );
}
