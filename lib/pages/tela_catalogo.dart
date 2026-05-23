import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../widgets/app_bottom_nav.dart';
import 'balcao_negociacao.dart';
import 'tela_visao_geral.dart';

class TelaCatalogo extends StatefulWidget {
  final bool mostrarMenuInferior;
  final VoidCallback? onVoltar;
  final ValueChanged<int>? onNavigate;

  const TelaCatalogo({
    super.key,
    this.mostrarMenuInferior = true,
    this.onVoltar,
    this.onNavigate,
  });

  @override
  State<TelaCatalogo> createState() => _TelaCatalogoState();
}

class _TelaCatalogoState extends State<TelaCatalogo> {
  String _filtroAtivo = "Todos";
  String busca = "";
  final Map<String, Future<String?>> _logoUrlFutures = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> _startupsStream() {
    return _firestore.collection('startups').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          // HEADER AZUL (Topo Inteiro)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            decoration: const BoxDecoration(
              color: Color(0xFF3F51B5),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: widget.onVoltar ?? () => Navigator.pop(context),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Catálogo de Startup",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "Descubra e invista em grandes ideias",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                TextField(
                  //executa sempre que algo for digitado
                  onChanged: (value) {
                    setState(() {
                      busca = value; //salva o texto digitado
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar por startup',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // FILTROS
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              children: ["Todos", "Nova", "Em operação", "Em expansão"].map((
                filtro,
              ) {
                final selecionado = _filtroAtivo == filtro;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filtro),
                    selected: selecionado,
                    onSelected: (val) => setState(() => _filtroAtivo = filtro),
                    selectedColor: const Color(0xFF3F51B5),
                    labelStyle: TextStyle(
                      color: selecionado ? Colors.white : Colors.black,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _startupsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildEstadoLista(
                    'Não foi possível carregar as startups.',
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3F51B5)),
                  );
                }

                final startups =
                    snapshot.data!.docs.map(_startupCatalogoFromDoc).toList()
                      ..sort(
                        (a, b) => (a['nome'] ?? '').compareTo(b['nome'] ?? ''),
                      );

                final startupsFiltradas = startups.where((startup) {
                  final status = startup['status'] ?? '';
                  final nome = startup['nome'] ?? '';
                  final filtroStatus =
                      _filtroAtivo == "Todos" ||
                      status.toLowerCase() == _filtroAtivo.toLowerCase();
                  final filtroBusca = nome.toLowerCase().contains(
                    busca.toLowerCase(),
                  );

                  return filtroStatus && filtroBusca;
                }).toList();

                if (startups.isEmpty) {
                  return _buildEstadoLista('Nenhuma startup cadastrada.');
                }

                if (startupsFiltradas.isEmpty) {
                  return _buildEstadoLista(
                    'Nenhuma startup encontrada para esse filtro.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: startupsFiltradas.length,
                  itemBuilder: (context, index) {
                    return _buildStartupCard(startupsFiltradas[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),

      // MENU INFERIOR
      bottomNavigationBar: widget.mostrarMenuInferior
          ? AppBottomNav(
              selectedIndex: 1,
              onItemSelected: _selecionarNav,
              backgroundColor: const Color(0xFFF8F9FE),
            )
          : null,
    );
  }

  Map<String, String> _startupCatalogoFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final socios = data['socios'];

    return {
      'id': doc.id,
      'nome': _texto(data['nome'] ?? data['name'] ?? data['startupName']),
      'imagem': _texto(data['logoUrl'] ?? data['imagem'] ?? data['imageUrl']),
      'logoStoragePath': _texto(
        data['logoStoragePath'] ??
            data['logoPath'] ??
            data['caminhoLogo'] ??
            data['logoStorage'],
        fallback: 'startups/${doc.id}/logo/logo.png',
      ),
      'desc': _texto(
        data['descricao'] ?? data['sumarioExecutivo'] ?? data['description'],
      ),
      'capital': _formatarNumeroBr(
        _numero(data['capitalAportado'] ?? data['capital']),
      ),
      'tokens': _formatarNumeroBr(
        _numero(
          data['totalTokens'] ??
              data['tokensDisponiveis'] ??
              data['quantidadeTokens'] ??
              data['tokens'],
        ),
      ),
      'socios': _quantidadeSocios(socios),
      'status': _texto(data['estagio'] ?? data['status']),
      'valorToken': _numero(
        data['tokenPrecoInicial'] ??
            data['valorToken'] ??
            data['precoToken'] ??
            data['preco'],
      ).toString(),
    };
  }

  Widget _buildStartupCard(Map<String, String> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: _buildStartupLogo(
                  item['imagem'] ?? '',
                  item['logoStoragePath'] ?? '',
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['nome']!.isEmpty
                          ? 'Startup sem nome'
                          : item['nome']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      item['desc']!.isEmpty
                          ? 'Descrição não informada'
                          : item['desc']!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color.fromARGB(115, 14, 13, 13),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item['status']!.isEmpty ? 'Sem estágio' : item['status']!,
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TelaVisaoGeral(
                            startup: item,
                            onNavigate: widget.onNavigate,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Conhecer",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoCol(
                Icons.bar_chart,
                "Capital",
                "R\$ ${item['capital']}",
              ),
              _buildInfoCol(Icons.layers, "Tokens", item['tokens']!),
              _buildInfoCol(Icons.people, "Sócios", item['socios']!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartupLogo(String imagem, String logoStoragePath) {
    final fallback = Container(
      width: 60,
      height: 60,
      color: Colors.white,
      child: const Icon(Icons.business, color: Color(0xFF3F51B5)),
    );

    if (imagem.startsWith('http://') || imagem.startsWith('https://')) {
      return Image.network(
        imagem,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    if (imagem.isNotEmpty) {
      return Image.asset(
        imagem,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    if (logoStoragePath.isEmpty) return fallback;

    return FutureBuilder<String?>(
      future: _logoUrlFutures.putIfAbsent(
        logoStoragePath,
        () => _buscarLogoUrl(logoStoragePath),
      ),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) return fallback;

        return Image.network(
          url,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      },
    );
  }

  Future<String?> _buscarLogoUrl(String storagePath) async {
    try {
      final ref = storagePath.startsWith('gs://')
          ? FirebaseStorage.instance.refFromURL(storagePath)
          : FirebaseStorage.instance.ref(storagePath);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Widget _buildEstadoLista(String mensagem) {
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

  void _selecionarNav(int index) {
    if (index == 1) {
      return;
    }

    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
      return;
    }

    if (index == 0) {
      if (widget.onVoltar != null) {
        widget.onVoltar!();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BalcaoNegociacao()),
    );
  }

  Widget _buildInfoCol(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ],
    );
  }
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

String _formatarNumeroBr(double value) {
  final inteiro = value.round().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < inteiro.length; i++) {
    final remaining = inteiro.length - i;
    buffer.write(inteiro[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }

  return buffer.toString();
}

String _quantidadeSocios(dynamic socios) {
  if (socios is Iterable) return socios.length.toString();
  if (socios is Map) return socios.length.toString();

  return _formatarNumeroBr(_numero(socios));
}
