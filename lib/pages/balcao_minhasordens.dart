import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../widgets/app_bottom_nav.dart';
import 'balcao_negociacao.dart';

class BalcaoMinhasOrdens extends StatefulWidget {
  final Function(int)? onNavigate;

  const BalcaoMinhasOrdens({super.key, this.onNavigate});

  @override
  State<BalcaoMinhasOrdens> createState() => _BalcaoMinhasOrdensState();
}

class _BalcaoMinhasOrdensState extends State<BalcaoMinhasOrdens> {
  static const _azulPrimario = Color(0xFF3F51B5);
  static const _rosaVenda = Color(0xFFC928B8);
  static const _verdeConcluido = Color(0xFF73CF4A);
  static const _laranjaStatus = Color(0xFFC98E16);
  static const _fundo = Colors.white;
  static const _textoEscuro = Color(0xFF111111);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _cancelando = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid ?? AuthSession.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream(String uid) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _startupsStream() {
    return _firestore.collection('startups').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: _fundo,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: uid == null
                  ? _buildEstadoCentral(
                      'Entre na sua conta para acessar suas ordens.',
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _ordersStream(uid),
                      builder: (context, ordersSnapshot) {
                        if (ordersSnapshot.hasError) {
                          return _buildEstadoCentral(
                            'Não foi possível carregar suas ordens.',
                          );
                        }

                        if (!ordersSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: _azulPrimario,
                            ),
                          );
                        }

                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: _startupsStream(),
                          builder: (context, startupsSnapshot) {
                            if (startupsSnapshot.hasError) {
                              return _buildEstadoCentral(
                                'Não foi possível carregar as startups.',
                              );
                            }

                            if (!startupsSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: _azulPrimario,
                                ),
                              );
                            }

                            final nomesStartups = {
                              for (final doc in startupsSnapshot.data!.docs)
                                doc.id: _nomeStartup(doc.data()),
                            };

                            final ordens =
                                ordersSnapshot.data!.docs
                                    .map(
                                      (doc) => _OrdemUsuario.fromDoc(
                                        doc,
                                        nomesStartups[doc
                                                .data()['startupId']] ??
                                            'Nome da Startup',
                                      ),
                                    )
                                    .toList()
                                  ..sort(
                                    (a, b) => b.dataOperacao.compareTo(
                                      a.dataOperacao,
                                    ),
                                  );

                            return _buildConteudo(ordens);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 2,
        onItemSelected: _selecionarNav,
        backgroundColor: _fundo,
      ),
    );
  }

  void _selecionarNav(int index) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
      Navigator.pop(context);
      return;
    }

    if (index != 2) {
      Navigator.pop(context);
    }
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 32, 22, 18),
      decoration: const BoxDecoration(color: _azulPrimario),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balcão de Negociação',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Invista com estratégia, acompanhe oportunidades e\nparticipe da evolução das startups do ecossistema\nMescla',
            style: TextStyle(color: Colors.white, fontSize: 11, height: 1.18),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudo(List<_OrdemUsuario> ordens) {
    final abertas = ordens.where((ordem) => ordem.estaAberta).toList();
    final concluidas = ordens.where((ordem) => ordem.estaConcluida).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSwitchBalcao(),
          const SizedBox(height: 30),
          _buildTituloSecao('Minhas ordens abertas'),
          const SizedBox(height: 10),
          const Text(
            'Acompanhe suas ordens de compra e venda',
            style: TextStyle(color: Colors.black, fontSize: 11),
          ),
          const SizedBox(height: 18),
          if (abertas.isEmpty)
            _buildMensagemLista('Nenhuma ordem aberta no momento.')
          else
            ...abertas.map(
              (ordem) => _OrdemCard(
                ordem: ordem,
                concluida: false,
                cancelando: _cancelando,
                onCancelar: () => _cancelarOrdem(ordem),
              ),
            ),
          const SizedBox(height: 32),
          _buildTituloSecao('Minhas ordens concluídas'),
          const SizedBox(height: 18),
          if (concluidas.isEmpty)
            _buildMensagemLista('Nenhuma ordem concluída ainda.')
          else
            ...concluidas.map(
              (ordem) => _OrdemCard(
                ordem: ordem,
                concluida: true,
                cancelando: false,
                onCancelar: null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSwitchBalcao() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwitchButton(texto: 'Minhas Ordens', ativo: true, onTap: () {}),
          const SizedBox(width: 10),
          _SwitchButton(
            texto: 'Catálogo de ofertas',
            ativo: false,
            onTap: () {
              if (widget.onNavigate != null) {
                Navigator.pop(context);
                return;
              }

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const BalcaoNegociacao()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTituloSecao(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        color: _textoEscuro,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildMensagemLista(String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.black54, fontSize: 12),
      ),
    );
  }

  Widget _buildEstadoCentral(String mensagem) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 14),
        ),
      ),
    );
  }

  Future<void> _cancelarOrdem(_OrdemUsuario ordem) async {
    if (_cancelando) return;

    setState(() => _cancelando = true);

    try {
      await _firestore.collection('orders').doc(ordem.id).update({
        'status': 'cancelada',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _mostrarMensagem('Ordem cancelada com sucesso.');
    } on FirebaseException catch (error) {
      _mostrarMensagem(_mensagemFirebase(error));
    } catch (_) {
      _mostrarMensagem('Não foi possível cancelar a ordem.');
    } finally {
      if (mounted) {
        setState(() => _cancelando = false);
      }
    }
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), behavior: SnackBarBehavior.floating),
    );
  }

  String _mensagemFirebase(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'Sem permissão para acessar estes dados no Firebase.';
    }

    return error.message ?? 'Não foi possível concluir a operação.';
  }
}

