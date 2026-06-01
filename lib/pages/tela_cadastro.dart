// Gabriel Rocca Padua dos Santos - RA: 25002330
// Formulário de criação de conta com máscaras e validação progressiva da senha.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'tela_login.dart';

/// Aplica a máscara visual de CPF sem alterar o valor persistido pelo backend.
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digits[i]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Aplica máscara de telefone brasileiro durante a digitação.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if (i == 7) buffer.write('-');
      buffer.write(digits[i]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Coleta os dados pessoais necessários para criar a conta e sua carteira.
class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _cpfController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;
  bool _carregando = false;
  String? _erroCadastro;

  bool _temMinCaracteres = false;
  bool _temMaiuscula = false;
  bool _temNumero = false;
  bool _temEspecial = false;

  bool get _senhaValida =>
      _temMinCaracteres && _temMaiuscula && _temNumero && _temEspecial;

  @override
  void initState() {
    super.initState();
    _senhaController.addListener(_validarSenha);
  }

  @override
  void dispose() {
    _senhaController.removeListener(_validarSenha);
    _nomeController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  /// Atualiza os indicadores visuais dos requisitos de senha.
  void _validarSenha() {
    final senha = _senhaController.text;
    setState(() {
      _temMinCaracteres = senha.length >= 6;
      _temMaiuscula = senha.contains(RegExp(r'[A-Z]'));
      _temNumero = senha.contains(RegExp(r'[0-9]'));
      _temEspecial = senha.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'));
    });
  }

  /// Valida o formulário e delega a criação da conta ao serviço de autenticação.
  Future<void> _fazerCadastro() async {
    setState(() => _erroCadastro = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      await AuthService().register(
        nomeCompleto: _nomeController.text.trim(),
        email: _emailController.text.trim(),
        cpf: _somenteDigitos(_cpfController.text),
        telefone: _somenteDigitos(_telefoneController.text),
        password: _senhaController.text,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const TelaLogin()),
        (_) => false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _erroCadastro = error.message);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _somenteDigitos(String value) => value.replaceAll(RegExp(r'\D'), '');

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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      const SizedBox(height: 20),
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
                                  'Crie sua conta',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildLabeledInput(
                                label: 'Nome completo',
                                hint: 'João Silva',
                                controller: _nomeController,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Campo obrigatório'
                                    : null,
                              ),
                              _buildLabeledInput(
                                label: 'E-mail',
                                hint: 'exemplo@email.com',
                                controller: _emailController,
                                keyboard: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Campo obrigatório';
                                  }
                                  if (!RegExp(
                                    r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,}$',
                                  ).hasMatch(value)) {
                                    return 'E-mail inválido';
                                  }
                                  return null;
                                },
                              ),
                              _buildLabeledInput(
                                label: 'CPF',
                                hint: '000.000.000-00',
                                controller: _cpfController,
                                keyboard: TextInputType.number,
                                formatters: [CpfInputFormatter()],
                                validator: (value) {
                                  final digits = _somenteDigitos(value ?? '');
                                  if (digits.isEmpty) {
                                    return 'Campo obrigatório';
                                  }
                                  if (digits.length != 11) {
                                    return 'CPF inválido';
                                  }
                                  return null;
                                },
                              ),
                              _buildLabeledInput(
                                label: 'Telefone',
                                hint: '(11) 91234-5678',
                                controller: _telefoneController,
                                keyboard: TextInputType.phone,
                                formatters: [PhoneInputFormatter()],
                                validator: (value) {
                                  final digits = _somenteDigitos(value ?? '');
                                  if (digits.isEmpty) {
                                    return 'Campo obrigatório';
                                  }
                                  if (digits.length < 10) {
                                    return 'Telefone inválido';
                                  }
                                  return null;
                                },
                              ),
                              _buildLabeledInput(
                                label: 'Senha',
                                hint: '••••••',
                                controller: _senhaController,
                                obscure: !_senhaVisivel,
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
                              const SizedBox(height: 4),
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
                              const SizedBox(height: 8),
                              _buildLabeledInput(
                                label: 'Confirmar senha',
                                hint: '••••••',
                                controller: _confirmarSenhaController,
                                obscure: !_confirmarSenhaVisivel,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _confirmarSenhaVisivel
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => setState(
                                    () => _confirmarSenhaVisivel =
                                        !_confirmarSenhaVisivel,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Campo obrigatório';
                                  }
                                  if (value != _senhaController.text) {
                                    return 'As senhas não coincidem';
                                  }
                                  return null;
                                },
                              ),
                              if (_erroCadastro != null) ...[
                                const SizedBox(height: 8),
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
                                        _erroCadastro!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _carregando
                                      ? null
                                      : _fazerCadastro,
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
                                          'Cadastrar-se',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: TextButton(
                                  onPressed: _carregando
                                      ? null
                                      : () => Navigator.pop(context),
                                  child: const Text(
                                    'Já tem conta? Login',
                                    style: TextStyle(color: Color(0xFF4C3BCF)),
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

  Widget _buildLabeledInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              children: const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Color(0xFF4C3BCF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            inputFormatters: formatters,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: themeColors.faintText),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              suffixIcon: suffixIcon,
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
      ),
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
