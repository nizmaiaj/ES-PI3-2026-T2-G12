// Gabriel Rocca Padua dos Santos - RA: 25002330
// Interface de redefinição local da senha após o fluxo de recuperação.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Permite digitar e confirmar uma nova senha.
class TelaRedefinirSenha extends StatefulWidget {
  const TelaRedefinirSenha({super.key});

  @override
  State<TelaRedefinirSenha> createState() => _TelaRedefinirSenhaState();
}

class _TelaRedefinirSenhaState extends State<TelaRedefinirSenha> {
  final _formKey = GlobalKey<FormState>();
  final _novaSenhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _obscureNovaSenha = true;
  bool _obscureConfirmarSenha = true;

  @override
  void dispose() {
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
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
                  onPressed: () => Navigator.pop(context),
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
                        "MesclaInvest",
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  "Redefinir senha",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: Text(
                                  "Digite e confirme sua nova senha para continuar",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: themeColors.mutedText,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              _buildLabeledPassword(
                                label: "Nova senha",
                                controller: _novaSenhaController,
                                obscure: _obscureNovaSenha,
                                onToggle: () => setState(
                                  () => _obscureNovaSenha = !_obscureNovaSenha,
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return "Campo obrigatório";
                                  }
                                  if (v.length < 6) {
                                    return "Mínimo 6 caracteres";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              _buildLabeledPassword(
                                label: "Confirmar senha",
                                controller: _confirmarSenhaController,
                                obscure: _obscureConfirmarSenha,
                                onToggle: () => setState(
                                  () => _obscureConfirmarSenha =
                                      !_obscureConfirmarSenha,
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return "Campo obrigatório";
                                  }
                                  if (v != _novaSenhaController.text) {
                                    return "As senhas não coincidem";
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 28),

                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      // Lógica de salvar nova senha
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4C3BCF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: const Text(
                                    "Salvar nova senha",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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

  Widget _buildLabeledPassword({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
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
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: "••••••",
            hintStyle: TextStyle(color: themeColors.faintText),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: onToggle,
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
