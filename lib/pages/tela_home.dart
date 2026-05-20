import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import 'balcao_negociacao.dart';
import 'tela_adicionar_credito.dart';
import 'tela_catalogo.dart';
import 'tela_detalhe_token.dart';
import 'tela_usuario.dart';

class TelaHome extends StatefulWidget {
  final String nomeDigitado;

  const TelaHome({super.key, required this.nomeDigitado});

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  bool _patrimonioVisivel = false;
  int _selectedIndex = 0;

  Future<_HomeResumo>? _homeResumoFuture;
  late final Future<String> _nomeUsuarioFuture;

  static const _roxo = Color(0xFF4C3BCF);

  @override
  void initState() {
    super.initState();
    _homeResumoFuture = _buscarResumoHome();
    _nomeUsuarioFuture = _buscarNomeUsuario();
  }

  void _recarregarHome() {
    setState(() {
      _homeResumoFuture = _buscarResumoHome();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
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
                                  child: const Icon(
                                    Icons.account_circle_outlined,
                                    size: 38,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Olá, $nomeUsuario',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.notification_add_outlined,
                                      color: _roxo,
                                      size: 22,
                                    ),
                                    onPressed: () {},
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
                                const Text(
                                  'Meus Tokens',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
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
                                      color: const Color(0xFFEEEEF5),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      'Não foi possível carregar seus tokens.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
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
                                      color: const Color(0xFFEEEEF5),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      'Você não possui tokens no momento',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
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
                                          color: const Color(0xFFEEEEF5),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade300,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    token.nome,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${_formatarQuantidade(token.quantidade)} tokens',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade500,
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
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
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
            Container(
              margin: const EdgeInsets.fromLTRB(40, 0, 40, 25),
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFEDEDED),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // BOTÃO HOME
                  GestureDetector(
                    onTap: _mostrarHome,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.home_outlined,
                          color: _selectedIndex == 0 ? _roxo : Colors.black87,
                        ),
                        Text(
                          "Home",
                          style: TextStyle(
                            fontSize: 10,
                            color: _selectedIndex == 0 ? _roxo : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // BOTÃO CATÁLOGO
                  GestureDetector(
                    onTap: () => _selecionarAba(1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          color: _selectedIndex == 1 ? _roxo : Colors.black87,
                        ),
                        Text(
                          "Catálogo",
                          style: TextStyle(
                            fontSize: 10,
                            color: _selectedIndex == 1 ? _roxo : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // BOTÃO BALCÃO
                  GestureDetector(
                    onTap: () => _selecionarAba(2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          color: _selectedIndex == 2 ? _roxo : Colors.black87,
                        ),
                        Text(
                          "Balcão",
                          style: TextStyle(
                            fontSize: 10,
                            color: _selectedIndex == 2 ? _roxo : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MÉTODOS DE SUPORTE LÓGICO E DE DADOS ---

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
      return const _StartupResumo(nome: 'Token sem startup', precoAtual: 0);
    }

    final startupDoc = await firestore
        .collection('startups')
        .doc(startupId)
        .get();
    final data = startupDoc.data();
    final nome = data?['nome'] ?? data?['nomeStartup'] ?? data?['razaoSocial'];
    final precoAtual = _lerNumero(
      data?['valorToken'] ??
          data?['precoToken'] ??
          data?['preco'] ??
          data?['tokenPrice'] ??
          data?['tokenPrecoInicial'],
    );

    if (nome is String && nome.trim().isNotEmpty) {
      return _StartupResumo(nome: nome.trim(), precoAtual: precoAtual);
    }

    return _StartupResumo(nome: startupId, precoAtual: precoAtual);
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

  String _formatarQuantidade(double quantidade) {
    if (quantidade % 1 == 0) {
      return quantidade.toInt().toString();
    }
    return Math.transformQuantidade(
      quantidade,
    ); // Fallback adaptado para consistência
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
    required this.quantidade,
    required this.precoMedioCompra,
    required this.precoAtual,
  });

  final String startupId;
  final String nome;
  final double quantidade;
  final double precoMedioCompra;
  final double precoAtual;

  double get valorTotal => quantidade * precoAtual;
}

class _StartupResumo {
  const _StartupResumo({required this.nome, required this.precoAtual});
  final String nome;
  final double precoAtual;
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
