// Eduarda Prado Deiró - RA: 25004440

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const kVgAzul = Color(0xFF3F51B5);
const kVgRoxoChat = Color(0xFF5B4FCF);
const kVgCoresSocios = [
  Color(0xFF3F51B5),
  Color(0xFF7C52D4),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFF59E0B),
  Color(0xFF0EA5E9),
];

Color corSocio(int index) => kVgCoresSocios[index % kVgCoresSocios.length];

// ── MODELOS ──────────────────────────────────────────────────────────────────

class SocioStartup {
  const SocioStartup({
    required this.nome,
    required this.cargo,
    required this.descricao,
    required this.percentual,
  });

  factory SocioStartup.fromValue(dynamic value) {
    if (value is Map) return SocioStartup.fromMap(value);
    return SocioStartup(
      nome: parseText(value),
      cargo: '',
      descricao: 'Sem descrição cadastrada.',
      percentual: null,
    );
  }

  factory SocioStartup.fromMapEntry(dynamic key, dynamic value) {
    if (value is Map) {
      final data = Map<dynamic, dynamic>.from(value);
      data.putIfAbsent('nome', () => key);
      return SocioStartup.fromMap(data);
    }
    final pct = parsePercentualSocio(value);
    return SocioStartup(
      nome: parseText(key),
      cargo: pct == null ? parseText(value) : '',
      descricao: 'Sem descrição cadastrada.',
      percentual: pct,
    );
  }

  factory SocioStartup.fromMap(Map<dynamic, dynamic> data) {
    return SocioStartup(
      nome: parseText(
        data['nome'] ??
            data['name'] ??
            data['nomeCompleto'] ??
            data['fullName'],
      ),
      cargo: parseText(
        data['cargo'] ??
            data['funcao'] ??
            data['função'] ??
            data['role'] ??
            data['position'],
      ),
      descricao: parseText(
        data['descricao'] ??
            data['descrição'] ??
            data['description'] ??
            data['bio'] ??
            data['biografia'] ??
            data['resumo'],
        fallback: 'Sem descrição cadastrada.',
      ),
      percentual: parsePercentualSocio(
        data['percentual'] ??
            data['participacao'] ??
            data['participação'] ??
            data['participacaoPercentual'] ??
            data['participaçãoPercentual'] ??
            data['equity'],
      ),
    );
  }

  final String nome;
  final String cargo;
  final String descricao;
  final double? percentual;

  String get percentualExibido {
    final v = percentual;
    if (v == null || v <= 0) return 'Não informado';
    return formatPercentual(v);
  }
}

class SegmentoDonut {
  const SegmentoDonut({
    required this.percentual,
    required this.cor,
    required this.label,
  });

  final double percentual;
  final Color cor;
  final String label;
}

class PerguntaStartup {
  const PerguntaStartup({
    required this.id,
    required this.nomeUsuario,
    required this.texto,
    required this.resposta,
    required this.isPrivada,
    required this.createdAt,
  });

  factory PerguntaStartup.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return PerguntaStartup(
      id: doc.id,
      nomeUsuario: parseText(data['nomeUsuario']),
      texto: parseText(data['texto'], fallback: 'Pergunta sem texto'),
      resposta: parseText(data['resposta']),
      isPrivada: data['isPrivada'] == true,
      createdAt: parseDateTime(data['createdAt']),
    );
  }

  final String id;
  final String nomeUsuario;
  final String texto;
  final String resposta;
  final bool isPrivada;
  final DateTime? createdAt;

  bool get foiRespondida => resposta.trim().isNotEmpty;
  String get respostaExibida =>
      foiRespondida ? resposta : 'Aguardando resposta do empreendedor.';
}

class AtualizacaoStartup {
  const AtualizacaoStartup({
    required this.tipo,
    required this.titulo,
    required this.conteudo,
    required this.createdAt,
  });

  factory AtualizacaoStartup.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return AtualizacaoStartup(
      tipo: parseText(data['tipo'] ?? data['type'], fallback: 'atualização'),
      titulo: parseText(
        data['titulo'] ?? data['title'] ?? data['assunto'],
        fallback: 'Atualização sem título',
      ),
      conteudo: parseText(
        data['conteudo'] ??
            data['conteúdo'] ??
            data['content'] ??
            data['descricao'] ??
            data['descrição'] ??
            data['texto'],
        fallback: 'Conteúdo não informado.',
      ),
      createdAt: parseDateTime(
        data['createdAt'] ?? data['data'] ?? data['date'],
      ),
    );
  }

  final String tipo;
  final String titulo;
  final String conteudo;
  final DateTime? createdAt;

  String get tipoExibido => tipoAtualizacaoExibido(tipo);
}

class DocumentoStartup {
  const DocumentoStartup({
    required this.titulo,
    required this.descricao,
    required this.storagePath,
    required this.url,
    required this.nomeArquivo,
    required this.tipo,
    required this.updatedAt,
  });

