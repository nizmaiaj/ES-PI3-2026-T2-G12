// Gabriel Rocca Padua dos Santos - RA: 25002330
// Tela de entrada por e-mail e senha, incluindo conclusão do MFA por SMS.

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sms_code_dialog.dart';
import 'tela_cadastro.dart';
import 'tela_esqueci_senha.dart';
import 'tela_home.dart';
import 'tela_inicial.dart';

/// Coleta credenciais e encaminha o usuário autenticado para a Home.
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _senhaVisivel = false;
  bool _carregando = false;
  String? _erroLogin;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  /// Tenta autenticar e abre o diálogo SMS quando a conta exige segundo fator.
  Future<void> _fazerLogin() async {
    setState(() => _erroLogin = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final authService = AuthService();

      await authService.login(
        email: _emailController.text.trim(),
        password: _senhaController.text,
      );

      _abrirHome();
    } on AuthMfaRequiredException catch (error) {
      try {
        await AuthService().resolveSmsMfaSignIn(
          challenge: error.challenge,
          smsCodeResolver: (_, _) {
            if (!mounted) return Future.value(null);
            return showSmsCodeDialog(
              context,
              phoneNumber: error.challenge.phoneNumber,
              title: 'Verificação em duas etapas',
              message: 'Digite o código enviado por SMS para concluir o login.',
            );
          },
        );

        _abrirHome();
      } on AuthException catch (mfaError) {
        if (!mounted) return;
        setState(() => _erroLogin = mfaError.message);
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _erroLogin = error.message);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _abrirHome() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TelaHome(nomeDigitado: _emailController.text.trim()),
      ),
    );
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
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const TelaInicial()),
                    );
                  },
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: themeColors.elevatedSurface.withValues(
                        alpha: 0.92,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(45),
                        bottom: Radius.circular(45),
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Boas-vindas ao MesclaInvest!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Precisamos desses dados para acessar o aplicativo',
                            style: TextStyle(
                              fontSize: 14,
                              color: themeColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _buildLabel('E-mail'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration('exemplo@email.com'),
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
                          const SizedBox(height: 16),
                          _buildLabel('Senha'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _senhaController,
                            obscureText: !_senhaVisivel,
                            decoration: _inputDecoration('Senha').copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _senhaVisivel
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(
                                  () => _senhaVisivel = !_senhaVisivel,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Campo obrigatório';
                              }
                              if (v.length < 6) return 'Senha muito curta';
                              return null;
                            },
                          ),
                          if (_erroLogin != null) ...[
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
                                    'Erro: $_erroLogin',
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
                              onPressed: _carregando ? null : _fazerLogin,
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
                                      'Entrar',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: TextButton(
                              onPressed: _carregando
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const TelaEsqueciSenha(),
                                      ),
                                    ),
                              child: const Text(
                                'Esqueceu a senha?',
                                style: TextStyle(
                                  color: Color(0xFF4C3BCF),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: TextButton(
                              onPressed: _carregando
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const TelaCadastro(),
                                      ),
                                    ),
                              child: RichText(
                                text: TextSpan(
                                  text: 'Não tem conta? ',
                                  style: TextStyle(
                                    color: themeColors.mutedText,
                                    fontSize: 14,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: 'Cadastre-se',
                                      style: TextStyle(
                                        color: Color(0xFF4C3BCF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: themeColors.faintText),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
    );
  }
}
