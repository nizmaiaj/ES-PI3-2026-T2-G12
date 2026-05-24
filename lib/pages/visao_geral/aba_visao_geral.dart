// Eduarda Prado Deiró

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'visao_geral_utils.dart';

class AbaVisaoGeral extends StatelessWidget {
  const AbaVisaoGeral({
    super.key,
    required this.startup,
    required this.startupId,
    required this.uid,
    required this.onAbrirBalcao,
    required this.onAbrirOfertasDaStartup,
  });

  final Map<String, String> startup;
  final String? startupId;
  final String? uid;
  final VoidCallback onAbrirBalcao;
  final VoidCallback onAbrirOfertasDaStartup;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          _buildSumario(context),
          const SizedBox(height: 16),
          _buildAreaInvestidor(context),
        ],
      ),
    );
  }

  Widget _buildSumario(BuildContext context) {
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
            'Sumário Executivo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            startup['desc'] ??
                'Este campo é destinado a apresentar um resumo prévio da startup, '
                    'destacando seus principais objetivos, propostas e a atuação da empresa no mercado.',
            style: TextStyle(
              fontSize: 13,
              color: themeColors.mutedText,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaInvestidor(BuildContext context) {
    final sId = startupId;
    if (sId == null) {
      return _buildCard(
        context: context,
        temTokens: false,
        mensagemBloqueio:
            'Não foi possível verificar sua participação porque a startup não possui identificador.',
      );
    }

    return StreamBuilder<bool>(
      stream: usuarioTemTokensStream(sId, uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildCard(
            context: context,
            temTokens: false,
            mensagemBloqueio:
                'Não foi possível verificar sua carteira neste momento.',
          );
        }
        if (!snapshot.hasData) {
          return _buildCard(
            context: context,
            temTokens: false,
            carregando: true,
          );
        }
        return _buildCard(context: context, temTokens: snapshot.data ?? false);
      },
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required bool temTokens,
    bool carregando = false,
    String? mensagemBloqueio,
  }) {
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
          const SizedBox(height: 10),
          Text(
            carregando
                ? 'Verificando sua carteira...'
                : temTokens
                ? 'Bem-vindo! Acesse o balcão completo para comprar e vender tokens desta startup.'
                : 'Se você já é investidor, poderá acessar o balcão completo para comprar e vender tokens. '
                      'Caso ainda não tenha investido nesta startup, você poderá iniciar sua participação adquirindo '
                      'seus primeiros tokens e desbloqueando recursos exclusivos para investidores.',
            style: TextStyle(
              fontSize: 12,
              color: themeColors.mutedText,
              height: 1.55,
            ),
          ),
          if (!carregando && !temTokens) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: themeColors.elevatedSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.deepOrange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mensagemBloqueio ??
                          'No momento, você ainda não possui participação nesta startup. '
                              'Para desbloquear recursos de compra e venda avançados, é necessário '
                              'realizar seu primeiro investimento.',
                      style: TextStyle(
                        fontSize: 11,
                        color: themeColors.mutedText,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: carregando
                  ? null
                  : temTokens
                  ? onAbrirBalcao
                  : onAbrirOfertasDaStartup,
              style: ElevatedButton.styleFrom(
                backgroundColor: temTokens ? const Color(0xFF2C3680) : kVgAzul,
                disabledBackgroundColor: kVgAzul.withValues(alpha: 0.35),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                temTokens ? 'Acessar balcão' : 'Quero me tornar investidor',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
