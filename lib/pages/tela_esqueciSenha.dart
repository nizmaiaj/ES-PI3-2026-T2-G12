import 'package:flutter/material.dart';
import 'tela_login.dart';

class TelaEsqueciSenha extends StatefulWidget {
  const TelaEsqueciSenha({super.key});

  @override 
  State<TelaEsqueciSenha> create() => _TelaEsqueciSenhaState();
}

class _TelaEsqueciSenhaState extends State<TelaEsqueciSenha> {
  // chave de validação do formulario 
  final _formKey = GlobalKey<FormState>();

  // Controladores para pegar o que o usuário digita

  final TextEditingController _emailController = TextEditingController();

  @override  
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _esqueciSenha() {
    //Aqui vai ficar a parte de mandar o e-mail para o usuario após enviar
  }



  @override  
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(padding: const EdgeInsets.all(32.0),
        child: Column (mainAxisAlignment: MainAxisAlignment.center,
        children: [
          //Logo do Mescla 
          Image.asset(
            'assets/logo_mescla.png',
            height: 80),
            const SizedBox(height: 12),
            const Text(
              'MeclaInvest',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30,),

            //  CAIXA CINZA
            Form(
              key: _formKey
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(24),
                 ),
                 child: Column(
                  children: [
                    const Text(
                      'Esqueci a senha',
                      style: TextStyle(fontSize: 20,
                      fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Digite seu e-mail para receber o código de verificação',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                  ],
                  ),
                 
              ),
            ),

        ],
        ),
        ),
        ),
      );
  }
}