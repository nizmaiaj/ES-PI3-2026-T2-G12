// Eduarda Prado Deiró - RA: 25004440

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../services/balcao_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/password_confirmation_dialog.dart';
import 'balcao_venda.dart';
import 'tela_balcao_compra.dart';

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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BalcaoService _balcaoService = BalcaoService();
  bool _processandoCompra = false;

  @override
  void initState() {
    super.initState();
    _seedOfertasSeNecessario();
  }

  Future<void> _seedOfertasSeNecessario() async {
    final startupId = _startupId;
    if (startupId == null) return;

    try {
      await _balcaoService.garantirOfertasCompra(startupId);
    } catch (_) {
      // A tela continua funcional mesmo se a inicialização das ofertas falhar.
    }
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    return _firestore
        .collection('orders')
        .where('status', whereIn: ['aberta', 'parcial'])
        .snapshots();
  }

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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPrecoAtual(),
                    const SizedBox(height: 22),
                    _buildSecaoOfertasCompraReais(),
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
        selectedIndex: 2,
        onItemSelected: _selecionarNav,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preço atual:',
          style: TextStyle(color: themeColors.mutedText, fontSize: 10),
        ),
        const SizedBox(height: 18),
        Text(
          _formatarMoeda(_precoAtual, comEspaco: true),
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoOfertasCompraReais() {
    final startupId = _startupId;

    if (startupId == null) {
      return _buildSecaoOfertasVazia('Ofertas de compra', 'Startup inválida.');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ordersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildSecaoOfertasVazia(
            'Ofertas de compra',
            'Não foi possível carregar as ofertas de compra.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _azulPrimario),
          );
        }

        final ofertas =
            snapshot.data!.docs
                .map(_OfertaCompraSistema.tryFromDoc)
                .whereType<_OfertaCompraSistema>()
                .where((o) => o.startupId == startupId && o.estaDisponivel)
                .toList()
              ..sort((a, b) => a.preco.compareTo(b.preco));

        if (ofertas.isEmpty) {
          return _buildSecaoOfertasVazia(
            'Ofertas de compra',
            'Nenhuma oferta de compra disponível para esta startup.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ofertas de compra',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
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
                color: Theme.of(
                  context,
                ).extension<AppThemeColors>()!.elevatedSurface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).extension<AppThemeColors>()!.shadow,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: ofertas
                    .map(
                      (oferta) => _OfertaCompraLinha(
                        oferta: oferta,
                        onComprar: () => _abrirCompra(oferta: oferta),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
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
            color: Theme.of(
              context,
            ).extension<AppThemeColors>()!.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).extension<AppThemeColors>()!.shadow,
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
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: themeColors.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            mensagem,
            style: TextStyle(color: themeColors.mutedText, fontSize: 10),
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
            onPressed: () => _abrirCompra(),
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

  void _abrirCompra({_OfertaCompraSistema? oferta}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaBalcaoCompra(
          startup: widget.startup,
          onNavigate: widget.onNavigate ?? (_) {},
          onCarteiraAlterada: () {},
          ofertaId: oferta?.id,
          ofertaPreco: oferta?.preco,
          ofertaMaxQtd: oferta?.quantidadeRestante,
        ),
      ),
    );
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

    if (quantidade == null || quantidade <= 0 || !mounted) return;

    final confirmado = await showPasswordConfirmationDialog(context: context);

    if (!confirmado) return;

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
      return 'Sem permissão para acessar estes dados no Firebase.';
    }

    return error.message ?? 'Não foi possível concluir a operação.';
  }
}

class _OfertaCompraSistema {
  const _OfertaCompraSistema({
    required this.id,
    required this.startupId,
    required this.preco,
    required this.quantidadeRestante,
    required this.status,
  });

  static _OfertaCompraSistema? tryFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final tipo = _texto(data['tipo']).toLowerCase();
    if (tipo != 'ofertacompra') return null;
    return _OfertaCompraSistema(
      id: doc.id,
      startupId: _texto(data['startupId']),
      preco: _numero(data['preco'] ?? data['precoUnitario']),
      quantidadeRestante: _quantidadeRestante(data),
      status: _texto(data['status']).toLowerCase(),
    );
  }

  final String id;
  final String startupId;
  final double preco;
  final int quantidadeRestante;
  final String status;

  double get total => preco * quantidadeRestante;
  bool get estaDisponivel => _statusAberto(status) && quantidadeRestante > 0;
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

class _OfertaCompraLinha extends StatelessWidget {
  const _OfertaCompraLinha({required this.oferta, required this.onComprar});

  final _OfertaCompraSistema oferta;
  final VoidCallback onComprar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          _TabelaCelula(
            _formatarNumero(oferta.preco),
            color: _BalcaoOfertasDaStartupState._azulPrimario,
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
              onPressed: onComprar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _BalcaoOfertasDaStartupState._azulPrimario,
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
    this.color,
    this.fontWeight = FontWeight.w400,
  });

  final String texto;
  final Color? color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.onSurface;

    return Expanded(
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: resolvedColor,
          fontSize: 10,
          fontWeight: fontWeight,
        ),
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
