// Painel principal após o login: patrimônio, posições, notificações e gráfico
// agregado dos investimentos do usuário.
import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';

import '../services/auth_session.dart';
import '../services/functions_api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/authenticated_storage_image.dart';
import 'balcao_negociacao.dart';
import 'tela_adicionar_credito.dart';
import 'tela_catalogo.dart';
import 'tela_detalhe_token.dart';
import 'tela_usuario.dart';

/// Organiza as áreas autenticadas e resume a carteira atual.
class TelaHome extends StatefulWidget {
  final String nomeDigitado;

  const TelaHome({super.key, required this.nomeDigitado});

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  bool _patrimonioVisivel = false;
  int _selectedIndex = 0;
  String _filtroGrafico = 'M';
  Future<List<_PontoGrafico>>? _graficoDadosFuture;

  Future<_HomeResumo>? _homeResumoFuture;
  late final Future<String> _nomeUsuarioFuture;
  final _notificacoesNovasController = StreamController<bool>.broadcast();
  final List<StreamSubscription<dynamic>> _notificacoesSubscriptions = [];
  final _updatesSubscriptions =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  final Map<String, DateTime?> _ultimaAtualizacaoPorStartup = {};
  DateTime? _notificacoesVistasEm;
  DateTime? _ultimaVendaEm;
  bool? _ultimoEstadoNotificacoesNovas;

  static const _roxo = Color(0xFF4C3BCF);

  @override
  void initState() {
    super.initState();
    _homeResumoFuture = _buscarResumoHome();
    _nomeUsuarioFuture = _buscarNomeUsuario();
    _graficoDadosFuture = _buscarDadosGrafico(_filtroGrafico);
    _iniciarMonitoramentoNotificacoes();
  }

  @override
  void dispose() {
    for (final subscription in _notificacoesSubscriptions) {
      subscription.cancel();
    }

    for (final subscription in _updatesSubscriptions.values) {
      subscription.cancel();
    }

    _notificacoesNovasController.close();
    super.dispose();
  }

  /// Atualiza cartões e gráfico depois de operações que alteram a carteira.
  void _recarregarHome() {
    setState(() {
      _homeResumoFuture = _buscarResumoHome();
      _graficoDadosFuture = _buscarDadosGrafico(_filtroGrafico);
    });
  }

