import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'tela_redefinir_senha.dart';

class TelaVerificacaoCodigo extends StatefulWidget {
  const TelaVerificacaoCodigo({
    super.key,
    required this.email,
    required this.resetId,
    this.initialMessage,
    this.devCode,
  });

  final String email;
  final String resetId;
  final String? initialMessage;
  final String? devCode;

  @override
  State<TelaVerificacaoCodigo> createState() => _TelaVerificacaoCodigoState();
}

class _TelaVerificacaoCodigoState extends State<TelaVerificacaoCodigo> {
  static const _codeLength = 4;

  final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );

  late String _email;
  late String _resetId;
  String? _mensagem;
  String? _erro;
  String? _devCode;
  bool _carregando = false;
  bool _reenviando = false;

  String get _codigo =>
      _controllers.map((controller) => controller.text).join();

  @override
  void initState() {
    super.initState();
    _email = widget.email;
    _resetId = widget.resetId;
    _mensagem = widget.initialMessage;
    _devCode = widget.devCode;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verificarCodigo() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _erro = null;
      _mensagem = null;
    });

    if (_codigo.length != _codeLength) {
      setState(() => _erro = 'Digite o código completo.');
      return;
    }

    setState(() => _carregando = true);

    try {
      final verificacao = await AuthService().verifyPasswordResetCode(
        email: _email,
        resetId: _resetId,
        code: _codigo,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TelaRedefinirSenha(
            email: _email,
            resetId: _resetId,
            resetToken: verificacao.resetToken,
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _erro = error.message);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _reenviarCodigo() async {
    setState(() {
      _erro = null;
      _mensagem = null;
      _reenviando = true;
    });

    try {
      final solicitacao = await AuthService().forgotPassword(email: _email);

      if (!mounted) return;

      _limparCodigo();
      setState(() {
        _email = solicitacao.email;
        _resetId = solicitacao.resetId;
        _mensagem = solicitacao.message;
        _devCode = solicitacao.devCode;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _erro = error.message);
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  void _limparCodigo() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes.first.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final bloqueado = _carregando || _reenviando;

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
                  onPressed: bloqueado ? null : () => Navigator.pop(context),
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
                            Text(
                              'Digite o código enviado para $_email',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                _codeLength,
                                (index) => _buildOtpBox(index, bloqueado),
                              ),
                            ),
                            if (_mensagem != null) ...[
                              const SizedBox(height: 16),
                              _buildStatusMessage(
                                _mensagem!,
                                Colors.green,
                                Icons.check_circle_outline,
                              ),
                            ],
                            if (_devCode != null) ...[
                              const SizedBox(height: 10),
                              _buildStatusMessage(
                                'Código de desenvolvimento: $_devCode',
                                const Color(0xFFB26A00),
                                Icons.code,
                              ),
                            ],
                            if (_erro != null) ...[
                              const SizedBox(height: 16),
                              _buildStatusMessage(
                                _erro!,
                                Colors.red,
                                Icons.error_outline,
                              ),
                            ],
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: bloqueado ? null : _verificarCodigo,
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
                                        'Verificar código',
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
                              onPressed: bloqueado ? null : _reenviarCodigo,
                              child: Text(
                                _reenviando
                                    ? 'Reenviando código...'
                                    : 'Não recebeu o código? Reenviar',
                                style: const TextStyle(
                                  color: Color(0xFF4C3BCF),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildOtpBox(int index, bool bloqueado) {
    return Container(
      width: 55,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0D0E0)),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        enabled: !bloqueado,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4C3BCF),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < _codeLength - 1) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
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
}
