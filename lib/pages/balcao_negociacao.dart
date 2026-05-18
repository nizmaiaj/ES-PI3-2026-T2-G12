import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../services/balcao_service.dart';
import 'balcao_ofertas_da_satartup.dart';
import 'balcao_minhasordens.dart';
import 'balcao_venda.dart';
import 'no_animation_route.dart';

class BalcaoNegociacao extends StatefulWidget {
  final Function(int)? onNavigate;
  final VoidCallback? onCarteiraAlterada;

  const BalcaoNegociacao({super.key, this.onNavigate, this.onCarteiraAlterada});

  @override
  State<BalcaoNegociacao> createState() => _BalcaoNegociacaoState();
}

class _BalcaoNegociacaoState extends State<BalcaoNegociacao> {
  static const _azulPrimario = Color(0xFF3F51B5);
  static const _rosaVenda = Color(0xFFC928B8);
  static const _fundo = Colors.white;
  static const _textoEscuro = Color(0xFF111111);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BalcaoService _balcaoService = BalcaoService();
  bool _processando = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> _startupsStream() {
    return _firestore.collection('startups').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _holdingsStream(String uid) {
    return _firestore
        .collection('tokenHoldings')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    return _firestore.collection('orders').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: _fundo,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: uid == null
                  ? _buildEstadoCentral(
                      'Entre na sua conta para acessar o balcão.',
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _startupsStream(),
                      builder: (context, startupsSnapshot) {
                        if (startupsSnapshot.hasError) {
                          return _buildEstadoCentral(
                            'Não foi possível carregar as startups.',
                          );
                        }

                        if (!startupsSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: _azulPrimario,
                            ),
                          );
                        }

                        final startups = startupsSnapshot.data!.docs
                            .map(_StartupOferta.fromDoc)
                            .toList();

                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: _holdingsStream(uid),
                          builder: (context, holdingsSnapshot) {
                            if (holdingsSnapshot.hasError) {
                              return _buildEstadoCentral(
                                'Não foi possível carregar sua carteira.',
                              );
                            }

                            if (!holdingsSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: _azulPrimario,
                                ),
                              );
                            }

                            final holdings = _agruparHoldings(
                              holdingsSnapshot.data!.docs,
                            );

                            return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: _ordersStream(),
                              builder: (context, ordersSnapshot) {
                                if (ordersSnapshot.hasError) {
                                  return _buildEstadoCentral(
                                    'Não foi possível carregar as ofertas.',
                                  );
                                }

                                if (!ordersSnapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: _azulPrimario,
                                    ),
                                  );
                                }

                                final ofertasVenda = _ordensVendaAbertas(
                                  ordersSnapshot.data!.docs,
                                  startups,
                                  uid,
                                );

