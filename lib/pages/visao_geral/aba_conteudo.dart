// Eduarda Prado Deiró - RA: 25004440
// Biblioteca multimídia da startup: vídeos, documentos, abertura e download.

import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../services/document_download.dart';
import '../../theme/app_theme.dart';
import 'visao_geral_utils.dart';

/// Mantém miniaturas de vídeo inicializadas e compartilhadas pela aba.
class VideoThumbnailCache extends ChangeNotifier {
  final Map<String, VideoPlayerController> _controllers = {};
  final Set<String> _urlsAtivas = {};
  final Set<String> _carregando = {};
  final Set<String> _comErro = {};
  bool _disposed = false;

  VideoPlayerController? controllerFor(String url) => _controllers[url];

  bool isLoading(String url) => _carregando.contains(url);

  void syncWithUrls(Iterable<String> urls) {
    if (_disposed) return;

    final novasUrls = urls.where((url) => url.isNotEmpty).toSet();
    final removidas = _urlsAtivas
        .where((url) => !novasUrls.contains(url))
        .toList();

    _urlsAtivas
      ..clear()
      ..addAll(novasUrls);

    for (final url in removidas) {
      _controllers.remove(url)?.dispose();
      _carregando.remove(url);
      _comErro.remove(url);
    }

    _carregando.removeWhere((url) => !novasUrls.contains(url));
    _comErro.removeWhere((url) => !novasUrls.contains(url));

    for (final url in novasUrls) {
      if (_controllers.containsKey(url) ||
          _carregando.contains(url) ||
          _comErro.contains(url)) {
        continue;
      }
      _load(url);
    }

    _notificar();
  }

  Future<void> _load(String url) async {
    if (_disposed) return;

    _carregando.add(url);
    _notificar();

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await controller.initialize();
      await controller.pause();
      await controller.setVolume(0);
      await controller.seekTo(Duration.zero);

      if (_disposed || !_urlsAtivas.contains(url)) {
        await controller.dispose();
        return;
      }

      _controllers[url] = controller;
      _comErro.remove(url);
    } catch (_) {
      await controller.dispose();
      if (!_disposed) _comErro.add(url);
    } finally {
      _carregando.remove(url);
      _notificar();
    }
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _urlsAtivas.clear();
    _carregando.clear();
    _comErro.clear();
    super.dispose();
  }
}

/// Resolve vídeos cadastrados no documento e no diretório padrão do Storage.
Future<List<VideoStartup>> carregarVideosStartup({
  required String? startupId,
  required Map<String, dynamic>? data,
}) async {
  final id = startupId?.trim() ?? '';
  final videosConfigurados = <VideoStartup>[
    ...parseVideosStartup(
      data?['videos'] ??
          data?['videosApresentacao'] ??
          data?['videoApresentacao'] ??
          data?['video'],
    ),
  ];

  if (videosConfigurados.isEmpty && data != null) {
    final videoUrl = parseText(
      data['videoUrl'] ?? data['urlVideo'] ?? data['linkVideo'],
    );
    final videoStoragePath = parseText(
      data['videoStoragePath'] ??
          data['videoPath'] ??
          data['caminhoVideo'] ??
          data['videoStorage'],
    );

    if (videoUrl.isNotEmpty || videoStoragePath.isNotEmpty) {
      videosConfigurados.add(
        VideoStartup(
          titulo: 'Vídeo de Apresentação',
          descricao: 'Conheça a startup',
          storagePath: videoStoragePath,
          url: videoUrl,
        ),
      );
    }
  }

  final candidatos = videosConfigurados.isEmpty && id.isNotEmpty
      ? [
          VideoStartup(
            titulo: 'Vídeo de Apresentação',
            descricao: 'Conheça a startup',
            storagePath: videoStoragePathPadrao(id),
            url: '',
          ),
        ]
      : videosConfigurados;

  final resolvidos = <VideoStartup>[];
  final urlsUsadas = <String>{};

  for (final video in candidatos) {
    final url = await _resolverUrlVideoStartup(video, id);
    if (url == null || url.isEmpty || !urlsUsadas.add(url)) continue;
    resolvidos.add(video.copyWith(url: url));
  }

  return resolvidos;
}

