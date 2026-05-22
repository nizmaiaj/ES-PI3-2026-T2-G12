import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'tela_home.dart';
import '../services/auth_session.dart';

class TelaAdicionarCredito extends StatefulWidget {
  const TelaAdicionarCredito({super.key});

  @override
  State<TelaAdicionarCredito> createState() => _TelaAdicionarCreditoState();
}

class _TelaAdicionarCreditoState extends State<TelaAdicionarCredito> {
  final TextEditingController _valorController = TextEditingController();
  bool _salvandoCredito = false;

  static const _azulPrimario = Color(0xFF3F51B5);
  static const _roxo = Color(0xFF4C3BCF);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quanto você vai depositar?',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Valor',
                      style: TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _valorController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'R\$ 0,00',
                        hintStyle: const TextStyle(
                          color: Color(0xFFB3B3B8),
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 18,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF8F8F8F),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF8F8F8F),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: _azulPrimario,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildConfirmarButton(context),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      decoration: BoxDecoration(
        color: _azulPrimario,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 42, height: 42),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            iconSize: 24,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Adicionar crédito a carteira',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmarButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 0, 60, 76),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _salvandoCredito ? null : _adicionarCredito,
          style: ElevatedButton.styleFrom(
            backgroundColor: _roxo,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: _salvandoCredito
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Confirmar depósito',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }

  Future<void> _adicionarCredito() async {
    final valor = _lerValorDigitado(_valorController.text);

    if (valor == null || valor <= 0) {
      await _mostrarPopup(
        titulo: 'Valor inválido',
        mensagem: 'Informe um valor maior que zero para adicionar créditos.',
      );
      return;
    }

    final uid = _uid;
    if (uid == null) {
      await _mostrarPopup(
        titulo: 'Erro ao adicionar créditos',
        mensagem: 'Usuário não autenticado.',
      );
      return;
    }

    setState(() => _salvandoCredito = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final walletRef = firestore.collection('wallets').doc(uid);

      await firestore.runTransaction((transaction) async {
        final walletCreditRef = firestore.collection('walletCredits').doc();
        final now = FieldValue.serverTimestamp();
        final snapshot = await transaction.get(walletRef);
        final dados = snapshot.data();
        final saldoAtual = _lerNumero(dados?['saldoReais']);

        transaction.set(walletRef, {
          'userId': uid,
          'saldoReais': saldoAtual + valor,
          'updatedAt': now,
        }, SetOptions(merge: true));

        transaction.set(walletCreditRef, {
          'userId': uid,
          'valor': valor,
          'tipo': 'depósito',
          'descricao': 'Depósito em carteira',
          'createdAt': now,
        });
      });

      if (!mounted) return;
      _valorController.clear();

      await _mostrarPopup(
        titulo: 'Créditos adicionados',
        mensagem:
            '${_formatarMoeda(valor)} foram adicionados à sua carteira com sucesso.',
      );
      if (!mounted) return;
      //volta para home apos adicionar o credito
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const TelaHome(nomeDigitado: 'tela_home'),
        ),
        (route) => false,
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      await _mostrarPopup(
        titulo: 'Erro ao adicionar créditos',
        mensagem:
            error.message ??
            'Não foi possível adicionar os créditos. Tente novamente.',
      );
    } catch (_) {
      if (!mounted) return;
      await _mostrarPopup(
        titulo: 'Erro ao adicionar créditos',
        mensagem: 'Não foi possível adicionar os créditos. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _salvandoCredito = false);
    }
  }

  Future<void> _mostrarPopup({
    required String titulo,
    required String mensagem,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(titulo),
          content: Text(mensagem),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(backgroundColor: _roxo),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  double? _lerValorDigitado(String texto) {
    final apenasNumero = texto.replaceAll(RegExp(r'[^0-9,.]'), '');
    if (apenasNumero.trim().isEmpty) return null;

    final ultimoPonto = apenasNumero.lastIndexOf('.');
    final ultimaVirgula = apenasNumero.lastIndexOf(',');
    final ultimoSeparador = ultimoPonto > ultimaVirgula
        ? ultimoPonto
        : ultimaVirgula;

    if (ultimoSeparador == -1) {
      return double.tryParse(apenasNumero);
    }

    final casasDecimais = apenasNumero.length - ultimoSeparador - 1;
    final separadorDecimal =
        (ultimoPonto != -1 && ultimaVirgula != -1) ||
        casasDecimais == 1 ||
        casasDecimais == 2;

    final normalizado = separadorDecimal
        ? '${apenasNumero.substring(0, ultimoSeparador).replaceAll(RegExp(r'[,.]'), '')}.${apenasNumero.substring(ultimoSeparador + 1)}'
        : apenasNumero.replaceAll(RegExp(r'[,.]'), '');

    return double.tryParse(normalizado);
  }

  double _lerNumero(dynamic valor) {
    if (valor is int) return valor.toDouble();
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();
    return 0;
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

  Widget _buildBottomNav(BuildContext context) {
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
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home_outlined, color: _roxo),
                Text("Home", style: TextStyle(fontSize: 10, color: _roxo)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined, color: Colors.black87),
                Text(
                  "Catálogo",
                  style: TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_horiz, color: Colors.black87),
                Text(
                  "Balcão",
                  style: TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
