import 'package:flutter/material.dart';
import 'tela_login.dart';
import 'package:cloud_functions/cloud_functions.dart';

class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // O Flutter já coloca o ícone de voltar automaticamente se houver uma rota anterior
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Página de Cadastro",
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              Image.asset('assets/logo_mescla.png', height: 80),
              const SizedBox(height: 12),
              const Text(
                "MesclaInvest",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // CAIXA CINZA
              Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0), // Cinza claro da imagem
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Cadastrar-se",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildInput("Nome Completo", _nomeController),
                      _buildInput(
                        "Cpf",
                        _cpfController,
                        keyboard: TextInputType.number,
                      ),
                      _buildInput(
                        "e-mail",
                        _emailController,
                        keyboard: TextInputType.emailAddress,
                      ),
                      _buildInput("Senha", _senhaController, obscure: true),
                      _buildInput(
                        "Confirmar senha",
                        _confirmarSenhaController,
                        obscure: true,
                      ),
                      const SizedBox(height: 32),
                      // BOTÃO ENTRAR (Roxo)
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              try {
                                print("Fazendo seu cadastro...");

                                final resultado =
                                    await FirebaseFunctions.instanceFor(
                                      region: 'southamerica-east1',
                                    ).httpsCallable('cadastrarUsuario').call({
                                      "email": _emailController.text,
                                      "senha": _senhaController.text,
                                      "cpf": _cpfController.text,
                                    });
                                print("Sucesso:${resultado.data}");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Usuario cadastrado com sucesso!',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                print("Erro ao cadastrar $e");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro: $e')),
                                );
                              }
                            }
                          },

                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4C3BCF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            "Criar conta",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TelaLogin(),
                            ),
                          );
                        },
                        child: const Text(
                          'Já tem conta? Login',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Para voltar a tela de login caso já tenha uma conta
            ],
          ),
        ),
      ),
    );
  }

  // Widget interno para evitar repetição de código
  Widget _buildInput(
    String hint,
    TextEditingController controller, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) => value!.isEmpty ? "Campo obrigatório" : null,
      ),
    );
  }
}