Future<String?> _resolverUrlVideoStartup(
  VideoStartup video,
  String startupId,
) async {
  final url = video.url.trim();
  if (url.startsWith('http://') || url.startsWith('https://')) return url;

  final storagePath = _pareceCaminhoStorageVideo(url)
      ? url
      : video.storagePath.trim();
  if (storagePath.isNotEmpty) return _buscarStorageDownloadUrl(storagePath);

  if (startupId.isEmpty) return null;
  return _buscarStorageDownloadUrl(videoStoragePathPadrao(startupId));
}

bool _pareceCaminhoStorageVideo(String value) {
  return value.startsWith('gs://') || value.startsWith('startups/');
}

Future<String?> _buscarStorageDownloadUrl(String storagePath) async {
  try {
    final ref = storagePath.startsWith('gs://')
        ? FirebaseStorage.instance.refFromURL(storagePath)
        : FirebaseStorage.instance.ref(storagePath);
    return await ref.getDownloadURL();
  } catch (_) {
    return null;
  }
}

/// Aba responsável por reproduzir vídeos e oferecer ações sobre documentos.
class AbaConteudo extends StatefulWidget {
  const AbaConteudo({super.key, required this.startupId, this.thumbnailCache});

  final String? startupId;
  final VideoThumbnailCache? thumbnailCache;

  @override
  State<AbaConteudo> createState() => _AbaConteudoState();
}

class _AbaConteudoState extends State<AbaConteudo> {
  static const _maxBytesDocumento = 100 * 1024 * 1024;

  List<VideoStartup> _videos = [];
  List<DocumentoStartup> _documentos = [];
  late final VideoThumbnailCache _thumbnailCache;
  late final bool _isThumbnailCacheLocal;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _conteudoSubscription;
  int _conteudoVersao = 0;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoLoading = false;
  String? _videoEmExecucaoUrl;
  String? _documentoEmAcao;

  @override
  void initState() {
    super.initState();
    _isThumbnailCacheLocal = widget.thumbnailCache == null;
    _thumbnailCache = widget.thumbnailCache ?? VideoThumbnailCache();
    _ouvirConteudo();
  }

  @override
  void dispose() {
    _conteudoSubscription?.cancel();
    if (_isThumbnailCacheLocal) _thumbnailCache.dispose();
    _disposeVideoController();
    super.dispose();
  }

  /// Escuta o documento da startup e atualiza vídeos e documentos exibidos.
  void _ouvirConteudo() {
    final startupId = widget.startupId;
    if (startupId == null) return;

    _conteudoSubscription = FirebaseFirestore.instance
        .collection('startups')
        .doc(startupId)
        .snapshots()
        .listen((snapshot) async {
          final versao = ++_conteudoVersao;
          if (!mounted) return;

          final data = snapshot.data();
          if (!snapshot.exists || data == null) {
            setState(() {
              _videos = [];
              _documentos = [];
            });
            _thumbnailCache.syncWithUrls(const []);
            return;
          }

          final documentosDoBanco = data['documentos'] ?? data['documents'];
          final novosVideos = await carregarVideosStartup(
            startupId: startupId,
            data: data,
          );

          if (!mounted || versao != _conteudoVersao) return;

          setState(() {
            _videos = novosVideos;
            _documentos = parseDocumentosStartup(documentosDoBanco);
          });
          _thumbnailCache.syncWithUrls(novosVideos.map((video) => video.url));
        });
  }

  /// Inicializa o player modal para o vídeo selecionado.
  Future<void> _playVideo(String url) async {
    if (url.isEmpty) return;
    if (_videoEmExecucaoUrl == url &&
        (_isVideoLoading || _chewieController != null)) {
      return;
    }

    await _disposeVideoController();

    if (!mounted) return;

    setState(() {
      _isVideoLoading = true;
      _videoEmExecucaoUrl = url;
    });

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await controller.initialize();

      if (!mounted || _videoEmExecucaoUrl != url) {
        await controller.dispose();
        return;
      }

      _videoPlayerController = controller;

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio,
        errorBuilder: (context, msg) => Center(
          child: Text(
            'Erro ao reproduzir: $msg',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );

      setState(() => _isVideoLoading = false);
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;

      setState(() {
        _isVideoLoading = false;
        _videoEmExecucaoUrl = null;
      });
      _mostrarMensagem('Não foi possível carregar o vídeo.');
    }
  }

