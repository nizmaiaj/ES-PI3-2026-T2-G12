import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TelaVerificacaoCodigo extends StatefulWidget {
  final String email;
  const TelaVerificacaoCodigo({super.key, required this.email});

  @override
  State<TelaVerificacaoCodigo> createState() => _TelaVerificacaoCodigoState();
}

class _TelaVerificacaoCodigoState extends State<TelaVerificacaoCodigo> {
  // Estrutura de controladores e foco para os 4 campos de código
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    // Limpeza obrigatória para evitar vazamento de memória (padrão de estrutura)
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // Gradiente de fundo conforme a imagem
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6A89FE), // Azul topo
              Color(0xFFFB639E), // Rosa base
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              // Identidade Visual
              Image.asset('assets/logo_mescla.png', height: 80),
              const SizedBox(height: 12),
              const Text(
                "MesclaInvest",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // CAIXA CINZA (Estrutura idêntica às outras telas)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Esqueci a senha",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Digite o código enviado para o seu e-mail",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Linha com os 4 campos de entrada (OTP)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        4,
                        (index) => _buildOtpBox(index),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Botão de Ação Principal
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          // Lógica para validar o código (removido o print conforme solicitado)
                          // String code = _controllers.map((e) => e.text).join();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C3BCF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          "Verificar Código",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Link Secundário
                    TextButton(
                      onPressed: () {
                        // Lógica para reenviar código
                      },
                      child: const Text(
                        "Não recebeu o código? Reenviar código",
                        style: TextStyle(color: Colors.blue, fontSize: 12),
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

  // Método auxiliar para manter o padrão de componentes limpos
  Widget _buildOtpBox(int index) {
    return Container(
      width: 50,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        inputFormatters: [
          FilteringTextInputFormatter
              .digitsOnly, // Garante que só números sejam digitados
        ],
        decoration: const InputDecoration(
          counterText: "", // Esconde o contador de caracteres do maxLength
          border: InputBorder.none,
        ),
        onChanged: (value) {
          // Lógica de navegação automática de foco
          if (value.isNotEmpty && index < 3) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}
