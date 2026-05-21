import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'visao_geral_utils.dart';

class AbaPerguntas extends StatefulWidget {
  const AbaPerguntas({
    super.key,
    required this.startupId,
    required this.uid,
    required this.nomeUsuario,
  });

  final String? startupId;
  final String? uid;
  final String nomeUsuario;

  @override
  State<AbaPerguntas> createState() => _AbaPerguntasState();
}

class _AbaPerguntasState extends State<AbaPerguntas> {
  final Set<String> _expandidas = {};
  bool _chatAberto = false;
  final _controllerPublico = TextEditingController();
  final _controllerPrivado = TextEditingController();

  @override
  void dispose() {
    _controllerPublico.dispose();
    _controllerPrivado.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chatAberto) return _buildChat();

    final sId = widget.startupId;
    if (sId == null) {
      return _buildEstado('Startup sem identificador para perguntas.');
    }

    return StreamBuilder<bool>(
      stream: usuarioTemTokensStream(sId, widget.uid),
      initialData: false,
      builder: (context, investidorSnap) {
        final temTokens = investidorSnap.data ?? false;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _perguntasStream(sId, isPrivada: false),
          builder: (context, perguntasSnap) {
            if (perguntasSnap.hasError) {
              return _buildEstado('Não foi possível carregar as perguntas.');
            }

            final carregando = !perguntasSnap.hasData;
            final perguntas = perguntasSnap.data == null
                ? <PerguntaStartup>[]
                : _ordenar(
                    perguntasSnap.data!.docs
                        .map(PerguntaStartup.fromDoc)
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
                        child: CircularProgressIndicator(color: kVgAzul),
                      ),
                    )
                  else if (perguntas.isEmpty)
                    _buildMensagem('Ainda não há perguntas públicas.')
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
                  _buildAreaInvestidorCard(temTokens: temTokens),
                  const SizedBox(height: 16),
                  _buildInputPublico(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── CHAT PRIVADO ─────────────────────────────────────────────────────────

  Widget _buildChat() {
    final sId = widget.startupId;
    if (sId == null) {
      return _buildEstado('Startup sem identificador para perguntas.');
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEBEDF8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Área do Investidor',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Acompanhe este canal para receber atualizações exclusivas '
                      'assim que sua solicitação for respondida',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _chatAberto = false),
                child: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.grey,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<bool>(
            stream: usuarioTemTokensStream(sId, widget.uid),
            initialData: false,
            builder: (context, snap) {
              if (!(snap.data ?? false)) {
                return _buildEstado(
                  'Você precisa possuir tokens desta startup para acessar as perguntas privadas.',
                );
              }
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _perguntasStream(sId, isPrivada: true),
                builder: (context, pergSnap) {
                  if (pergSnap.hasError) {
                    return _buildEstado(
                      'Não foi possível carregar as perguntas privadas.',
                    );
                  }
                  if (!pergSnap.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: kVgAzul),
                    );
                  }
                  final perguntas = _ordenar(
                    pergSnap.data!.docs.map(PerguntaStartup.fromDoc).toList(),
                  );
                  if (perguntas.isEmpty) {
                    return _buildEstado(
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

  // ── WIDGETS ───────────────────────────────────────────────────────────────

  Widget _buildPerguntaItem(PerguntaStartup p) {
    final expandido = _expandidas.contains(p.id);
    return GestureDetector(
      onTap: () => setState(() {
        if (expandido) {
          _expandidas.remove(p.id);
        } else {
          _expandidas.add(p.id);
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
                color: kVgAzul,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.nomeUsuario.isNotEmpty) ...[
                    Text(
                      p.nomeUsuario,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    p.texto,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (expandido) ...[
                    const SizedBox(height: 6),
                    Text(
                      p.respostaExibida,
                      style: TextStyle(
                        fontSize: 12,
                        color: p.foiRespondida
                            ? Colors.grey
                            : Colors.grey.shade500,
                        fontStyle: p.foiRespondida
                            ? FontStyle.normal
                            : FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
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

  Widget _buildAreaInvestidorCard({required bool temTokens}) {
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
                  ? () => setState(() => _chatAberto = true)
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

  Widget _buildInputPublico() {
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
                    color: kVgAzul,
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

  Widget _buildPerguntaPrivada(PerguntaStartup p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBubble(p.texto, ehInvestidor: true),
        if (p.foiRespondida)
          _buildBubble(p.respostaExibida, ehInvestidor: false)
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

  Widget _buildBubble(String texto, {required bool ehInvestidor}) {
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
                color: kVgAzul,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: ehInvestidor ? kVgRoxoChat : Colors.white,
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
                  color: ehInvestidor
                      ? Colors.white
                      : const Color(0xFF1A1A2E),
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
                color: kVgAzul,
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
                color: kVgRoxoChat,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.near_me, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> _perguntasStream(
    String startupId, {
    required bool isPrivada,
  }) {
    return FirebaseFirestore.instance
        .collection('startups')
        .doc(startupId)
        .collection('questions')
        .where('isPrivada', isEqualTo: isPrivada)
        .snapshots();
  }

  Future<bool> _usuarioTemTokens(String startupId) async {
    final uid = widget.uid;
    if (uid == null) return false;
    final snap = await FirebaseFirestore.instance
        .collection('tokenHoldings')
        .where('userId', isEqualTo: uid)
        .get();
    return snap.docs.any((doc) {
      final data = doc.data();
      return parseText(data['startupId']) == startupId &&
          parseNumber(data['quantidade']).toInt() > 0;
    });
  }

  Future<void> _enviarPergunta({required bool isPrivada}) async {
    final sId = widget.startupId;
    final controller = isPrivada ? _controllerPrivado : _controllerPublico;
    final texto = controller.text.trim();
    if (texto.isEmpty) return;
    if (sId == null) {
      _mostrarMensagem('Startup sem identificador para perguntas.');
      return;
    }
    if (isPrivada) {
      if (widget.uid == null) {
        _mostrarMensagem('Entre na sua conta para enviar perguntas privadas.');
        return;
      }
      final temTokens = await _usuarioTemTokens(sId);
      if (!temTokens) {
        _mostrarMensagem(
          'Você precisa possuir tokens desta startup para enviar perguntas privadas.',
        );
        return;
      }
    }
    try {
      await FirebaseFirestore.instance
          .collection('startups')
          .doc(sId)
          .collection('questions')
          .add({
            'startupId': sId,
            'userId': widget.uid ?? '',
            'nomeUsuario': widget.nomeUsuario,
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

  List<PerguntaStartup> _ordenar(List<PerguntaStartup> lista) {
    return lista..sort((a, b) {
      final ca = a.createdAt;
      final cb = b.createdAt;
      if (ca == null && cb == null) return 0;
      if (ca == null) return 1;
      if (cb == null) return -1;
      return cb.compareTo(ca);
    });
  }

  Widget _buildEstado(String mensagem) {
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

  Widget _buildMensagem(String mensagem) {
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

  void _mostrarMensagem(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}
