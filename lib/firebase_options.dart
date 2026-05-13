import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase ainda não foi configurado para Web. Rode no Android ou adicione as opções Web do Firebase.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase ainda não foi configurado para esta plataforma. Rode no Android ou adicione o arquivo de configuração correspondente.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-sPucUybWUXAkTus0bhtERR1UYdejvKA',
    appId: '1:6585935876:android:caa18c84c031f5e957ed51',
    messagingSenderId: '6585935876',
    projectId: 'bd-pi3-1808d',
    storageBucket: 'bd-pi3-1808d.firebasestorage.app',
  );
}
