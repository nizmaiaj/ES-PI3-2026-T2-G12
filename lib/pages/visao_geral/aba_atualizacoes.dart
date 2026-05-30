// Eduarda Prado Deiró - RA: 25004440
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'visao_geral_utils.dart';

class AbaAtualizacoes extends StatelessWidget {
  const AbaAtualizacoes({super.key, required this.startupId});

  final String? startupId;

  @override
  Widget build(BuildContext context) {
    final sId = startupId;

    if (sId == null) {
      return _buildEstado(
        context,
        'Startup sem identificador para carregar as atualizações.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('startups')
          .doc(sId)
          .collection('updates')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEstado(
            context,
            'Não foi possível carregar as atualizações.',
          );
        }

        final colorScheme = Theme.of(context).colorScheme;
        final themeColors = Theme.of(context).extension<AppThemeColors>()!;

        final carregando = !snapshot.hasData;
        final atualizacoes = snapshot.data == null
            ? <AtualizacaoStartup>[]
            : _ordenar(
                snapshot.data!.docs.map(AtualizacaoStartup.fromDoc).toList(),
              );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Atualizações da empresa',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Acompanhe comunicados, notícias e marcos recentes da startup',
                style: TextStyle(fontSize: 12, color: themeColors.faintText),
              ),
              const SizedBox(height: 16),
              if (carregando)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(color: kVgAzul),
                  ),
                )
              else if (atualizacoes.isEmpty)
                _buildMensagem(
                  context,
                  'Ainda não há atualizações cadastradas para esta startup.',
                )
              else
                ...List.generate(atualizacoes.length, (i) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: i < atualizacoes.length - 1 ? 12 : 0,
                    ),
                    child: _buildItem(context, atualizacoes[i]),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItem(BuildContext context, AtualizacaoStartup at) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final cor = _cor(at.tipo);
    final dataExibida = at.createdAt == null
        ? 'Data não informada'
        : formatDataAtualizacao(at.createdAt!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
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
            child: Icon(_icone(at.tipo), color: cor, size: 22),
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
                        at.tipoExibido,
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
                  at.titulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  at.conteudo,
                  style: TextStyle(
                    fontSize: 12,
                    color: themeColors.mutedText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<AtualizacaoStartup> _ordenar(List<AtualizacaoStartup> lista) {
    return lista..sort((a, b) {
      final ca = a.createdAt;
      final cb = b.createdAt;
      if (ca == null && cb == null) return 0;
      if (ca == null) return 1;
      if (cb == null) return -1;
      return cb.compareTo(ca);
    });
  }

  Widget _buildEstado(BuildContext context, String mensagem) {
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

  Widget _buildMensagem(BuildContext context, String mensagem) {
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

  IconData _icone(String tipo) {
    final n = tipo.toLowerCase();
    if (n.contains('evento')) return Icons.event_note_outlined;
    if (n.contains('financ')) return Icons.trending_up_outlined;
    if (n.contains('produto')) return Icons.inventory_2_outlined;
    if (n.contains('not')) return Icons.article_outlined;
    return Icons.campaign_outlined;
  }

  Color _cor(String tipo) {
    final n = tipo.toLowerCase();
    if (n.contains('evento')) return const Color(0xFF7C52D4);
    if (n.contains('financ')) return const Color(0xFF059669);
    if (n.contains('produto')) return const Color(0xFF0EA5E9);
    if (n.contains('not')) return kVgAzul;
    return const Color(0xFFF59E0B);
  }
}
