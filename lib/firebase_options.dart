// File ini merupakan konfigurasi Firebase untuk platform aplikasi ZieSocial.
// Disesuaikan langsung dengan google-services.json project: ziesocial-8fbd7

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
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB9hlrj619SXufKgESf_FKelPwUfjUavk0',
    appId: '1:62387759719:web:a733055edaf3b4bb8582c2',
    messagingSenderId: '62387759719',
    projectId: 'ziesocial-8fbd7',
    authDomain: 'ziesocial-8fbd7.firebaseapp.com',
    storageBucket: 'ziesocial-8fbd7.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB9hlrj619SXufKgESf_FKelPwUfjUavk0',
    appId: '1:62387759719:android:a733055edaf3b4bb8582c2',
    messagingSenderId: '62387759719',
    projectId: 'ziesocial-8fbd7',
    storageBucket: 'ziesocial-8fbd7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB9hlrj619SXufKgESf_FKelPwUfjUavk0',
    appId: '1:62387759719:ios:a733055edaf3b4bb8582c2',
    messagingSenderId: '62387759719',
    projectId: 'ziesocial-8fbd7',
    storageBucket: 'ziesocial-8fbd7.firebasestorage.app',
    iosBundleId: 'com.example.ziesocial',
  );
}