class _SwitchButton extends StatelessWidget {
  const _SwitchButton({
    required this.texto,
    required this.ativo,
    required this.onTap,
  });

  final String texto;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: ativo
              ? _BalcaoMinhasOrdensState._azulPrimario
              : Colors.transparent,
          foregroundColor: ativo
              ? Colors.white
              : _BalcaoMinhasOrdensState._textoEscuro,
          side: const BorderSide(color: _BalcaoMinhasOrdensState._azulPrimario),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(texto, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

class _OrdemCard extends StatelessWidget {
  const _OrdemCard({
    required this.ordem,
    required this.concluida,
    required this.cancelando,
    required this.onCancelar,
  });

  final _OrdemUsuario ordem;
  final bool concluida;
  final bool cancelando;
  final VoidCallback? onCancelar;

  @override
  Widget build(BuildContext context) {
    final corTipo = ordem.tipo == 'venda'
        ? _BalcaoMinhasOrdensState._rosaVenda
        : _BalcaoMinhasOrdensState._azulPrimario;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ordem.nomeStartup,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _capitalizar(ordem.tipo),
                  style: TextStyle(
                    color: corTipo,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${concluida ? 'Concluída' : 'Criada'} em ${_formatarData(ordem.dataOperacao)}',
                  style: const TextStyle(fontSize: 7, color: Colors.black54),
                ),
              ],
            ),
          ),
          _SeparadorVertical(altura: concluida ? 58 : 68),
          _InfoColuna(label: 'Qtd de tokens', valor: '${ordem.quantidade}'),
          _SeparadorVertical(altura: concluida ? 58 : 68),
          _InfoColuna(label: 'Preço', valor: _formatarMoeda(ordem.preco)),
          _SeparadorVertical(altura: concluida ? 58 : 68),
          Expanded(
            flex: 9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 7, color: Colors.black54),
                ),
                const SizedBox(height: 7),
                Text(
                  _formatarMoeda(ordem.total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                if (concluida)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _StatusPill(
                      texto: 'Concluído',
                      cor: _BalcaoMinhasOrdensState._verdeConcluido,
                      preenchido: false,
                    ),
                  )
                else ...[
                  _StatusLinha(status: ordem.status),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 22,
                      child: OutlinedButton(
                        onPressed: cancelando ? null : onCancelar,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(fontSize: 7),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoColuna extends StatelessWidget {
  const _InfoColuna({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 7, color: Colors.black54),
          ),
          const SizedBox(height: 7),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8,
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLinha extends StatelessWidget {
  const _StatusLinha({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.hourglass_bottom,
          size: 8,
          color: _BalcaoMinhasOrdensState._laranjaStatus,
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            _descricaoStatus(status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _BalcaoMinhasOrdensState._laranjaStatus,
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.texto,
    required this.cor,
    required this.preenchido,
  });

  final String texto;
  final Color cor;
  final bool preenchido;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: preenchido ? cor : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cor),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: preenchido ? Colors.white : cor,
          fontSize: 7,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SeparadorVertical extends StatelessWidget {
  const _SeparadorVertical({required this.altura});

  final double altura;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: altura,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: Colors.black.withValues(alpha: 0.28),
    );
  }
}

class _OrdemUsuario {
  const _OrdemUsuario({
    required this.id,
    required this.nomeStartup,
    required this.tipo,
    required this.status,
    required this.quantidade,
    required this.preco,
    required this.dataOperacao,
  });

  factory _OrdemUsuario.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String nomeStartup,
  ) {
    final data = doc.data() ?? {};
    final quantidade = _numero(data['quantidade']).toInt();
    final preco = _numero(data['preco'] ?? data['precoUnitario']);

    return _OrdemUsuario(
      id: doc.id,
      nomeStartup: nomeStartup,
      tipo: _texto(data['tipo'], fallback: 'compra').toLowerCase(),
      status: _texto(data['status'], fallback: 'aberta').toLowerCase(),
      quantidade: quantidade,
      preco: preco,
      dataOperacao: _data(data['createdAt'] ?? data['executadaEm']),
    );
  }

  final String id;
  final String nomeStartup;
  final String tipo;
  final String status;
  final int quantidade;
  final double preco;
  final DateTime dataOperacao;

  double get total => quantidade * preco;

  bool get estaAberta =>
      status == 'aberta' ||
      status == 'parcial' ||
      status == 'pendente' ||
      status.contains('aguardando');

  bool get estaConcluida =>
      status == 'executada' ||
      status == 'concluida' ||
      status == 'concluído' ||
      status == 'concluido';
}

String _nomeStartup(Map<String, dynamic> data) {
  return _texto(
    data['nome'] ?? data['name'] ?? data['startupName'],
    fallback: 'Nome da Startup',
  );
}

String _descricaoStatus(String status) {
  if (status == 'parcial') return 'Aguardando execução';
  if (status == 'pendente') return 'Aguardando execução';
  if (status.contains('comprador')) return 'Aguardando comprador';
  if (status.contains('vendedor')) return 'Aguardando vendedor';
  return 'Aguardando comprador';
}

String _capitalizar(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
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

DateTime _data(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

String _formatarData(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final ano = data.year.toString();
  return '$dia/$mes/$ano';
}

String _formatarMoeda(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final reais = parts.first;
  final centavos = parts.last;
  final buffer = StringBuffer();

  for (var i = 0; i < reais.length; i++) {
    final remaining = reais.length - i;
    buffer.write(reais[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }

  return 'R\$ ${buffer.toString()},$centavos';
}
