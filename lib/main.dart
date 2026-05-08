import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// import 'package:es_pi3_2026_t2_g12/pages/tela_login.dart';
// import 'pages/tela_cadastro.dart';
// import 'package:es_pi3_2026_t2_g12/pages/tela_visao_geral.dart';
import 'pages/tela_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true, // Usa o design mais recente do Google
      ),
      home: const TelaHome(nomeDigitado: "Fernanda"),
    );
  }
}
