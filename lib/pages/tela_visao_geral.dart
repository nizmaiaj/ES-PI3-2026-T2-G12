//Eduarda Prado Deiró

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import 'balcao_negociacao.dart';
import 'balcao_ofertas_da_startup.dart';
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
  final Map<String, Future<String?>> _logoUrlFutures = {};
  final ScrollController _tabsScrollController = ScrollController();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _conteudoPreloadSubscription;
  int _conteudoPreloadVersao = 0;
  bool _tabsPodeRolarInicio = false;
  bool _tabsPodeRolarFim = false;

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
    _tabsScrollController.addListener(_atualizarIndicadoresTabs);
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
    _tabsScrollController.dispose();
    _thumbnailCache.dispose();
    super.dispose();
  }

  void _atualizarIndicadoresTabs() {
    if (!mounted || !_tabsScrollController.hasClients) return;

    final position = _tabsScrollController.position;
    final podeRolarInicio = position.pixels > 1;
    final podeRolarFim = position.pixels < position.maxScrollExtent - 1;

    if (_tabsPodeRolarInicio == podeRolarInicio &&
        _tabsPodeRolarFim == podeRolarFim) {
      return;
    }

    setState(() {
      _tabsPodeRolarInicio = podeRolarInicio;
      _tabsPodeRolarFim = podeRolarFim;
    });
  }

  void _rolarTabs(int direcao) {
    if (!_tabsScrollController.hasClients) return;

    final position = _tabsScrollController.position;
    final destino = (position.pixels + (direcao * 140))
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    _tabsScrollController.animateTo(
      destino,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _iniciarPreloadConteudo() {
    _conteudoPreloadSubscription?.cancel();

    final startupId = _startupId;
    if (startupId == null) {
      _conteudoPreloadVersao++;
      _thumbnailCache.syncWithUrls(const []);
      return;
    }

    _conteudoPreloadSubscription = FirebaseFirestore.instance
        .collection('startups')
        .doc(startupId)
        .snapshots()
        .listen((snapshot) async {
          final versao = ++_conteudoPreloadVersao;
          final data = snapshot.data();

          if (!snapshot.exists || data == null) {
            _thumbnailCache.syncWithUrls(const []);
            return;
          }

          final videos = await carregarVideosStartup(
            startupId: startupId,
            data: data,
          );

          if (!mounted || versao != _conteudoPreloadVersao) return;

          _thumbnailCache.syncWithUrls(videos.map((video) => video.url));
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
        backgroundColor: theme.scaffoldBackgroundColor,
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
        return Center(
          child: Text(
            'Em construção',
            style: TextStyle(
              color: Theme.of(context).extension<AppThemeColors>()!.mutedText,
            ),
          ),
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
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            tooltip: 'Voltar',
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
              child: _buildLogo(
                widget.startup['imagem'] ?? '',
                widget.startup['logoStoragePath'] ?? '',
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.startup['nome'] ?? 'Nome da startup',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

  Widget _buildLogo(String imagem, String logoStoragePath) {
    const fallback = Icon(Icons.business, color: _azulPrimario, size: 36);

    if (imagem.startsWith('http://') || imagem.startsWith('https://')) {
      return Image.network(
        imagem,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    if (imagem.isNotEmpty) {
      return Image.asset(
        imagem,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    if (logoStoragePath.isEmpty) return fallback;

    return FutureBuilder<String?>(
      future: _logoUrlFutures.putIfAbsent(
        logoStoragePath,
        () => _buscarLogoUrl(logoStoragePath),
      ),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) return fallback;

        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );
      },
    );
  }

  Future<String?> _buscarLogoUrl(String storagePath) async {
    try {
      final ref = storagePath.startsWith('gs://')
          ? FirebaseStorage.instance.refFromURL(storagePath)
          : FirebaseStorage.instance.ref(storagePath);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  // ── STATS CARD ────────────────────────────────────────────────────────────

  Widget _buildStatsCard() {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final precoToken = _formatarPrecoToken();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: themeColors.shadow.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compacto = constraints.maxWidth < 360;

          if (!compacto) {
            return Row(
              children: [
                _buildStatItem(
                  Icons.sell_outlined,
                  'Preço do Token',
                  precoToken,
                ),
                _buildDivisor(),
                _buildStatItem(
                  Icons.toll_outlined,
                  'Tokens emitidos',
                  widget.startup['tokens'] ?? 'Não informado',
                ),
                _buildDivisor(),
                _buildStatItem(
                  Icons.account_balance_outlined,
                  'Capital aportado',
                  'R\$ ${widget.startup['capital'] ?? '0,00'}',
                ),
              ],
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 116,
                  child: _buildStatItem(
                    Icons.sell_outlined,
                    'Preço do Token',
                    precoToken,
                    expanded: false,
                  ),
                ),
                _buildDivisor(),
                SizedBox(
                  width: 116,
                  child: _buildStatItem(
                    Icons.toll_outlined,
                    'Tokens emitidos',
                    widget.startup['tokens'] ?? 'Não informado',
                    expanded: false,
                  ),
                ),
                _buildDivisor(),
                SizedBox(
                  width: 130,
                  child: _buildStatItem(
                    Icons.account_balance_outlined,
                    'Capital aportado',
                    'R\$ ${widget.startup['capital'] ?? '0,00'}',
                    expanded: false,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String valor, {
    bool expanded = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    final content = Semantics(
      label: '$label: $valor',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, color: _azulPrimario, size: 22)),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: themeColors.mutedText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            valor,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );

    return expanded ? Expanded(child: content) : content;
  }

  Widget _buildDivisor() => Container(
    width: 1,
    height: 44,
    color: Theme.of(context).extension<AppThemeColors>()!.panelBorder,
  );

  // ── TABS ──────────────────────────────────────────────────────────────────

  Widget _buildTabs() {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _atualizarIndicadoresTabs();
    });

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: themeColors.panelBorder)),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _tabsScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: _tabs.map((tab) {
                final ativo = _tabAtiva == tab;
                return Semantics(
                  button: true,
                  selected: ativo,
                  label: 'Aba $tab',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _tabAtiva = tab),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 108,
                          minHeight: 48,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: ativo ? _azulPrimario : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: Text(
                          tab,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: ativo
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: ativo
                                ? _azulPrimario
                                : themeColors.mutedText,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_tabsPodeRolarInicio) _buildIndicadorRolarTabs(esquerda: true),
          if (_tabsPodeRolarFim) _buildIndicadorRolarTabs(esquerda: false),
        ],
      ),
    );
  }

  Widget _buildIndicadorRolarTabs({required bool esquerda}) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Positioned(
      top: 0,
      bottom: 0,
      left: esquerda ? 0 : null,
      right: esquerda ? null : 0,
      child: Container(
        width: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: esquerda ? Alignment.centerLeft : Alignment.centerRight,
            end: esquerda ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              background.withValues(alpha: 0.98),
              background.withValues(alpha: 0),
            ],
          ),
        ),
        alignment: esquerda ? Alignment.centerLeft : Alignment.centerRight,
        child: Tooltip(
          message: esquerda ? 'Ver abas anteriores' : 'Ver mais abas',
          child: IconButton(
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            iconSize: 22,
            onPressed: () => _rolarTabs(esquerda ? -1 : 1),
            style: IconButton.styleFrom(
              backgroundColor: themeColors.elevatedSurface,
              foregroundColor: _azulPrimario,
              side: BorderSide(color: themeColors.panelBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            icon: Icon(esquerda ? Icons.chevron_left : Icons.chevron_right),
          ),
        ),
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

  String _formatarPrecoToken() {
    final preco = _numero(
      widget.startup['valorToken'] ??
          widget.startup['precoToken'] ??
          widget.startup['preco'],
    );

    if (preco <= 0) return 'Não informado';
    return _formatarMoeda(preco);
  }

  double _numero(String? value) {
    if (value == null) return 0;

    final text = value.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (text.isEmpty) return 0;

    final normalized = text.contains(',')
        ? text.replaceAll('.', '').replaceAll(',', '.')
        : text;
    return double.tryParse(normalized) ?? 0;
  }

  String _formatarMoeda(double valor) {
    final partes = valor.toStringAsFixed(2).split('.');
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

    return 'R\$ ${buffer.toString()},$centavos';
  }
}
