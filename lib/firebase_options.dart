// Configuração de conexão gerada para o projeto Firebase do aplicativo.
// Web e Android estão habilitados; as demais plataformas exigem configuração.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Entrega ao Firebase Core as credenciais adequadas à plataforma atual.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAI_R_o01ibJXmAC-v4oPLFl-_LyDhMMKg',
    appId: '1:6585935876:web:7bdcc029cfd73ebd57ed51',
    messagingSenderId: '6585935876',
    projectId: 'bd-pi3-1808d',
    storageBucket: 'bd-pi3-1808d.firebasestorage.app',
    authDomain: 'bd-pi3-1808d.firebaseapp.com',
    measurementId: 'G-F496CK67LS',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-sPucUybWUXAkTus0bhtERR1UYdejvKA',
    appId: '1:6585935876:android:caa18c84c031f5e957ed51',
    messagingSenderId: '6585935876',
    projectId: 'bd-pi3-1808d',
    storageBucket: 'bd-pi3-1808d.firebasestorage.app',
  );
}
