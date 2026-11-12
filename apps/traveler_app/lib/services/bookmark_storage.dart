import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class BookmarkStore {
  Future<List<int>> read();
  Future<void> write(Iterable<int> ids);
}

class SecureBookmarkStore implements BookmarkStore {
  static const _key = 'lakbay_bookmarked_destination_ids';

  final FlutterSecureStorage _storage;

  const SecureBookmarkStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  @override
  Future<List<int>> read() async {
    final value = await _storage.read(key: _key);
    if (value == null || value.isEmpty) return [];

    final decoded = jsonDecode(value);
    if (decoded is! List) return [];
    return decoded.whereType<num>().map((id) => id.toInt()).toSet().toList();
  }

  @override
  Future<void> write(Iterable<int> ids) {
    return _storage.write(key: _key, value: jsonEncode(ids.toSet().toList()));
  }
}
