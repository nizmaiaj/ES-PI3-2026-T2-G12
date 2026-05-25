import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../services/balcao_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';

class BalcaoVenda extends StatefulWidget {
  const BalcaoVenda({
    super.key,
    required this.startup,
    required this.tokensDisponiveis,
    required this.precoAtual,
    this.onNavigate,
  });

  final Map<String, String> startup;
  final int tokensDisponiveis;
  final double precoAtual;
  final Function(int)? onNavigate;

  @override
  State<BalcaoVenda> createState() => _BalcaoVendaState();
}

class _BalcaoVendaState extends State<BalcaoVenda> {
  static const _azulPrimario = Color(0xFF3F51B5);
  static const _rosaVenda = Color(0xFFC928B8);
  static const _erro = Color(0xFFFF3B30);

  final BalcaoService _balcaoService = BalcaoService();
  final TextEditingController _precoController = TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();
  bool _processando = false;

  @override
  void dispose() {
    _precoController.dispose();
    _quantidadeController.dispose();
    super.dispose();
  }

  String get _nomeStartup => widget.startup['nome'] ?? 'Nome';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

  String? get _startupId {
    final id = widget.startup['id']?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  double get _precoInformado => _numero(_precoController.text);

  int get _quantidadeInformada =>
      int.tryParse(_quantidadeController.text.trim()) ?? 0;

  bool get _precoValido => _precoInformado > 0;

  bool get _quantidadeValida => _quantidadeInformada > 0;

  bool get _temTokens => widget.tokensDisponiveis > 0;

  bool get _quantidadeDentroDaCarteira =>
      _quantidadeInformada <= widget.tokensDisponiveis;

  bool get _podeVender =>
      _temTokens &&
      _uid != null &&
      _startupId != null &&
      !_processando &&
      _precoValido &&
      _quantidadeValida &&
      _quantidadeDentroDaCarteira;

  double get _totalEstimado => _precoValido && _quantidadeValida
      ? _precoInformado * _quantidadeInformada
      : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResumoStartup(),
                    const SizedBox(height: 22),
                    _buildCampoPreco(),
                    const SizedBox(height: 22),
                    _buildCampoQuantidade(),
                    const SizedBox(height: 24),
                    _buildTotalEstimado(),
                    const SizedBox(height: 16),
                    _buildTokensDisponiveis(),
                    const SizedBox(height: 14),
                    if (!_temTokens || !_quantidadeDentroDaCarteira)
                      _buildAvisoSaldoInsuficiente(),
                    const SizedBox(height: 104),
                  ],
                ),
              ),
            ),
            _buildVendaFooter(),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 2,
        onItemSelected: _selecionarNav,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 82,
      color: _azulPrimario,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 22),
          const Expanded(
            child: Text(
              'Vender Tokens',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoStartup() {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: themeColors.shadow,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _nomeStartup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                _formatarMoeda(widget.precoAtual),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Qtd de tokens:',
                  style: TextStyle(fontSize: 11, color: themeColors.mutedText),
                ),
              ),
              Text(
                '/Token',
                style: TextStyle(fontSize: 11, color: themeColors.mutedText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampoPreco() {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preço (R\$)',
          style: TextStyle(fontSize: 12, color: themeColors.mutedText),
        ),
        const SizedBox(height: 10),
        _EntradaNegociacao(
          controller: _precoController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (!_precoValido)
          const _MensagemErro('Informe um valor válido para negociação.'),
      ],
    );
  }

  Widget _buildCampoQuantidade() {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Quantidade (tokens)',
              style: TextStyle(fontSize: 12, color: themeColors.mutedText),
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(
                color: _azulPrimario,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
              child: _EntradaNegociacao(
                controller: _quantidadeController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            if (!_quantidadeValida)
              const Expanded(
                child: _MensagemErro('Informe uma quantidade válida de tokens'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTotalEstimado() {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Row(
      children: [
        Text(
          'Total estimado',
          style: TextStyle(fontSize: 12, color: themeColors.mutedText),
        ),
        const Spacer(),
        Text(
          _formatarMoeda(_totalEstimado),
          style: const TextStyle(
            color: _rosaVenda,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildTokensDisponiveis() {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text(
            'Tokens Disponíveis',
            style: TextStyle(fontSize: 12, color: themeColors.mutedText),
          ),
          const Spacer(),
          Text(
            '${widget.tokensDisponiveis}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvisoSaldoInsuficiente() {
    return const _MensagemErro(
      'Você não possui tokens suficientes para realizar esta venda. Verifique sua carteira e tente novamente.',
    );
  }

  Widget _buildVendaFooter() {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
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
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Total estimado da venda',
                value: _formatarMoeda(_totalEstimado),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total estimado',
                      style: TextStyle(
                        color: themeColors.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatarMoeda(_totalEstimado),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _rosaVenda,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(width: 160, child: _buildBotaoVender()),
          ],
        ),
      ),
    );
  }

  Widget _buildBotaoVender() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _podeVender ? _confirmarVenda : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _rosaVenda,
          disabledBackgroundColor: _rosaVenda.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          _processando ? 'Publicando...' : 'Vender',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _confirmarVenda() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final themeColors = Theme.of(
          dialogContext,
        ).extension<AppThemeColors>()!;

        return AlertDialog(
          title: const Text('Publicar ordem de venda?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nomeStartup,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _ConfirmacaoVendaLinha(
                label: 'Quantidade',
                valor: '$_quantidadeInformada tokens',
              ),
              _ConfirmacaoVendaLinha(
                label: 'Preço por token',
                valor: _formatarMoeda(_precoInformado),
              ),
              Divider(color: themeColors.panelBorder),
              _ConfirmacaoVendaLinha(
                label: 'Total estimado',
                valor: _formatarMoeda(_totalEstimado),
                destaque: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: _rosaVenda),
              child: const Text('Publicar venda'),
            ),
          ],
        );
      },
    );

    if (confirmado == true) {
      await _registrarVenda();
    }
  }

  Future<void> _registrarVenda() async {
    final uid = _uid;
    final startupId = _startupId;

    if (uid == null || startupId == null) {
      _mostrarMensagem('Entre na sua conta para publicar uma venda.');
      return;
    }

    setState(() => _processando = true);

    try {
      await _balcaoService.criarOrdemVenda(
        vendedorId: uid,
        startupId: startupId,
        quantidade: _quantidadeInformada,
        preco: _precoInformado,
      );

      _mostrarMensagem('Ordem de venda publicada com sucesso.');

      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseException catch (error) {
      _mostrarMensagem(_mensagemFirebase(error));
    } catch (error) {
      _mostrarMensagem(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  void _selecionarNav(int index) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    if (index != 2) {
      Navigator.pop(context);
    }
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), behavior: SnackBarBehavior.floating),
    );
  }

  String _mensagemFirebase(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'Sem permissão para registrar a venda no Firebase.';
    }

    return error.message ?? 'Não foi possível registrar a venda.';
  }
}

class _ConfirmacaoVendaLinha extends StatelessWidget {
  const _ConfirmacaoVendaLinha({
    required this.label,
    required this.valor,
    this.destaque = false,
  });

  final String label;
  final String valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: themeColors.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              color: destaque
                  ? _BalcaoVendaState._rosaVenda
                  : colorScheme.onSurface,
              fontSize: destaque ? 14 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntradaNegociacao extends StatelessWidget {
  const _EntradaNegociacao({
    required this.controller,
    required this.keyboardType,
    required this.onChanged,
  });

  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: themeColors.elevatedSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _MensagemErro extends StatelessWidget {
  const _MensagemErro(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline,
          color: _BalcaoVendaState._erro,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(fontSize: 12, color: themeColors.mutedText),
          ),
        ),
      ],
    );
  }
}

double _numero(dynamic value, {double fallback = 0}) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is num) return value.toDouble();

  if (value is String) {
    final texto = value.replaceAll('R\$', '').replaceAll(' ', '').trim();
    final normalizado = texto.contains(',')
        ? texto.replaceAll('.', '').replaceAll(',', '.')
        : texto;

    return double.tryParse(normalizado) ?? fallback;
  }

  return fallback;
}

String _formatarMoeda(double value) {
  return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}
