// Gabriel Rocca Padua dos Santos - RA: 25002330
// Solicita ao Firebase o envio de um link para recuperação da senha.

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Formulário de recuperação associado ao e-mail da conta.
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

  /// Valida o e-mail, chama o serviço e apresenta sucesso ou erro na própria tela.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF101116), Color(0xFF1C2030)]
                : const [Color(0xFFF0F0F7), Color(0xFFC2CEF5)],
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
                      Text(
                        'MesclaInvest',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: themeColors.subtleSurface,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Text(
                                'Esqueci a senha',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Digite seu e-mail para receber o link de recuperação',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: themeColors.mutedText,
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
                                  onPressed: _carregando ? null : _enviarEmail,
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
          child: Text(message, style: TextStyle(color: color, fontSize: 13)),
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
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: themeColors.faintText),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
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
              borderSide: const BorderSide(
                color: Color(0xFF4C3BCF),
                width: 1.5,
              ),
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
