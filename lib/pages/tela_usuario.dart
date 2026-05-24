import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_session.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sms_code_dialog.dart';
import '../widgets/theme_mode_selector.dart';
import 'tela_inicial.dart';

class TelaUsuario extends StatefulWidget {
  final String nomeFallback;

  const TelaUsuario({super.key, this.nomeFallback = ''});

  @override
  State<TelaUsuario> createState() => _TelaUsuarioState();
}

class _TelaUsuarioState extends State<TelaUsuario> {
  static const _roxo = Color(0xFF4C3BCF);

  bool _salvandoMfa = false;
  String? _erro;

  // Identifica o usuario logado pelo Firebase Auth ou pela sessao salva no app.
  String? get _uid => FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

  // Referencia do documento do usuario no Firestore: users/{uid}.
  DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  // Atualiza no Firebase Auth e no Firestore se o 2FA por SMS está ativado.
  Future<void> _alterarMfa(bool habilitado, String telefone) async {
    final ref = _userRef;
    if (ref == null) {
      setState(() => _erro = 'Usuário não autenticado.');
      return;
    }

    setState(() {
      _salvandoMfa = true;
      _erro = null;
    });

    try {
      final authService = AuthService();
      String? phoneNumber;

      if (habilitado) {
        final mfaPhoneNumber = AuthService.normalizePhoneNumberForSmsMfa(
          telefone,
        );
        phoneNumber = mfaPhoneNumber;

        await authService.enrollSmsMfa(
          phoneNumber: mfaPhoneNumber,
          smsCodeResolver: (_, _) {
            if (!mounted) return Future.value(null);
            return showSmsCodeDialog(
              context,
              phoneNumber: mfaPhoneNumber,
              title: 'Ativar verificação em duas etapas',
              message:
                  'Digite o código enviado por SMS para cadastrar este telefone.',
            );
          },
        );
      } else {
        await authService.unenrollSmsMfa();
      }

      await ref.set({
        'mfaHabilitado': habilitado,
        'mfaTelefone': habilitado ? phoneNumber : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            habilitado
                ? 'Verificação em duas etapas ativada.'
                : 'Verificação em duas etapas desativada.',
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _erro = error.message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _erro = error.message ?? 'Não foi possível salvar.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _erro = 'Não foi possível salvar.');
    } finally {
      if (mounted) setState(() => _salvandoMfa = false);
    }
  }

  Future<void> _sairDaConta() async {
    await AuthService().logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const TelaInicial()),
      (route) => false,
    );
  }

  Future<void> _confirmarSaida() async {
    final deveSair = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sair da conta?'),
          content: const Text(
            'Ao sair, você será desconectado e precisará fazer login novamente para acessar sua conta.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: _roxo),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (deveSair == true) {
      await _sairDaConta();
    }
  }

  String _formatarCpf(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return value.isEmpty ? '000.000.000-00' : value;
    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
  }

  String _formatarTelefone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return value.isEmpty ? '(11) 91234-5678' : value;
  }

  @override
  Widget build(BuildContext context) {
    final ref = _userRef;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    // Estrutura principal da tela, com o fundo escuro e o painel branco central.
    return Scaffold(
      backgroundColor: themeColors.modalBackdrop,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: Container(
                width: double.infinity,
                height: constraints.maxHeight - 36,
                margin: const EdgeInsets.symmetric(horizontal: 22),
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  color: themeColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: themeColors.panelBorder, width: 5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: ref == null
                      ? _buildEstadoMensagem('Usuário não autenticado.')
                      // Escuta os dados do usuario em tempo real no Firestore.
                      : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: ref.snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(color: _roxo),
                              );
                            }

                            if (snapshot.hasError) {
                              return _buildEstadoMensagem(
                                'Não foi possível carregar seus dados.',
                              );
                            }

                            final dados = snapshot.data?.data() ?? {};
                            return _buildConteudo(dados);
                          },
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEstadoMensagem(String mensagem) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(Icons.close, color: colorScheme.onSurface, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudo(Map<String, dynamic> dados) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    // Extrai os campos que vieram do Firebase para preencher a tela.
    final nomeCompleto = (dados['nomeCompleto'] as String?)?.trim();
    final nomeFallback = nomeCompleto?.isNotEmpty == true
        ? nomeCompleto!
        : widget.nomeFallback;
    final email =
        (dados['email'] as String?) ??
        FirebaseAuth.instance.currentUser?.email ??
        AuthSession.email ??
        '';
    final cpf = (dados['cpf'] as String?) ?? '';
    final telefone = (dados['telefone'] as String?) ?? '';
    final mfaHabilitado = dados['mfaHabilitado'] == true;

    // Conteúdo rolável com dados pessoais e configuração do 2FA.
    return Column(
      children: [
        _buildCabecalho(nomeFallback),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seus dados',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDadosCard(
                  email: email,
                  cpf: _formatarCpf(cpf),
                  telefone: _formatarTelefone(telefone),
                ),
                const SizedBox(height: 26),
                Text(
                  'Configurações',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Tema do aplicativo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                const SizedBox(
                  width: double.infinity,
                  child: ThemeModeSelector(),
                ),
                const SizedBox(height: 26),
                Text(
                  'Verificação em duas etapas',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Adicione uma camada extra de segurança à sua conta.',
                  style: TextStyle(fontSize: 12, color: themeColors.mutedText),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ao ativar a verificação em duas etapas (2FA), será necessário confirmar sua identidade durante o login utilizando um código de verificação.',
                  style: TextStyle(
                    fontSize: 11,
                    color: themeColors.mutedText,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ativar Verificação em Duas Etapas',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Switch(
                      value: mfaHabilitado,
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        return Colors.white;
                      }),
                      trackColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return _roxo;
                        }
                        return Colors.grey.shade400;
                      }),
                      // Ao clicar, grava o novo valor do 2FA no Firestore.
                      onChanged: _salvandoMfa
                          ? null
                          : (value) => _alterarMfa(value, telefone),
                    ),
                  ],
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _erro!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sair da conta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _roxo,
                      side: const BorderSide(color: _roxo),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _confirmarSaida,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Cabecalho com icone do usuario, saudacao e botao X para voltar.
  Widget _buildCabecalho(String nome) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 18, 20),
      decoration: BoxDecoration(
        color: themeColors.subtleSurface,
        boxShadow: [
          BoxShadow(
            color: themeColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              Icon(
                Icons.account_circle_outlined,
                size: 28,
                color: colorScheme.onSurface,
              ),
              const SizedBox(height: 16),
              Text(
                'Olá, $nome',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 2,
            child: IconButton(
              icon: Icon(Icons.close, color: colorScheme.onSurface, size: 18),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Fechar',
            ),
          ),
        ],
      ),
    );
  }

  // Card que mostra os dados pessoais carregados do banco.
  Widget _buildDadosCard({
    required String email,
    required String cpf,
    required String telefone,
  }) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 22, 30, 26),
      decoration: BoxDecoration(
        color: themeColors.subtleSurface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: themeColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCampoDado('Email', email.isEmpty ? 'exemplo@email.com' : email),
          _buildDivisor(),
          _buildCampoDado('CPF', cpf),
          _buildDivisor(),
          _buildCampoDado('Telefone', telefone),
        ],
      ),
    );
  }

  Widget _buildCampoDado(String label, String valor) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          valor,
          style: TextStyle(fontSize: 12, color: themeColors.faintText),
        ),
      ],
    );
  }

  Widget _buildDivisor() {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Divider(height: 1, thickness: 1, color: themeColors.panelBorder),
    );
  }
}
