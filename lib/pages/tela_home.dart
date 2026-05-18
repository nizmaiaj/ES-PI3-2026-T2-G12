import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import 'balcao_negociacao.dart';
import 'tela_adicionar_credito.dart';
import 'tela_catalogo.dart';
import 'tela_usuario.dart';

class TelaHome extends StatefulWidget {
  final String nomeDigitado;

  const TelaHome({super.key, required this.nomeDigitado});

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  bool _patrimonioVisivel = false;
  int _selectedIndex = 0; // Variável para controlar a troca de telas

  late Future<List<_TokenResumo>> _tokensFuture;
  late final Future<String> _nomeUsuarioFuture;

  static const _roxo = Color(0xFF4C3BCF);

  @override
  void initState() {
    super.initState();
    _tokensFuture = _buscarTokensDoUsuario();
    _nomeUsuarioFuture = _buscarNomeUsuario();
  }

  void _recarregarTokens() {
    setState(() {
      _tokensFuture = _buscarTokensDoUsuario();
    });
  }

  void _mostrarHome() {
    setState(() {
      _selectedIndex = 0;
      _tokensFuture = _buscarTokensDoUsuario();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: SafeArea(
        child: Column(
          children: [
            // O conteúdo troca aqui dependendo do clique no menu
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildConteudoHome(), // Tela 0
                  TelaCatalogo(
                    mostrarMenuInferior: false,
                    onVoltar: _mostrarHome,
                    onNavigate: (index) =>
                        setState(() => _selectedIndex = index),
                  ), // Tela 1
                  BalcaoNegociacao(
                    onNavigate: (index) =>
                        setState(() => _selectedIndex = index),
                  ), // Tela 2
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // Função que isola o conteúdo da sua Home (Header, Card, Lista)
  Widget _buildConteudoHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          FutureBuilder<List<_TokenResumo>>(
            future: _tokensFuture,
            builder: (context, snapshot) {
              final tokens = snapshot.data ?? const <_TokenResumo>[];
              final valorInvestido = tokens.fold<double>(
                0,
                (total, token) => total + token.valorTotal,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPatrimonioCard(valorInvestido),
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
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (snapshot.hasError)
                    _buildMensagemTokens(
                      'Não foi possível carregar seus tokens.',
                    )
                  else if (tokens.isEmpty)
                    _buildMensagemTokens('Você não possui tokens no momento')
                  else
                    ...tokens.map(_buildTokenItem),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // --- MÉTODOS DE COMPONENTES ---

  Widget _buildHeader() {
    return FutureBuilder<String>(
      future: _nomeUsuarioFuture,
      builder: (context, snapshot) {
        final nomeUsuario = snapshot.data ?? _nomeFallback();

        return Row(
          children: [
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TelaUsuario(nomeFallback: nomeUsuario),
                  ),
                );
                if (mounted) {
                  _recarregarTokens();
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
                border: Border.all(color: Colors.grey.shade300),
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
    );
  }

  Widget _buildPatrimonioCard(double valorInvestido) {
    final valorFormatado = _formatarMoeda(valorInvestido);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6070F0), Color(0xFF3A4DD6)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Patrimônio Total',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    setState(() => _patrimonioVisivel = !_patrimonioVisivel),
                child: Icon(
                  _patrimonioVisivel ? Icons.visibility : Icons.visibility_off,
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
                    valorFormatado,
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
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Valor total investido',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    Text(
                      valorFormatado,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TelaAdicionarCredito(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _roxo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Adicionar Crédito',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMensagemTokens(String mensagem) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        mensagem,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
    );
  }

  Widget _buildTokenItem(_TokenResumo token) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.nome,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_formatarQuantidade(token.quantidade)} tokens',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatarMoeda(token.valorTotal),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'PM ${_formatarMoeda(token.precoMedioCompra)}',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: _roxo, size: 22),
        ],
      ),
    );
  }

  Future<List<_TokenResumo>> _buscarTokensDoUsuario() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

    if (uid == null) {
      return const [];
    }

    final firestore = FirebaseFirestore.instance;
    final holdingsSnapshot = await firestore
        .collection('tokenHoldings')
        .where('userId', isEqualTo: uid)
        .get();

    final tokens = await Future.wait(
      holdingsSnapshot.docs.map((doc) async {
        final data = doc.data();
        final startupId = (data['startupId'] as String?) ?? '';
        final quantidade = _lerNumero(data['quantidade']);
        final precoMedioCompra = _lerNumero(data['precoMedioCompra']);
        final nome = await _buscarNomeStartup(firestore, startupId);

        return _TokenResumo(
          nome: nome,
          quantidade: quantidade,
          precoMedioCompra: precoMedioCompra,
        );
      }),
    );

    final tokensComQuantidade = tokens
        .where((token) => token.quantidade > 0)
        .toList();
    tokensComQuantidade.sort((a, b) => a.nome.compareTo(b.nome));

    return tokensComQuantidade;
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
      } on FirebaseException {
        // Usa os fallbacks locais abaixo se o Firestore não responder.
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

  Future<String> _buscarNomeStartup(
    FirebaseFirestore firestore,
    String startupId,
  ) async {
    if (startupId.isEmpty) return 'Token sem startup';

    final startupDoc = await firestore
        .collection('startups')
        .doc(startupId)
        .get();
    final data = startupDoc.data();
    final nome = data?['nome'] ?? data?['nomeStartup'] ?? data?['razaoSocial'];

    if (nome is String && nome.trim().isNotEmpty) {
      return nome.trim();
    }

    return startupId;
  }

  double _lerNumero(dynamic valor) {
    if (valor is int) return valor.toDouble();
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();
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

    return quantidade.toStringAsFixed(2).replaceAll('.', ',');
  }

  // --- O SEU MENU INFERIOR COMO VOCÊ PASSOU ---
  Widget _buildBottomNav() {
    return Container(
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
          // HOME
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
          // CATÁLOGO
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 1),
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
          // BALCÃO
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 2),
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
    );
  }
}

class _TokenResumo {
  const _TokenResumo({
    required this.nome,
    required this.quantidade,
    required this.precoMedioCompra,
  });

  final String nome;
  final double quantidade;
  final double precoMedioCompra;

  double get valorTotal => quantidade * precoMedioCompra;
}
