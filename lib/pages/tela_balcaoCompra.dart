import 'package:flutter/material.dart';

class TelaBalcaoCompra extends StatefulWidget {
  final Function(int) onNavigate; // Permite alternar as abas na TelaHome

  const TelaBalcaoCompra({super.key, required this.onNavigate});

  @override
  State<TelaBalcaoCompra> createState() => _TelaBalcaoCompraState();
}

class _TelaBalcaoCompraState extends State<TelaBalcaoCompra> {
  int _selectedIndex = 2; // Começa na aba Balcão (índice 2)
  bool _patrimonioVisivel = false; // Mantido para consistência se precisar usar

  static const _roxo = Color(
    0xFF4C3BCF,
  ); // O mesmo roxo oficial da sua TelaHome

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: SafeArea(
        child: Column(
          children: [
            // ----------------------------------------------------
            // HEADER ROXO SÓLIDO (Padronizado com o estilo do app)
            // ----------------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              decoration: const BoxDecoration(color: _roxo),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: 48.0,
                      ), // Centraliza o texto compensando a seta
                      child: Text(
                        'Comprar Tokens',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ----------------------------------------------------
            // CONTEÚDO SCROLLABLE (Tudo junto de forma linear)
            // ----------------------------------------------------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CARD TOKENS (NOME / VALOR) - Estilo cinza padrão do protótipo
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFEEEEF5,
                        ), // Mesmo cinza dos itens da Home
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nome',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Qtd de tokens:',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'R\$ 480,00',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                '/Token',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // CAMPO: PREÇO
                    const Text(
                      'Preço (R\$)',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEEF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // CAMPO: QUANTIDADE + ALERTA LADO A LADO
                    const Text(
                      'Quantidade (tokens) *',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120, // Largura fixa do campo
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEEEF5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Informe uma quantidade válida de tokens',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // TOTAL ESTIMADO
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total estimado',
                          style: TextStyle(color: Colors.black54),
                        ),
                        Text(
                          'R\$ 72,00',
                          style: TextStyle(
                            color: _roxo,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // CARD SALDO DISPONÍVEL
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEEF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Saldo Disponível',
                            style: TextStyle(color: Colors.black54),
                          ),
                          Text(
                            'R\$ 250,00',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // MENSAGEM DE ERRO (SALDO INSUFICIENTE)
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 22),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Você não possui saldo suficiente para concluir esta compra. Adicione créditos à sua carteira para continuar.',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // BOTÃO COMPRAR
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _roxo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Comprar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ----------------------------------------------------
            // MENU INFERIOR PADRÃO (Igualzinho ao da TelaHome)
            // ----------------------------------------------------
            Container(
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
                  // ABA 0: HOME
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedIndex = 0);
                      widget.onNavigate(0); // Avisa a Home para trocar de tela
                    },
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
                  // ABA 1: CATÁLOGO
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedIndex = 1);
                      widget.onNavigate(1); // Avisa a Home para trocar de tela
                    },
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
                  // ABA 2: BALCÃO
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedIndex = 2);
                      widget.onNavigate(2);
                    },
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
            ),
          ],
        ),
      ),
    );
  }
}
