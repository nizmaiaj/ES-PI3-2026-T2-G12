// Eduarda Prado Deiró - RA: 25004440

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../services/balcao_service.dart';
import '../theme/app_theme.dart';
import 'balcao_ofertas_da_startup.dart';
import 'balcao_minhasordens.dart';
import 'balcao_venda.dart';
import 'no_animation_route.dart';

enum _BalcaoSecao { compras, vendas, meusTokens }

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
  static const _itensPorPagina = 5;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BalcaoService _balcaoService = BalcaoService();
  bool _processando = false;
  _BalcaoSecao _secaoAtiva = _BalcaoSecao.compras;
  int _paginaCompras = 0;
  int _paginaVendas = 0;
  int _paginaMeusTokens = 0;

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
    return _firestore
        .collection('orders')
        .where('status', whereIn: ['aberta', 'parcial'])
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          const SizedBox(height: 24),
          _buildFiltroSecoes(
            compras: startups.length,
            vendas: ofertasVenda.length,
            meusTokens: tokensParaVenda.length,
          ),
          const SizedBox(height: 24),
          _buildSecaoSelecionada(
            uid: uid,
            startups: startups,
            holdings: holdings,
            ofertasVenda: ofertasVenda,
            tokensParaVenda: tokensParaVenda,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroSecoes({
    required int compras,
    required int vendas,
    required int meusTokens,
  }) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Escolha uma lista',
          style: TextStyle(
            color: themeColors.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_BalcaoSecao>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _BalcaoSecao.compras,
                label: Text('Compras ($compras)'),
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              ),
              ButtonSegment(
                value: _BalcaoSecao.vendas,
                label: Text('Vendas ($vendas)'),
                icon: const Icon(Icons.sell_outlined, size: 18),
              ),
              ButtonSegment(
                value: _BalcaoSecao.meusTokens,
                label: Text('Meus tokens ($meusTokens)'),
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                ),
              ),
            ],
            selected: {_secaoAtiva},
            onSelectionChanged: (selection) {
              setState(() => _secaoAtiva = selection.first);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoSelecionada({
    required String uid,
    required List<_StartupOferta> startups,
    required Map<String, _HoldingToken> holdings,
    required List<_OrdemVendaAberta> ofertasVenda,
    required List<_StartupOferta> tokensParaVenda,
  }) {
    switch (_secaoAtiva) {
      case _BalcaoSecao.compras:
        return _buildSecaoCompras(startups, holdings);
      case _BalcaoSecao.vendas:
        return _buildSecaoVendas(uid, ofertasVenda);
      case _BalcaoSecao.meusTokens:
        return _buildSecaoMeusTokens(tokensParaVenda, holdings);
    }
  }

  Widget _buildSecaoCompras(
    List<_StartupOferta> startups,
    Map<String, _HoldingToken> holdings,
  ) {
    return _buildSecaoLista(
      titulo: 'Ofertas de compra abertas',
      subtitulo: 'Startups disponíveis para compra direta de tokens.',
      vazio: 'Nenhuma startup disponível para compra.',
      temItens: startups.isNotEmpty,
      paginaAtual: _paginaCompras,
      onPaginaSelecionada: (pagina) => setState(() => _paginaCompras = pagina),
      children: startups
          .map(
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
          )
          .toList(),
    );
  }

  Widget _buildSecaoVendas(String uid, List<_OrdemVendaAberta> ofertasVenda) {
    return _buildSecaoLista(
      titulo: 'Ofertas de vendas abertas',
      subtitulo: 'Ordens publicadas por outros investidores no balcão.',
      vazio: 'Nenhuma oferta de venda aberta no momento.',
      temItens: ofertasVenda.isNotEmpty,
      paginaAtual: _paginaVendas,
      onPaginaSelecionada: (pagina) => setState(() => _paginaVendas = pagina),
      children: ofertasVenda
          .map(
            (ordem) => _OfertaCard(
              nome: ordem.nomeStartup,
              quantidade: ordem.quantidadeRestante,
              valorToken: ordem.preco,
              botaoTexto: 'Comprar',
              botaoCor: _azulPrimario,
              bloqueado: _processando,
              onPressed: () => _confirmarCompraOrdemVenda(uid, ordem),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSecaoMeusTokens(
    List<_StartupOferta> tokensParaVenda,
    Map<String, _HoldingToken> holdings,
  ) {
    return _buildSecaoLista(
      titulo: 'Meus tokens disponíveis para venda',
      subtitulo: 'Tokens da sua carteira que podem virar uma ordem de venda.',
      vazio: 'Você não possui tokens disponíveis para venda.',
      temItens: tokensParaVenda.isNotEmpty,
      paginaAtual: _paginaMeusTokens,
      onPaginaSelecionada: (pagina) =>
          setState(() => _paginaMeusTokens = pagina),
      children: tokensParaVenda.map((startup) {
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
      }).toList(),
    );
  }

  Widget _buildSecaoLista({
    required String titulo,
    required String subtitulo,
    required String vazio,
    required bool temItens,
    required int paginaAtual,
    required ValueChanged<int> onPaginaSelecionada,
    required List<Widget> children,
  }) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final totalPaginas = children.isEmpty
        ? 0
        : ((children.length - 1) ~/ _itensPorPagina) + 1;
    final paginaSegura = totalPaginas == 0
        ? 0
        : paginaAtual < 0
        ? 0
        : paginaAtual >= totalPaginas
        ? totalPaginas - 1
        : paginaAtual;
    final inicio = paginaSegura * _itensPorPagina;
    final fim = inicio + _itensPorPagina > children.length
        ? children.length
        : inicio + _itensPorPagina;
    final childrenPagina = temItens ? children.sublist(inicio, fim) : children;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTituloSecao(titulo),
        const SizedBox(height: 6),
        Text(
          subtitulo,
          style: TextStyle(
            color: themeColors.mutedText,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        if (!temItens)
          _buildMensagemLista(vazio)
        else ...[
          if (totalPaginas > 1) ...[
            _buildPaginacao(
              paginaAtual: paginaSegura,
              totalPaginas: totalPaginas,
              totalItens: children.length,
              inicio: inicio,
              fim: fim,
              onPaginaSelecionada: onPaginaSelecionada,
            ),
            const SizedBox(height: 14),
          ],
          ...childrenPagina,
          if (totalPaginas > 1)
            _buildPaginacao(
              paginaAtual: paginaSegura,
              totalPaginas: totalPaginas,
              totalItens: children.length,
              inicio: inicio,
              fim: fim,
              onPaginaSelecionada: onPaginaSelecionada,
            ),
        ],
      ],
    );
  }

  Widget _buildPaginacao({
    required int paginaAtual,
    required int totalPaginas,
    required int totalItens,
    required int inicio,
    required int fim,
    required ValueChanged<int> onPaginaSelecionada,
  }) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mostrando ${inicio + 1}-$fim de $totalItens',
            style: TextStyle(
              color: themeColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(totalPaginas, (index) {
                final selecionada = index == paginaAtual;

                return Padding(
                  padding: EdgeInsets.only(
                    right: index == totalPaginas - 1 ? 0 : 8,
                  ),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Semantics(
                      button: true,
                      selected: selecionada,
                      label: 'Página ${index + 1}',
                      child: OutlinedButton(
                        onPressed: selecionada
                            ? null
                            : () => onPaginaSelecionada(index),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: selecionada
                              ? _azulPrimario
                              : themeColors.elevatedSurface,
                          foregroundColor: selecionada
                              ? Colors.white
                              : colorScheme.onSurface,
                          disabledForegroundColor: Colors.white,
                          side: BorderSide(
                            color: selecionada
                                ? _azulPrimario
                                : themeColors.panelBorder,
                          ),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
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
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildMensagemLista(String texto) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(color: themeColors.mutedText, fontSize: 12),
      ),
    );
  }

  Widget _buildEstadoCentral(String mensagem) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: TextStyle(color: themeColors.mutedText, fontSize: 14),
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
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final total = valorToken * quantidade;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 112),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeColors.panelBorder),
        boxShadow: [
          BoxShadow(
            color: themeColors.shadow.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compacto = constraints.maxWidth < 340;
          final info = Semantics(
            label:
                '$nome, $quantidade tokens, preço por token ${_formatarMoeda(valorToken)}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _OfertaInfoLinha(
                  label: 'Quantidade',
                  valor: '$quantidade tokens',
                ),
                const SizedBox(height: 6),
                _OfertaInfoLinha(
                  label: 'Preço por token',
                  valor: _formatarMoeda(valorToken),
                ),
                const SizedBox(height: 6),
                _OfertaInfoLinha(
                  label: 'Total estimado',
                  valor: _formatarMoeda(total),
                  destaque: true,
                  destaqueCor: botaoCor,
                ),
              ],
            ),
          );
          final acao = SizedBox(
            width: compacto ? double.infinity : 124,
            height: 48,
            child: ElevatedButton(
              onPressed: bloqueado ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: botaoCor,
                disabledBackgroundColor: botaoCor.withValues(alpha: 0.45),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                botaoTexto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );

          if (compacto) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 14), acao],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: info),
              const SizedBox(width: 16),
              acao,
            ],
          );
        },
      ),
    );
  }
}

class _OfertaInfoLinha extends StatelessWidget {
  const _OfertaInfoLinha({
    required this.label,
    required this.valor,
    this.destaque = false,
    this.destaqueCor,
  });

  final String label;
  final String valor;
  final bool destaque;
  final Color? destaqueCor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: themeColors.mutedText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: destaque ? 14 : 13,
              fontWeight: destaque ? FontWeight.w800 : FontWeight.w700,
              color: destaque
                  ? destaqueCor ?? colorScheme.primary
                  : colorScheme.onSurface,
            ),
          ),
        ),
      ],
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
    final inactiveColor = Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: ativo
              ? _BalcaoNegociacaoState._azulPrimario
              : Colors.transparent,
          foregroundColor: ativo ? Colors.white : inactiveColor,
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
      nomeStartup: startup?.nome ?? 'Nome da startup',
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
