import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_bottom_nav.dart';

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
  static const _fundo = Colors.white;
  static const _verde = Color(0xFF1B8F4B);
  static const _vermelho = Color(0xFFD04444);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final Future<_TokenDetalheDados> _dadosFuture;
  _PeriodoGrafico _periodo = _PeriodoGrafico.mensal;

  @override
  void initState() {
    super.initState();
    _dadosFuture = _buscarDadosToken();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TokenDetalheDados>(
      future: _dadosFuture,
      builder: (context, snapshot) {
        final dados =
            snapshot.data ??
            _TokenDetalheDados(
              precoAtual: widget.precoAtualInicial,
              historico: const [],
            );

        return Scaffold(
          backgroundColor: _fundo,
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                _buildHeader(dados.precoAtual),
                Expanded(child: _buildBody(snapshot, dados)),
              ],
            ),
          ),
          bottomNavigationBar: AppBottomNav(
            selectedIndex: 0,
            onItemSelected: _selecionarNav,
            backgroundColor: _fundo,
          ),
        );
      },
    );
  }

  Widget _buildHeader(double precoAtual) {
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
            padding: const EdgeInsets.only(left: 88),
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
                    _formatarMoeda(precoAtual),
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
    );
  }

  Widget _buildBody(
    AsyncSnapshot<_TokenDetalheDados> snapshot,
    _TokenDetalheDados dados,
  ) {
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

    final historicoFiltrado = _filtrarHistorico(dados.historico);
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
              const Expanded(
                child: Text(
                  'Valorização do Token',
                  style: TextStyle(
                    color: Colors.black,
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
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildResumoSemHistorico() {
    return Text(
      'Ainda não há negociações suficientes para calcular a variação.',
      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
    );
  }

  Widget _buildResumoCarteira(double precoAtual) {
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
        color: const Color(0xFFF1F1F6),
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFD8D8E2)),
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

  Future<_TokenDetalheDados> _buscarDadosToken() async {
    final startupId = widget.startupId.trim();
    final startupDoc = startupId.isEmpty
        ? null
        : await _firestore.collection('startups').doc(startupId).get();
    final historico = startupId.isEmpty
        ? <_PontoPreco>[]
        : await _buscarHistoricoPrecos(startupId);

    final precoStartup = _lerPrecoStartup(startupDoc?.data());
    final precoHistorico = historico.isNotEmpty ? historico.last.preco : 0.0;
    final precoAtual = _primeiroPrecoValido([
      precoStartup,
      precoHistorico,
      widget.precoAtualInicial,
      widget.precoMedioCompra,
    ]);

    final historicoComAtual = _incluirPrecoAtual(historico, precoAtual);

    return _TokenDetalheDados(
      precoAtual: precoAtual,
      historico: historicoComAtual,
    );
  }

  Future<List<_PontoPreco>> _buscarHistoricoPrecos(String startupId) async {
    final snapshot = await _firestore
        .collection('tokenPrices')
        .where('startupId', isEqualTo: startupId)
        .orderBy('timestamp')
        .limitToLast(180)
        .get();

    final pontos =
        snapshot.docs
            .map((doc) => _PontoPreco.fromMap(doc.data()))
            .where((ponto) => ponto.preco > 0)
            .toList()
          ..sort((a, b) => a.data.compareTo(b.data));

    return pontos;
  }

  List<_PontoPreco> _incluirPrecoAtual(
    List<_PontoPreco> historico,
    double precoAtual,
  ) {
    if (precoAtual <= 0) return historico;

    final agora = DateTime.now();
    if (historico.isEmpty) {
      return [_PontoPreco(data: agora, preco: precoAtual)];
    }

    final ultimo = historico.last;
    final mesmoPreco = (ultimo.preco - precoAtual).abs() < 0.01;
    final recente = agora.difference(ultimo.data).inHours < 12;

    if (mesmoPreco && recente) return historico;

    return [...historico, _PontoPreco(data: agora, preco: precoAtual)];
  }

  List<_PontoPreco> _filtrarHistorico(List<_PontoPreco> historico) {
    if (_periodo == _PeriodoGrafico.tudo || historico.length <= 1) {
      return historico;
    }

    final inicio = DateTime.now().subtract(_periodo.duracao!);
    final filtrado = historico
        .where((ponto) => !ponto.data.isBefore(inicio))
        .toList();

    if (filtrado.length >= 2) return filtrado;

    return historico;
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

    return _numero(
      data['valorToken'] ??
          data['precoToken'] ??
          data['preco'] ??
          data['tokenPrice'] ??
          data['tokenPrecoInicial'],
    );
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
    return AspectRatio(
      aspectRatio: 0.78,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GraficoPrecoPainter(
                pontos: pontos,
                periodo: periodo,
                lineColor: lineColor,
              ),
            ),
          ),
          if (pontos.length < 2)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: const Text(
                  'Histórico insuficiente',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GraficoPrecoPainter extends CustomPainter {
  _GraficoPrecoPainter({
    required this.pontos,
    required this.periodo,
    required this.lineColor,
  });

  final List<_PontoPreco> pontos;
  final _PeriodoGrafico periodo;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: Colors.black.withValues(alpha: 0.74),
      fontSize: 10,
    );
    final titleStyle = TextStyle(
      color: Colors.black.withValues(alpha: 0.86),
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    final axisPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.42)
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 0.8;

    _drawText(
      canvas,
      'Valorização ${periodo.label}',
      Offset(size.width / 2, 2),
      titleStyle,
      textAlign: TextAlign.center,
    );

    final plot = Rect.fromLTWH(48, 28, size.width - 62, size.height - 70);
    canvas.drawRect(plot, axisPaint..style = PaintingStyle.stroke);

    final bounds = _ChartBounds.fromPontos(pontos);

    for (var i = 0; i <= 4; i++) {
      final y = plot.top + (plot.height / 4) * i;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);

      final valor = bounds.max - ((bounds.max - bounds.min) / 4) * i;
      _drawText(
        canvas,
        _formatarNumeroCurto(valor),
        Offset(plot.left - 8, y - 7),
        textStyle,
        textAlign: TextAlign.right,
      );
    }

    final verticalTicks = pontos.length < 2 ? 4 : math.min(7, pontos.length);
    for (var i = 0; i < verticalTicks; i++) {
      final x = verticalTicks == 1
          ? plot.center.dx
          : plot.left + (plot.width / (verticalTicks - 1)) * i;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
    }

    _drawText(
      canvas,
      'Valor (R\$)',
      Offset(10, plot.center.dy),
      textStyle,
      rotation: -math.pi / 2,
      textAlign: TextAlign.center,
    );
    _drawText(
      canvas,
      periodo.eixoX,
      Offset(plot.center.dx, size.height - 16),
      textStyle,
      textAlign: TextAlign.center,
    );

    if (pontos.isEmpty) return;

    final offsets = <Offset>[];
    for (var i = 0; i < pontos.length; i++) {
      offsets.add(_offsetDoPonto(pontos[i], i, plot, bounds));
    }

    if (offsets.length >= 2) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final pointPaint = Paint()..color = lineColor;
    final markerRadius = pontos.length > 45 ? 2.2 : 3.2;
    for (final offset in offsets) {
      canvas.drawCircle(offset, markerRadius, pointPaint);
    }

    final labelIndexes = _labelIndexes(pontos.length);
    for (final index in labelIndexes) {
      final offset = offsets[index];
      _drawText(
        canvas,
        _formatarData(pontos[index].data, periodo),
        Offset(offset.dx, plot.bottom + 8),
        textStyle,
        textAlign: TextAlign.center,
      );
    }
  }

  Offset _offsetDoPonto(
    _PontoPreco ponto,
    int index,
    Rect plot,
    _ChartBounds bounds,
  ) {
    final x = bounds.periodoMs <= 0 || pontos.length == 1
        ? plot.center.dx
        : plot.left +
              (ponto.data.millisecondsSinceEpoch - bounds.inicioMs) /
                  bounds.periodoMs *
                  plot.width;
    final y =
        plot.bottom -
        ((ponto.preco - bounds.min) / (bounds.max - bounds.min)) * plot.height;

    return Offset(
      x.clamp(plot.left, plot.right),
      y.clamp(plot.top, plot.bottom),
    );
  }

  List<int> _labelIndexes(int length) {
    if (length == 0) return const [];
    if (length <= 3) return List.generate(length, (index) => index);

    return {
      0,
      (length * 0.25).round().clamp(0, length - 1),
      (length * 0.5).round().clamp(0, length - 1),
      (length * 0.75).round().clamp(0, length - 1),
      length - 1,
    }.toList()..sort();
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    TextAlign textAlign = TextAlign.left,
    double rotation = 0,
  }) {
    final span = TextSpan(text: text, style: style);
    final painter = TextPainter(
      text: span,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 90);

    final dx = switch (textAlign) {
      TextAlign.center => offset.dx - painter.width / 2,
      TextAlign.right => offset.dx - painter.width,
      _ => offset.dx,
    };

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.rotate(rotation);
    painter.paint(canvas, Offset(dx - offset.dx, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GraficoPrecoPainter oldDelegate) {
    return oldDelegate.pontos != pontos ||
        oldDelegate.periodo != periodo ||
        oldDelegate.lineColor != lineColor;
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
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TokenDetalheDados {
  const _TokenDetalheDados({required this.precoAtual, required this.historico});

  final double precoAtual;
  final List<_PontoPreco> historico;
}

class _PontoPreco {
  const _PontoPreco({required this.data, required this.preco});

  factory _PontoPreco.fromMap(Map<String, dynamic> data) {
    return _PontoPreco(
      data:
          _data(
            data['timestamp'] ??
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

class _ChartBounds {
  const _ChartBounds({
    required this.min,
    required this.max,
    required this.inicioMs,
    required this.periodoMs,
  });

  factory _ChartBounds.fromPontos(List<_PontoPreco> pontos) {
    if (pontos.isEmpty) {
      return _ChartBounds(
        min: 0,
        max: 1,
        inicioMs: DateTime.now().millisecondsSinceEpoch,
        periodoMs: 0,
      );
    }

    final precos = pontos.map((ponto) => ponto.preco);
    final minPreco = precos.reduce(math.min);
    final maxPreco = precos.reduce(math.max);
    final margem = minPreco == maxPreco
        ? math.max(1, maxPreco * 0.05)
        : (maxPreco - minPreco) * 0.12;

    return _ChartBounds(
      min: math.max(0, minPreco - margem),
      max: maxPreco + margem,
      inicioMs: pontos.first.data.millisecondsSinceEpoch,
      periodoMs:
          pontos.last.data.millisecondsSinceEpoch -
          pontos.first.data.millisecondsSinceEpoch,
    );
  }

  final double min;
  final double max;
  final int inicioMs;
  final int periodoMs;
}

enum _PeriodoGrafico {
  semanal('Semanal', 'Dias', Duration(days: 7)),
  mensal('Mensal', 'Dias', Duration(days: 30)),
  anual('Anual', 'Meses', Duration(days: 365)),
  tudo('Tudo', 'Período', null);

  const _PeriodoGrafico(this.label, this.eixoX, this.duracao);

  final String label;
  final String eixoX;
  final Duration? duracao;
}

DateTime? _data(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
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

  if (periodo == _PeriodoGrafico.anual || periodo == _PeriodoGrafico.tudo) {
    return '$mes/$ano';
  }

  return dia;
}
