import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class AuthenticatedStorageImage extends StatefulWidget {
  const AuthenticatedStorageImage({
    super.key,
    required this.pathOrUrl,
    required this.fallback,
    this.fit,
    this.height,
    this.width,
    this.maxBytes = 5 * 1024 * 1024,
  });

  final String pathOrUrl;
  final Widget fallback;
  final BoxFit? fit;
  final double? height;
  final double? width;
  final int maxBytes;

  static bool isStoragePathOrUrl(String value) {
    if (value.startsWith('gs://') || value.startsWith('startups/')) {
      return true;
    }

    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.host == 'firebasestorage.googleapis.com' ||
            uri.host == 'storage.googleapis.com');
  }

  @override
  State<AuthenticatedStorageImage> createState() =>
      _AuthenticatedStorageImageState();
}

class _AuthenticatedStorageImageState extends State<AuthenticatedStorageImage> {
  static final Map<String, Future<Uint8List?>> _cache = {};

  late Future<Uint8List?> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _load();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedStorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pathOrUrl != widget.pathOrUrl ||
        oldWidget.maxBytes != widget.maxBytes) {
      _bytesFuture = _load();
    }
  }

  Future<Uint8List?> _load() {
    final cacheKey = '${widget.pathOrUrl}|${widget.maxBytes}';
    final cached = _cache[cacheKey];

    if (cached != null) return cached;

    final future = _downloadWithRetry().then((bytes) {
      if (bytes == null) _cache.remove(cacheKey);
      return bytes;
    });

    _cache[cacheKey] = future;
    return future;
  }

  Future<Uint8List?> _downloadWithRetry() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await FirebaseAuth.instance.currentUser?.getIdToken(attempt > 0);
        final data = await _reference(
          widget.pathOrUrl,
        ).getData(widget.maxBytes);

        if (data != null) return data;
      } catch (_) {
        if (attempt == 2) return null;
      }

      await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
    }

    return null;
  }

  Reference _reference(String pathOrUrl) {
    return AuthenticatedStorageImage.isStoragePathOrUrl(pathOrUrl) &&
            (pathOrUrl.startsWith('gs://') ||
                pathOrUrl.startsWith('http://') ||
                pathOrUrl.startsWith('https://'))
        ? FirebaseStorage.instance.refFromURL(pathOrUrl)
        : FirebaseStorage.instance.ref(pathOrUrl);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;

        if (bytes == null) return widget.fallback;

        return Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => widget.fallback,
        );
      },
    );
  }
}
