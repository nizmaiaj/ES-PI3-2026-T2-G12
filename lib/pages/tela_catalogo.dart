import 'package:flutter/material.dart';

class TelaCatalogo extends StatefulWidget {
  const TelaCatalogo({super.key});

  @override
  State<TelaCatalogo> createState() => _TelaCatalogoState();
}

class _TelaCatalogoState extends State<TelaCatalogo> {
  String _filtroAtivo = "Todos";

  @override
  Widget build(BuildContext context) {
    // 1. DADOS VINDOS DA SUA PLANILHA
    final List<Map<String, String>> startups = [
      {
        "nome": "EcoTech",
        "imagem": "asstes/logo_EcoTech.png",
        "desc": "Plataforma de monitoramento ambiental para empresas",
        "capital": "300.000",
        "tokens": "100.000",
        "socios": "2",
        "status": "Em operação",
      },
      {
        "nome": "FinFast",
        "imagem": "assets/logo_FinFast.png",
        "desc":
            "Aplicativo de pagamentos instantâneos e gestão para freelancer",
        "capital": "500.000",
        "tokens": "200.000",
        "socios": "2",
        "status": "Nova",
      },
      {
        "nome": "QueroJa",
        "imagem": "assets/logo_QueroJa.png",
        "desc":
            "Pequenos restaurantes locais com logística de entrega integrada",
        "capital": "150.000.000",
        "tokens": "500.000",
        "socios": "2",
        "status": "Em expanção",
      },
      {
        "nome": "EduPlay",
        "imagem": "assets/logo_EduPlay.png",
        "desc": "Plataforma de gamificação para ensino de matemática básica",
        "capital": "150.000",
        "tokens": "50.000",
        "socios": "2",
        "status": "Em operação",
      },
      {
        "nome": "HealthSync",
        "imagem": "asstes/logo_HealthSync.png",
        "desc": "Integração de prontuários médicos seguros via rede blockchain",
        "capital": "1.200.000",
        "tokens": "500.000",
        "socios": "3",
        "status": "Nova",
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          // HEADER AZUL (Topo Inteiro)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
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
                  onPressed: () => Navigator.pop(context),
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

          // LISTA DE STARTUPS (MAP DA PLANILHA)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: startups.map((item) {
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
                            child: Image.asset(
                              item['imagem']!, // O '!' garante ao Dart que o caminho existe
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              // Se a imagem não for encontrada, ele mostra o ícone de fallback
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.white,
                                  child: const Icon(
                                    Icons.business,
                                    color: Color(0xFF3F51B5),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['nome']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  item['desc']!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
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
                                    color: const Color.fromARGB(
                                      115,
                                      14,
                                      13,
                                      13,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  item['status']!,
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3F51B5),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  "Conhecer",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
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
                          _buildInfoCol(
                            Icons.layers,
                            "Tokens",
                            item['tokens']!,
                          ),
                          _buildInfoCol(
                            Icons.people,
                            "Sócios",
                            item['socios']!,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),

      // MENU INFERIOR
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(40, 0, 40, 25),
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(35),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home_outlined),
                Text("Home", style: TextStyle(fontSize: 10)),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, color: Color(0xFF3F51B5)),
                Text(
                  "Pesquisar",
                  style: TextStyle(fontSize: 10, color: Color(0xFF3F51B5)),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_horiz),
                Text("Balcão", style: TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
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
