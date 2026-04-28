import 'package:flutter/material.dart';
import 'pages/tela_login.dart';
import 'package:flutter/foundation.dart'; // Para o kDebugMode
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // INICIALIZA O FIREBASE:
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    // Configura os emuladores
    FirebaseFunctions.instanceFor(
      region: 'southamerica-east1',
    ).useFunctionsEmulator('127.0.0.1', 5001);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true, // Usa o design mais recente do Google
      ),
      home: const TelaLogin(),
    );
  }
}
