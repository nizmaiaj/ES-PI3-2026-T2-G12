import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'visao_geral_utils.dart';

class AbaConteudo extends StatefulWidget {
  const AbaConteudo({super.key, required this.startupId});

  final String? startupId;

  @override
  State<AbaConteudo> createState() => _AbaConteudoState();
}

class _AbaConteudoState extends State<AbaConteudo> {
  List<Map<String, String>> _videos = [];
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoLoading = false;

  @override
  void initState() {
    super.initState();
    _ouvirVideos();
  }

  @override
  void dispose() {
    _disposeVideoController();
    super.dispose();
  }

  void _ouvirVideos() {
    final startupId = widget.startupId;
    if (startupId == null) return;

    FirebaseFirestore.instance
        .collection('startups')
        .doc(startupId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) return;
          final videosDoBanco =
              snapshot.data()!['videos'] as List<dynamic>?;
          if (videosDoBanco != null && mounted) {
            setState(() {
              _videos = videosDoBanco.map((v) {
                return {
                  'titulo': parseText(
                    v['titulo'],
                    fallback: 'Vídeo de Apresentação',
                  ),
                  'descricao': parseText(
                    v['descricao'],
                    fallback: 'Conheça a startup',
                  ),
                  'url': parseText(v['url']),
                };
              }).toList();
            });
          }
        });
  }

  Future<void> _playVideo(String url) async {
    if (url.isEmpty) return;
    await _disposeVideoController();

    setState(() => _isVideoLoading = true);

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, msg) => Center(
          child: Text(
            'Erro ao reproduzir: $msg',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );

      setState(() => _isVideoLoading = false);

      if (mounted) _showVideoDialog();
    } catch (_) {
      setState(() => _isVideoLoading = false);
      _mostrarMensagem('Não foi possível carregar o vídeo.');
    }
  }

  Future<void> _disposeVideoController() async {
    _chewieController?.dispose();
    await _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
  }

  void _showVideoDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        contentPadding: EdgeInsets.zero,
        content: AspectRatio(
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
      ),
    ).then((_) => _disposeVideoController());
  }

  void _mostrarMensagem(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          _buildVideosCard(),
          const SizedBox(height: 16),
          _buildDocumentosCard(),
        ],
      ),
    );
  }

  Widget _buildVideosCard() {
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
            'Vídeos de apresentação',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Conheça mais sobre a startup através de conteúdos selecionados',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (_isVideoLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFFE0E0E0),
                color: Color(0xFF1A1A2E),
              ),
            ),
          if (_videos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Nenhum vídeo disponível para esta startup.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ...List.generate(_videos.length, (i) {
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final url = _videos[i]['url'] ?? '';
                if (url.isNotEmpty) {
                  _playVideo(url);
                } else {
                  _mostrarMensagem('Vídeo indisponível.');
                }
              },
              child: _buildVideoItem(
                _videos[i]['titulo'] ?? 'Vídeo de Apresentação',
                _videos[i]['descricao'] ?? 'Conheça a startup',
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVideoItem(String titulo, String descricao) {
    return Row(
      children: [
        Container(
          width: 110,
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFFD4D4D4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.play_circle_outline,
            color: Colors.white,
            size: 38,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              descricao,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentosCard() {
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
            'Documentos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(kVgDocumentos.length, (i) {
            return Column(
              children: [
                _buildDocumentoItem(kVgDocumentos[i]),
                if (i < kVgDocumentos.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDocumentoItem(String nome) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEBEDF8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.insert_drive_file_outlined,
            color: kVgAzul,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Text(nome, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
