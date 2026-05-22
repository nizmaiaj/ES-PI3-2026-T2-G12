import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../widgets/app_bottom_nav.dart';
import 'tela_balcao_finalizacao_compra.dart';

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
  static const _fundo = Color(0xFFF8F9FE);
  static const _cinza = Color(0xFFEEEEF5);

  final _quantidadeController = TextEditingController();
  bool _erroQuantidade = false;
  double _totalEstimado = 0.0;

  String? get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

  String get _nomeStartup => widget.startup['nome'] ?? 'Startup';

  // Usa o preço da oferta se disponível, caso contrário usa o preço atual da startup
  double get _preco =>
      widget.ofertaPreco ??
      _numero(widget.startup['valorToken'], fallback: 1.45);

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
    final max = widget.ofertaMaxQtd;
    setState(() {
      _totalEstimado = qtd * _preco;
      _erroQuantidade = _quantidadeController.text.isNotEmpty &&
          (qtd <= 0 || (max != null && qtd > max));
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
    final bool dentroDoLimite =
        widget.ofertaMaxQtd == null || qtd <= widget.ofertaMaxQtd!;
    final bool podeComprar = qtd > 0 &&
        !_erroQuantidade &&
        _totalEstimado > 0 &&
        saldoSuficiente &&
        dentroDoLimite;
    final bool exibirAvisoSaldo = _totalEstimado > 0 && !saldoSuficiente;

    return Scaffold(
      backgroundColor: _fundo,
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
                    const SizedBox(height: 32),
                    _buildBotaoComprar(podeComprar, qtd, saldo),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 2,
        onItemSelected: (index) {
          widget.onNavigate(index);
          Navigator.popUntil(context, (route) => route.isFirst);
        },
        backgroundColor: _fundo,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cinza,
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.ofertaMaxQtd != null
                    ? 'Disponível: ${widget.ofertaMaxQtd} tokens'
                    : 'Qtd de tokens:',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R\$ ${_formatarNumero(_preco)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '/Token',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampoPreco() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preço (R\$)',
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _cinza,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            'R\$ ${_formatarNumero(_preco)}',
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoQuantidade() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quantidade (tokens) *',
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
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
                decoration: InputDecoration(
                  fillColor: _cinza,
                  filled: true,
                  hintText: widget.ofertaMaxQtd != null
                      ? 'Máx: ${widget.ofertaMaxQtd}'
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
                        widget.ofertaMaxQtd != null
                            ? 'Máximo disponível: ${widget.ofertaMaxQtd} tokens'
                            : 'Informe uma quantidade válida de tokens',
                        style: const TextStyle(
                          color: Colors.black87,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total estimado',
          style: TextStyle(color: Colors.black54),
        ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cinza,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Saldo Disponível',
            style: TextStyle(color: Colors.black54),
          ),
          Text(
            'R\$ ${_formatarNumero(saldo)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvisoSaldo() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, color: Colors.red, size: 22),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Você não possui saldo suficiente para concluir esta compra. Adicione créditos à sua carteira para continuar.',
            style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.3),
          ),
        ),
      ],
    );
  }

  Widget _buildBotaoComprar(bool podeComprar, int qtd, double saldo) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: podeComprar ? () => _irParaFinalizacao(qtd, saldo) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _azulPrimario,
          disabledBackgroundColor: _azulPrimario.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Comprar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _irParaFinalizacao(int quantidade, double saldo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaBalcaoFinalizacaoCompra(
          startup: widget.startup,
          quantidade: quantidade,
          total: _totalEstimado,
          saldoDisponivel: saldo,
          ofertaId: widget.ofertaId,
          precoFinal: widget.ofertaPreco,
          onNavigate: widget.onNavigate,
          onCarteiraAlterada: widget.onCarteiraAlterada,
        ),
      ),
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
    final n = t.contains(',')
        ? t.replaceAll('.', '').replaceAll(',', '.')
        : t;
    return double.tryParse(n) ?? fallback;
  }
  return fallback;
}
