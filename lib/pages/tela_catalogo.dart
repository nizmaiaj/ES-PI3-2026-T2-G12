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
    final startupsFiltradas = startups.where((startup) {
      final filtroStatus =
          _filtroAtivo == "Todos" || startup['status'] == _filtroAtivo;

      //verifica se a startup tem o nome pesquisado
      final filtroBusca = startup['nome']!.toLowerCase().contains(
        busca.toLowerCase(),
      );
      //a startup so é exibida se passar no filtro de status e busca
      return filtroStatus && filtroBusca;
    }).toList();

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

          // LISTA DE STARTUPS (MAP DA PLANILHA)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: startupsFiltradas.map((item) {
                //percoree cada startup filtrada
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
      bottomNavigationBar: widget.mostrarMenuInferior
          ? AppBottomNav(
              selectedIndex: 1,
              onItemSelected: _selecionarNav,
              backgroundColor: const Color(0xFFF8F9FE),
            )
          : null,
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
