// Gabriel Rocca Padua dos Santos - RA: 25002330
// Etapa legada de revisão final da compra e confirmação por senha.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../services/balcao_service.dart';
import '../services/password_reauthentication_service.dart';
import '../theme/app_theme.dart';

/// Resume a compra e exige reautenticação antes de alterar a carteira.
class TelaBalcaoFinalizacaoCompra extends StatefulWidget {
  const TelaBalcaoFinalizacaoCompra({
    super.key,
    required this.startup,
    required this.quantidade,
    required this.total,
    required this.saldoDisponivel,
    required this.onNavigate,
    required this.onCarteiraAlterada,
    this.ofertaId,
    this.precoFinal,
  });

  final Map<String, String> startup;
  final int quantidade;
  final double total;
  final double saldoDisponivel;
  final Function(int) onNavigate;
  final VoidCallback onCarteiraAlterada;
  final String? ofertaId;
  final double? precoFinal;

  @override
  State<TelaBalcaoFinalizacaoCompra> createState() =>
      _TelaBalcaoFinalizacaoCompraState();
}

class _TelaBalcaoFinalizacaoCompraState
    extends State<TelaBalcaoFinalizacaoCompra> {
  static const _azulPrimario = Color(0xFF3F51B5);

  final _senhaController = TextEditingController();
  final _balcaoService = BalcaoService();

  bool _mostrarConfirmacaoSenha = false;
  bool _erroSenha = false;
  bool _processando = false;
  bool _senhaVisivel = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

  String? get _startupId {
    final id = widget.startup['id']?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  String get _nomeStartup => widget.startup['nome'] ?? 'Startup';

  // Usa precoFinal (da oferta) se disponível, senão o preço atual da startup
  double get _preco =>
      widget.precoFinal ??
      _numero(widget.startup['valorToken'], fallback: 1.45);

  @override
  void dispose() {
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _azulPrimario,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Comprar Tokens',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardToken(),
              const SizedBox(height: 24),
              if (!_mostrarConfirmacaoSenha) ...[
                _buildResumo(),
                const SizedBox(height: 32),
                _buildBotaoConfirmar(),
              ] else ...[
                _buildConfirmacaoSenha(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardToken() {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nomeStartup,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Qtd: ${widget.quantidade} tokens',
                style: TextStyle(color: themeColors.mutedText, fontSize: 12),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R\$ ${_formatarNumero(_preco)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '/Token',
                style: TextStyle(color: themeColors.mutedText, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumo() {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preço (R\$)', style: TextStyle(color: themeColors.mutedText)),
        const SizedBox(height: 8),
        _campoReadonly('R\$ ${_formatarNumero(_preco)}'),
        const SizedBox(height: 20),
        Text(
          'Quantidade (tokens)',
          style: TextStyle(color: themeColors.mutedText),
        ),
        const SizedBox(height: 8),
        _campoReadonly('${widget.quantidade}'),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total estimado',
              style: TextStyle(color: themeColors.mutedText),
            ),
            Text(
              'R\$ ${_formatarNumero(widget.total)}',
              style: const TextStyle(
                color: _azulPrimario,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: themeColors.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saldo disponível',
                style: TextStyle(color: themeColors.mutedText),
              ),
              Text(
                'R\$ ${_formatarNumero(widget.saldoDisponivel)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _campoReadonly(String valor) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(valor, style: TextStyle(color: colorScheme.onSurface)),
    );
  }

  Widget _buildBotaoConfirmar() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _processando
            ? null
            : () => setState(() => _mostrarConfirmacaoSenha = true),
        style: ElevatedButton.styleFrom(
          backgroundColor: _azulPrimario,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Comprar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildConfirmacaoSenha() {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => setState(() {
                _mostrarConfirmacaoSenha = false;
                _erroSenha = false;
                _senhaController.clear();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: themeColors.subtleSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'X',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          Text(
            'Confirme sua identidade para concluir a compra',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Por segurança, informe sua senha para finalizar a transação e confirmar a aquisição dos tokens.',
            style: TextStyle(color: themeColors.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Text(
            'Digite a sua senha',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _senhaController,
            obscureText: !_senhaVisivel,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              fillColor: colorScheme.surface,
              filled: true,
              hintText: '••••••',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _senhaVisivel ? Icons.visibility : Icons.visibility_off,
                  color: themeColors.mutedText,
                ),
                onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_erroSenha) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Senha inválida.\nNão foi possível confirmar sua identidade e, por segurança, a compra dos tokens não foi realizada. Verifique sua senha e tente novamente.',
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _processando ? null : _finalizarCompra,
              style: ElevatedButton.styleFrom(
                backgroundColor: _azulPrimario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _processando
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Finalizar transação',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Confirma a identidade e chama o endpoint adequado para concluir a compra.
  Future<void> _finalizarCompra() async {
    final uid = _uid;
    final startupId = _startupId;

    if (uid == null || startupId == null) {
      _mostrarMensagem('Dados inválidos. Tente novamente.');
      return;
    }

    setState(() {
      _processando = true;
      _erroSenha = false;
    });

    try {
      await reauthenticateCurrentUserWithPassword(_senhaController.text);

      // Usa comprarDeOferta quando veio de uma oferta específica,
      // senão comprarDiretamente ao preço atual da startup
      final ofertaId = widget.ofertaId;
      if (ofertaId != null) {
        await _balcaoService.comprarDeOferta(
          compradorId: uid,
          ofertaId: ofertaId,
          quantidade: widget.quantidade,
        );
      } else {
        await _balcaoService.comprarDiretamente(
          compradorId: uid,
          startupId: startupId,
          quantidade: widget.quantidade,
          preco: _preco,
        );
      }

      widget.onCarteiraAlterada();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Compra realizada com sucesso!',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      widget.onNavigate(0);
      Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseAuthException {
      setState(() => _erroSenha = true);
    } on FirebaseException catch (e) {
      _mostrarMensagem(e.message ?? 'Não foi possível concluir a operação.');
    } catch (e) {
      _mostrarMensagem(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), behavior: SnackBarBehavior.floating),
    );
  }
}

String _formatarNumero(double value) =>
    value.toStringAsFixed(2).replaceAll('.', ',');

double _numero(dynamic value, {double fallback = 0}) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final t = value.replaceAll('R\$', '').replaceAll(' ', '').trim();
    final n = t.contains(',') ? t.replaceAll('.', '').replaceAll(',', '.') : t;
    return double.tryParse(n) ?? fallback;
  }
  return fallback;
}
