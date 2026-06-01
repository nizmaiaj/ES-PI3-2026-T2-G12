// Seleciona em tempo de compilação a implementação compatível com a plataforma.
export 'document_download_stub.dart'
    if (dart.library.js_interop) 'document_download_web.dart';
