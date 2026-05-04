import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class TelaEsqueciSenha extends StatefulWidget {
  const TelaEsqueciSenha({super.key});

  @override
  State<TelaEsqueciSenha> createState() => _TelaEsqueciSenhaState();
}

class _TelaEsqueciSenhaState extends State<TelaEsqueciSenha> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _carregando = false;
  String? _mensagem;
  String? _erro;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _enviarEmail() async {
    setState(() {
      _mensagem = null;
      _erro = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final mensagem = await AuthService().forgotPassword(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _mensagem = mensagem);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _erro = error.message);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0F0F7), Color(0xFFC2CEF5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Color(0xFF4C3BCF),
                  ),
                  onPressed: _carregando ? null : () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      Image.asset('assets/logo_mescla.png', height: 70),
                      const SizedBox(height: 8),
                      const Text(
                        'MesclaInvest',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECEDF5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              const Text(
                                'Esqueci a senha',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Digite seu e-mail para receber o link de recuperação',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildLabeledInput(
                                label: 'E-mail',
                                hint: 'exemplo@email.com',
                                controller: _emailController,
                                keyboard: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Campo obrigatório';
                                  }
                                  if (!RegExp(
                                    r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,}$',
                                  ).hasMatch(v)) {
                                    return 'E-mail inválido';
                                  }
                                  return null;
                                },
                              ),
                              if (_mensagem != null) ...[
                                const SizedBox(height: 14),
                                _buildStatusMessage(
                                  _mensagem!,
                                  Colors.green,
                                  Icons.check_circle_outline,
                                ),
                              ],
                              if (_erro != null) ...[
                                const SizedBox(height: 14),
                                _buildStatusMessage(
                                  _erro!,
                                  Colors.red,
                                  Icons.error_outline,
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed:
                                      _carregando ? null : _enviarEmail,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4C3BCF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: _carregando
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Text(
                                          'Enviar e-mail',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: _carregando
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text(
                                  'Voltar para o Login',
                                  style: TextStyle(color: Color(0xFF4C3BCF)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildStatusMessage(String message, Color color, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: color, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
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
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Color(0xFF4C3BCF), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