  Future<void> _disposeVideoController() async {
    _chewieController?.dispose();
    await _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
    _videoEmExecucaoUrl = null;
  }

  void _mostrarMensagem(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// Resolve URL externa ou caminho autenticado do Firebase Storage.
  Future<String> _resolverUrlDocumento(DocumentoStartup documento) async {
    final storagePath = documento.storagePath.trim();

    if (storagePath.isNotEmpty) {
      return _buscarDownloadUrlStorage(storagePath);
    }

    final url = documento.url.trim();

    if (url.isEmpty) {
      throw Exception('Documento sem arquivo configurado.');
    }

    if (_pareceUrlStorage(url)) {
      return _buscarDownloadUrlStorage(url);
    }

    return url;
  }

  Future<String> _buscarDownloadUrlStorage(String pathOrUrl) {
    final ref = _pareceUrlStorage(pathOrUrl)
        ? FirebaseStorage.instance.refFromURL(pathOrUrl)
        : FirebaseStorage.instance.ref(pathOrUrl);
    return ref.getDownloadURL();
  }

  bool _pareceUrlStorage(String value) {
    if (value.startsWith('gs://')) return true;

    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.host == 'firebasestorage.googleapis.com' ||
            uri.host == 'storage.googleapis.com');
  }

  Future<void> _abrirDocumento(DocumentoStartup documento) async {
    await _executarAcaoDocumento(documento, baixar: false);
  }

  Future<void> _baixarDocumento(DocumentoStartup documento) async {
    await _executarAcaoDocumento(documento, baixar: true);
  }

