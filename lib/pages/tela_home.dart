import 'dart:ui';
import 'package:flutter/material.dart';

class TelaHome extends StatefulWidget {
  final String nomeDigitado;

  const TelaHome({super.key, required this.nomeDigitado});

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  bool _patrimonioVisivel = false;
  int _selectedIndex = 0; // Variável para controlar a troca de telas

  final String _patrimonioTotal = 'R\$ 58.430,00';
  final String _valorInvestido = 'R\$ 14.000,00';

  final List<Map<String, String>> _tokens = [
    {
      'nome': 'Nome',
      'qtd': 'Qtd de tokens',
      'valor': 'R\$ 480,00',
      'variacao': '+6%',
    },
    {
      'nome': 'Nome',
      'qtd': 'Qtd de tokens',
      'valor': 'R\$ 480,00',
      'variacao': '+6%',
    },
    {
      'nome': 'Nome',
      'qtd': 'Qtd de tokens',
      'valor': 'R\$ 480,00',
      'variacao': '+6%',
    },
  ];

  static const _roxo = Color(0xFF4C3BCF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: SafeArea(
        child: Column(
          children: [
            // O conteúdo troca aqui dependendo do clique no menu
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildConteudoHome(), // Tela 0
                  const Center(child: Text("Tela Catálogo")), // Tela 1
                  const Center(child: Text("Tela Balcão")), // Tela 2
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // Função que isola o conteúdo da sua Home (Header, Card, Lista)
  Widget _buildConteudoHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildPatrimonioCard(),
          const SizedBox(height: 24),
          const Text(
            'Meus Tokens',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ..._tokens.map(_buildTokenItem),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // --- MÉTODOS DE COMPONENTES ---

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.account_circle_outlined,
          size: 38,
          color: Colors.black87,
        ),
        const SizedBox(width: 8),
        Text(
          'Olá, ${widget.nomeDigitado}', // Usa o nome vindo do login
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.notification_add_outlined,
              color: _roxo,
              size: 22,
            ),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildPatrimonioCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6070F0), Color(0xFF3A4DD6)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Patrimônio Total',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    setState(() => _patrimonioVisivel = !_patrimonioVisivel),
                child: Icon(
                  _patrimonioVisivel ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _patrimonioTotal,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!_patrimonioVisivel)
                  Positioned.fill(
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Valor total investido',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    Text(
                      _valorInvestido,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _roxo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Adicionar Crédito',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenItem(Map<String, String> token) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token['nome']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  token['qtd']!,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                token['valor']!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                token['variacao']!,
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: _roxo, size: 22),
        ],
      ),
    );
  }

  // --- O SEU MENU INFERIOR COMO VOCÊ PASSOU ---
  Widget _buildBottomNav() {
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
          // HOME
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.home_outlined,
                  color: _selectedIndex == 0 ? _roxo : Colors.black87,
                ),
                Text(
                  "Home",
                  style: TextStyle(
                    fontSize: 10,
                    color: _selectedIndex == 0 ? _roxo : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // CATÁLOGO
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: _selectedIndex == 1 ? _roxo : Colors.black87,
                ),
                Text(
                  "Catálogo",
                  style: TextStyle(
                    fontSize: 10,
                    color: _selectedIndex == 1 ? _roxo : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // BALCÃO
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_horiz,
                  color: _selectedIndex == 2 ? _roxo : Colors.black87,
                ),
                Text(
                  "Balcão",
                  style: TextStyle(
                    fontSize: 10,
                    color: _selectedIndex == 2 ? _roxo : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
