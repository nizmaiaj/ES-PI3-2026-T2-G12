import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../services/balcao_service.dart';
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
  final BalcaoService _balcaoService = BalcaoService();
  bool _processandoCompra = false;

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

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    return _firestore.collection('orders').snapshots();
  }

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
                    _buildSecaoOfertasVendaReais(),
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

  Widget _buildSecaoOfertasVendaReais() {
    final uid = _uid;
    final startupId = _startupId;

    if (uid == null || startupId == null) {
      return _buildSecaoOfertasVazia(
        'Ofertas de Vendas',
        'Entre na sua conta para ver ofertas de venda.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ordersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildSecaoOfertasVazia(
            'Ofertas de Vendas',
            'Não foi possível carregar as ofertas de venda.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _azulPrimario),
          );
        }

        final ofertas =
            snapshot.data!.docs
                .map(_OrdemVendaAberta.fromDoc)
                .whereType<_OrdemVendaAberta>()
                .where(
                  (ordem) =>
                      ordem.startupId == startupId &&
                      ordem.vendedorId != uid &&
                      ordem.estaDisponivel,
                )
                .toList()
              ..sort((a, b) => a.preco.compareTo(b.preco));

        return _buildSecaoVendas(titulo: 'Ofertas de Vendas', ofertas: ofertas);
      },
    );
  }

  Widget _buildSecaoVendas({
    required String titulo,
    required List<_OrdemVendaAberta> ofertas,
  }) {
    if (ofertas.isEmpty) {
      return _buildSecaoOfertasVazia(
        titulo,
        'Nenhuma oferta de venda aberta para esta startup.',
      );
    }

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
        const _TabelaHeader(comAcao: true),
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
                  (oferta) => _OfertaVendaLinha(
                    oferta: oferta,
                    bloqueado: _processandoCompra,
                    onComprar: () => _confirmarCompraOrdemVenda(oferta),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoOfertasVazia(String titulo, String mensagem) {
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: _cardTabela,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            mensagem,
            style: const TextStyle(color: Colors.black54, fontSize: 10),
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

  Future<void> _confirmarCompraOrdemVenda(_OrdemVendaAberta ordem) async {
    final uid = _uid;

    if (uid == null) {
      _mostrarMensagem('Entre na sua conta para comprar esta oferta.');
      return;
    }

    final quantidade = await showDialog<int>(
      context: context,
      builder: (context) => _QuantidadeDialog(
        startup: _nomeStartup,
        quantidadeMaxima: ordem.quantidadeRestante,
      ),
    );

    if (quantidade == null || quantidade <= 0) return;

    if (_processandoCompra) return;

    setState(() => _processandoCompra = true);

    try {
      await _balcaoService.comprarOrdemVenda(
        compradorId: uid,
        ordemId: ordem.id,
        quantidade: quantidade,
      );

      _mostrarMensagem('Compra registrada com sucesso.');
    } on FirebaseException catch (error) {
      _mostrarMensagem(_mensagemFirebase(error));
    } catch (error) {
      _mostrarMensagem(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _processandoCompra = false);
      }
    }
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

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), behavior: SnackBarBehavior.floating),
    );
  }

  String _mensagemFirebase(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'Sem permissão para acessar estes dados no Firebase.';
    }

    return error.message ?? 'Não foi possível concluir a operação.';
  }
}

class OfertaStartup {
  const OfertaStartup({required this.preco, required this.quantidade});

  final double preco;
  final int quantidade;

  double get total => preco * quantidade;
}

class _OrdemVendaAberta {
  const _OrdemVendaAberta({
    required this.id,
    required this.tipo,
    required this.vendedorId,
    required this.startupId,
    required this.quantidadeRestante,
    required this.preco,
    required this.status,
  });

  factory _OrdemVendaAberta.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return _OrdemVendaAberta(
      id: doc.id,
      tipo: _texto(data['tipo']).toLowerCase(),
      vendedorId: _texto(data['sellerId'] ?? data['userId']),
      startupId: _texto(data['startupId']),
      quantidadeRestante: _quantidadeRestante(data),
      preco: _numero(data['preco'] ?? data['precoUnitario']),
      status: _texto(data['status']).toLowerCase(),
    );
  }

  final String id;
  final String tipo;
  final String vendedorId;
  final String startupId;
  final int quantidadeRestante;
  final double preco;
  final String status;

  double get total => preco * quantidadeRestante;

  bool get estaDisponivel =>
      tipo == 'venda' && _statusAberto(status) && quantidadeRestante > 0;
}

class _TabelaHeader extends StatelessWidget {
  const _TabelaHeader({this.comAcao = false});

  final bool comAcao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          const _TabelaCelula('Preço (R\$)'),
          const _TabelaCelula('Quantidade'),
          const _TabelaCelula('Total (R\$)'),
          if (comAcao) const SizedBox(width: 84),
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

class _OfertaVendaLinha extends StatelessWidget {
  const _OfertaVendaLinha({
    required this.oferta,
    required this.bloqueado,
    required this.onComprar,
  });

  final _OrdemVendaAberta oferta;
  final bool bloqueado;
  final VoidCallback onComprar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          _TabelaCelula(
            _formatarNumero(oferta.preco),
            color: _BalcaoOfertasDaStartupState._rosaVenda,
            fontWeight: FontWeight.w700,
          ),
          _TabelaCelula(
            '${oferta.quantidadeRestante}',
            fontWeight: FontWeight.w700,
          ),
          _TabelaCelula(
            _formatarNumero(oferta.total),
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            height: 30,
            child: ElevatedButton(
              onPressed: bloqueado ? null : onComprar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _BalcaoOfertasDaStartupState._azulPrimario,
                disabledBackgroundColor: _BalcaoOfertasDaStartupState
                    ._azulPrimario
                    .withValues(alpha: 0.4),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Comprar', style: TextStyle(fontSize: 11)),
            ),
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

class _QuantidadeDialog extends StatefulWidget {
  const _QuantidadeDialog({
    required this.startup,
    required this.quantidadeMaxima,
  });

  final String startup;
  final int quantidadeMaxima;

  @override
  State<_QuantidadeDialog> createState() => _QuantidadeDialogState();
}

class _QuantidadeDialogState extends State<_QuantidadeDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Comprar tokens'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.startup),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantidade',
              helperText: 'Máximo: ${widget.quantidadeMaxima}',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final quantidade = int.tryParse(_controller.text.trim()) ?? 0;
            if (quantidade <= 0 || quantidade > widget.quantidadeMaxima) {
              return;
            }

            Navigator.pop(context, quantidade);
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

bool _statusAberto(String status) {
  return status == 'aberta' ||
      status == 'parcial' ||
      status == 'pendente' ||
      status.contains('aguardando');
}

int _quantidadeRestante(Map<String, dynamic> order) {
  final restante = _numero(order['quantidadeRestante']).toInt();
  if (restante > 0) return restante;

  final quantidade = _numero(order['quantidade']).toInt();
  final executada = _numero(order['quantidadeExecutada']).toInt();
  final calculada = quantidade - executada;
  return calculada < 0 ? 0 : calculada;
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
