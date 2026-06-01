// Inicializa dependências globais e monta a raiz visual do aplicativo.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'pages/tela_inicial.dart';
import 'services/app_theme_controller.dart';
import 'theme/app_theme.dart';

// import 'pages/tela_balcao_compra.dart';
// import 'pages/tela_home.dart';
// import 'pages/tela_cadastro.dart';
// import 'pages/tela_login.dart';
// import 'package:es_pi3_2026_t2_g12/pages/tela_visao_geral.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppThemeController.instance.load();

  if (!kIsWeb &&
      kDebugMode &&
      defaultTargetPlatform == TargetPlatform.android) {
    // Local debug builds are not Play Store-distributed, so test Phone Auth via reCAPTCHA.
    await FirebaseAuth.instance.setSettings(forceRecaptchaFlow: true);
  }

  runApp(const MeuApp());
}

/// Configura navegação inicial, temas e comportamento global de rolagem.
class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false, // Tira a faixa de "DEBUG" da tela
          title: 'Mescla invest',
          scrollBehavior: const _SemOverscrollElastic(),
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: AppThemeController.instance.themeMode,
          home: const TelaInicial(),
        );
      },
    );
  }
}

/// Remove o efeito elástico padrão para manter a rolagem consistente nas telas.
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
