import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'tela_login.dart';

class TelaRedefinirSenha extends StatefulWidget {
  const TelaRedefinirSenha({
    super.key,
    required this.email,
    required this.resetId,
    required this.resetToken,
  });

  final String email;
  final String resetId;
  final String resetToken;

  @override
  State<TelaRedefinirSenha> createState() => _TelaRedefinirSenhaState();
}

class _TelaRedefinirSenhaState extends State<TelaRedefinirSenha> {
  final _formKey = GlobalKey<FormState>();
  final _novaSenhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _obscureNovaSenha = true;
  bool _obscureConfirmarSenha = true;
  bool _carregando = false;
  String? _erro;

  bool _temMinCaracteres = false;
  bool _temMaiuscula = false;
  bool _temNumero = false;
  bool _temEspecial = false;

  bool get _senhaValida =>
      _temMinCaracteres && _temMaiuscula && _temNumero && _temEspecial;

  @override
  void initState() {
    super.initState();
    _novaSenhaController.addListener(_validarSenha);
  }

  @override
  void dispose() {
    _novaSenhaController.removeListener(_validarSenha);
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  void _validarSenha() {
    final senha = _novaSenhaController.text;
    setState(() {
      _temMinCaracteres = senha.length >= 6;
      _temMaiuscula = senha.contains(RegExp(r'[A-Z]'));
      _temNumero = senha.contains(RegExp(r'[0-9]'));
      _temEspecial = senha.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'));
    });
  }

  Future<void> _salvarNovaSenha() async {
    setState(() => _erro = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final mensagem = await AuthService().resetPassword(
        email: widget.email,
        resetId: widget.resetId,
        resetToken: widget.resetToken,
        newPassword: _novaSenhaController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const TelaLogin()),
        (_) => false,
      );
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Center(
                                child: Text(
                                  'Redefinir senha',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Center(
                                child: Text(
                                  'Digite e confirme sua nova senha para continuar',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildLabeledPassword(
                                label: 'Nova senha',
                                controller: _novaSenhaController,
                                obscure: _obscureNovaSenha,
                                enabled: !_carregando,
                                onToggle: () => setState(
                                  () => _obscureNovaSenha = !_obscureNovaSenha,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Campo obrigatório';
                                  }
                                  if (!_senhaValida) {
                                    return 'A senha não atende aos requisitos';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 6),
                              _buildSenhaIndicador(
                                'Pelo menos 6 caracteres',
                                _temMinCaracteres,
                              ),
                              _buildSenhaIndicador(
                                'Letra maiúscula',
                                _temMaiuscula,
                              ),
                              _buildSenhaIndicador('Número', _temNumero),
                              _buildSenhaIndicador(
                                'Caractere especial (!@#\$...)',
                                _temEspecial,
                              ),
                              const SizedBox(height: 12),
                              _buildLabeledPassword(
                                label: 'Confirmar senha',
                                controller: _confirmarSenhaController,
                                obscure: _obscureConfirmarSenha,
                                enabled: !_carregando,
                                onToggle: () => setState(
                                  () => _obscureConfirmarSenha =
                                      !_obscureConfirmarSenha,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Campo obrigatório';
                                  }
                                  if (value != _novaSenhaController.text) {
                                    return 'As senhas não coincidem';
                                  }
                                  return null;
                                },
                              ),
                              if (_erro != null) ...[
                                const SizedBox(height: 14),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _erro!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _carregando
                                      ? null
                                      : _salvarNovaSenha,
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
                                          'Salvar nova senha',
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
    required bool enabled,
    required VoidCallback onToggle,
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
          enabled: enabled,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: '••••••',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: enabled ? onToggle : null,
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

  Widget _buildSenhaIndicador(String texto, bool valido) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            valido ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: valido ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              color: valido ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
