import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_session.dart';
import '../services/auth_service.dart';
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

  // Atualiza no Firebase se a verificação em duas etapas está ativada.
  Future<void> _alterarMfa(bool habilitado) async {
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
      await ref.set({
        'mfaHabilitado': habilitado,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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

    // Estrutura principal da tela, com o fundo escuro e o painel branco central.
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFD8D1E0), width: 5),
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
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudo(Map<String, dynamic> dados) {
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
                const Text(
                  'Seus dados',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _buildDadosCard(
                  email: email,
                  cpf: _formatarCpf(cpf),
                  telefone: _formatarTelefone(telefone),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Configurações',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Adicione uma camada extra de segurança à sua conta.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ao ativar a verificação em duas etapas (2FA), será necessário confirmar sua identidade durante o login utilizando um código de verificação.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black87,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ativar Verificação em Duas Etapas',
                        style: TextStyle(fontSize: 12, color: Colors.black),
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
                      onChanged: _salvandoMfa ? null : _alterarMfa,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 18, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
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
              const Icon(Icons.account_circle_outlined, size: 28),
              const SizedBox(height: 16),
              Text(
                'Olá, $nome',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 2,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black, size: 18),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 22, 30, 26),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          valor,
          style: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
        ),
      ],
    );
  }

  Widget _buildDivisor() {
    return const Padding(
      padding: EdgeInsets.only(top: 8, bottom: 8),
      child: Divider(height: 1, thickness: 1, color: Color(0xFF6F6F6F)),
    );
  }
}