                                return _buildConteudo(
                                  uid,
                                  startups,
                                  holdings,
                                  ofertasVenda,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 52, 30, 34),
      decoration: const BoxDecoration(color: _azulPrimario),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balcão de Negociação',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Invista com estratégia, acompanhe oportunidades e\nparticipe da evolução das startups do ecossistema\nMescla',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.18),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudo(
    String uid,
    List<_StartupOferta> startups,
    Map<String, _HoldingToken> holdings,
    List<_OrdemVendaAberta> ofertasVenda,
  ) {
    final tokensParaVenda = startups
        .where((startup) => (holdings[startup.id]?.quantidade ?? 0) > 0)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(30, 48, 30, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSwitchBalcao(),
          const SizedBox(height: 30),
          _buildTituloSecao('Ofertas de Compras Abertas'),
          const SizedBox(height: 20),
          if (startups.isEmpty)
            _buildMensagemLista('Nenhuma startup disponível para compra.')
          else
            ...startups.map(
              (startup) => _OfertaCard(
                nome: startup.nome,
                quantidade: startup.quantidadeDisponivel,
                valorToken: startup.valorToken,
                botaoTexto: 'Comprar',
                botaoCor: _azulPrimario,
                bloqueado: _processando,
                onPressed: () => _abrirOfertasDaStartup(
                  startup,
                  tokensCarteira: holdings[startup.id]?.quantidade ?? 0,
                ),
              ),
            ),
          const SizedBox(height: 50),
          _buildTituloSecao('Ofertas de Vendas Abertas'),
          const SizedBox(height: 26),
          if (ofertasVenda.isEmpty)
            _buildMensagemLista('Nenhuma oferta de venda aberta no momento.')
          else
            ...ofertasVenda.map(
              (ordem) => _OfertaCard(
                nome: ordem.nomeStartup,
                quantidade: ordem.quantidadeRestante,
                valorToken: ordem.preco,
                botaoTexto: 'Comprar',
                botaoCor: _azulPrimario,
                bloqueado: _processando,
                onPressed: () => _confirmarCompraOrdemVenda(uid, ordem),
              ),
            ),
          const SizedBox(height: 50),
          _buildTituloSecao('Meus tokens disponíveis para venda'),
          const SizedBox(height: 26),
          if (tokensParaVenda.isEmpty)
            _buildMensagemLista(
              'Você não possui tokens disponíveis para venda.',
            )
          else
            ...tokensParaVenda.map((startup) {
              final holding = holdings[startup.id]!;

              return _OfertaCard(
                nome: startup.nome,
                quantidade: holding.quantidade,
                valorToken: startup.valorToken,
                botaoTexto: 'Vender',
                botaoCor: _rosaVenda,
                bloqueado: _processando,
                onPressed: () =>
                    _abrirVenda(startup, tokensDisponiveis: holding.quantidade),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSwitchBalcao() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwitchButton(
            texto: 'Minhas Ordens',
            ativo: false,
            onTap: () {
              final route = noAnimationRoute(
                builder: (_) =>
                    BalcaoMinhasOrdens(onNavigate: widget.onNavigate),
              );

              if (widget.onNavigate != null) {
                Navigator.push(context, route);
              } else {
                Navigator.pushReplacement(context, route);
              }
            },
          ),
          const SizedBox(width: 10),
          _SwitchButton(
            texto: 'Catálogo de ofertas',
            ativo: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  void _abrirOfertasDaStartup(
    _StartupOferta startup, {
    required int tokensCarteira,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BalcaoOfertasDaStartup(
          startup: {
            'id': startup.id,
            'nome': startup.nome,
            'tokens': startup.quantidadeDisponivel.toString(),
            'tokensCarteira': tokensCarteira.toString(),
            'valorToken': startup.valorToken.toStringAsFixed(2),
          },
          onNavigate: widget.onNavigate,
        ),
      ),
    );
  }

  void _abrirVenda(_StartupOferta startup, {required int tokensDisponiveis}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BalcaoVenda(
          startup: {
            'id': startup.id,
            'nome': startup.nome,
            'tokens': startup.quantidadeDisponivel.toString(),
            'tokensCarteira': tokensDisponiveis.toString(),
            'valorToken': startup.valorToken.toStringAsFixed(2),
          },
          tokensDisponiveis: tokensDisponiveis,
          precoAtual: startup.valorToken,
          onNavigate: widget.onNavigate,
        ),
      ),
    );
  }

  Widget _buildTituloSecao(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        color: _textoEscuro,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildMensagemLista(String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.black54, fontSize: 12),
      ),
    );
  }

  Widget _buildEstadoCentral(String mensagem) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 14),
        ),
      ),
    );
  }

  Future<void> _confirmarCompraOrdemVenda(
    String uid,
    _OrdemVendaAberta ordem,
  ) async {
    if (ordem.quantidadeRestante <= 0) {
      _mostrarMensagem('Esta oferta não possui tokens disponíveis.');
      return;
    }

    final quantidade = await showDialog<int>(
      context: context,
      builder: (context) => _QuantidadeDialog(
        titulo: 'Comprar tokens',
        startup: ordem.nomeStartup,
        quantidadeMaxima: ordem.quantidadeRestante,
      ),
    );

    if (quantidade == null || quantidade <= 0) return;

    await _executarComFeedback(() async {
      await _balcaoService.comprarOrdemVenda(
        compradorId: uid,
        ordemId: ordem.id,
        quantidade: quantidade,
      );

      widget.onCarteiraAlterada?.call();
      _mostrarMensagem('Compra registrada com sucesso.');
    });
  }

  List<_OrdemVendaAberta> _ordensVendaAbertas(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    List<_StartupOferta> startups,
    String uid,
  ) {
    final startupsPorId = {for (final startup in startups) startup.id: startup};
    final ordens = <_OrdemVendaAberta>[];

    for (final doc in docs) {
      final ordem = _OrdemVendaAberta.fromDoc(doc, startupsPorId);

      if (ordem == null || ordem.vendedorId == uid || !ordem.estaDisponivel) {
        continue;
      }

      ordens.add(ordem);
    }

    ordens.sort((a, b) {
      final precoCompare = a.preco.compareTo(b.preco);
      if (precoCompare != 0) return precoCompare;
      return a.nomeStartup.compareTo(b.nomeStartup);
    });

    return ordens;
  }

  Map<String, _HoldingToken> _agruparHoldings(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final holdings = <String, _HoldingToken>{};

    for (final doc in docs) {
      final holding = _HoldingToken.fromDoc(doc);

      if (holding.startupId.isEmpty || holding.quantidade <= 0) {
        continue;
      }

      final atual = holdings[holding.startupId];
      holdings[holding.startupId] = atual == null
          ? holding
          : atual.somar(holding);
    }

    return holdings;
  }

  Future<void> _executarComFeedback(Future<void> Function() acao) async {
    if (_processando) return;

    setState(() => _processando = true);

    try {
      await acao();
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

class _OfertaCard extends StatelessWidget {
  const _OfertaCard({
    required this.nome,
    required this.quantidade,
    required this.valorToken,
    required this.botaoTexto,
    required this.botaoCor,
    required this.onPressed,
    required this.bloqueado,
  });

  final String nome;
  final int quantidade;
  final double valorToken;
  final String botaoTexto;
  final Color botaoCor;
  final VoidCallback onPressed;
  final bool bloqueado;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
      padding: const EdgeInsets.fromLTRB(20, 9, 12, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Qtd de tokens: $quantidade',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatarMoeda(valorToken),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  '/Token',
                  style: TextStyle(fontSize: 8, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 65,
            height: 31,
            child: ElevatedButton(
              onPressed: bloqueado ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: botaoCor,
                disabledBackgroundColor: botaoCor.withValues(alpha: 0.45),
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: Text(
                botaoTexto,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchButton extends StatelessWidget {
  const _SwitchButton({
    required this.texto,
    required this.ativo,
    required this.onTap,
  });

  final String texto;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: ativo
              ? _BalcaoNegociacaoState._azulPrimario
              : Colors.transparent,
          foregroundColor: ativo
              ? Colors.white
              : _BalcaoNegociacaoState._textoEscuro,
          side: const BorderSide(color: _BalcaoNegociacaoState._azulPrimario),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(texto, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

class _QuantidadeDialog extends StatefulWidget {
  const _QuantidadeDialog({
    required this.titulo,
    required this.startup,
    required this.quantidadeMaxima,
  });

  final String titulo;
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
      title: Text(widget.titulo),
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

class _OrdemVendaAberta {
  const _OrdemVendaAberta({
    required this.id,
    required this.vendedorId,
    required this.nomeStartup,
    required this.quantidadeRestante,
    required this.preco,
    required this.status,
  });

  static _OrdemVendaAberta? fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, _StartupOferta> startupsPorId,
  ) {
    final data = doc.data() ?? {};
    final tipo = _texto(data['tipo']).toLowerCase();
    final startupId = _texto(data['startupId']);
    final startup = startupsPorId[startupId];
    final preco = _numero(data['preco'] ?? data['precoUnitario']);
    final quantidadeRestante = _quantidadeRestante(data);

    if (tipo != 'venda' ||
        startupId.isEmpty ||
        preco <= 0 ||
        quantidadeRestante <= 0) {
      return null;
    }

    return _OrdemVendaAberta(
      id: doc.id,
      vendedorId: _texto(data['sellerId'] ?? data['userId']),
      nomeStartup: startup?.nome ?? 'Nome da Startup',
      quantidadeRestante: quantidadeRestante,
      preco: preco,
      status: _texto(data['status']).toLowerCase(),
    );
  }

  final String id;
  final String vendedorId;
  final String nomeStartup;
  final int quantidadeRestante;
  final double preco;
  final String status;

  bool get estaDisponivel => _statusAberto(status) && quantidadeRestante > 0;
}

class _StartupOferta {
  const _StartupOferta({
    required this.id,
    required this.nome,
    required this.quantidadeDisponivel,
    required this.valorToken,
  });

  factory _StartupOferta.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final quantidadeCampo = _primeiroCampoNumerico(data, const [
      'tokensDisponiveis',
      'quantidadeTokens',
      'tokens',
      'tokensEmitidos',
      'totalTokens',
    ]);

    return _StartupOferta(
      id: doc.id,
      nome: _texto(
        data['nome'] ?? data['name'] ?? data['startupName'],
        fallback: 'Nome',
      ),
      quantidadeDisponivel: _numero(
        data[quantidadeCampo] ?? data['quantidade'],
      ).toInt(),
      valorToken: _numero(
        data['valorToken'] ??
            data['precoToken'] ??
            data['preco'] ??
            data['tokenPrice'],
        fallback: 480,
      ),
    );
  }

  final String id;
  final String nome;
  final int quantidadeDisponivel;
  final double valorToken;
}

class _HoldingToken {
  const _HoldingToken({required this.startupId, required this.quantidade});

  factory _HoldingToken.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return _HoldingToken(
      startupId: _texto(data['startupId']),
      quantidade: _numero(data['quantidade']).toInt(),
    );
  }

  final String startupId;
  final int quantidade;

  _HoldingToken somar(_HoldingToken other) {
    return _HoldingToken(
      startupId: startupId,
      quantidade: quantidade + other.quantidade,
    );
  }
}

String? _primeiroCampoNumerico(Map<String, dynamic> data, List<String> campos) {
  for (final campo in campos) {
    if (data.containsKey(campo)) return campo;
  }

  return null;
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

String _texto(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;

  final texto = value.toString().trim();
  return texto.isEmpty ? fallback : texto;
}

double _numero(dynamic value, {double fallback = 0}) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final normalizado = value
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();

    return double.tryParse(normalizado) ?? fallback;
  }

  return fallback;
}

String _formatarMoeda(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final reais = parts.first;
  final centavos = parts.last;
  final buffer = StringBuffer();

  for (var i = 0; i < reais.length; i++) {
    final remaining = reais.length - i;
    buffer.write(reais[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }

  return 'R\$ ${buffer.toString()},$centavos';
}
