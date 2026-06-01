// Permite adicionar saldo fictício à carteira para demonstrar negociações.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show TextInputFormatter, TextEditingValue, TextSelection;
import 'tela_home.dart';
import '../services/auth_session.dart';
import '../services/functions_api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';

/// Formulário de depósito simulado conectado à Function da carteira.
class TelaAdicionarCredito extends StatefulWidget {
  const TelaAdicionarCredito({super.key});

  @override
  State<TelaAdicionarCredito> createState() => _TelaAdicionarCreditoState();
}

class _TelaAdicionarCreditoState extends State<TelaAdicionarCredito> {
  final TextEditingController _valorController = TextEditingController();
  bool _salvandoCredito = false;

  static const _azulPrimario = Color(0xFF3F51B5);
  static const _roxo = Color(0xFF4C3BCF);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quanto você vai depositar?',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Valor',
                      style: TextStyle(
                        color: themeColors.mutedText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _valorController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_CurrencyInputFormatter()],
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Valor do depósito',
                        hintText: 'R\$ 0,00',
                        labelStyle: TextStyle(
                          color: themeColors.mutedText,
                          fontSize: 13,
                        ),
                        hintStyle: TextStyle(
                          color: themeColors.faintText,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 18,
                        ),
                        filled: true,
                        fillColor: colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: themeColors.panelBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: themeColors.panelBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: _azulPrimario,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildConfirmarButton(context),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      decoration: BoxDecoration(
        color: _azulPrimario,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            iconSize: 24,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Adicionar crédito à carteira',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmarButton(BuildContext context) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        decoration: BoxDecoration(
          color: themeColors.elevatedSurface,
          border: Border(top: BorderSide(color: themeColors.panelBorder)),
          boxShadow: [
            BoxShadow(
              color: themeColors.shadow.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _salvandoCredito ? null : _adicionarCredito,
            style: ElevatedButton.styleFrom(
              backgroundColor: _roxo,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _salvandoCredito
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Confirmar depósito',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }

  /// Valida o valor, solicita o crédito ao backend e informa o resultado.
  Future<void> _adicionarCredito() async {
    final valor = _lerValorDigitado(_valorController.text);

    if (valor == null || valor <= 0) {
      await _mostrarPopup(
        titulo: 'Valor inválido',
        mensagem: 'Informe um valor maior que zero para adicionar créditos.',
      );
      return;
    }

    final uid = _uid;
    if (uid == null) {
      await _mostrarPopup(
        titulo: 'Erro ao adicionar créditos',
        mensagem: 'Usuário não autenticado.',
      );
      return;
    }

    setState(() => _salvandoCredito = true);

    try {
      await FunctionsApiClient.instance.post(
        'walletAddCredit',
        body: {'valor': valor},
      );

      if (!mounted) return;
      _valorController.clear();

      await _mostrarPopup(
        titulo: 'Créditos adicionados',
        mensagem:
            '${_formatarMoeda(valor)} foram adicionados à sua carteira com sucesso.',
      );
      if (!mounted) return;
      // Volta para a home após adicionar o crédito.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const TelaHome(nomeDigitado: 'tela_home'),
        ),
        (route) => false,
      );
    } on FunctionsApiException catch (error) {
      if (!mounted) return;
      await _mostrarPopup(
        titulo: 'Erro ao adicionar créditos',
        mensagem: error.message,
      );
    } catch (_) {
      if (!mounted) return;
      await _mostrarPopup(
        titulo: 'Erro ao adicionar créditos',
        mensagem: 'Não foi possível adicionar os créditos. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _salvandoCredito = false);
    }
  }

  Future<void> _mostrarPopup({
    required String titulo,
    required String mensagem,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(titulo),
          content: Text(mensagem),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(backgroundColor: _roxo),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Com o _CurrencyInputFormatter, o texto está sempre em "R$ X.XXX,YY".
  // Basta extrair os dígitos e dividir por 100.
  double? _lerValorDigitado(String texto) {
    final digits = texto.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    final centavos = int.tryParse(digits) ?? 0;
    if (centavos <= 0) return null;
    return centavos / 100;
  }

  String _formatarMoeda(double valor) {
    final partes = valor.toStringAsFixed(2).split('.');
    final reais = partes.first;
    final centavos = partes.last;
    final buffer = StringBuffer();

    for (var i = 0; i < reais.length; i++) {
      final posicaoRestante = reais.length - i;
      buffer.write(reais[i]);
      if (posicaoRestante > 1 && posicaoRestante % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'R\$ ${buffer.toString()},$centavos';
  }

  Widget _buildBottomNav(BuildContext context) {
    return AppBottomNav(
      selectedIndex: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      onItemSelected: (index) {
        if (index == 0) Navigator.pop(context);
      },
    );
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    // Limita a 11 dígitos → máx R$ 999.999.999,99
    final clamped = digits.length > 11
        ? digits.substring(digits.length - 11)
        : digits;
    final centavos = int.parse(clamped);
    final reais = centavos ~/ 100;
    final cents = centavos % 100;

    final reaisStr = reais.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < reaisStr.length; i++) {
      final remaining = reaisStr.length - i;
      buffer.write(reaisStr[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
    }

    final formatted =
        'R\$ ${buffer.toString()},${cents.toString().padLeft(2, '0')}';
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
