// Implementação usada fora da web, onde o download via DOM não está disponível.
import 'package:flutter/foundation.dart';

/// Informa explicitamente que o fluxo depende de um navegador.
Future<void> baixarDocumentoNoNavegador({
  required String nomeArquivo,
  required Uint8List bytes,
}) {
  throw UnsupportedError('Download pelo navegador não disponível.');
}
