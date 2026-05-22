import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'visao_geral_utils.dart';

class AbaSociedade extends StatefulWidget {
  const AbaSociedade({super.key, required this.startupId});

  final String? startupId;

  @override
  State<AbaSociedade> createState() => _AbaSociedadeState();
}

class _AbaSociedadeState extends State<AbaSociedade> {
  bool _verTodosAberto = false;

  @override
  Widget build(BuildContext context) {
    final startupId = widget.startupId;

    if (startupId == null) {
      return _buildEstado('Startup sem identificador para carregar os sócios.');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('startups')
          .doc(startupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEstado(
            'Não foi possível carregar os dados da sociedade.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: kVgAzul),
          );
        }

        final socios = _sociosFromData(snapshot.data!.data());

        if (socios.isEmpty) {
          return _buildEstado('Nenhum sócio cadastrado para esta startup.');
        }

        if (_verTodosAberto) return _buildVerTodosView(socios);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              _buildEstruturaCard(socios),
              const SizedBox(height: 16),
              _buildApresentacaoSocios(socios),
            ],
          ),
        );
      },
    );
  }

  // ── ESTRUTURA SOCIETÁRIA ──────────────────────────────────────────────────

  Widget _buildEstruturaCard(List<SocioStartup> socios) {
    final totalPercentual = socios.fold<double>(
      0,
      (total, s) => total + (s.percentual ?? 0),
    );

    final sections = List.generate(socios.length, (i) {
      final pct = socios[i].percentual ?? 0;
      return PieChartSectionData(
        value: pct,
        color: corSocio(i),
        radius: 28,
        showTitle: false,
      );
    });

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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 37,
                        sectionsSpace: 2,
                        startDegreeOffset: -90,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatPercentual(totalPercentual),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const Text(
                          'Total',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(socios.length, (i) {
                    final s = socios[i];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i < socios.length - 1 ? 12 : 0,
                      ),
                      child: _buildLegendaItem(
                        corSocio(i),
                        s.cargo.isEmpty ? s.nome : '${s.nome} (${s.cargo})',
                        s.percentualExibido,
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

  // ── APRESENTAÇÃO DOS SÓCIOS ───────────────────────────────────────────────

  Widget _buildApresentacaoSocios(List<SocioStartup> socios) {
    final sociosExibidos = socios.take(3).toList();

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
                    color: kVgAzul,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(sociosExibidos.length, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i < sociosExibidos.length - 1 ? 8 : 0,
                  ),
                  child: _buildSocioCardCompacto(sociosExibidos[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSocioCardCompacto(SocioStartup socio) {
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
              color: kVgAzul,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            socio.nome,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            socio.cargo.isEmpty ? 'Sócio' : socio.cargo,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            socio.descricao,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVerTodosView(List<SocioStartup> socios) {
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
            ...List.generate(socios.length, (i) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  i == socios.length - 1 ? 20 : 4,
                ),
                child: _buildSocioCardExpandido(socios[i]),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSocioCardExpandido(SocioStartup socio) {
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
            child: const Icon(Icons.person_outline, color: kVgAzul, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  socio.nome,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  socio.cargo.isEmpty ? 'Sócio' : socio.cargo,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  socio.descricao,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Widget _buildEstado(String mensagem) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ),
    );
  }

  List<SocioStartup> _sociosFromData(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final raw =
        data['socios'] ??
        data['sócios'] ??
        data['sociedade'] ??
        data['sociosFundadores'] ??
        data['fundadores'];
    return _sociosFromDynamic(raw);
  }

  List<SocioStartup> _sociosFromDynamic(dynamic value) {
    if (value is Iterable) {
      return value
          .map(SocioStartup.fromValue)
          .where((s) => s.nome.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      if (_pareceSocio(value)) {
        final s = SocioStartup.fromValue(value);
        return s.nome.isEmpty ? const [] : [s];
      }
      return value.entries
          .map((e) => SocioStartup.fromMapEntry(e.key, e.value))
          .where((s) => s.nome.isNotEmpty)
          .toList();
    }
    return const [];
  }

  bool _pareceSocio(Map<dynamic, dynamic> value) {
    const campos = {
      'nome', 'name', 'nomeCompleto', 'fullName', 'cargo', 'funcao',
      'função', 'role', 'position', 'percentual', 'participacao',
      'participação', 'participacaoPercentual', 'equity', 'descricao',
      'descrição', 'description', 'bio', 'biografia',
    };
    return value.keys.any((k) => campos.contains(k.toString()));
  }
}
