import 'package:flutter/material.dart';
import 'tela_cadastro.dart';
import 'tela_esqueciSenha.dart';
import 'package:cloud_functions/cloud_functions.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  // chave de validação do formúlario
  final _formKey = GlobalKey<FormState>();

  // Controladores para capturar o que o usuário digita
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  // Função que será chamada ao clicar no botão Entrar
  Future<void> _fazerLogin() async {
    // Troque a linha 30 por esta:
    if (_formKey.currentState?.validate() ?? false) {
      try {
        print("Fazendo seu login...");

        //Instancia a função apontando para a região correta
        final callable = FirebaseFunctions.instanceFor(
          region: 'southamerica-east1',
        ).httpsCallable('loginUsuario');

        //Chama a função passando os dados que o LoginInput espera
        final result = await callable.call({
          "email": _emailController.text,
          "senha": _senhaController.text,
        });

        //O retorno contém o JSON definiDO no return do handler
        final data = result.data as Map<String, dynamic>;

        if (data['success'] == true) {
          _showMesage(
            'Login Realizado, ${data['usuario']['email']}!',
            Colors.green,
          );
          // Lógica de navegação para a home aqui
        }
      } on FirebaseFunctionsException catch (e) {
        //Captura os erros HttpsError
        _showMesage(e.message ?? 'Erro ao autenticar', Colors.red);
      } catch (e) {
        _showMesage('Erro inesperado de conexão.', Colors.red);
      }
    }
  }

  void _showMesage(String mensagem, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Logo (Imagem)
              Image.asset(
                'assets/logo_mescla.png',
                height: 100,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),

              // Título fora da caixa
              const Text(
                'Mescla Invest',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // 2. A CAIXA CINZA
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(
                    255,
                    216,
                    215,
                    215,
                  ), // Cor cinza clara
                  borderRadius: BorderRadius.circular(
                    20,
                  ), // Bordas arredondadas
                ),
                child: Column(
                  children: [
                    const Text(
                      "Entrar",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    //E-mail
                    _LoginInputField(
                      hint: 'E-mail',
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          (value == null || !value.contains('@'))
                          ? 'E-mail inválido'
                          : null,
                    ),

                    //Senha
                    _LoginInputField(
                      hint: 'Senha',
                      controller: _senhaController,
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (value) => (value == null || value.length < 6)
                          ? 'Senha muito curta'
                          : null,
                    ),

                    const SizedBox(height: 8),

                    // Botão de entrar (dentro da caixa)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF4A3BB9,
                          ), // Azul escuro
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _fazerLogin,
                        child: const Text(
                          'ENTRAR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TelaEsqueciSenha(),
                          ),
                        );
                      },
                      child: const Text(
                        'Esqueci a senha',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TelaCadastro(),
                          ),
                        );
                      },
                      child: const Text(
                        'Não tem conta? Cadastrar-se',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//Widget de Input especializado para  a tela de Login
// Widget de Input especializado para a tela de Login
class _LoginInputField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _LoginInputField({
    required this.hint,
    required this.controller,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          errorStyle: const TextStyle(height: 0.7),
        ),
      ),
    );
  }
}
