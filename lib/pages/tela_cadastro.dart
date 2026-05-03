import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

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

    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

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

  bool _temMinCaracteres = false;
  bool _temMaiuscula = false;
  bool _temNumero = false;
  bool _temEspecial = false;

  @override
  void initState() {
    super.initState();
    _senhaController.addListener(_validarSenha);
  }

  void _validarSenha() {
    final senha = _senhaController.text;
    setState(() {
      _temMinCaracteres = senha.length >= 6;
      _temMaiuscula = senha.contains(RegExp(r'[A-Z]'));
      _temNumero = senha.contains(RegExp(r'[0-9]'));
      _temEspecial = senha.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'));
    });
  }

  bool get _senhaValida =>
      _temMinCaracteres && _temMaiuscula && _temNumero && _temEspecial;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
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
                      const Text(
                        "MesclaInvest",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

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
                                  "Crie sua conta",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              _buildLabeledInput(
                                label: "Nome completo",
                                hint: "João Silva",
                                controller: _nomeController,
                                validator: (v) =>
                                    v!.trim().isEmpty ? "Campo obrigatório" : null,
                              ),
                              _buildLabeledInput(
                                label: "Email",
                                hint: "exemplo@email.com",
                                controller: _emailController,
                                keyboard: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v!.isEmpty) return "Campo obrigatório";
                                  if (!RegExp(
                                    r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,}$',
                                  ).hasMatch(v)) {
                                    return "E-mail inválido";
                                  }
                                  return null;
                                },
                              ),
                              _buildLabeledInput(
                                label: "CPF",
                                hint: "000.000.000-00",
                                controller: _cpfController,
                                keyboard: TextInputType.number,
                                formatters: [CpfInputFormatter()],
                                validator: (v) {
                                  final digits = v!.replaceAll(RegExp(r'\D'), '');
                                  if (digits.isEmpty) return "Campo obrigatório";
                                  if (digits.length != 11) return "CPF inválido";
                                  return null;
                                },
                              ),
                              _buildLabeledInput(
                                label: "Telefone",
                                hint: "(11) 91234-5678",
                                controller: _telefoneController,
                                keyboard: TextInputType.phone,
                                formatters: [PhoneInputFormatter()],
                                validator: (v) {
                                  final digits = v!.replaceAll(RegExp(r'\D'), '');
                                  if (digits.isEmpty) return "Campo obrigatório";
                                  if (digits.length < 10) return "Telefone inválido";
                                  return null;
                                },
                              ),

                              _buildLabeledInput(
                                label: "Senha",
                                hint: "••••••",
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
                                validator: (v) {
                                  if (v!.isEmpty) return "Campo obrigatório";
                                  if (!_senhaValida) {
                                    return "A senha não atende aos requisitos";
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 4),
                              _buildSenhaIndicador(
                                "Pelo menos 6 caracteres",
                                _temMinCaracteres,
                              ),
                              _buildSenhaIndicador(
                                "Letra maiúscula",
                                _temMaiuscula,
                              ),
                              _buildSenhaIndicador("Número", _temNumero),
                              _buildSenhaIndicador(
                                "Caractere especial (!@#\$...)",
                                _temEspecial,
                              ),
                              const SizedBox(height: 8),

                              _buildLabeledInput(
                                label: "Confirmar senha",
                                hint: "••••••",
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
                                validator: (v) {
                                  if (v!.isEmpty) return "Campo obrigatório";
                                  if (v != _senhaController.text) {
                                    return "As senhas não coincidem";
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      // Lógica de cadastro
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4C3BCF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: const Text(
                                    "Cadastrar-se",
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
                                  onPressed: () => Navigator.pop(context),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
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
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
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
