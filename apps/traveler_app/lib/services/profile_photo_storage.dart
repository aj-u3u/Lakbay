import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps gallery photos in app storage, since the profile API only accepts URLs.
class ProfilePhotoStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String _key(String userId) =>
      'lakbay_profile_photo_${base64Url.encode(utf8.encode(userId))}';

  Future<String?> read(String userId) async {
    final path = await _storage.read(key: _key(userId));
    if (path == null) return null;
    if (await File(path).exists()) return path;
    await _storage.delete(key: _key(userId));
    return null;
  }

  Future<String> save(String userId, String sourcePath) async {
    final source = File(sourcePath);
    final directory = await getApplicationSupportDirectory();
    final photoDirectory = Directory('${directory.path}/profile_photos');
    await photoDirectory.create(recursive: true);

    final extension = sourcePath.split('.').last.toLowerCase();
    final safeExtension =
        {'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(extension)
        ? extension
        : 'jpg';
    final filename =
        '${base64Url.encode(utf8.encode(userId))}_${DateTime.now().microsecondsSinceEpoch}.$safeExtension';
    final saved = await source.copy('${photoDirectory.path}/$filename');
    final oldPath = await _storage.read(key: _key(userId));
    try {
      await _storage.write(key: _key(userId), value: saved.path);
    } catch (_) {
      await saved.delete();
      rethrow;
    }
    if (oldPath != null && oldPath != saved.path) {
      final oldFile = File(oldPath);
      try {
        if (await oldFile.exists()) await oldFile.delete();
      } catch (_) {
        // The new photo is already saved; stale-file cleanup can wait.
      }
    }
    return saved.path;
  }

  Future<void> clear(String userId) async {
    final path = await _storage.read(key: _key(userId));
    await _storage.delete(key: _key(userId));
    if (path != null) {
      final file = File(path);
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // The mapping is cleared, so this photo will no longer be displayed.
      }
    }
  }
}