  void _selecionarAba(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) {
        _homeResumoFuture = _buscarResumoHome();
      }
    });
  }

  void _mostrarHome() {
    _selecionarAba(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeColors = theme.extension<AppThemeColors>()!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ----------------------------------------------------
            // CONTEÚDO PRINCIPAL (INDEXED STACK)
            // ----------------------------------------------------
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  // --- ABA 0: CONTEÚDO DA HOME INTEGRADO DIRETO AQUI ---
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER DO USUÁRIO
                        FutureBuilder<String>(
                          future: _nomeUsuarioFuture,
                          builder: (context, snapshot) {
                            final nomeUsuario =
                                snapshot.data ?? _nomeFallback();

                            return Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TelaUsuario(
                                          nomeFallback: nomeUsuario,
                                        ),
                                      ),
                                    );
                                    if (mounted) {
                                      _recarregarHome();
                                    }
                                  },
                                  child: Icon(
                                    Icons.account_circle_outlined,
                                    size: 38,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Olá, $nomeUsuario',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: themeColors.panelBorder,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: StreamBuilder<bool>(
                                    stream: _notificacoesNovasController.stream,
                                    initialData: false,
                                    builder: (context, snapshot) {
                                      final temNovas = snapshot.data ?? false;

                                      return Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(
                                              Icons.notifications_outlined,
                                              color: _roxo,
                                              size: 22,
                                            ),
                                            onPressed: _abrirNotificacoes,
                                          ),
                                          if (temNovas)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                width: 9,
                                                height: 9,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFE53935,
                                                  ),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: themeColors
                                                        .elevatedSurface,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // CARD DE PATRIMÔNIO E MEUS TOKENS (FUTURE BUILDER)
                        FutureBuilder<_HomeResumo>(
                          future: _homeResumoFuture ??= _buscarResumoHome(),
                          builder: (context, snapshot) {
                            final resumo =
                                snapshot.data ?? const _HomeResumo.vazio();
                            final tokens = resumo.tokens;

                            final patrimonioFormatado = _formatarMoeda(
                              resumo.patrimonioTotal,
                            );
                            final valorInvestidoFormatado = _formatarMoeda(
                              resumo.valorInvestido,
                            );
                            final saldoReaisFormatado = _formatarMoeda(
                              resumo.saldoReais,
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // CARD PATRIMÔNIO
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF6070F0),
                                        Color(0xFF3A4DD6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Patrimônio Total',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => setState(
                                              () => _patrimonioVisivel =
                                                  !_patrimonioVisivel,
                                            ),
                                            child: Icon(
                                              _patrimonioVisivel
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                              color: Colors.white70,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 40,
                                        child: Stack(
                                          children: [
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                patrimonioFormatado,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            if (!_patrimonioVisivel)
                                              Positioned.fill(
                                                child: ClipRect(
                                                  child: BackdropFilter(
                                                    filter: ImageFilter.blur(
                                                      sigmaX: 10,
                                                      sigmaY: 10,
                                                    ),
                                                    child: Container(
                                                      color: Colors.transparent,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          // Bloco Valor em Tokens inline
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black26,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Valor em tokens',
                                                  style: TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                _patrimonioVisivel
                                                    ? Text(
                                                        valorInvestidoFormatado,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      )
                                                    : ClipRect(
                                                        child: ImageFiltered(
                                                          imageFilter:
                                                              ImageFilter.blur(
                                                                sigmaX: 10,
                                                                sigmaY: 10,
                                                              ),
                                                          child: Text(
                                                            valorInvestidoFormatado,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                              ],
                                            ),
                                          ),
                                          // Bloco Saldo em Carteira inline
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black26,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Saldo em carteira',
                                                  style: TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                _patrimonioVisivel
                                                    ? Text(
                                                        saldoReaisFormatado,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      )
                                                    : ClipRect(
                                                        child: ImageFiltered(
                                                          imageFilter:
                                                              ImageFilter.blur(
                                                                sigmaX: 10,
                                                                sigmaY: 10,
                                                              ),
                                                          child: Text(
                                                            saldoReaisFormatado,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const TelaAdicionarCredito(),
                                              ),
                                            );
                                            if (mounted) {
                                              _recarregarHome();
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: _roxo,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                          child: const Text(
                                            'Adicionar Crédito',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildGraficoInvestimentos(),
                                const SizedBox(height: 24),
                                Text(
                                  'Meus Tokens',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // LISTAGEM DE TOKENS INLINE
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else if (snapshot.hasError)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: themeColors.subtleSurface,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      'Não foi possível carregar seus tokens.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: themeColors.mutedText,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                else if (tokens.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: themeColors.subtleSurface,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      'Você não possui tokens no momento',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: themeColors.mutedText,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                else
                                  ...tokens.map((token) {
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _abrirDetalheToken(token),
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: themeColors.subtleSurface,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            _buildTokenLogo(token),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    token.nome,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color:
                                                          colorScheme.onSurface,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${_formatarQuantidade(token.quantidade)} tokens',
                                                    style: TextStyle(
                                                      color:
                                                          themeColors.faintText,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  _formatarMoeda(
                                                    token.valorTotal,
                                                  ),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color:
                                                        colorScheme.onSurface,
                                                  ),
                                                ),
                                                Text(
                                                  'PM ${_formatarMoeda(token.precoMedioCompra)}',
                                                  style: const TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: _roxo,
                                              size: 22,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  // --- ABA 1: CATÁLOGO ---
                  TelaCatalogo(
                    mostrarMenuInferior: false,
                    onVoltar: _mostrarHome,
                    onNavigate: _selecionarAba,
                  ),

                  // --- ABA 2: BALCÃO ---
                  BalcaoNegociacao(
                    onNavigate: _selecionarAba,
                    onCarteiraAlterada: _recarregarHome,
                  ),
                ],
              ),
            ),

            // ----------------------------------------------------
            // MENU INFERIOR PERSONALIZADO (INTEGRADO NO BUILD)
            // ----------------------------------------------------
            AppBottomNav(
              selectedIndex: _selectedIndex,
              onItemSelected: (index) {
                if (index == 0) {
                  _mostrarHome();
                } else {
                  _selecionarAba(index);
                }
              },
              backgroundColor: theme.scaffoldBackgroundColor,
            ),
          ],
        ),
      ),
    );
  }

  // --- MÉTODOS DE SUPORTE LÓGICO E DE DADOS ---

  /// Abre a página com preço histórico e resumo da posição selecionada.
  Future<void> _abrirDetalheToken(_TokenResumo token) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaDetalheToken(
          startupId: token.startupId,
          nome: token.nome,
          quantidade: token.quantidade,
          precoMedioCompra: token.precoMedioCompra,
          precoAtualInicial: token.precoAtual,
          onNavigate: _selecionarAba,
        ),
      ),
    );

    if (mounted) {
      _recarregarHome();
    }
  }

  /// Observa leitura, vendas e comunicados das startups investidas.
  ///
  /// O indicador de novidades é recalculado a cada snapshot recebido.
  void _iniciarMonitoramentoNotificacoes() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

    if (uid == null) {
      _emitirEstadoNotificacoesNovas(false);
      return;
    }

    final firestore = FirebaseFirestore.instance;

    _notificacoesSubscriptions.add(
      firestore
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen(
            (snapshot) {
              _notificacoesVistasEm = _lerData(
                snapshot.data()?['notificacoesVistasEm'],
              );
              _recalcularIndicadorNotificacoes();
            },
            onError: (Object error) {
              debugPrint(
                'Não foi possível monitorar leitura das notificações: $error',
              );
            },
          ),
    );

    _notificacoesSubscriptions.add(
      firestore
          .collection('transactions')
          .where('sellerId', isEqualTo: uid)
          .snapshots()
          .listen(
            (snapshot) {
              _ultimaVendaEm = _dataMaisRecente(
                snapshot.docs.map((doc) {
                  final data = doc.data();
                  return _lerData(
                    data['executadaEm'] ??
                        data['createdAt'] ??
                        data['updatedAt'],
                  );
                }),
              );
              _recalcularIndicadorNotificacoes();
            },
            onError: (Object error) {
              debugPrint(
                'Não foi possível monitorar vendas concluídas: $error',
              );
            },
          ),
    );

    _notificacoesSubscriptions.add(
      firestore
          .collection('tokenHoldings')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .listen(
            (snapshot) {
              final startupIds = <String>{};

              for (final doc in snapshot.docs) {
                final data = doc.data();
                final startupId = _lerTexto(data['startupId']);
                final quantidade = _lerNumero(data['quantidade']);

                if (startupId.isNotEmpty && quantidade > 0) {
                  startupIds.add(startupId);
                }
              }

              _atualizarMonitoramentoUpdates(startupIds);
            },
            onError: (Object error) {
              debugPrint(
                'Não foi possível monitorar tokens do usuário: $error',
              );
            },
          ),
    );
  }

  /// Ajusta dinamicamente os listeners de comunicados conforme a carteira muda.
  void _atualizarMonitoramentoUpdates(Set<String> startupIds) {
    final removidas = _updatesSubscriptions.keys
        .where((startupId) => !startupIds.contains(startupId))
        .toList();

    for (final startupId in removidas) {
      _updatesSubscriptions.remove(startupId)?.cancel();
      _ultimaAtualizacaoPorStartup.remove(startupId);
    }

    final firestore = FirebaseFirestore.instance;

    for (final startupId in startupIds) {
      if (_updatesSubscriptions.containsKey(startupId)) continue;

      _updatesSubscriptions[startupId] = firestore
          .collection('startups')
          .doc(startupId)
          .collection('updates')
          .snapshots()
          .listen(
            (snapshot) {
              _ultimaAtualizacaoPorStartup[startupId] = _dataMaisRecente(
                snapshot.docs.map((doc) {
                  final data = doc.data();
                  return _lerData(
                    data['createdAt'] ?? data['data'] ?? data['date'],
                  );
                }),
              );
              _recalcularIndicadorNotificacoes();
            },
            onError: (Object error) {
              debugPrint(
                'Não foi possível monitorar atualizações da startup $startupId: $error',
              );
            },
          );
    }

    _recalcularIndicadorNotificacoes();
  }

  /// Decide se existe algum evento posterior à última abertura da central.
  void _recalcularIndicadorNotificacoes() {
    final ultimaNotificacao = _dataMaisRecente([
      _ultimaVendaEm,
      ..._ultimaAtualizacaoPorStartup.values,
    ]);
    final temNovas =
        ultimaNotificacao != null &&
        (_notificacoesVistasEm == null ||
            ultimaNotificacao.isAfter(_notificacoesVistasEm!));

    _emitirEstadoNotificacoesNovas(temNovas);
  }

  void _emitirEstadoNotificacoesNovas(bool temNovas) {
    if (_notificacoesNovasController.isClosed ||
        _ultimoEstadoNotificacoesNovas == temNovas) {
      return;
    }

    _ultimoEstadoNotificacoesNovas = temNovas;
    _notificacoesNovasController.add(temNovas);
  }

  /// Abre a central e persiste o momento em que as novidades foram vistas.
  Future<void> _abrirNotificacoes() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

    if (uid == null) {
      _mostrarMensagem('Entre na sua conta para ver suas notificações.');
      return;
    }

    final visualizadasEm = DateTime.now().toUtc();
    _notificacoesVistasEm = visualizadasEm;
    _recalcularIndicadorNotificacoes();

    unawaited(
      FunctionsApiClient.instance
          .patch(
            'usersMarkNotificationsViewed',
            body: {'viewedAt': visualizadasEm.toIso8601String()},
          )
          .catchError(
            (Object e) => debugPrint('Erro ao marcar notificações: $e'),
          ),
    );

    final notificacoesFuture = _buscarNotificacoesUsuario(uid);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _buildNotificacoesSheet(context, notificacoesFuture),
    );
  }

  Widget _buildNotificacoesSheet(
    BuildContext context,
    Future<List<_NotificacaoHome>> notificacoesFuture,
  ) {
    final altura = MediaQuery.of(context).size.height * 0.82;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return SizedBox(
      height: altura,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: themeColors.panelBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _roxo.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: _roxo,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notificações',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Vendas concluídas e atualizações das suas empresas',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeColors.faintText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<_NotificacaoHome>>(
                future: notificacoesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _buildEstadoNotificacoes(
                      'Não foi possível carregar suas notificações.',
                    );
                  }

                  final notificacoes = snapshot.data ?? <_NotificacaoHome>[];

                  if (notificacoes.isEmpty) {
                    return _buildEstadoNotificacoes(
                      'Você ainda não possui notificações.',
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomPadding),
                    itemCount: notificacoes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildNotificacaoItem(notificacoes[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoNotificacoes(String mensagem) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: TextStyle(color: themeColors.mutedText, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildNotificacaoItem(_NotificacaoHome notificacao) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final cor = notificacao.tipo == _TipoNotificacaoHome.venda
        ? const Color(0xFF059669)
        : _corTipoAtualizacao(notificacao.categoria);
    final dataExibida = notificacao.data == null
        ? 'Data não informada'
        : _formatarDataNotificacao(notificacao.data!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColors.panelBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconeNotificacao(notificacao), color: cor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notificacao.tipo == _TipoNotificacaoHome.venda
                            ? 'Venda'
                            : _tipoAtualizacaoExibido(notificacao.categoria),
                        style: TextStyle(
                          color: cor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      dataExibida,
                      style: TextStyle(
                        color: themeColors.faintText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  notificacao.titulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notificacao.startupNome,
                  style: TextStyle(
                    color: themeColors.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notificacao.mensagem,
                  style: TextStyle(
                    fontSize: 12,
                    color: themeColors.mutedText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Combina vendas concluídas e comunicados em uma lista cronológica.
  Future<List<_NotificacaoHome>> _buscarNotificacoesUsuario(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final startupCache = <String, Future<_StartupResumo>>{};

    Future<_StartupResumo> buscarStartup(String startupId) {
      return startupCache.putIfAbsent(
        startupId,
        () => _buscarDadosStartup(firestore, startupId),
      );
    }

    final resultados = await Future.wait([
      _buscarNotificacoesDeVendas(firestore, uid, buscarStartup),
      _buscarNotificacoesDeAtualizacoes(firestore, uid, buscarStartup),
    ]);

    final notificacoes = resultados.expand((grupo) => grupo).toList();
    notificacoes.sort((a, b) {
      final dataA = a.data;
      final dataB = b.data;

      if (dataA == null && dataB == null) return 0;
      if (dataA == null) return 1;
      if (dataB == null) return -1;

      return dataB.compareTo(dataA);
    });

    return notificacoes;
  }

  Future<List<_NotificacaoHome>> _buscarNotificacoesDeVendas(
    FirebaseFirestore firestore,
    String uid,
    Future<_StartupResumo> Function(String startupId) buscarStartup,
  ) async {
    final vendasSnapshot = await firestore
        .collection('transactions')
        .where('sellerId', isEqualTo: uid)
        .get();
    final notificacoes = <_NotificacaoHome>[];

    for (final doc in vendasSnapshot.docs) {
      final data = doc.data();
      final startupId = _lerTexto(data['startupId']);

      if (startupId.isEmpty) continue;

      final startup = await buscarStartup(startupId);
      final quantidade = _lerNumero(data['quantidade']);
      final valorTotal = _lerNumero(data['valorTotal']);
      final precoUnitario = _lerNumero(data['precoUnitario'] ?? data['preco']);
      final dataEvento = _lerData(
        data['executadaEm'] ?? data['createdAt'] ?? data['updatedAt'],
      );
      final unidade = quantidade == 1 ? 'token' : 'tokens';
      final valorTexto = valorTotal > 0
          ? ' por ${_formatarMoeda(valorTotal)}'
          : '';
      final precoTexto = precoUnitario > 0
          ? ' a ${_formatarMoeda(precoUnitario)} cada'
          : '';

      notificacoes.add(
        _NotificacaoHome(
          id: 'venda-${doc.id}',
          tipo: _TipoNotificacaoHome.venda,
          startupId: startupId,
          startupNome: startup.nome,
          categoria: 'venda',
          titulo: 'Venda concluída',
          mensagem:
              'Você vendeu ${_formatarQuantidade(quantidade)} $unidade de ${startup.nome}$valorTexto$precoTexto.',
          data: dataEvento,
        ),
      );
    }

    return notificacoes;
  }

  Future<List<_NotificacaoHome>> _buscarNotificacoesDeAtualizacoes(
    FirebaseFirestore firestore,
    String uid,
    Future<_StartupResumo> Function(String startupId) buscarStartup,
  ) async {
    final holdingsSnapshot = await firestore
        .collection('tokenHoldings')
        .where('userId', isEqualTo: uid)
        .get();
    final startupIds = <String>{};

    for (final doc in holdingsSnapshot.docs) {
      final data = doc.data();
      final startupId = _lerTexto(data['startupId']);
      final quantidade = _lerNumero(data['quantidade']);

      if (startupId.isNotEmpty && quantidade > 0) {
        startupIds.add(startupId);
      }
    }

    final grupos = await Future.wait(
      startupIds.map((startupId) async {
        final startup = await buscarStartup(startupId);
        final updatesSnapshot = await firestore
            .collection('startups')
            .doc(startupId)
            .collection('updates')
            .get();

        return updatesSnapshot.docs.map((doc) {
          final data = doc.data();
          final tipo = _lerTexto(
            data['tipo'] ?? data['type'],
            fallback: 'atualização',
          );
          final titulo = _lerTexto(
            data['titulo'] ?? data['title'] ?? data['assunto'],
            fallback: 'Atualização de ${startup.nome}',
          );
          final conteudo = _lerTexto(
            data['conteudo'] ??
                data['conteúdo'] ??
                data['content'] ??
                data['descricao'] ??
                data['descrição'] ??
                data['texto'],
            fallback: 'Conteúdo não informado.',
          );

          return _NotificacaoHome(
            id: 'atualizacao-$startupId-${doc.id}',
            tipo: _TipoNotificacaoHome.atualizacao,
            startupId: startupId,
            startupNome: startup.nome,
            categoria: tipo,
            titulo: titulo,
            mensagem: _limitarTexto(conteudo),
            data: _lerData(data['createdAt'] ?? data['data'] ?? data['date']),
          );
        }).toList();
      }),
    );

    return grupos.expand((grupo) => grupo).toList();
  }

  /// Calcula patrimônio e posições exibidos no início da Home.
  Future<_HomeResumo> _buscarResumoHome() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

    if (uid == null) {
      return const _HomeResumo.vazio();
    }

    final firestore = FirebaseFirestore.instance;
    final tokensFuture = _buscarTokensDoUsuario(firestore, uid);
    final saldoReaisFuture = _buscarSaldoCarteira(firestore, uid);

    return _HomeResumo(
      tokens: await tokensFuture,
      saldoReais: await saldoReaisFuture,
    );
  }

  /// Agrupa holdings por startup e anexa preço, nome e logotipo atuais.
  Future<List<_TokenResumo>> _buscarTokensDoUsuario(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    final holdingsSnapshot = await firestore
        .collection('tokenHoldings')
        .where('userId', isEqualTo: uid)
        .get();
    final holdingsAgrupados = <String, _HoldingAgregado>{};

    for (final doc in holdingsSnapshot.docs) {
      final data = doc.data();
      final startupId = (data['startupId'] as String?) ?? '';
      final quantidade = _lerNumero(data['quantidade']);
      final precoMedioCompra = _lerNumero(data['precoMedioCompra']);

      if (startupId.isEmpty || quantidade <= 0) {
        continue;
      }

      final atual = holdingsAgrupados[startupId];
      holdingsAgrupados[startupId] = atual == null
          ? _HoldingAgregado(
              startupId: startupId,
              quantidade: quantidade,
              custoTotal: quantidade * precoMedioCompra,
            )
          : atual.somar(
              quantidade: quantidade,
              custoTotal: quantidade * precoMedioCompra,
            );
    }

    final tokens = await Future.wait(
      holdingsAgrupados.values.map((holding) async {
        final startup = await _buscarDadosStartup(firestore, holding.startupId);
        final precoAtual = startup.precoAtual > 0
            ? startup.precoAtual
            : holding.precoMedioCompra;

        return _TokenResumo(
          startupId: holding.startupId,
          nome: startup.nome,
          logoUrl: startup.logoUrl,
          logoStoragePath: startup.logoStoragePath,
          quantidade: holding.quantidade,
          precoMedioCompra: holding.precoMedioCompra,
          precoAtual: precoAtual,
        );
      }),
    );

    final tokensComQuantidade = tokens
        .where((token) => token.quantidade > 0)
        .toList();
    tokensComQuantidade.sort((a, b) => a.nome.compareTo(b.nome));

    return tokensComQuantidade;
  }

  Future<double> _buscarSaldoCarteira(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    final walletDoc = await firestore.collection('wallets').doc(uid).get();
    return _lerNumero(walletDoc.data()?['saldoReais']);
  }

  Future<String> _buscarNomeUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? AuthSession.uid;

    if (uid != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final nomeCompleto = userDoc.data()?['nomeCompleto'];

        if (nomeCompleto is String && nomeCompleto.trim().isNotEmpty) {
          return nomeCompleto.trim();
        }
      } on FirebaseException catch (error) {
        debugPrint('Não foi possível buscar o nome do usuário: ${error.code}');
      }
    }

    final displayName = user?.displayName;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return _primeiroNome(displayName);
    }

    return _nomeFallback();
  }

  String _nomeFallback() {
    final nomeDigitado = widget.nomeDigitado.trim();
    if (nomeDigitado.isNotEmpty && !nomeDigitado.contains('@')) {
      return _primeiroNome(nomeDigitado);
    }
    return 'Usuário';
  }

  String _primeiroNome(String value) {
    final nome = value.trim();
    if (nome.isEmpty) return 'Usuário';
    if (nome.contains('@')) return 'Usuário';
    return nome.split(RegExp(r'\s+')).first;
  }

  Future<_StartupResumo> _buscarDadosStartup(
    FirebaseFirestore firestore,
    String startupId,
  ) async {
    if (startupId.isEmpty) {
      return const _StartupResumo(
        nome: 'Token sem startup',
        precoAtual: 0,
        logoUrl: '',
        logoStoragePath: '',
      );
    }

    final startupDoc = await firestore
        .collection('startups')
        .doc(startupId)
        .get();
    final data = startupDoc.data();
    final nome = data?['nome'] ?? data?['nomeStartup'] ?? data?['razaoSocial'];
    final logoUrl = _lerTexto(
      data?['logoUrl'] ?? data?['imagem'] ?? data?['imageUrl'],
    );
    final logoStoragePath = _lerTexto(
      data?['logoStoragePath'] ??
          data?['logoPath'] ??
          data?['caminhoLogo'] ??
          data?['logoStorage'],
      fallback: nome is String && nome.trim().isNotEmpty
          ? 'startups/${nome.trim().toLowerCase().replaceAll(' ', '-')}/logo/logo.png'
          : '',
    );
    final precoAtual = _lerNumero(
      data?['valorToken'] ?? data?['tokenPrecoInicial'],
    );

    if (nome is String && nome.trim().isNotEmpty) {
      return _StartupResumo(
        nome: nome.trim(),
        precoAtual: precoAtual,
        logoUrl: logoUrl,
        logoStoragePath: logoStoragePath,
      );
    }

    return _StartupResumo(
      nome: startupId,
      precoAtual: precoAtual,
      logoUrl: logoUrl,
      logoStoragePath: logoStoragePath,
    );
  }

  Widget _buildTokenLogo(_TokenResumo token) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final fallback = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: themeColors.panelBorder,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.business, color: _roxo, size: 24),
    );

    final imagem = token.logoUrl.trim();
    final storagePath = _logoStoragePathToken(token);

    Widget clip(Widget child) {
      return ClipRRect(borderRadius: BorderRadius.circular(10), child: child);
    }

    if (AuthenticatedStorageImage.isStoragePathOrUrl(imagem)) {
      return clip(
        AuthenticatedStorageImage(
          pathOrUrl: imagem,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          fallback: fallback,
        ),
      );
    }

    if (imagem.startsWith('http://') || imagem.startsWith('https://')) {
      return clip(
        Image.network(
          imagem,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }

    if (imagem.isNotEmpty) {
      return clip(
        Image.asset(
          imagem,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }

    if (storagePath.isEmpty) return fallback;

    return clip(
      AuthenticatedStorageImage(
        pathOrUrl: storagePath,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        fallback: fallback,
      ),
    );
  }

  String _logoStoragePathToken(_TokenResumo token) {
    final imagem = token.logoUrl.trim();
    if (AuthenticatedStorageImage.isStoragePathOrUrl(imagem)) return imagem;

    final configurado = token.logoStoragePath.trim();
    if (configurado.isNotEmpty) return configurado;

    final nome = token.nome.trim();
    return nome.isNotEmpty
        ? 'startups/${nome.toLowerCase().replaceAll(' ', '-')}/logo/logo.png'
        : '';
  }

  double _lerNumero(dynamic valor) {
    if (valor is int) return valor.toDouble();
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();
    if (valor is String) {
      final texto = valor.replaceAll('R\$', '').replaceAll(' ', '').trim();
      final normalizado = texto.contains(',')
          ? texto.replaceAll('.', '').replaceAll(',', '.')
          : texto;
      return double.tryParse(normalizado) ?? 0;
    }
    return 0;
  }

  DateTime? _lerData(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor);

    return null;
  }

  DateTime? _dataMaisRecente(Iterable<DateTime?> datas) {
    DateTime? maisRecente;

    for (final data in datas) {
      if (data == null) continue;

      if (maisRecente == null || data.isAfter(maisRecente)) {
        maisRecente = data;
      }
    }

    return maisRecente;
  }

  String _lerTexto(dynamic valor, {String fallback = ''}) {
    if (valor == null) return fallback;

    final texto = valor.toString().trim();
    return texto.isEmpty ? fallback : texto;
  }

  String _limitarTexto(String texto) {
    const limite = 180;
    final normalizado = texto.trim();

    if (normalizado.length <= limite) return normalizado;

    return '${normalizado.substring(0, limite).trimRight()}...';
  }

  String _formatarMoeda(double valor) {
    final negativo = valor < 0;
    final absoluto = valor.abs();
    final partes = absoluto.toStringAsFixed(2).split('.');
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

    return '${negativo ? '-' : ''}R\$ ${buffer.toString()},$centavos';
  }

  String _formatarDataNotificacao(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$ano às $hora:$minuto';
  }

  String _formatarQuantidade(double quantidade) {
    if (quantidade % 1 == 0) {
      return quantidade.toInt().toString();
    }
    return Math.transformQuantidade(
      quantidade,
    ); // Fallback adaptado para consistência
  }

  IconData _iconeNotificacao(_NotificacaoHome notificacao) {
    if (notificacao.tipo == _TipoNotificacaoHome.venda) {
      return Icons.check_circle_outline;
    }

    return _iconeTipoAtualizacao(notificacao.categoria);
  }

  IconData _iconeTipoAtualizacao(String tipo) {
    final normalizado = tipo.toLowerCase();

    if (normalizado.contains('evento')) return Icons.event_note_outlined;
    if (normalizado.contains('financ')) return Icons.trending_up_outlined;
    if (normalizado.contains('produto')) return Icons.inventory_2_outlined;
    if (normalizado.contains('not')) return Icons.article_outlined;

    return Icons.campaign_outlined;
  }

  Color _corTipoAtualizacao(String tipo) {
    final normalizado = tipo.toLowerCase();

    if (normalizado.contains('evento')) return const Color(0xFF7C52D4);
    if (normalizado.contains('financ')) return const Color(0xFF059669);
    if (normalizado.contains('produto')) return const Color(0xFF0EA5E9);
    if (normalizado.contains('not')) return _roxo;

    return const Color(0xFFF59E0B);
  }

  String _tipoAtualizacaoExibido(String value) {
    final normalizado = value.toLowerCase().trim();

    if (normalizado == 'venda') return 'Venda';
    if (normalizado.contains('not')) return 'Notícia';
    if (normalizado.contains('evento')) return 'Evento';
    if (normalizado.contains('financ')) return 'Financeiro';
    if (normalizado.contains('produto')) return 'Produto';

    return _capitalizar(value);
  }

  String _capitalizar(String value) {
    final texto = _lerTexto(value, fallback: 'Atualização');
    if (texto.isEmpty) return 'Atualização';

    return '${texto[0].toUpperCase()}${texto.substring(1)}';
  }

  /// Monta o cartão e o gráfico agregado de aportes do usuário.
  Widget _buildGraficoInvestimentos() {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evolução dos Investimentos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          _buildFiltrosGrafico(),
          const SizedBox(height: 20),
          FutureBuilder<List<_PontoGrafico>>(
            future: _graficoDadosFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 160,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final pontos = snapshot.data ?? [];
              final temDados = pontos.any((p) => p.valor > 0);

              if (!temDados) {
                return SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(
                      'Nenhuma movimentação no período.',
                      style: TextStyle(
                        color: themeColors.faintText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }

              return SizedBox(
                height: 160,
                child: LineChart(_buildLineChartData(pontos)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFiltrosGrafico() {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    const filtros = [
      ('D', 'Diário'),
      ('Se', 'Semanal'),
      ('M', 'Mensal'),
      ('S', 'Semestral'),
      ('A', 'YTD'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filtros.map((f) {
          final ativo = _filtroGrafico == f.$1;
          return GestureDetector(
            onTap: () {
              if (_filtroGrafico != f.$1) {
                setState(() {
                  _filtroGrafico = f.$1;
                  _graficoDadosFuture = _buscarDadosGrafico(f.$1);
                });
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ativo ? _roxo : themeColors.subtleSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                f.$2,
                style: TextStyle(
                  fontSize: 11,
                  color: ativo ? Colors.white : themeColors.faintText,
                  fontWeight: ativo ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  LineChartData _buildLineChartData(List<_PontoGrafico> pontos) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final spots = List.generate(
      pontos.length,
      (i) => FlSpot(i.toDouble(), pontos[i].valor),
    );
    final maxY = pontos.fold<double>(0, (m, p) => p.valor > m ? p.valor : m);
    final effectiveMaxY = maxY > 0 ? maxY * 1.25 : 100.0;
    final interval = (effectiveMaxY / 4).ceilToDouble();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: themeColors.panelBorder, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 46,
            interval: interval,
            getTitlesWidget: (val, _) => Text(
              'R\$${_compactarValor(val)}',
              style: TextStyle(fontSize: 8, color: themeColors.faintText),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: _intervaloXLabel(pontos.length),
            getTitlesWidget: (val, meta) {
              final i = val.toInt();
              if (i < 0 || i >= pontos.length) return const SizedBox.shrink();
              if (val != meta.appliedInterval * (val ~/ meta.appliedInterval)) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 4,
                child: Text(
                  _labelEixoX(pontos[i].data),
                  style: TextStyle(fontSize: 8, color: themeColors.faintText),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: effectiveMaxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: _roxo,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _roxo.withValues(alpha: 0.20),
                _roxo.withValues(alpha: 0.02),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Busca compras do período e soma seus valores nos buckets do eixo X.
  Future<List<_PontoGrafico>> _buscarDadosGrafico(String filtro) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;
    if (uid == null) return [];

    final agora = DateTime.now();
    DateTime inicio;

    switch (filtro) {
      case 'D':
        inicio = DateTime(agora.year, agora.month, agora.day);
        break;
      case 'Se':
        inicio = agora.subtract(const Duration(days: 6));
        inicio = DateTime(inicio.year, inicio.month, inicio.day);
        break;
      case 'S':
        final mes = agora.month - 5;
        inicio = mes <= 0
            ? DateTime(agora.year - 1, mes + 12, 1)
            : DateTime(agora.year, mes, 1);
        break;
      case 'A':
        inicio = DateTime(agora.year, 1, 1);
        break;
      default: // 'M'
        inicio = DateTime(agora.year, agora.month, 1);
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('transactions')
        .where('buyerId', isEqualTo: uid)
        .get();

    final Map<String, double> buckets = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final dt = _lerData(
        data['executadaEm'] ?? data['createdAt'] ?? data['updatedAt'],
      );
      if (dt == null || dt.isBefore(inicio)) continue;

      final chave = _bucketKey(dt, filtro);
      final valor = _lerNumero(
        data['valorTotal'] ?? data['valor'] ?? data['amount'],
      );
      buckets[chave] = (buckets[chave] ?? 0) + valor;
    }

    return _gerarPontos(filtro, agora, inicio, buckets);
  }

  /// Preenche buckets ausentes com zero para manter o intervalo visual completo.
  List<_PontoGrafico> _gerarPontos(
    String filtro,
    DateTime agora,
    DateTime inicio,
    Map<String, double> buckets,
  ) {
    final pontos = <_PontoGrafico>[];

    switch (filtro) {
      case 'D':
        for (var h = 0; h <= agora.hour; h++) {
          final dt = DateTime(agora.year, agora.month, agora.day, h);
          pontos.add(
            _PontoGrafico(dt, buckets[h.toString().padLeft(2, '0')] ?? 0),
          );
        }
        break;
      case 'Se':
        for (var i = 6; i >= 0; i--) {
          final dt = DateTime(
            agora.year,
            agora.month,
            agora.day,
          ).subtract(Duration(days: i));
          final key =
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          pontos.add(_PontoGrafico(dt, buckets[key] ?? 0));
        }
        break;
      case 'M':
        for (var d = 1; d <= agora.day; d++) {
          final dt = DateTime(agora.year, agora.month, d);
          pontos.add(
            _PontoGrafico(dt, buckets[d.toString().padLeft(2, '0')] ?? 0),
          );
        }
        break;
      case 'S':
        for (var i = 5; i >= 0; i--) {
          var m = agora.month - i;
          var y = agora.year;
          if (m <= 0) {
            m += 12;
            y--;
          }
          final dt = DateTime(y, m, 1);
          pontos.add(
            _PontoGrafico(
              dt,
              buckets['$y-${m.toString().padLeft(2, '0')}'] ?? 0,
            ),
          );
        }
        break;
      case 'A':
        for (var m = 1; m <= agora.month; m++) {
          final dt = DateTime(agora.year, m, 1);
          pontos.add(
            _PontoGrafico(
              dt,
              buckets['${agora.year}-${m.toString().padLeft(2, '0')}'] ?? 0,
            ),
          );
        }
        break;
    }

    return pontos;
  }

  String _bucketKey(DateTime dt, String filtro) {
    switch (filtro) {
      case 'D':
        return dt.hour.toString().padLeft(2, '0');
      case 'Se':
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      case 'M':
        return dt.day.toString().padLeft(2, '0');
      default:
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    }
  }

  String _labelEixoX(DateTime dt) {
    switch (_filtroGrafico) {
      case 'D':
        return '${dt.hour}h';
      case 'Se':
        const dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
        return dias[dt.weekday % 7];
      case 'M':
        return dt.day.toString().padLeft(2, '0');
      default:
        const m = [
          'Jan',
          'Fev',
          'Mar',
          'Abr',
          'Mai',
          'Jun',
          'Jul',
          'Ago',
          'Set',
          'Out',
          'Nov',
          'Dez',
        ];
        return m[dt.month - 1];
    }
  }

  double _intervaloXLabel(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 21) return 3;
    return (count / 5).ceilToDouble();
  }

  String _compactarValor(double val) {
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}k';
    return val.toStringAsFixed(0);
  }

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }
}

// Pequeno helper de fallback local adicionado para compilar a quantidade sem pacotes extras externos
class Math {
  static String transformQuantidade(double q) =>
      q.toStringAsFixed(2).replaceAll('.', ',');
}

// ----------------------------------------------------
// MODELOS DE DADOS COMPLEMENTARES
// ----------------------------------------------------
class _HomeResumo {
  const _HomeResumo({required this.tokens, required this.saldoReais});
  const _HomeResumo.vazio() : tokens = const <_TokenResumo>[], saldoReais = 0;

  final List<_TokenResumo> tokens;
  final double saldoReais;

  double get valorInvestido =>
      tokens.fold<double>(0, (total, token) => total + token.valorTotal);
  double get patrimonioTotal => valorInvestido + saldoReais;
}

class _TokenResumo {
  const _TokenResumo({
    required this.startupId,
    required this.nome,
    required this.logoUrl,
    required this.logoStoragePath,
    required this.quantidade,
    required this.precoMedioCompra,
    required this.precoAtual,
  });

  final String startupId;
  final String nome;
  final String logoUrl;
  final String logoStoragePath;
  final double quantidade;
  final double precoMedioCompra;
  final double precoAtual;

  double get valorTotal => quantidade * precoAtual;
}

enum _TipoNotificacaoHome { venda, atualizacao }

class _NotificacaoHome {
  const _NotificacaoHome({
    required this.id,
    required this.tipo,
    required this.startupId,
    required this.startupNome,
    required this.categoria,
    required this.titulo,
    required this.mensagem,
    required this.data,
  });

  final String id;
  final _TipoNotificacaoHome tipo;
  final String startupId;
  final String startupNome;
  final String categoria;
  final String titulo;
  final String mensagem;
  final DateTime? data;
}

class _StartupResumo {
  const _StartupResumo({
    required this.nome,
    required this.precoAtual,
    required this.logoUrl,
    required this.logoStoragePath,
  });

  final String nome;
  final double precoAtual;
  final String logoUrl;
  final String logoStoragePath;
}

class _PontoGrafico {
  const _PontoGrafico(this.data, this.valor);
  final DateTime data;
  final double valor;
}

class _HoldingAgregado {
  const _HoldingAgregado({
    required this.startupId,
    required this.quantidade,
    required this.custoTotal,
  });

  final String startupId;
  final double quantidade;
  final double custoTotal;

  double get precoMedioCompra => quantidade > 0 ? custoTotal / quantidade : 0;

  _HoldingAgregado somar({
    required double quantidade,
    required double custoTotal,
  }) {
    return _HoldingAgregado(
      startupId: startupId,
      quantidade: this.quantidade + quantidade,
      custoTotal: this.custoTotal + custoTotal,
    );
  }
}
