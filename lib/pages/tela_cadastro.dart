import 'package:flutter/material.dart';

class TelaCadastro extends StatelessWidget {
  const TelaCadastro({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Criar conta"),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          // CORREÇÃO: O nome correto é EdgeInsets com 's' no final
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/logo_mescla.png',
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),

              // Aqui você pode continuar adicionando os campos de texto...
              const Text(
                "Página de Cadastro",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
