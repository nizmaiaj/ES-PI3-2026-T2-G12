// Gabriel Henrique Pozeti de Faria - 25022716
// Detalha uma posição da carteira e desenha seu histórico real de preços.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/authenticated_storage_image.dart';

/// Mostra cotação atual, variação por período e resultado da posição do usuário.
class TelaDetalheToken extends StatefulWidget {
  const TelaDetalheToken({
    super.key,
    required this.startupId,
    required this.nome,
    required this.quantidade,
    required this.precoMedioCompra,
    required this.precoAtualInicial,
    this.onNavigate,
  });

  final String startupId;
  final String nome;
  final double quantidade;
  final double precoMedioCompra;
  final double precoAtualInicial;
  final ValueChanged<int>? onNavigate;

  @override
  State<TelaDetalheToken> createState() => _TelaDetalheTokenState();
}

class _TelaDetalheTokenState extends State<TelaDetalheToken> {
  static const _azulPrimario = Color(0xFF3F51B5);
  static const _verde = Color(0xFF1B8F4B);
  static const _vermelho = Color(0xFFD04444);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final Stream<_TokenDetalheDados> _dadosStream;
  _PeriodoGrafico _periodo = _PeriodoGrafico.mensal;

  @override
  void initState() {
    super.initState();
    _dadosStream = _monitorarDadosToken();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_TokenDetalheDados>(
      stream: _dadosStream,
      builder: (context, snapshot) {
        final dados =
            snapshot.data ??
            _TokenDetalheDados(
              precoAtual: widget.precoAtualInicial,
              precoInicial: 0,
              historico: const [],
              logoUrl: '',
              logoStoragePath: _logoStoragePathPadrao(),
            );

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                _buildHeader(dados),
                Expanded(child: _buildBody(snapshot, dados)),
              ],
            ),
          ),
          bottomNavigationBar: AppBottomNav(
            selectedIndex: 0,
            onItemSelected: _selecionarNav,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          ),
        );
      },
    );
  }

  Widget _buildHeader(_TokenDetalheDados dados) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, topPadding + 22, 24, 48),
      decoration: BoxDecoration(
        color: _azulPrimario,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 31,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildHeaderLogo(dados.logoUrl, dados.logoStoragePath),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preço atual',
                        style: TextStyle(color: Colors.white70, fontSize: 20),
                      ),
                      const SizedBox(height: 20),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatarMoeda(dados.precoAtual),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
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
    );
  }

  Widget _buildHeaderLogo(String logoUrl, String logoStoragePath) {
    Widget frame(Widget child) {
      return Container(
        width: 118,
        height: 118,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(21), child: child),
      );
    }

    final fallback = frame(
      const Icon(Icons.business_rounded, color: _azulPrimario, size: 50),
    );
    final imagem = logoUrl.trim();
    final storagePath = _logoStoragePath(imagem, logoStoragePath);

    if (AuthenticatedStorageImage.isStoragePathOrUrl(imagem)) {
      return frame(
        AuthenticatedStorageImage(
          pathOrUrl: imagem,
          fit: BoxFit.contain,
          fallback: const Icon(
            Icons.business_rounded,
            color: _azulPrimario,
            size: 50,
          ),
        ),
      );
    }

    if (imagem.startsWith('http://') || imagem.startsWith('https://')) {
      return frame(
        Image.network(
          imagem,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.business_rounded,
            color: _azulPrimario,
            size: 50,
          ),
        ),
      );
    }

    if (imagem.isNotEmpty) {
      return frame(
        Image.asset(
          imagem,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.business_rounded,
            color: _azulPrimario,
            size: 50,
          ),
        ),
      );
    }

    if (storagePath.isEmpty) return fallback;

    return frame(
      AuthenticatedStorageImage(
        pathOrUrl: storagePath,
        fit: BoxFit.contain,
        fallback: const Icon(
          Icons.business_rounded,
          color: _azulPrimario,
          size: 50,
        ),
      ),
    );
  }

  String _logoStoragePath(String imagem, String logoStoragePath) {
    if (AuthenticatedStorageImage.isStoragePathOrUrl(imagem)) return imagem;

    final configurado = logoStoragePath.trim();
    if (configurado.isNotEmpty) return configurado;

    return _logoStoragePathPadrao();
  }

  String _logoStoragePathPadrao() {
    final nome = widget.nome.trim();
    if (nome.isNotEmpty) {
      return 'startups/${nome.toLowerCase().replaceAll(' ', '-')}/logo/logo.png';
    }
    final startupId = widget.startupId.trim();
    if (startupId.isEmpty) return '';
    return 'startups/$startupId/logo/logo.png';
  }

  Widget _buildBody(
    AsyncSnapshot<_TokenDetalheDados> snapshot,
    _TokenDetalheDados dados,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: _azulPrimario),
      );
    }

    if (snapshot.hasError) {
      return _buildEstadoCentral(
        'Não foi possível carregar o histórico do token.',
      );
    }

    final historicoFiltrado = _filtrarHistorico(
      dados.historico,
      precoInicial: dados.precoInicial,
      precoAtual: dados.precoAtual,
    );
    final variacao = _calcularVariacao(historicoFiltrado);
    final corVariacao = (variacao ?? 0) >= 0 ? _verde : _vermelho;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 56, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Valorização do Token',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildPeriodoDropdown(),
            ],
          ),
          const SizedBox(height: 18),
          if (variacao != null)
            _buildResumoVariacao(variacao, corVariacao)
          else
            _buildResumoSemHistorico(),
          const SizedBox(height: 22),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _GraficoPreco(
                pontos: historicoFiltrado,
                periodo: _periodo,
                lineColor: corVariacao,
              ),
            ),
          ),
          const SizedBox(height: 26),
          _buildResumoCarteira(dados.precoAtual),
        ],
      ),
    );
  }

  Widget _buildPeriodoDropdown() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _azulPrimario,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_PeriodoGrafico>(
          value: _periodo,
          dropdownColor: _azulPrimario,
          iconEnabledColor: Colors.white,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          items: _PeriodoGrafico.values
              .map(
                (periodo) => DropdownMenuItem(
                  value: periodo,
                  child: Text(periodo.label),
                ),
              )
              .toList(),
          onChanged: (periodo) {
            if (periodo == null) return;
            setState(() => _periodo = periodo);
          },
        ),
      ),
    );
  }

  Widget _buildResumoVariacao(double variacao, Color cor) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final prefixo = variacao >= 0 ? '+' : '';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$prefixo${variacao.toStringAsFixed(2).replaceAll('.', ',')}%',
            style: TextStyle(
              color: cor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'no período selecionado',
          style: TextStyle(color: themeColors.mutedText, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildResumoSemHistorico() {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Text(
      'Ainda não há transações suficientes para calcular a variação.',
      style: TextStyle(color: themeColors.mutedText, fontSize: 12),
    );
  }

  Widget _buildResumoCarteira(double precoAtual) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final valorAtual = widget.quantidade * precoAtual;
    final valorInvestido = widget.quantidade * widget.precoMedioCompra;
    final resultado = valorAtual - valorInvestido;
    final rentabilidade = widget.precoMedioCompra > 0
        ? ((precoAtual - widget.precoMedioCompra) / widget.precoMedioCompra) *
              100
        : null;
    final resultadoCor = resultado >= 0 ? _verde : _vermelho;
    final resultadoLabel = resultado > 0
        ? 'Lucro'
        : resultado < 0
        ? 'Prejuízo'
        : 'Resultado';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ResumoCarteiraItem(
                  label: 'Tokens',
                  value: _formatarQuantidade(widget.quantidade),
                ),
              ),
              Expanded(
                child: _ResumoCarteiraItem(
                  label: 'Preço médio',
                  value: _formatarMoeda(widget.precoMedioCompra),
                ),
              ),
              Expanded(
                child: _ResumoCarteiraItem(
                  label: 'Valor atual',
                  value: _formatarMoeda(valorAtual),
                  alignRight: true,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: themeColors.panelBorder),
          ),
          Row(
            children: [
              Expanded(
                child: _ResumoCarteiraItem(
                  label: 'Investido',
                  value: _formatarMoeda(valorInvestido),
                ),
              ),
              Expanded(
                child: _ResumoCarteiraItem(
                  label: resultadoLabel,
                  value: _formatarMoeda(resultado),
                  valueColor: resultadoCor,
                ),
              ),
              Expanded(
                child: _ResumoCarteiraItem(
                  label: 'Rentabilidade',
                  value: _formatarPercentual(rentabilidade),
                  valueColor: resultadoCor,
                  alignRight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoCentral(String mensagem) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: TextStyle(color: themeColors.mutedText, fontSize: 14),
        ),
      ),
    );
  }

  /// Combina snapshots da startup, preços simulados e negócios executados.
  ///
  /// A tela reage em tempo real sempre que qualquer uma dessas fontes muda.
  Stream<_TokenDetalheDados> _monitorarDadosToken() {
    final startupId = widget.startupId.trim();
    if (startupId.isEmpty) {
      return Stream.value(_montarDadosToken());
    }

    late final StreamController<_TokenDetalheDados> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];
    Map<String, dynamic>? startupData;
    var historicoVariacoes = <_PontoPreco>[];
    var historicoTransacoes = <_PontoPreco>[];

    void emitirDados() {
      if (controller.isClosed) return;

      controller.add(
        _montarDadosToken(
          startupData: startupData,
          historico: [...historicoVariacoes, ...historicoTransacoes],
        ),
      );
    }

    void registrarErro(Object error) {
      debugPrint('Não foi possível monitorar o histórico do token: $error');
    }

    controller = StreamController<_TokenDetalheDados>(
      onListen: () {
        subscriptions.add(
          _firestore.collection('startups').doc(startupId).snapshots().listen((
            snapshot,
          ) {
            startupData = snapshot.data();
            emitirDados();
          }, onError: registrarErro),
        );
        subscriptions.add(
          _firestore
              .collection('startups')
              .doc(startupId)
              .collection('priceHistory')
              .snapshots()
              .listen((snapshot) {
                historicoVariacoes = _lerHistorico(snapshot);
                emitirDados();
              }, onError: registrarErro),
        );
        subscriptions.add(
          _firestore
              .collection('tokenPrices')
              .where('startupId', isEqualTo: startupId)
              .snapshots()
              .listen((snapshot) {
                historicoTransacoes = _lerHistorico(snapshot);
                emitirDados();
              }, onError: registrarErro),
        );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  /// Normaliza os snapshots e separa preço inicial de preço atual.
  _TokenDetalheDados _montarDadosToken({
    Map<String, dynamic>? startupData,
    List<_PontoPreco> historico = const [],
  }) {
    final precoStartup = _lerPrecoStartup(startupData);
    final precoInicial = _lerPrecoInicialStartup(startupData);
    final precoAtual = _primeiroPrecoValido([
      precoStartup,
      widget.precoAtualInicial,
      precoInicial,
      widget.precoMedioCompra,
    ]);

    final historicoOrdenado = [...historico]
      ..sort((a, b) => a.data.compareTo(b.data));

    final logoUrl = _texto(
      startupData?['logoUrl'] ??
          startupData?['imagem'] ??
          startupData?['imageUrl'],
    );
    final logoStoragePath = _texto(
      startupData?['logoStoragePath'] ??
          startupData?['logoPath'] ??
          startupData?['caminhoLogo'] ??
          startupData?['logoStorage'],
      fallback: _logoStoragePathPadrao(),
    );

    return _TokenDetalheDados(
      precoAtual: precoAtual,
      precoInicial: precoInicial,
      historico: historicoOrdenado,
      logoUrl: logoUrl,
      logoStoragePath: logoStoragePath,
    );
  }

  List<_PontoPreco> _lerHistorico(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => _PontoPreco.fromMap(doc.data()))
        .where((ponto) => ponto.preco > 0)
        .toList();
  }

  /// Recorta os pontos para o filtro escolhido e garante as duas bordas do eixo:
  /// o início exato do período e o instante atual. Antes do primeiro registro,
  /// usa o último preço conhecido ou o preço inicial cadastrado da startup.
  List<_PontoPreco> _filtrarHistorico(
    List<_PontoPreco> historico, {
    required double precoInicial,
    required double precoAtual,
  }) {
    final fim = DateTime.now();
    final inicio = _periodo.inicio(fim);
    final ordenado = [...historico]..sort((a, b) => a.data.compareTo(b.data));
    final pontosAntes = ordenado
        .where((ponto) => ponto.data.isBefore(inicio))
        .toList();
    final pontosNoPeriodo = ordenado
        .where(
          (ponto) => !ponto.data.isBefore(inicio) && !ponto.data.isAfter(fim),
        )
        .toList();
    final pontosIntermediarios = pontosNoPeriodo
        .where(
          (ponto) => ponto.data.isAfter(inicio) && ponto.data.isBefore(fim),
        )
        .toList();
    final pontoNoInicio = pontosNoPeriodo
        .where((ponto) => ponto.data.isAtSameMomentAs(inicio))
        .lastOrNull;
    final precoAbertura = _primeiroPrecoValido([
      pontoNoInicio?.preco ?? 0,
      pontosAntes.lastOrNull?.preco ?? 0,
      precoInicial,
      pontosNoPeriodo.firstOrNull?.preco ?? 0,
      precoAtual,
    ]);
    final precoFechamento = _primeiroPrecoValido([
      precoAtual,
      pontosNoPeriodo.lastOrNull?.preco ?? 0,
      precoAbertura,
    ]);

    return [
      if (precoAbertura > 0) _PontoPreco(data: inicio, preco: precoAbertura),
      ...pontosIntermediarios,
      if (precoFechamento > 0) _PontoPreco(data: fim, preco: precoFechamento),
    ];
  }

  double? _calcularVariacao(List<_PontoPreco> historico) {
    if (historico.length < 2) return null;

    final inicial = historico.first.preco;
    final atual = historico.last.preco;
    if (inicial <= 0) return null;

    return ((atual - inicial) / inicial) * 100;
  }

  double _lerPrecoStartup(Map<String, dynamic>? data) {
    if (data == null) return 0;

    return _numero(data['valorToken'] ?? data['tokenPrecoInicial']);
  }

  double _lerPrecoInicialStartup(Map<String, dynamic>? data) {
    if (data == null) return 0;

    return _numero(data['tokenPrecoInicial']);
  }

  double _primeiroPrecoValido(List<double> precos) {
    for (final preco in precos) {
      if (preco > 0) return preco;
    }

    return 0;
  }

  void _selecionarNav(int index) {
    if (index == 0) {
      Navigator.pop(context);
      return;
    }

    widget.onNavigate?.call(index);
    Navigator.pop(context);
  }
}

/// Desenha pontos posicionados pela data real, sem suavização artificial.
///
/// Segmentos lineares evitam que curvas Bézier pareçam voltar no tempo quando
/// há oscilações grandes em registros muito próximos.
class _GraficoPreco extends StatelessWidget {
  const _GraficoPreco({
    required this.pontos,
    required this.periodo,
    required this.lineColor,
  });

  final List<_PontoPreco> pontos;
  final _PeriodoGrafico periodo;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    if (pontos.length < 2) {
      return AspectRatio(
        aspectRatio: 0.78,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: themeColors.elevatedSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: themeColors.panelBorder),
            ),
            child: Text(
              'Histórico insuficiente',
              style: TextStyle(
                color: themeColors.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    final inicio = pontos.first.data;
    final fim = pontos.last.data;
    final duracaoEmMilissegundos = fim.difference(inicio).inMilliseconds;
    final maxX = duracaoEmMilissegundos > 0
        ? duracaoEmMilissegundos.toDouble()
        : 1.0;
    final spots = pontos
        .map(
          (ponto) => FlSpot(
            ponto.data.difference(inicio).inMilliseconds.toDouble(),
            ponto.preco,
          ),
        )
        .toList();

    final precos = pontos.map((p) => p.preco);
    final minPreco = precos.reduce((a, b) => a < b ? a : b);
    final maxPreco = precos.reduce((a, b) => a > b ? a : b);
    final margem = minPreco == maxPreco
        ? (maxPreco * 0.05).clamp(1.0, double.infinity)
        : (maxPreco - minPreco) * 0.12;
    final minY = (minPreco - margem).clamp(0.0, double.infinity);
    final maxY = maxPreco + margem;
    final intervalY = ((maxY - minY) / 4).clamp(0.01, double.infinity);
    final n = pontos.length;
    final xInterval = maxX / 4;

    return AspectRatio(
      aspectRatio: 0.78,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: intervalY,
            verticalInterval: xInterval,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: themeColors.panelBorder, strokeWidth: 0.8),
            getDrawingVerticalLine: (_) =>
                FlLine(color: themeColors.panelBorder, strokeWidth: 0.8),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: Text(
                'Valor (R\$)',
                style: TextStyle(fontSize: 10, color: themeColors.faintText),
              ),
              axisNameSize: 16,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 54,
                interval: intervalY,
                getTitlesWidget: (val, _) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _formatarNumeroCurto(val),
                    style: TextStyle(fontSize: 9, color: themeColors.faintText),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: Text(
                periodo.eixoX,
                style: TextStyle(fontSize: 10, color: themeColors.faintText),
              ),
              axisNameSize: 16,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: xInterval,
                getTitlesWidget: (val, meta) {
                  if (val < 0 || val > maxX) {
                    return const SizedBox.shrink();
                  }
                  final data = inicio.add(Duration(milliseconds: val.round()));
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Text(
                      _formatarData(data, periodo),
                      style: TextStyle(
                        fontSize: 9,
                        color: themeColors.faintText,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: themeColors.panelBorder),
          ),
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: lineColor,
              barWidth: 2.6,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: n <= 30,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: lineColor,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    lineColor.withValues(alpha: 0.18),
                    lineColor.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumoCarteiraItem extends StatelessWidget {
  const _ResumoCarteiraItem({
    required this.label,
    required this.value,
    this.alignRight = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool alignRight;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: themeColors.mutedText, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? colorScheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TokenDetalheDados {
  const _TokenDetalheDados({
    required this.precoAtual,
    required this.precoInicial,
    required this.historico,
    required this.logoUrl,
    required this.logoStoragePath,
  });

  final double precoAtual;
  final double precoInicial;
  final List<_PontoPreco> historico;
  final String logoUrl;
  final String logoStoragePath;
}

class _PontoPreco {
  const _PontoPreco({required this.data, required this.preco});

  factory _PontoPreco.fromMap(Map<String, dynamic> data) {
    return _PontoPreco(
      data:
          _data(
            data['timestamp'] ??
                data['registradoEm'] ??
                data['createdAt'] ??
                data['executadaEm'] ??
                data['data'],
          ) ??
          DateTime.now(),
      preco: _numero(
        data['preco'] ??
            data['precoUnitario'] ??
            data['valorToken'] ??
            data['tokenPrice'],
      ),
    );
  }

  final DateTime data;
  final double preco;
}

/// Períodos disponíveis e regra para calcular o início de cada janela.
enum _PeriodoGrafico {
  diario('Diário', 'Horas'),
  semanal('Semanal', 'Dias'),
  mensal('Mensal', 'Dias'),
  ultimosSeisMeses('Últimos 6 meses', 'Meses'),
  ytd('YTD', 'Meses');

  const _PeriodoGrafico(this.label, this.eixoX);

  final String label;
  final String eixoX;

  DateTime inicio(DateTime agora) {
    return switch (this) {
      _PeriodoGrafico.diario => agora.subtract(const Duration(days: 1)),
      _PeriodoGrafico.semanal => agora.subtract(const Duration(days: 7)),
      _PeriodoGrafico.mensal => agora.subtract(const Duration(days: 30)),
      _PeriodoGrafico.ultimosSeisMeses => DateTime(
        agora.year,
        agora.month - 6,
        agora.day,
        agora.hour,
        agora.minute,
        agora.second,
        agora.millisecond,
        agora.microsecond,
      ),
      _PeriodoGrafico.ytd => DateTime(agora.year),
    };
  }
}

DateTime? _data(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
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
    final texto = value.replaceAll('R\$', '').replaceAll(' ', '').trim();
    final normalizado = texto.contains(',')
        ? texto.replaceAll('.', '').replaceAll(',', '.')
        : texto;

    return double.tryParse(normalizado) ?? fallback;
  }

  return fallback;
}

String _formatarMoeda(double valor) {
  final negativo = valor < 0;
  final absoluto = valor.abs();
  final partes = absoluto.toStringAsFixed(2).split('.');
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

  return '${negativo ? '-' : ''}R\$ ${buffer.toString()},$centavos';
}

String _formatarQuantidade(double quantidade) {
  if (quantidade % 1 == 0) {
    return quantidade.toInt().toString();
  }

  return quantidade.toStringAsFixed(2).replaceAll('.', ',');
}

String _formatarPercentual(double? percentual) {
  if (percentual == null) return 'N/A';

  final prefixo = percentual > 0 ? '+' : '';
  return '$prefixo${percentual.toStringAsFixed(2).replaceAll('.', ',')}%';
}

String _formatarNumeroCurto(double value) {
  if (value >= 1000) return value.toStringAsFixed(0);
  if (value >= 100) return value.toStringAsFixed(0);
  if (value >= 10) return value.toStringAsFixed(1).replaceAll('.', ',');
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

String _formatarData(DateTime data, _PeriodoGrafico periodo) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final ano = (data.year % 100).toString().padLeft(2, '0');
  final hora = data.hour.toString().padLeft(2, '0');
  final minuto = data.minute.toString().padLeft(2, '0');

  if (periodo == _PeriodoGrafico.diario) {
    return '$hora:$minuto';
  }

  if (periodo == _PeriodoGrafico.ultimosSeisMeses ||
      periodo == _PeriodoGrafico.ytd) {
    return '$mes/$ano';
  }

  return '$dia/$mes';
}
