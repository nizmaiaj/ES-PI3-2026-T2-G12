import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart';

Future<void> baixarDocumentoNoNavegador({
  required String nomeArquivo,
  required Uint8List bytes,
}) async {
  final url = URL.createObjectURL(
    Blob(
      <JSUint8Array>[bytes.toJS].toJS,
      BlobPropertyBag(type: 'application/octet-stream'),
    ),
  );
  final anchor = document.createElement('a') as HTMLAnchorElement
    ..href = url
    ..download = nomeArquivo
    ..style.display = 'none';

  document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  await Future<void>.delayed(const Duration(seconds: 1));
  URL.revokeObjectURL(url);
}
