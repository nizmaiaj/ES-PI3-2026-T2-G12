import 'package:flutter/material.dart';
import 'pages/tela_login.dart';

void main() {
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
      home: const TelaLogin(),
    );
  }
}
