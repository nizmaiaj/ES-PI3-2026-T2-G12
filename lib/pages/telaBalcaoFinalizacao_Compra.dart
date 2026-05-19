import 'package:flutter/material.dart';

class TelaBalcaoFinalizacaoCompra extends StatefulWidget {
  final Function(int) onNavigate;
  final VoidCallback onCarteiraAlterada;

  const TelaBalcaoFinalizacaoCompra({
    super.key,
    required this.onNavigate,
    required this.onCarteiraAlterada,
  });

  @override
  State<TelaBalcaoFinalizacaoCompra> createState() =>
      _TelaBalcaoFinalizacaoCompraState();
}

class _TelaBalcaoFinalizacaoCompraState
    extends State<TelaBalcaoFinalizacaoCompra> {
  // Controles de Texto
  final TextEditingController _precoController = TextEditingController(
    text: "R\$ 480,00",
  );
  final TextEditingController _quantidadeController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  // Estados da Tela
  bool _mostrarConfirmacaoSenha = false;
  bool _erroQuantidade = false;
  bool _erroSenha = false;

  // Dados simulados baseados nos seus prints
  double _saldoDisponivel = 250.00;
  final double _precoPorToken = 480.00;
  double _totalEstimado = 0.0;

  @override
  void initState() {
    super.initState();
    _quantidadeController.addListener(_calcularTotal);
  }

  void _calcularTotal() {
    final texto = _quantidadeController.text.replaceAll(',', '.');
    final qtd = double.tryParse(texto) ?? 0.0;

    setState(() {
      _totalEstimado = qtd * _precoPorToken;
      // Valida se a quantidade digitada é válida
      _erroQuantidade = _quantidadeController.text.isNotEmpty && qtd <= 0;
    });
  }

  @override
  void dispose() {
    _quantidadeController.dispose();
    _precoController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool possuiSaldoSuficiente = _saldoDisponivel >= _totalEstimado;
    bool exibirAvisoSaldo = _totalEstimado > 0 && !possuiSaldoSuficiente;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF3F51B5),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => widget.onNavigate(0),
        ),
        title: const Text(
          'Comprar Tokens',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CARD SUPERIOR: INFOS DO TOKEN
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(12),
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
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Qtd de tokens:',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
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
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '/Token',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SE NÃO ESTIVER NO MODAL DE SENHA, MOSTRA O FLUXO NORMAL DE COMPRA
              if (!_mostrarConfirmacaoSenha) ...[
                const Text('Preço (R\$)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _precoController,
                  enabled: false,
                  decoration: InputDecoration(
                    fillColor: const Color(0xFFE0E0E0),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    const Text('Quantidade (tokens)'),
                    const SizedBox(width: 4),
                    Text('*', style: TextStyle(color: Colors.blue.shade300)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantidadeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          fillColor: const Color(0xFFE0E0E0),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    if (_erroQuantidade) ...[
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Informe uma quantidade válida de tokens',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total estimado',
                      style: TextStyle(color: Colors.black54),
                    ),
                    Text(
                      'R\$ ${_totalEstimado.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(
                        color: Color(0xFF3F51B5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Saldo Disponível',
                        style: TextStyle(color: Colors.black54),
                      ),
                      Text(
                        'R\$ ${_saldoDisponivel.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (exibirAvisoSaldo) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Você não possui saldo suficiente para concluir esta compra. Adicione créditos à sua carteira para continuar.',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          (_totalEstimado > 0 &&
                              possuiSaldoSuficiente &&
                              !_erroQuantidade)
                          ? () =>
                                setState(() => _mostrarConfirmacaoSenha = true)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F51B5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                ),
              ]
              // LAYOUT DE CONFIRMAÇÃO DE SENHA
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3D3D3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _mostrarConfirmacaoSenha = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'X',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const Text(
                        'Confirme sua identidade para concluir a compra',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Por segurança, informe sua senha para finalizar a transação e confirmar a aquisição dos tokens.',
                        style: TextStyle(color: Colors.black87, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Digite a sua senha',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _senhaController,
                        obscureText: true,
                        decoration: InputDecoration(
                          fillColor: Colors.white,
                          filled: true,
                          hintText: '••••••',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_erroSenha)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Senha inválida.\nNão foi possível confirmar sua identidade e, por segurança, a compra dos tokens não foi realizada. Verifique sua senha e tente novamente.',
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_senhaController.text != "123456") {
                              setState(() => _erroSenha = true);
                            } else {
                              // === AQUI ENTRA O CÓDIGO DE SUCESSO ===

                              // 1. Esconde o modal de senha e zera os campos
                              setState(() {
                                _erroSenha = false;
                                _mostrarConfirmacaoSenha = false;
                                _saldoDisponivel -=
                                    _totalEstimado; // Opcional: Desconta do saldo visualmente
                                _quantidadeController.clear();
                                _senhaController.clear();
                                _totalEstimado = 0.0;
                              });

                              // 2. Mostra um aviso verde de sucesso
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Compra realizada com sucesso!',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );

                              // 3. Avisa a Home para atualizar o saldo
                              widget.onCarteiraAlterada();

                              // 4. Redireciona para a Home depois de 2 segundos (tempo para o usuário ler)
                              Future.delayed(const Duration(seconds: 2), () {
                                widget.onNavigate(0);
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3F51B5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Finalizar Transação',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