  factory DocumentoStartup.fromValue(dynamic value) {
    if (value is Map) return DocumentoStartup.fromMap(value);
    return DocumentoStartup(
      titulo: parseText(value, fallback: 'Documento'),
      descricao: '',
      storagePath: '',
      url: '',
      nomeArquivo: '',
      tipo: '',
      updatedAt: null,
    );
  }

  factory DocumentoStartup.fromMapEntry(dynamic key, dynamic value) {
    if (value is Map) {
      final data = Map<dynamic, dynamic>.from(value);
      data.putIfAbsent('titulo', () => key);
      return DocumentoStartup.fromMap(data);
    }

    return DocumentoStartup(
      titulo: parseText(key, fallback: 'Documento'),
      descricao: '',
      storagePath: parseText(value),
      url: '',
      nomeArquivo: '',
      tipo: '',
      updatedAt: null,
    );
  }

  factory DocumentoStartup.fromMap(Map<dynamic, dynamic> data) {
    return DocumentoStartup(
      titulo: parseText(
        data['titulo'] ?? data['title'] ?? data['nome'] ?? data['name'],
        fallback: 'Documento',
      ),
      descricao: parseText(
        data['descricao'] ??
            data['descrição'] ??
            data['description'] ??
            data['resumo'] ??
            data['summary'],
      ),
      storagePath: parseText(
        data['storagePath'] ??
            data['path'] ??
            data['caminhoStorage'] ??
            data['arquivoStorage'],
      ),
      url: parseText(
        data['url'] ??
            data['downloadUrl'] ??
            data['downloadURL'] ??
            data['link'],
      ),
      nomeArquivo: parseText(
        data['nomeArquivo'] ??
            data['fileName'] ??
            data['filename'] ??
            data['arquivo'],
      ),
      tipo: parseText(data['tipo'] ?? data['type']),
      updatedAt: parseDateTime(
        data['updatedAt'] ?? data['atualizadoEm'] ?? data['geradoEm'],
      ),
    );
  }

  final String titulo;
  final String descricao;
  final String storagePath;
  final String url;
  final String nomeArquivo;
  final String tipo;
  final DateTime? updatedAt;

  bool get temArquivo => storagePath.isNotEmpty || url.isNotEmpty;

  String get chave {
    if (storagePath.isNotEmpty) return storagePath;
    if (url.isNotEmpty) return url;
    return titulo;
  }

  String get nomeArquivoDownload {
    if (nomeArquivo.trim().isNotEmpty) return nomeArquivo.trim();
    final base = titulo
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${base.isEmpty ? 'documento' : base}.pdf';
  }

  String get detalheExibido {
    if (descricao.isNotEmpty && nomeArquivo.isNotEmpty) {
      return '$descricao - $nomeArquivo';
    }
    if (descricao.isNotEmpty) return descricao;
    if (nomeArquivo.isNotEmpty) return nomeArquivo;
    return temArquivo ? 'PDF disponível' : 'Arquivo não configurado';
  }
}

class VideoStartup {
  const VideoStartup({
    required this.titulo,
    required this.descricao,
    required this.storagePath,
    required this.url,
  });

  factory VideoStartup.fromValue(dynamic value) {
    if (value is Map) return VideoStartup.fromMap(value);

    return VideoStartup(
      titulo: 'Vídeo de Apresentação',
      descricao: 'Conheça a startup',
      storagePath: '',
      url: parseText(value),
    );
  }

  factory VideoStartup.fromMapEntry(dynamic key, dynamic value) {
    if (value is Map) {
      final data = Map<dynamic, dynamic>.from(value);
      data.putIfAbsent('titulo', () => key);
      return VideoStartup.fromMap(data);
    }

    return VideoStartup(
      titulo: parseText(key, fallback: 'Vídeo de Apresentação'),
      descricao: 'Conheça a startup',
      storagePath: '',
      url: parseText(value),
    );
  }

  factory VideoStartup.fromMap(Map<dynamic, dynamic> data) {
    return VideoStartup(
      titulo: parseText(
        data['titulo'] ?? data['title'] ?? data['nome'] ?? data['name'],
        fallback: 'Vídeo de Apresentação',
      ),
      descricao: parseText(
        data['descricao'] ??
            data['descrição'] ??
            data['description'] ??
            data['resumo'] ??
            data['summary'],
        fallback: 'Conheça a startup',
      ),
      storagePath: parseText(
        data['storagePath'] ??
            data['videoStoragePath'] ??
            data['path'] ??
            data['videoPath'] ??
            data['caminhoStorage'] ??
            data['caminhoVideo'] ??
            data['arquivoStorage'],
      ),
      url: parseText(
        data['url'] ??
            data['videoUrl'] ??
            data['downloadUrl'] ??
            data['downloadURL'] ??
            data['link'],
      ),
    );
  }

