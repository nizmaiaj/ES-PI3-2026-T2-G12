// Eduarda Prado Deiró - RA: 25004440
// Canal público de perguntas e chat privado disponível para investidores.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/functions_api_client.dart';
import '../../theme/app_theme.dart';
import 'visao_geral_utils.dart';

/// Lista dúvidas públicas e oferece conversa privada a quem possui tokens.
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
        final colorScheme = Theme.of(context).colorScheme;
        final themeColors = Theme.of(context).extension<AppThemeColors>()!;

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
                  Text(
                    'Perguntas e respostas públicas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Confira dúvidas frequentes da comunidade sobre a startup',
                    style: TextStyle(
                      fontSize: 12,
                      color: themeColors.faintText,
                    ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
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
            color: themeColors.subtleSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Área do Investidor',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Acompanhe este canal para receber atualizações exclusivas '
                      'assim que sua solicitação for respondida',
                      style: TextStyle(
                        fontSize: 11,
                        color: themeColors.mutedText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Voltar para perguntas',
                onPressed: () => setState(() => _chatAberto = false),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.grey,
                  size: 18,
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
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final expandido = _expandidas.contains(p.id);
    return Semantics(
      button: true,
      expanded: expandido,
      label: 'Pergunta de ${p.nomeUsuario.isEmpty ? 'usuário' : p.nomeUsuario}',
      child: GestureDetector(
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
            color: themeColors.elevatedSurface,
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
                        style: TextStyle(
                          fontSize: 11,
                          color: themeColors.faintText,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      p.texto,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (expandido) ...[
                      const SizedBox(height: 6),
                      Text(
                        p.respostaExibida,
                        style: TextStyle(
                          fontSize: 12,
                          color: p.foiRespondida
                              ? themeColors.mutedText
                              : themeColors.faintText,
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
      ),
    );
  }

  Widget _buildAreaInvestidorCard({required bool temTokens}) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeColors.subtleSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Área do Investidor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Como investidor, você pode enviar perguntas privadas diretamente a startup '
            'para obter informações estratégicas e exclusivas.',
            style: TextStyle(
              fontSize: 12,
              color: themeColors.mutedText,
              height: 1.5,
            ),
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
            Text(
              'Perguntas privadas ficam disponíveis para usuários que possuem tokens desta startup.',
              style: TextStyle(fontSize: 11, color: themeColors.mutedText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputPublico() {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tem uma pergunta?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controllerPublico,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _enviarPergunta(isPrivada: false),
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Pergunta pública',
                    hintText: 'Digite sua pergunta...',
                    labelStyle: TextStyle(
                      color: themeColors.mutedText,
                      fontSize: 12,
                    ),
                    hintStyle: TextStyle(
                      color: themeColors.faintText,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: themeColors.subtleSurface,
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
              SizedBox(
                width: 48,
                height: 48,
                child: Tooltip(
                  message: 'Enviar pergunta pública',
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: kVgAzul,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _enviarPergunta(isPrivada: false),
                    icon: const Icon(Icons.near_me, size: 20),
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
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

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
                color: themeColors.mutedText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBubble(String texto, {required bool ehInvestidor}) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

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
              child: const Icon(Icons.person_outline, color: kVgAzul, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: ehInvestidor ? kVgRoxoChat : themeColors.elevatedSurface,
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
                  color: ehInvestidor ? Colors.white : colorScheme.onSurface,
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
              child: const Icon(Icons.person_outline, color: kVgAzul, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: themeColors.elevatedSurface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: themeColors.panelBorder),
              ),
              child: TextField(
                controller: _controllerPrivado,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _enviarPergunta(isPrivada: true),
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Pergunta privada',
                  hintText: 'Digite sua pergunta...',
                  labelStyle: TextStyle(
                    color: themeColors.mutedText,
                    fontSize: 12,
                  ),
                  hintStyle: TextStyle(
                    color: themeColors.faintText,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: Tooltip(
              message: 'Enviar pergunta privada',
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: kVgRoxoChat,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _enviarPergunta(isPrivada: true),
                icon: const Icon(Icons.near_me, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  /// Escuta perguntas da startup e deixa a filtragem de privacidade para a UI.
  Stream<QuerySnapshot<Map<String, dynamic>>> _perguntasStream(
    String startupId, {
    required bool isPrivada,
  }) {
    final query = FirebaseFirestore.instance
        .collection('startups')
        .doc(startupId)
        .collection('questions')
        .where('isPrivada', isEqualTo: isPrivada);

    if (!isPrivada) return query.snapshots();

    final uid = widget.uid;
    if (uid == null) return const Stream.empty();

    return query.where('userId', isEqualTo: uid).snapshots();
  }

  /// Confere se o usuário possui tokens antes de habilitar o canal privado.
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

  /// Envia pergunta pública ou privada por uma Function autenticada.
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
      await FunctionsApiClient.instance.post(
        'startupsCreateQuestion',
        body: {'startupId': sId, 'texto': texto, 'isPrivada': isPrivada},
      );
      controller.clear();
      _mostrarMensagem('Pergunta enviada com sucesso.');
    } on FunctionsApiException catch (error) {
      _mostrarMensagem(error.message);
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
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: TextStyle(color: themeColors.mutedText, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildMensagem(String mensagem) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        mensagem,
        textAlign: TextAlign.center,
        style: TextStyle(color: themeColors.mutedText, fontSize: 12),
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
