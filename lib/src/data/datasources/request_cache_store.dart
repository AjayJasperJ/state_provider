import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/entities/cached_request.dart';

/// Persists cached requests to disk so they survive app restarts.
class RequestCacheStore {
  RequestCacheStore({Directory? directory}) : _directory = directory;

  final Directory? _directory;
  File? _file;

  static const _defaultFileName = 'state_provider_request_cache.json';

  Future<File> _resolveFile() async {
    if (_file != null) return _file!;
    final dir = _directory ?? await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/$_defaultFileName');
    if (!await file.exists()) {
      await file.writeAsString(jsonEncode([]));
    }
    _file = file;
    return file;
  }

  Future<List<CachedRequest>> readAll() async {
    final file = await _resolveFile();
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => CachedRequest.fromJson(Map<String, Object?>.from(e)))
          .toList(growable: true);
    } catch (_) {
      // If corruption occurs, reset the cache to avoid crashes.
      await file.writeAsString(jsonEncode([]));
      return [];
    }
  }

  Future<void> writeAll(Iterable<CachedRequest> requests) async {
    final file = await _resolveFile();
    final payload = requests.map((request) => request.toJson()).toList();
    await file.writeAsString(jsonEncode(payload));
  }

  Future<void> upsert(CachedRequest request) async {
    final all = await readAll();
    final existingIndex = all.indexWhere((element) => element.id == request.id);
    if (existingIndex == -1) {
      all.add(request);
    } else {
      all[existingIndex] = request;
    }
    await writeAll(all);
  }

  Future<void> remove(String id) async {
    final all = await readAll();
    all.removeWhere((element) => element.id == id);
    await writeAll(all);
  }

  Future<void> clear() async {
    final file = await _resolveFile();
    await file.writeAsString(jsonEncode([]));
  }
}