  final String titulo;
  final String descricao;
  final String storagePath;
  final String url;

  VideoStartup copyWith({
    String? titulo,
    String? descricao,
    String? storagePath,
    String? url,
  }) {
    return VideoStartup(
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      storagePath: storagePath ?? this.storagePath,
      url: url ?? this.url,
    );
  }
}

// ── FUNÇÕES UTILITÁRIAS ───────────────────────────────────────────────────────

String parseText(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final texto = value.toString().trim();
  return texto.isEmpty ? fallback : texto;
}

double parseNumber(dynamic value, {double fallback = 0}) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final n = value
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(n) ?? fallback;
  }
  return fallback;
}

double? parsePercentualSocio(dynamic value) {
  if (value == null) return null;
  final n = value is String
      ? parseNumber(value.replaceAll('%', ''), fallback: double.nan)
      : parseNumber(value, fallback: double.nan);
  if (n.isNaN || n <= 0) return null;
  return n <= 1 ? n * 100 : n;
}

String formatPercentual(double value) {
  final arredondado = value.roundToDouble();
  if ((value - arredondado).abs() < 0.05) return '${arredondado.toInt()}%';
  return '${value.toStringAsFixed(1).replaceAll('.', ',')}%';
}

DateTime? parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<DocumentoStartup> parseDocumentosStartup(dynamic value) {
  if (value is Iterable) {
    return value
        .map(DocumentoStartup.fromValue)
        .where((doc) => doc.titulo.trim().isNotEmpty)
        .toList();
  }

  if (value is Map) {
    return value.entries
        .map((entry) => DocumentoStartup.fromMapEntry(entry.key, entry.value))
        .where((doc) => doc.titulo.trim().isNotEmpty)
        .toList();
  }

  return const [];
}

List<VideoStartup> parseVideosStartup(dynamic value) {
  if (value is Iterable) {
    return value
        .map(VideoStartup.fromValue)
        .where((video) => video.titulo.trim().isNotEmpty)
        .toList();
  }

  if (value is Map) {
    return value.entries
        .map((entry) => VideoStartup.fromMapEntry(entry.key, entry.value))
        .where((video) => video.titulo.trim().isNotEmpty)
        .toList();
  }

  if (value != null) {
    final video = VideoStartup.fromValue(value);
    return video.url.isEmpty ? const [] : [video];
  }

  return const [];
}

String videoStoragePathPadrao(String startupId) =>
    'startups/$startupId/video/video.mp4';

String formatDataAtualizacao(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final hora = data.hour.toString().padLeft(2, '0');
  final minuto = data.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year} às $hora:$minuto';
}

String capitalizarTexto(String value) {
  final texto = parseText(value, fallback: 'Atualização');
  if (texto.isEmpty) return 'Atualização';
  return '${texto[0].toUpperCase()}${texto.substring(1)}';
}

String tipoAtualizacaoExibido(String value) {
  final n = value.toLowerCase().trim();
  if (n.contains('not')) return 'Notícia';
  if (n.contains('evento')) return 'Evento';
  if (n.contains('financ')) return 'Financeiro';
  if (n.contains('produto')) return 'Produto';
  return capitalizarTexto(value);
}

// ── STREAMS COMPARTILHADOS ────────────────────────────────────────────────────

Stream<bool> usuarioTemTokensStream(String startupId, String? uid) {
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('tokenHoldings')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map(
        (snap) => snap.docs.any((doc) {
          final data = doc.data();
          return parseText(data['startupId']) == startupId &&
              parseNumber(data['quantidade']).toInt() > 0;
        }),
      );
}

// ── GRÁFICO PIZZA ─────────────────────────────────────────────────────────────

class GraficoPizzaPainter extends CustomPainter {
  const GraficoPizzaPainter(this.segmentos);

  final List<SegmentoDonut> segmentos;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const innerRatio = 0.55;
    const gap = 0.018;

    final segs = segmentos.where((s) => s.percentual > 0).toList();
    final total = segs.fold<double>(0, (acc, s) => acc + s.percentual);

    if (total <= 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xFFE5E7EB),
      );
      canvas.drawCircle(
        center,
        radius * innerRatio,
        Paint()..color = Colors.white,
      );
      return;
    }

    double startAngle = -math.pi / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (final seg in segs) {
      final sweep = 2 * math.pi * (seg.percentual / total);
      final actualSweep = math.max(0.0, sweep - gap);

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, startAngle + gap / 2, actualSweep, false)
        ..close();

      canvas.drawPath(path, Paint()..color = seg.cor);

      startAngle += 2 * math.pi * (seg.percentual / total);
    }

    // Círculo interno — cria o efeito de rosquinha
    canvas.drawCircle(
      center,
      radius * innerRatio,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant GraficoPizzaPainter old) =>
      old.segmentos != segmentos;
}
