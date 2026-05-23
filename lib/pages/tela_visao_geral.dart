//Eduarda Prado Deiró

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../widgets/app_bottom_nav.dart';
import 'balcao_negociacao.dart';
import 'balcao_ofertas_da_satartup.dart';
import 'visao_geral/aba_atualizacoes.dart';
import 'visao_geral/aba_conteudo.dart';
import 'visao_geral/aba_perguntas.dart';
import 'visao_geral/aba_sociedade.dart';
import 'visao_geral/aba_visao_geral.dart';

class TelaVisaoGeral extends StatefulWidget {
  final Map<String, String> startup;
  final ValueChanged<int>? onNavigate;

  const TelaVisaoGeral({super.key, required this.startup, this.onNavigate});

  @override
  State<TelaVisaoGeral> createState() => _TelaVisaoGeralState();
}

class _TelaVisaoGeralState extends State<TelaVisaoGeral> {
  String _tabAtiva = 'Visão Geral';
  final VideoThumbnailCache _thumbnailCache = VideoThumbnailCache();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _conteudoPreloadSubscription;

  static const _azulPrimario = Color(0xFF3F51B5);

  static const _tabs = [
    'Visão Geral',
    'Sociedade',
    'Conteúdo',
    'Atualizações',
    'Perguntas',
  ];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

  String? get _startupId {
    final id = widget.startup['id']?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  String get _nomeUsuario {
    final user = FirebaseAuth.instance.currentUser;
    final nome = user?.displayName?.trim();
    if (nome != null && nome.isNotEmpty) return nome;
    final email = user?.email?.trim() ?? AuthSession.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'Usuário';
  }

  @override
  void initState() {
    super.initState();
    _iniciarPreloadConteudo();
  }

  @override
  void didUpdateWidget(covariant TelaVisaoGeral oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startup['id'] != widget.startup['id']) {
      _iniciarPreloadConteudo();
    }
  }

  @override
  void dispose() {
    _conteudoPreloadSubscription?.cancel();
    _thumbnailCache.dispose();
    super.dispose();
  }

  void _iniciarPreloadConteudo() {
    _conteudoPreloadSubscription?.cancel();

    final startupId = _startupId;
    if (startupId == null) {
      _thumbnailCache.syncWithUrls(const []);
      return;
    }

    _conteudoPreloadSubscription = FirebaseFirestore.instance
        .collection('startups')
        .doc(startupId)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          final videos = data?['videos'];

          if (videos is! Iterable) {
            _thumbnailCache.syncWithUrls(const []);
            return;
          }

          _thumbnailCache.syncWithUrls(
            videos.map((video) {
              if (video is! Map) return '';
              return video['url']?.toString().trim() ?? '';
            }),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          _buildHeader(),
          _buildStatsCard(),
          _buildTabs(),
          Expanded(child: _buildConteudoAtivo()),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onItemSelected: _selecionarNav,
        backgroundColor: const Color(0xFFF8F9FE),
      ),
    );
  }

  Widget _buildConteudoAtivo() {
    final sId = _startupId;
    final uid = _uid;

    switch (_tabAtiva) {
      case 'Visão Geral':
        return AbaVisaoGeral(
          startup: widget.startup,
          startupId: sId,
          uid: uid,
          onAbrirBalcao: () => _selecionarNav(2),
          onAbrirOfertasDaStartup: _abrirOfertasDaStartup,
        );
      case 'Sociedade':
        return AbaSociedade(startupId: sId);
      case 'Conteúdo':
        return AbaConteudo(startupId: sId, thumbnailCache: _thumbnailCache);
      case 'Atualizações':
        return AbaAtualizacoes(startupId: sId);
      case 'Perguntas':
        return AbaPerguntas(
          startupId: sId,
          uid: uid,
          nomeUsuario: _nomeUsuario,
        );
      default:
        return const Center(
          child: Text('Em construção', style: TextStyle(color: Colors.grey)),
        );
    }
  }

  // ── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 55, 20, 28),
      decoration: const BoxDecoration(
        color: _azulPrimario,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildLogo(widget.startup['imagem'] ?? ''),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.startup['nome'] ?? 'Nome da Startup',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(String imagem) {
    const fallback = Icon(Icons.business, color: _azulPrimario, size: 36);
    if (imagem.isEmpty) return fallback;
    if (imagem.startsWith('http://') || imagem.startsWith('https://')) {
      return Image.network(
        imagem,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.asset(
      imagem,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  // ── STATS CARD ────────────────────────────────────────────────────────────

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(Icons.sell_outlined, 'Preço do Token', 'R\$ 50,00'),
          _buildDivisor(),
          _buildStatItem(
            Icons.toll_outlined,
            'Tokens emitidos',
            widget.startup['tokens'] ?? '1.700',
          ),
          _buildDivisor(),
          _buildStatItem(
            Icons.account_balance_outlined,
            'Capital aportado',
            'R\$ ${widget.startup['capital'] ?? '10.000,00'}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String valor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _azulPrimario, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
          const SizedBox(height: 3),
          Text(
            valor,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivisor() =>
      Container(width: 1, height: 44, color: const Color(0xFFE0E0E0));

  // ── TABS ──────────────────────────────────────────────────────────────────

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
      ),
      child: Row(
        children: _tabs.map((tab) {
          final ativo = _tabAtiva == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabAtiva = tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: ativo ? _azulPrimario : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tab,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: ativo ? FontWeight.bold : FontWeight.normal,
                      color: ativo ? _azulPrimario : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── NAVEGAÇÃO ─────────────────────────────────────────────────────────────

  void _selecionarNav(int index) {
    if (index == 1) return;

    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    if (index == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BalcaoNegociacao()),
    );
  }

  void _abrirOfertasDaStartup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BalcaoOfertasDaStartup(
          startup: {...widget.startup, 'tokensCarteira': '0'},
          onNavigate: widget.onNavigate,
        ),
      ),
    );
  }
}
