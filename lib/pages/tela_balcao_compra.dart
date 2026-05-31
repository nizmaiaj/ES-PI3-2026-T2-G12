// Gabriel Rocca Padua dos Santos - RA: 25002330

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../services/balcao_service.dart';
import '../services/password_reauthentication_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';

class TelaBalcaoCompra extends StatefulWidget {
  const TelaBalcaoCompra({
    super.key,
    required this.startup,
    required this.onNavigate,
    required this.onCarteiraAlterada,
    this.ofertaId,
    this.ofertaPreco,
    this.ofertaMaxQtd,
  });

  final Map<String, String> startup;
  final Function(int) onNavigate;
  final VoidCallback onCarteiraAlterada;
  final String? ofertaId;
  final double? ofertaPreco;
  final int? ofertaMaxQtd;

  @override
  State<TelaBalcaoCompra> createState() => _TelaBalcaoCompraState();
}

class _TelaBalcaoCompraState extends State<TelaBalcaoCompra> {
  static const _azulPrimario = Color(0xFF3F51B5);

  final _quantidadeController = TextEditingController();
  final _balcaoService = BalcaoService();
  bool _erroQuantidade = false;
  bool _processandoCompra = false;
  double _totalEstimado = 0.0;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

  String? get _startupId {
    final id = widget.startup['id']?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  String get _nomeStartup => widget.startup['nome'] ?? 'Startup';

  // Usa o preço da oferta se disponível, caso contrário usa o preço atual da startup
  double get _preco =>
      widget.ofertaPreco ??
      _numero(widget.startup['valorToken'], fallback: 1.45);

  int? get _tokensEmitidos => _quantidadeTokens(widget.startup['tokens']);

  int? get _limiteCompra {
    final tokensEmitidos = _tokensEmitidos;
    final ofertaMaxQtd = widget.ofertaMaxQtd;

    if (tokensEmitidos == null) return ofertaMaxQtd;
    if (ofertaMaxQtd == null) return tokensEmitidos;
    return tokensEmitidos < ofertaMaxQtd ? tokensEmitidos : ofertaMaxQtd;
  }

  bool _quantidadeAcimaDosTokensEmitidos(int quantidade) {
    final tokensEmitidos = _tokensEmitidos;
    return tokensEmitidos != null && quantidade > tokensEmitidos;
  }

  @override
  void initState() {
    super.initState();
    _quantidadeController.addListener(_calcularTotal);
  }

  @override
  void dispose() {
    _quantidadeController.dispose();
    super.dispose();
  }

  void _calcularTotal() {
    final qtd = int.tryParse(_quantidadeController.text.trim()) ?? 0;
    final limiteCompra = _limiteCompra;
    setState(() {
      _totalEstimado = qtd * _preco;
      _erroQuantidade =
          _quantidadeController.text.isNotEmpty &&
          (qtd <= 0 || (limiteCompra != null && qtd > limiteCompra));
    });
  }

  Stream<double> _saldoStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(0.0);
    return FirebaseFirestore.instance
        .collection('wallets')
        .doc(uid)
        .snapshots()
        .map((doc) => _numero(doc.data()?['saldoReais']));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: _saldoStream(),
      builder: (context, snapshot) {
        return _buildTela(snapshot.data ?? 0.0);
      },
    );
  }

  Widget _buildTela(double saldo) {
    final int qtd = int.tryParse(_quantidadeController.text.trim()) ?? 0;
    final bool saldoSuficiente = saldo >= _totalEstimado;
    final limiteCompra = _limiteCompra;
    final bool dentroDoLimite = limiteCompra == null || qtd <= limiteCompra;
    final bool podeComprar =
        qtd > 0 &&
        !_erroQuantidade &&
        _totalEstimado > 0 &&
        saldoSuficiente &&
        dentroDoLimite &&
        !_processandoCompra;
    final bool exibirAvisoSaldo = _totalEstimado > 0 && !saldoSuficiente;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCardToken(),
                    const SizedBox(height: 24),
                    _buildCampoPreco(),
                    const SizedBox(height: 24),
                    _buildCampoQuantidade(),
                    const SizedBox(height: 24),
                    _buildTotalEstimado(),
                    const SizedBox(height: 12),
                    _buildCardSaldo(saldo),
                    if (exibirAvisoSaldo) ...[
                      const SizedBox(height: 16),
                      _buildAvisoSaldo(),
                    ],
                    const SizedBox(height: 104),
                  ],
                ),
              ),
            ),
            _buildCompraFooter(podeComprar, qtd, saldo),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 2,
        onItemSelected: (index) {
          widget.onNavigate(index);
          Navigator.popUntil(context, (route) => route.isFirst);
        },
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      color: _azulPrimario,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 48),
              child: Text(
                'Comprar Tokens',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(14),
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
              const SizedBox(height: 12),
              Text(
                widget.ofertaMaxQtd != null
                    ? 'Disponível: ${widget.ofertaMaxQtd} tokens'
                    : _tokensEmitidos != null
                    ? 'Emitidos: $_tokensEmitidos tokens'
                    : 'Qtd de tokens:',
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
              const SizedBox(height: 12),
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

  Widget _buildCampoPreco() {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preço (R\$)',
          style: TextStyle(
            color: themeColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: themeColors.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            'R\$ ${_formatarNumero(_preco)}',
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoQuantidade() {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantidade (tokens) *',
          style: TextStyle(
            color: themeColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: TextField(
                controller: _quantidadeController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  fillColor: themeColors.elevatedSurface,
                  filled: true,
                  hintText: _limiteCompra != null
                      ? 'Máx: $_limiteCompra'
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_erroQuantidade) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _mensagemErroQuantidade(),
                        style: TextStyle(
                          color: themeColors.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTotalEstimado() {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Total estimado', style: TextStyle(color: themeColors.mutedText)),
        Text(
          'R\$ ${_formatarNumero(_totalEstimado)}',
          style: const TextStyle(
            color: _azulPrimario,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildCardSaldo(double saldo) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            'R\$ ${_formatarNumero(saldo)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvisoSaldo() {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Você não possui saldo suficiente para concluir esta compra. Adicione créditos à sua carteira para continuar.',
            style: TextStyle(
              color: themeColors.mutedText,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompraFooter(bool podeComprar, int qtd, double saldo) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return SafeArea(
      top: false,
      child: Container(
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
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Total estimado da compra',
                value: 'R\$ ${_formatarNumero(_totalEstimado)}',
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
                      'R\$ ${_formatarNumero(_totalEstimado)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _azulPrimario,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 160,
              child: _buildBotaoComprar(podeComprar, qtd, saldo),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotaoComprar(bool podeComprar, int qtd, double saldo) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: podeComprar ? () => _abrirConfirmacaoCompra(qtd) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _azulPrimario,
          disabledBackgroundColor: _azulPrimario.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _processandoCompra
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Comprar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Future<void> _abrirConfirmacaoCompra(int quantidade) async {
    final uid = _uid;
    final startupId = _startupId;

    if (uid == null || startupId == null) {
      _mostrarMensagem('Dados inválidos. Tente novamente.');
      return;
    }

    if (_quantidadeAcimaDosTokensEmitidos(quantidade)) {
      _mostrarMensagem(_mensagemErroQuantidade());
      return;
    }

    final senhaController = TextEditingController();
    var erroSenha = false;
    String? mensagemErro;

    final compraConfirmada = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;
            final themeColors = Theme.of(context).extension<AppThemeColors>()!;

            Future<void> finalizarCompra() async {
              if (_processandoCompra) return;

              if (senhaController.text.isEmpty) {
                setDialogState(() {
                  erroSenha = true;
                  mensagemErro = 'Informe sua senha para confirmar a compra.';
                });
                return;
              }

              setState(() => _processandoCompra = true);
              setDialogState(() {
                erroSenha = false;
                mensagemErro = null;
              });

              try {
                await _executarCompra(
                  uid: uid,
                  startupId: startupId,
                  quantidade: quantidade,
                  senha: senhaController.text,
                );

                widget.onCarteiraAlterada();

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
              } on FirebaseAuthException {
                if (!mounted) return;
                setState(() => _processandoCompra = false);
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  erroSenha = true;
                  mensagemErro = null;
                });
              } on FirebaseException catch (e) {
                if (!mounted) return;
                setState(() => _processandoCompra = false);
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  erroSenha = true;
                  mensagemErro =
                      e.message ?? 'Não foi possível concluir a operação.';
                });
              } catch (e) {
                if (!mounted) return;
                setState(() => _processandoCompra = false);
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  erroSenha = true;
                  mensagemErro = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              backgroundColor: Colors.transparent,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: themeColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Fechar confirmação',
                          onPressed: _processandoCompra
                              ? null
                              : () => Navigator.of(dialogContext).pop(false),
                          icon: Icon(Icons.close, color: colorScheme.onSurface),
                          style: IconButton.styleFrom(
                            backgroundColor: themeColors.subtleSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
                        style: TextStyle(
                          color: themeColors.mutedText,
                          fontSize: 13,
                        ),
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
                        controller: senhaController,
                        obscureText: true,
                        enabled: !_processandoCompra,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => finalizarCompra(),
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          fillColor: colorScheme.surface,
                          filled: true,
                          hintText: '••••••',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (erroSenha) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                mensagemErro ??
                                    'Senha inválida.\nNão foi possível confirmar sua identidade e, por segurança, a compra dos tokens não foi realizada. Verifique sua senha e tente novamente.',
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 12,
                                ),
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
                          onPressed: _processandoCompra
                              ? null
                              : finalizarCompra,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _azulPrimario,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _processandoCompra
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
                ),
              ),
            );
          },
        );
      },
    );

    senhaController.dispose();

    if (compraConfirmada != true || !mounted) return;

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
  }

  Future<void> _executarCompra({
    required String uid,
    required String startupId,
    required int quantidade,
    required String senha,
  }) async {
    await reauthenticateCurrentUserWithPassword(senha);

    final ofertaId = widget.ofertaId;
    if (ofertaId != null) {
      await _balcaoService.comprarDeOferta(
        compradorId: uid,
        ofertaId: ofertaId,
        quantidade: quantidade,
      );
      return;
    }

    await _balcaoService.comprarDiretamente(
      compradorId: uid,
      startupId: startupId,
      quantidade: quantidade,
      preco: _preco,
    );
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), behavior: SnackBarBehavior.floating),
    );
  }

  String _mensagemErroQuantidade() {
    final quantidade = int.tryParse(_quantidadeController.text.trim()) ?? 0;
    final tokensEmitidos = _tokensEmitidos;

    if (tokensEmitidos != null && quantidade > tokensEmitidos) {
      return 'A quantidade desejada é maior que os $tokensEmitidos tokens emitidos pela startup.';
    }

    final ofertaMaxQtd = widget.ofertaMaxQtd;
    if (ofertaMaxQtd != null && quantidade > ofertaMaxQtd) {
      return 'Máximo disponível nesta oferta: $ofertaMaxQtd tokens';
    }

    return 'Informe uma quantidade válida de tokens';
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

int? _quantidadeTokens(dynamic value) {
  if (value is num) return value.toInt();
  if (value is! String) return null;

  final texto = value.replaceAll(RegExp(r'[^\d,.-]'), '').trim();
  if (texto.isEmpty) return null;

  final temSeparadorDeMilhar =
      !texto.contains(',') && RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(texto);
  final normalizado = texto.contains(',')
      ? texto.replaceAll('.', '').replaceAll(',', '.')
      : temSeparadorDeMilhar
      ? texto.replaceAll('.', '')
      : texto;

  return num.tryParse(normalizado)?.toInt();
}
