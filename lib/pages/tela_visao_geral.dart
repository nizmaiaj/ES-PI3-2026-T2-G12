import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../services/auth_session.dart';
import '../widgets/app_bottom_nav.dart';
import 'balcao_negociacao.dart';

class TelaVisaoGeral extends StatefulWidget {
  final Map<String, String> startup;
  final ValueChanged<int>? onNavigate;

  const TelaVisaoGeral({super.key, required this.startup, this.onNavigate});

  @override
  State<TelaVisaoGeral> createState() => _TelaVisaoGeralState();
}

class _TelaVisaoGeralState extends State<TelaVisaoGeral> {
  String _tabAtiva = 'Visão Geral';
  bool _ehInvestidor = false;
  bool _verTodosAberto = false;
  final Set<String> _perguntasExpandidas = {};
  bool _investidorChatAberto = false;
  final TextEditingController _controllerPublico = TextEditingController();
  final TextEditingController _controllerPrivado = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _azulPrimario = Color(0xFF3F51B5);
  static const _roxoChat = Color(0xFF5B4FCF);

  static const _socios = [
    {
      'nome': 'Maria Fernanda Silva',
      'cargo': 'CEO',
      'percentual': '40%',
      'descricao': 'Campo destinado a descrição breve do sócio',
    },
    {
      'nome': 'Lucas Fernando Martins',
      'cargo': 'CTO',
      'percentual': '35%',
      'descricao': 'Campo destinado a descrição breve do sócio',
    },
    {
      'nome': 'João Pedro Rocha',
      'cargo': 'COO',
      'percentual': '25%',
      'descricao': 'Campo destinado a descrição breve do sócio',
    },
  ];

  static const _videos = [
    {'titulo': 'Título vídeo 1', 'descricao': 'Descrição breve'},
    {'titulo': 'Título vídeo 2', 'descricao': 'Descrição breve'},
  ];

  static const _documentos = ['Plano de negócios', 'Eventos'];

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
  void dispose() {
    _controllerPublico.dispose();
    _controllerPrivado.dispose();
    super.dispose();
  }

