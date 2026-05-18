import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../widgets/app_bottom_nav.dart';
import 'balcao_venda.dart';

class BalcaoOfertasDaStartup extends StatefulWidget {
  const BalcaoOfertasDaStartup({
    super.key,
    required this.startup,
    this.onNavigate,
  });

  final Map<String, String> startup;
  final Function(int)? onNavigate;

  @override
  State<BalcaoOfertasDaStartup> createState() => _BalcaoOfertasDaStartupState();
}

class _BalcaoOfertasDaStartupState extends State<BalcaoOfertasDaStartup> {
  static const _azulPrimario = Color(0xFF3F51B5);
  static const _rosaVenda = Color(0xFFC928B8);
  static const _fundo = Color(0xFFF8F9FE);
  static const _cardTabela = Color(0xFFD9D9D9);
  static const _textoEscuro = Color(0xFF111111);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<OfertaStartup> get _ofertasCompra {
    final preco = _precoAtual;
    final variacao = _variacaoPreco;

    return [
      OfertaStartup(preco: preco, quantidade: 50),
      OfertaStartup(preco: _precoComPiso(preco - variacao), quantidade: 120),
      OfertaStartup(
        preco: _precoComPiso(preco - (variacao * 2)),
        quantidade: 200,
      ),
      OfertaStartup(
        preco: _precoComPiso(preco - (variacao * 3)),
        quantidade: 150,
      ),
      OfertaStartup(
        preco: _precoComPiso(preco - (variacao * 4)),
        quantidade: 100,
      ),
    ];
  }

  List<OfertaStartup> get _ofertasVenda {
    final preco = _precoAtual;
    final variacao = _variacaoPreco;

    return [
      OfertaStartup(preco: preco + variacao, quantidade: 40),
      OfertaStartup(preco: preco + (variacao * 2), quantidade: 80),
      OfertaStartup(preco: preco + (variacao * 3), quantidade: 150),
      OfertaStartup(preco: preco + (variacao * 4), quantidade: 120),
      OfertaStartup(preco: preco + (variacao * 5), quantidade: 200),
    ];
  }

  List<OfertaStartup> _ordenadas(List<OfertaStartup> ofertas) {
    return [...ofertas]..sort((a, b) => a.preco.compareTo(b.preco));
  }

  String get _nomeStartup => widget.startup['nome'] ?? 'Nome da startup';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

  String? get _startupId {
    final id = widget.startup['id']?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  int get _tokensCarteiraInicial =>
      _numero(widget.startup['tokensCarteira']).toInt();

  double get _precoAtual =>
      _numero(widget.startup['valorToken'], fallback: 1.45);

  double get _variacaoPreco => _precoAtual >= 10 ? 1 : 0.01;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPrecoAtual(),
                    const SizedBox(height: 22),
                    _buildSecaoOfertas(
                      titulo: 'Ofertas de Compras',
                      ofertas: _ordenadas(_ofertasCompra),
                      precoColor: _azulPrimario,
                    ),
                    const SizedBox(height: 28),
                    _buildSecaoOfertas(
                      titulo: 'Ofertas de Vendas',
                      ofertas: _ordenadas(_ofertasVenda),
                      precoColor: _rosaVenda,
                    ),
                    const SizedBox(height: 34),
                    _buildAcoesCarteira(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onItemSelected: _selecionarNav,
        backgroundColor: _fundo,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 100,
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _nomeStartup,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
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

  Widget _buildPrecoAtual() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preço atual:',
          style: TextStyle(color: Colors.black54, fontSize: 10),
        ),
        const SizedBox(height: 18),
        Text(
          _formatarMoeda(_precoAtual, comEspaco: true),
          style: const TextStyle(
            color: _textoEscuro,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoOfertas({
    required String titulo,
    required List<OfertaStartup> ofertas,
    required Color precoColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: _textoEscuro,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const _TabelaHeader(),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _cardTabela,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: ofertas
                .map(
                  (oferta) =>
                      _OfertaLinha(oferta: oferta, precoColor: precoColor),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAcoesCarteira() {
    final stream = _tokensDisponiveisStream();

    if (stream == null) {
      return _buildAcoes(tokensDisponiveis: _tokensCarteiraInicial);
    }

    return StreamBuilder<int>(
      stream: stream,
      initialData: _tokensCarteiraInicial,
      builder: (context, snapshot) {
        return _buildAcoes(tokensDisponiveis: snapshot.data ?? 0);
      },
    );
  }

  Widget _buildAcoes({required int tokensDisponiveis}) {
    return Row(
      children: [
        Expanded(
          child: _AcaoButton(
            texto: 'Comprar',
            cor: _azulPrimario,
            onPressed: () {},
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _AcaoButton(
            texto: 'Vender',
            cor: _rosaVenda,
            onPressed: tokensDisponiveis > 0
                ? () => _abrirVenda(tokensDisponiveis)
                : null,
          ),
        ),
      ],
    );
  }

  Stream<int>? _tokensDisponiveisStream() {
    final uid = _uid;
    final startupId = _startupId;

    if (uid == null || startupId == null) return null;

    return _firestore
        .collection('tokenHoldings')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          var total = 0;

          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (_texto(data['startupId']) == startupId) {
              total += _numero(data['quantidade']).toInt();
            }
          }

          return total;
        });
  }

  void _abrirVenda(int tokensDisponiveis) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BalcaoVenda(
          startup: widget.startup,
          tokensDisponiveis: tokensDisponiveis,
          precoAtual: _precoAtual,
          onNavigate: widget.onNavigate,
        ),
      ),
    );
  }

  void _selecionarNav(int index) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    if (index != 1) {
      Navigator.pop(context);
    }
  }
}

class OfertaStartup {
  const OfertaStartup({required this.preco, required this.quantidade});

  final double preco;
  final int quantidade;

  double get total => preco * quantidade;
}

class _TabelaHeader extends StatelessWidget {
  const _TabelaHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          _TabelaCelula('Preço (R\$)'),
          _TabelaCelula('Quantidade'),
          _TabelaCelula('Total (R\$)'),
        ],
      ),
    );
  }
}

class _OfertaLinha extends StatelessWidget {
  const _OfertaLinha({required this.oferta, required this.precoColor});

  final OfertaStartup oferta;
  final Color precoColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          _TabelaCelula(
            _formatarNumero(oferta.preco),
            color: precoColor,
            fontWeight: FontWeight.w700,
          ),
          _TabelaCelula('${oferta.quantidade}', fontWeight: FontWeight.w700),
          _TabelaCelula(
            _formatarNumero(oferta.total),
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
    );
  }
}

class _TabelaCelula extends StatelessWidget {
  const _TabelaCelula(
    this.texto, {
    this.color = Colors.black87,
    this.fontWeight = FontWeight.w400,
  });

  final String texto;
  final Color color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 10, fontWeight: fontWeight),
      ),
    );
  }
}

class _AcaoButton extends StatelessWidget {
  const _AcaoButton({
    required this.texto,
    required this.cor,
    required this.onPressed,
  });

  final String texto;
  final Color cor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 43,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: cor,
          disabledBackgroundColor: cor.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Text(
          texto,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

String _formatarMoeda(double value, {bool comEspaco = false}) {
  final prefixo = comEspaco ? 'R\$  ' : 'R\$ ';
  return '$prefixo${_formatarNumero(value)}';
}

String _formatarNumero(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

double _precoComPiso(double value) {
  return value < 0.01 ? 0.01 : value;
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

String _texto(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;

  final texto = value.toString().trim();
  return texto.isEmpty ? fallback : texto;
}
