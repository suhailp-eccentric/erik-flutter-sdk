import 'dart:io';

import 'package:flutter/services.dart';

class ErikAssetServer {
  ErikAssetServer._();

  static final ErikAssetServer instance = ErikAssetServer._();

  static const _assetRoot = 'packages/erik_flutter_sdk/assets/erik_browser/';

  HttpServer? _server;
  Uri? _baseUri;
  Set<String>? _availableAssets;

  Future<Uri> ensureStarted() async {
    if (_baseUri != null) {
      return _baseUri!;
    }

    _availableAssets ??= await _loadAssetManifest();
    _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: true,
    );
    _baseUri = Uri.parse('http://127.0.0.1:${_server!.port}/');

    _server!.listen(_handleRequest);
    return _baseUri!;
  }

  Future<Uri> urlForEntryPoint(String entryPoint) async {
    final baseUri = await ensureStarted();
    return baseUri.resolve(entryPoint);
  }

  Future<Set<String>> _loadAssetManifest() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest
        .listAssets()
        .where((key) => key.startsWith(_assetRoot))
        .toSet();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final normalizedPath = _normalizePath(request.uri.path);
    final assetKey = _resolveAssetKey(normalizedPath);

    if (assetKey == null) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found');
      await request.response.close();
      return;
    }

    try {
      final data = await rootBundle.load(assetKey);
      request.response.headers.contentType = _contentTypeForPath(assetKey);
      request.response.add(_toBytes(data));
    } catch (_) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Asset missing');
    } finally {
      await request.response.close();
    }
  }

  String _normalizePath(String rawPath) {
    var path = rawPath;
    if (path.isEmpty || path == '/') {
      return 'index.html';
    }
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    return Uri.decodeComponent(path);
  }

  String? _resolveAssetKey(String normalizedPath) {
    final directKey = '$_assetRoot$normalizedPath';
    if (_availableAssets!.contains(directKey)) {
      return directKey;
    }

    if (!normalizedPath.contains('.')) {
      final fallbackKey = '${_assetRoot}index.html';
      if (_availableAssets!.contains(fallbackKey)) {
        return fallbackKey;
      }
    }

    return null;
  }

  Uint8List _toBytes(ByteData data) {
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  ContentType _contentTypeForPath(String assetPath) {
    final extension = assetPath.split('.').last.toLowerCase();

    switch (extension) {
      case 'html':
        return ContentType.html;
      case 'css':
        return ContentType('text', 'css', charset: 'utf-8');
      case 'js':
        return ContentType('application', 'javascript', charset: 'utf-8');
      case 'json':
        return ContentType.json;
      case 'wasm':
        return ContentType('application', 'wasm');
      case 'png':
        return ContentType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return ContentType('image', 'jpeg');
      case 'ico':
        return ContentType('image', 'x-icon');
      case 'svg':
        return ContentType('image', 'svg+xml');
      case 'ttf':
        return ContentType('font', 'ttf');
      case 'woff':
        return ContentType('font', 'woff');
      case 'woff2':
        return ContentType('font', 'woff2');
      case 'hdr':
      case 'ash':
      case 'erik':
        return ContentType.binary;
      default:
        return ContentType.binary;
    }
  }
}
