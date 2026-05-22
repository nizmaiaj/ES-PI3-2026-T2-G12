import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'pages/tela_inicial.dart';

// import 'pages/tela_balcao_compra.dart';
// import 'pages/tela_home.dart';
// import 'pages/tela_cadastro.dart';
// import 'pages/tela_login.dart';
// import 'package:es_pi3_2026_t2_g12/pages/tela_visao_geral.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb &&
      kDebugMode &&
      defaultTargetPlatform == TargetPlatform.android) {
    // Local debug builds are not Play Store-distributed, so test Phone Auth via reCAPTCHA.
    await FirebaseAuth.instance.setSettings(forceRecaptchaFlow: true);
  }

  runApp(const MeuApp());
}

// O widget principal que configura o aplicativo
class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Tira a faixa de "DEBUG" da tela
      title: 'Mescla invest',
      scrollBehavior: const _SemOverscrollElastic(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true, // Usa o design mais recente do Google
      ),
      home: const TelaInicial(),
    );
  }
}

class _SemOverscrollElastic extends MaterialScrollBehavior {
  const _SemOverscrollElastic();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