  /// Compartilha tratamento de estado e erro entre abrir e baixar documento.
  Future<void> _executarAcaoDocumento(
    DocumentoStartup documento, {
    required bool baixar,
  }) async {
    if (!documento.temArquivo) {
      _mostrarMensagem('Arquivo do documento não configurado.');
      return;
    }

    setState(() => _documentoEmAcao = documento.chave);

    try {
      if (baixar) {
        await _salvarDocumento(documento);
        return;
      }

      final url = await _resolverUrlDocumento(documento);
      final abriu = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!abriu) {
        _mostrarMensagem('Não foi possível abrir o documento.');
      }
    } on FirebaseException catch (error) {
      debugPrint(
        'Firebase Storage recusou o documento ${documento.chave}: '
        '${error.code} - ${error.message}',
      );
      _mostrarMensagem(_mensagemErroStorage(error));
    } catch (error) {
      debugPrint('Não foi possível acessar o documento: $error');
      _mostrarMensagem(
        'Não foi possível acessar este documento. Detalhes: $error',
      );
    } finally {
      if (mounted) setState(() => _documentoEmAcao = null);
    }
  }

  Future<void> _salvarDocumento(DocumentoStartup documento) async {
    final nomeArquivo = documento.nomeArquivoDownload;
    final storagePath = documento.storagePath.trim();
    final url = documento.url.trim();
    final caminhoStorage = storagePath.isNotEmpty
        ? storagePath
        : _pareceUrlStorage(url)
        ? url
        : null;

    if (caminhoStorage != null) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final downloadUrl = await _referenciaStorage(
          caminhoStorage,
        ).getDownloadURL();
        await FileSaver.instance.downloadLink(
          link: LinkDetails(link: downloadUrl),
          name: nomeArquivo,
        );
        _mostrarMensagem(
          'Download iniciado. O arquivo será salvo em Downloads.',
        );
        return;
      }

      final bytes = await _buscarBytesDocumentoStorage(caminhoStorage);
      if (kIsWeb) {
        await baixarDocumentoNoNavegador(
          nomeArquivo: nomeArquivo,
          bytes: bytes,
        );
        _mostrarMensagem('Download concluído.');
        return;
      }

      await FileSaver.instance.saveFile(
        name: nomeArquivo,
        bytes: bytes,
        includeExtension: false,
      );
      _mostrarMensagem('Download concluído.');
      return;
    }

    final link = LinkDetails(link: url);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await FileSaver.instance.downloadLink(link: link, name: nomeArquivo);
      _mostrarMensagem('Download iniciado. O arquivo será salvo em Downloads.');
      return;
    }

    await FileSaver.instance.saveFile(
      name: nomeArquivo,
      link: link,
      includeExtension: false,
    );
    _mostrarMensagem('Download concluído.');
  }

  Future<Uint8List> _buscarBytesDocumentoStorage(String pathOrUrl) async {
    for (var tentativa = 0; tentativa < 3; tentativa++) {
      try {
        await FirebaseAuth.instance.currentUser?.getIdToken(tentativa > 0);
        final bytes = await _referenciaStorage(
          pathOrUrl,
        ).getData(_maxBytesDocumento);
        if (bytes != null) return bytes;
      } on FirebaseException {
        if (tentativa == 2) rethrow;
      }

      await Future<void>.delayed(Duration(milliseconds: 250 * (tentativa + 1)));
    }

    throw Exception('O arquivo não retornou conteúdo.');
  }

  Reference _referenciaStorage(String pathOrUrl) {
    return _pareceUrlStorage(pathOrUrl)
        ? FirebaseStorage.instance.refFromURL(pathOrUrl)
        : FirebaseStorage.instance.ref(pathOrUrl);
  }

  String _mensagemErroStorage(FirebaseException error) {
    final code = error.code.replaceFirst('storage/', '');

    return switch (code) {
      'object-not-found' => 'Arquivo não encontrado no Firebase Storage.',
      'unauthenticated' =>
        'Sua sessão expirou. Entre novamente para baixar o documento.',
      'unauthorized' => 'Você não possui permissão para baixar este documento.',
      'retry-limit-exceeded' =>
        'Não foi possível baixar o documento. Verifique sua conexão.',
      _ => 'Não foi possível acessar este documento ($code).',
    };
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
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vídeos de apresentação',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Conheça mais sobre a startup através de conteúdos selecionados',
            style: TextStyle(fontSize: 11, color: themeColors.faintText),
          ),
          const SizedBox(height: 16),
          if (_videos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Nenhum vídeo disponível para esta startup.',
                  style: TextStyle(
                    fontSize: 12,
                    color: themeColors.faintText,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ...List.generate(_videos.length, (i) {
            final video = _videos[i];
            return Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
              child: _buildVideoItem(video.url),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVideoItem(String url) {
    final estaAtivo = _videoEmExecucaoUrl == url;
    final estaCarregando = estaAtivo && _isVideoLoading;
    final videoPlayerController = _videoPlayerController;
    final chewieController = _chewieController;

    if (estaAtivo &&
        videoPlayerController != null &&
        videoPlayerController.value.isInitialized &&
        chewieController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: videoPlayerController.value.aspectRatio,
          child: Chewie(controller: chewieController),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (url.isNotEmpty) {
            _playVideo(url);
          } else {
            _mostrarMensagem('Vídeo indisponível.');
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildVideoThumbnail(url),
            if (estaCarregando)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x66000000)),
                ),
              ),
            if (estaCarregando)
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(String url) {
    return AnimatedBuilder(
      animation: _thumbnailCache,
      builder: (context, _) {
        final controller = _thumbnailCache.controllerFor(url);
        final carregando = _thumbnailCache.isLoading(url);
        final pronto = controller != null && controller.value.isInitialized;
        final tamanho = pronto ? controller.value.size : Size.zero;
        final larguraVideo = tamanho.width > 0 ? tamanho.width : 16.0;
        final alturaVideo = tamanho.height > 0 ? tamanho.height : 9.0;

        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (pronto)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: larguraVideo,
                    height: alturaVideo,
                    child: VideoPlayer(controller),
                  ),
                )
              else
                const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFFD4D4D4)),
                ),
              if (pronto)
                const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x33000000)),
                ),
              if (carregando && !pronto)
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 58,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentosCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documentos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          if (_documentos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Nenhum documento disponível para esta startup.',
                  style: TextStyle(
                    fontSize: 12,
                    color: themeColors.faintText,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ...List.generate(_documentos.length, (i) {
            return Column(
              children: [
                _buildDocumentoItem(_documentos[i]),
                if (i < _documentos.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: themeColors.panelBorder),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDocumentoItem(DocumentoStartup documento) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final carregando = _documentoEmAcao == documento.chave;
    final tipoDocumento = _tipoDocumento(documento);
    final corDocumento = _corDocumento(tipoDocumento);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: corDocumento.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _iconeDocumento(tipoDocumento),
            color: corDocumento,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                documento.titulo,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                documento.detalheExibido,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: themeColors.faintText),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (carregando)
          const SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else ...[
          Tooltip(
            message: 'Abrir documento',
            child: IconButton(
              icon: const Icon(Icons.open_in_new, size: 20),
              color: kVgAzul,
              onPressed: documento.temArquivo
                  ? () => _abrirDocumento(documento)
                  : null,
            ),
          ),
          Tooltip(
            message: 'Baixar documento',
            child: IconButton(
              icon: const Icon(Icons.download_outlined, size: 21),
              color: kVgAzul,
              onPressed: documento.temArquivo
                  ? () => _baixarDocumento(documento)
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  /// Classifica o arquivo para escolher ícone e cor exibidos na lista.
  _TipoDocumento _tipoDocumento(DocumentoStartup documento) {
    final referencia = [
      documento.tipo,
      documento.nomeArquivo,
      documento.storagePath,
      documento.url,
    ].join(' ').toLowerCase();

    if (_possuiFormato(referencia, const ['pdf'])) {
      return _TipoDocumento.pdf;
    }
    if (_possuiFormato(referencia, const ['xls', 'xlsx', 'ods', 'csv']) ||
        referencia.contains('spreadsheet') ||
        referencia.contains('ms-excel')) {
      return _TipoDocumento.planilha;
    }
    if (_possuiFormato(referencia, const ['ppt', 'pptx', 'odp']) ||
        referencia.contains('presentation') ||
        referencia.contains('ms-powerpoint')) {
      return _TipoDocumento.apresentacao;
    }
    if (_possuiFormato(referencia, const [
          'doc',
          'docx',
          'odt',
          'rtf',
          'txt',
        ]) ||
        referencia.contains('wordprocessing') ||
        referencia.contains('msword') ||
        referencia.contains('text/')) {
      return _TipoDocumento.texto;
    }
    if (_possuiFormato(referencia, const [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'svg',
          'bmp',
        ]) ||
        referencia.contains('image/')) {
      return _TipoDocumento.imagem;
    }
    if (_possuiFormato(referencia, const ['zip', 'rar', '7z', 'gz', 'tar'])) {
      return _TipoDocumento.compactado;
    }

    return _TipoDocumento.generico;
  }

  IconData _iconeDocumento(_TipoDocumento tipo) {
    return switch (tipo) {
      _TipoDocumento.pdf => Icons.picture_as_pdf_outlined,
      _TipoDocumento.planilha => Icons.table_chart_outlined,
      _TipoDocumento.apresentacao => Icons.slideshow_outlined,
      _TipoDocumento.texto => Icons.description_outlined,
      _TipoDocumento.imagem => Icons.image_outlined,
      _TipoDocumento.compactado => Icons.archive_outlined,
      _TipoDocumento.generico => Icons.insert_drive_file_outlined,
    };
  }

  Color _corDocumento(_TipoDocumento tipo) {
    return switch (tipo) {
      _TipoDocumento.pdf => const Color(0xFFD32F2F),
      _TipoDocumento.planilha => const Color(0xFF188038),
      _TipoDocumento.apresentacao => const Color(0xFFF57C00),
      _TipoDocumento.texto => const Color(0xFF2563EB),
      _TipoDocumento.imagem => const Color(0xFF7C3AED),
      _TipoDocumento.compactado => const Color(0xFFD97706),
      _TipoDocumento.generico => kVgAzul,
    };
  }

  bool _possuiFormato(String referencia, List<String> formatos) {
    return formatos.any(
      (formato) => RegExp(
        '(?:^|[./_-])${RegExp.escape(formato)}(?:\$|[?&#;\\s])',
      ).hasMatch(referencia),
    );
  }
}

enum _TipoDocumento {
  pdf,
  planilha,
  apresentacao,
  texto,
  imagem,
  compactado,
  generico,
}