  // ── SCAFFOLD PRINCIPAL ─────────────────────────────────────────────────────

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
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildConteudoAtivo() {
    if (_tabAtiva == 'Sociedade' && _verTodosAberto) {
      return _buildVerTodosView();
    }
    switch (_tabAtiva) {
      case 'Visão Geral':
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              _buildConteudoCard(),
              const SizedBox(height: 16),
              _buildAreaInvestidor(),
            ],
          ),
        );
      case 'Sociedade':
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              _buildEstruturaCard(),
              const SizedBox(height: 16),
              _buildApresentacaoSocios(),
            ],
          ),
        );
      case 'Conteúdo':
        return _buildConteudoConteudo();
      case 'Perguntas':
        return _buildPerguntasConteudo();
      default:
        return const Center(
          child: Text('Em construção', style: TextStyle(color: Colors.grey)),
        );
    }
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

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
              child: _buildStartupLogo(widget.startup['imagem'] ?? ''),
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

  // ── STATS CARD ─────────────────────────────────────────────────────────────

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
          _buildDivisorV(),
          _buildStatItem(
            Icons.toll_outlined,
            'Tokens emitidos',
            widget.startup['tokens'] ?? '1.700',
          ),
          _buildDivisorV(),
          _buildStatItem(
            Icons.account_balance_outlined,
            'Capital aportado',
            'R\$ ${widget.startup['capital'] ?? '10.000,00'}',
          ),
        ],
      ),
    );
  }

  Widget _buildStartupLogo(String imagem) {
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

  Widget _buildDivisorV() =>
      Container(width: 1, height: 44, color: const Color(0xFFE0E0E0));

  // ── TABS ───────────────────────────────────────────────────────────────────

  Widget _buildTabs() {
    const tabs = ['Visão Geral', 'Sociedade', 'Conteúdo', 'Perguntas'];
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
      ),
      child: Row(
        children: tabs.map((tab) {
          final ativo = _tabAtiva == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _tabAtiva = tab;
                _verTodosAberto = false;
                _investidorChatAberto = false;
              }),
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
          );
        }).toList(),
      ),
    );
  }

  // ── ABA: VISÃO GERAL ───────────────────────────────────────────────────────

  Widget _buildConteudoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sumário Executivo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.startup['desc'] ??
                'Este campo é destinado a apresentar um resumo prévio da startup, '
                    'destacando seus principais objetivos, propostas e a atuação da empresa no mercado.',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Destaques',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Este campo é destinado a apresentar um resumo prévio da startup, '
            'destacando seus principais objetivos, propostas e a atuação da empresa no mercado.',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.55),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaInvestidor() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEBEDF8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Área do Investidor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _ehInvestidor
                ? 'Bem-vindo! Acesse o balcão completo para comprar e vender tokens desta startup.'
                : 'Se você já é investidor, poderá acessar o balcão completo para comprar e vender tokens. '
                      'Caso ainda não investe nesta startup, você poderá iniciar sua participação adquirindo '
                      'seus primeiros tokens e desbloqueando recursos exclusivos para investidores',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              height: 1.55,
            ),
          ),
          if (!_ehInvestidor) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: Colors.deepOrange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No momento, você ainda não possui participação nesta startup. '
                      'Para desbloquear recursos de compra e venda avançados, é necessário '
                      'realizar seu primeiro investimento',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _ehInvestidor = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3680),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Já sou investidor',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _azulPrimario,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Quero me tornar\ninvestidor',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── ABA: SOCIEDADE ─────────────────────────────────────────────────────────

  Widget _buildEstruturaCard() {
    const coresSocios = [
      Color(0xFF3F51B5),
      Color(0xFF7C52D4),
      Color(0xFFEC4899),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estrutura Societária',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _GraficoDonutPainter(),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '100%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
                          'Total',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(_socios.length, (i) {
                    final s = _socios[i];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i < _socios.length - 1 ? 12 : 0,
                      ),
                      child: _buildLegendaItem(
                        coresSocios[i],
                        '${s['nome']} (${s['cargo']})',
                        s['percentual']!,
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendaItem(Color cor, String nome, String percentual) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            nome,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ),
        Text(
          percentual,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _buildApresentacaoSocios() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Apresentação dos Sócios',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _verTodosAberto = true),
                child: const Text(
                  'Ver todos',
                  style: TextStyle(
                    fontSize: 12,
                    color: _azulPrimario,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_socios.length, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i < _socios.length - 1 ? 8 : 0,
                  ),
                  child: _buildSocioCardCompacto(_socios[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSocioCardCompacto(Map<String, String> socio) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.person_outline,
              color: _azulPrimario,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            socio['nome']!,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            socio['cargo']!,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            socio['descricao']!,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVerTodosView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Apresentação dos Sócios',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _verTodosAberto = false),
                    child: const Text(
                      'X',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(_socios.length, (i) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  i == _socios.length - 1 ? 20 : 4,
                ),
                child: _buildSocioCardExpandido(_socios[i]),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSocioCardExpandido(Map<String, String> socio) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.person_outline,
              color: _azulPrimario,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  socio['nome']!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  socio['cargo']!,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  socio['descricao']!,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ABA: CONTEÚDO ──────────────────────────────────────────────────────────

  Widget _buildConteudoConteudo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          _buildVideosCard(),
          const SizedBox(height: 16),
          _buildDocumentosCard(),
        ],
      ),
    );
  }

  Widget _buildVideosCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vídeos de apresentação',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Conheça mais sobre a startup através de conteúdos selecionados',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ...List.generate(_videos.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: i < _videos.length - 1 ? 14 : 0),
              child: _buildVideoItem(
                _videos[i]['titulo']!,
                _videos[i]['descricao']!,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVideoItem(String titulo, String descricao) {
    return Row(
      children: [
        Container(
          width: 110,
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFFD4D4D4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.play_circle_outline,
            color: Colors.white,
            size: 38,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              descricao,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentosCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Documentos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(_documentos.length, (i) {
            return Column(
              children: [
                _buildDocumentoItem(_documentos[i]),
                if (i < _documentos.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDocumentoItem(String nome) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEBEDF8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.insert_drive_file_outlined,
            color: _azulPrimario,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          nome,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ── ABA: PERGUNTAS ─────────────────────────────────────────────────────────

  Widget _buildPerguntasConteudo() {
    if (_investidorChatAberto) return _buildInvestidorChat();
    final startupId = _startupId;

    if (startupId == null) {
      return _buildEstadoPerguntas('Startup sem identificador para perguntas.');
    }

    return StreamBuilder<bool>(
      stream: _usuarioTemTokensStream(startupId),
      initialData: false,
      builder: (context, investidorSnapshot) {
        final temTokens = investidorSnapshot.data ?? false;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _perguntasStream(startupId, isPrivada: false),
          builder: (context, perguntasSnapshot) {
            if (perguntasSnapshot.hasError) {
              return _buildEstadoPerguntas(
                'Não foi possível carregar as perguntas.',
              );
            }

            final carregando = !perguntasSnapshot.hasData;
            final perguntas = perguntasSnapshot.data == null
                ? <_PerguntaStartup>[]
                : _ordenarPerguntas(
                    perguntasSnapshot.data!.docs
                        .map(_PerguntaStartup.fromDoc)
                        .toList(),
                  );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perguntas e respostas públicas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Confira dúvidas frequentes da comunidade sobre a startup',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  if (carregando)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(color: _azulPrimario),
                      ),
                    )
                  else if (perguntas.isEmpty)
                    _buildMensagemPerguntas('Ainda não há perguntas públicas.')
                  else
                    ...List.generate(perguntas.length, (i) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: i < perguntas.length - 1 ? 10 : 0,
                        ),
                        child: _buildPerguntaItem(perguntas[i]),
                      );
                    }),
                  const SizedBox(height: 16),
                  _buildAreaInvestidorPerguntasCard(temTokens: temTokens),
                  const SizedBox(height: 16),
                  _buildInputPerguntaPublica(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPerguntaItem(_PerguntaStartup pergunta) {
    final expandido = _perguntasExpandidas.contains(pergunta.id);

    return GestureDetector(
      onTap: () => setState(() {
        if (expandido) {
          _perguntasExpandidas.remove(pergunta.id);
        } else {
          _perguntasExpandidas.add(pergunta.id);
        }
      }),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE7F6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.person_outline,
                color: _azulPrimario,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pergunta.nomeUsuario.isNotEmpty) ...[
                    Text(
                      pergunta.nomeUsuario,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    pergunta.texto,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (expandido) ...[
                    const SizedBox(height: 6),
                    Text(
                      pergunta.respostaExibida,
                      style: TextStyle(
                        fontSize: 12,
                        color: pergunta.foiRespondida
                            ? Colors.grey
                            : Colors.grey.shade500,
                        fontStyle: pergunta.foiRespondida
                            ? FontStyle.normal
                            : FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    if (pergunta.isPrivada) ...[
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 13,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Pergunta privada',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: expandido ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaInvestidorPerguntasCard({required bool temTokens}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEBEDF8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Área do Investidor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Como investidor, você pode enviar perguntas privadas diretamente a startup '
            'para obter informações estratégicas e exclusivas.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: temTokens
                  ? () => setState(() => _investidorChatAberto = true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C3680),
                disabledBackgroundColor: Colors.grey.shade400,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Enviar pergunta privada',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (!temTokens) ...[
            const SizedBox(height: 10),
            const Text(
              'Perguntas privadas ficam disponíveis para usuários que possuem tokens desta startup.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputPerguntaPublica() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tem uma Pergunta?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controllerPublico,
                  decoration: InputDecoration(
                    hintText: 'Digite sua pergunta...',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FE),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _enviarPergunta(isPrivada: false),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: _azulPrimario,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.near_me,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CHAT PRIVADO DO INVESTIDOR ─────────────────────────────────────────────

  Widget _buildInvestidorChat() {
    final startupId = _startupId;

    if (startupId == null) {
      return _buildEstadoPerguntas('Startup sem identificador para perguntas.');
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFEBEDF8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Área do Investidor',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _investidorChatAberto = false),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.grey,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Acompanhe este canal para receber atualizações exclusivas assim que '
                'sua solicitação for respondida',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<bool>(
            stream: _usuarioTemTokensStream(startupId),
            initialData: false,
            builder: (context, investidorSnapshot) {
              final temTokens = investidorSnapshot.data ?? false;

              if (!temTokens) {
                return _buildEstadoPerguntas(
                  'Você precisa possuir tokens desta startup para acessar as perguntas privadas.',
                );
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _perguntasStream(startupId, isPrivada: true),
                builder: (context, perguntasSnapshot) {
                  if (perguntasSnapshot.hasError) {
                    return _buildEstadoPerguntas(
                      'Não foi possível carregar as perguntas privadas.',
                    );
                  }

                  if (!perguntasSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: _azulPrimario),
                    );
                  }

                  final perguntas = _ordenarPerguntas(
                    perguntasSnapshot.data!.docs
                        .map(_PerguntaStartup.fromDoc)
                        .toList(),
                  );

                  if (perguntas.isEmpty) {
                    return _buildEstadoPerguntas(
                      'Nenhuma pergunta privada enviada ainda.',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    itemCount: perguntas.length,
                    itemBuilder: (_, i) => _buildPerguntaPrivada(perguntas[i]),
                  );
                },
              );
            },
          ),
        ),
        _buildChatInput(),
      ],
    );
  }

  Widget _buildPerguntaPrivada(_PerguntaStartup pergunta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMensagemBubble(pergunta.texto, ehInvestidor: true),
        if (pergunta.foiRespondida)
          _buildMensagemBubble(pergunta.respostaExibida, ehInvestidor: false)
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Aguardando resposta do empreendedor',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMensagemBubble(String texto, {required bool ehInvestidor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: ehInvestidor
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!ehInvestidor) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFEDE7F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                color: _azulPrimario,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: ehInvestidor ? _roxoChat : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(ehInvestidor ? 16 : 4),
                  bottomRight: Radius.circular(ehInvestidor ? 4 : 16),
                ),
              ),
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 12,
                  color: ehInvestidor ? Colors.white : const Color(0xFF1A1A2E),
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (ehInvestidor) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFEDE7F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                color: _azulPrimario,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: const Color(0xFFF8F9FE),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: TextField(
                controller: _controllerPrivado,
                decoration: const InputDecoration(
                  hintText: 'Digite sua pergunta...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _enviarPergunta(isPrivada: true),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: _roxoChat,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.near_me, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _perguntasStream(
    String startupId, {
    required bool isPrivada,
  }) {
    return _firestore
        .collection('startups')
        .doc(startupId)
        .collection('questions')
        .where('isPrivada', isEqualTo: isPrivada)
        .snapshots();
  }

  Stream<bool> _usuarioTemTokensStream(String startupId) {
    final uid = _uid;

    if (uid == null) return Stream.value(false);

    return _firestore
        .collection('tokenHoldings')
        .doc('${uid}_$startupId')
        .snapshots()
        .map((doc) => _numero(doc.data()?['quantidade']).toInt() > 0);
  }

  Future<void> _enviarPergunta({required bool isPrivada}) async {
    final startupId = _startupId;
    final uid = _uid;
    final controller = isPrivada ? _controllerPrivado : _controllerPublico;
    final texto = controller.text.trim();

    if (texto.isEmpty) return;
    if (startupId == null) {
      _mostrarMensagem('Startup sem identificador para perguntas.');
      return;
    }

    if (isPrivada) {
      if (uid == null) {
        _mostrarMensagem('Entre na sua conta para enviar perguntas privadas.');
        return;
      }

      final holding = await _firestore
          .collection('tokenHoldings')
          .doc('${uid}_$startupId')
          .get();
      final temTokens = _numero(holding.data()?['quantidade']).toInt() > 0;

      if (!temTokens) {
        _mostrarMensagem(
          'Você precisa possuir tokens desta startup para enviar perguntas privadas.',
        );
        return;
      }
    }

    try {
      await _firestore
          .collection('startups')
          .doc(startupId)
          .collection('questions')
          .add({
            'startupId': startupId,
            'userId': uid ?? '',
            'nomeUsuario': _nomeUsuario,
            'texto': texto,
            'resposta': null,
            'respondidaEm': null,
            'isPrivada': isPrivada,
            'createdAt': FieldValue.serverTimestamp(),
          });

      controller.clear();
      _mostrarMensagem('Pergunta enviada com sucesso.');
    } catch (_) {
      _mostrarMensagem('Não foi possível enviar a pergunta.');
    }
  }

  List<_PerguntaStartup> _ordenarPerguntas(List<_PerguntaStartup> perguntas) {
    return perguntas..sort((a, b) {
      final createdAtA = a.createdAt;
      final createdAtB = b.createdAt;

      if (createdAtA == null && createdAtB == null) return 0;
      if (createdAtA == null) return 1;
      if (createdAtB == null) return -1;

      return createdAtB.compareTo(createdAtA);
    });
  }

  Widget _buildEstadoPerguntas(String mensagem) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildMensagemPerguntas(String mensagem) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        mensagem,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54, fontSize: 12),
      ),
    );
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), behavior: SnackBarBehavior.floating),
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return AppBottomNav(
      selectedIndex: 1,
      onItemSelected: _selecionarNav,
      backgroundColor: const Color(0xFFF8F9FE),
    );
  }

  void _selecionarNav(int index) {
    if (index == 1) {
      return;
    }

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
}

class _PerguntaStartup {
  const _PerguntaStartup({
    required this.id,
    required this.nomeUsuario,
    required this.texto,
    required this.resposta,
    required this.isPrivada,
    required this.createdAt,
  });

  factory _PerguntaStartup.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return _PerguntaStartup(
      id: doc.id,
      nomeUsuario: _texto(data['nomeUsuario']),
      texto: _texto(data['texto'], fallback: 'Pergunta sem texto'),
      resposta: _texto(data['resposta']),
      isPrivada: data['isPrivada'] == true,
      createdAt: _dateTime(data['createdAt']),
    );
  }

  final String id;
  final String nomeUsuario;
  final String texto;
  final String resposta;
  final bool isPrivada;
  final DateTime? createdAt;

  bool get foiRespondida => resposta.trim().isNotEmpty;

  String get respostaExibida =>
      foiRespondida ? resposta : 'Aguardando resposta do empreendedor.';
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

DateTime? _dateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  return null;
}

// ── GRÁFICO DONUT ────────────────────────────────────────────────────────────

class _GraficoDonutPainter extends CustomPainter {
  static const _segmentos = [
    (percentual: 0.40, cor: Color(0xFF3F51B5), label: '40%'),
    (percentual: 0.35, cor: Color(0xFF7C52D4), label: '35%'),
    (percentual: 0.25, cor: Color(0xFFEC4899), label: '25%'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 26.0;
    const gap = 0.04;

    double startAngle = -math.pi / 2;

    for (final seg in _segmentos) {
      final sweepAngle = 2 * math.pi * seg.percentual - gap;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle + gap / 2,
        sweepAngle,
        false,
        Paint()
          ..color = seg.cor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );

      final midAngle = startAngle + gap / 2 + sweepAngle / 2;
      final labelR = radius - strokeWidth / 2;
      final lx = center.dx + labelR * math.cos(midAngle);
      final ly = center.dy + labelR * math.sin(midAngle);

      final tp = TextPainter(
        text: TextSpan(
          text: seg.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));

      startAngle += 2 * math.pi * seg.percentual;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
