import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionTokens {
  final String accessToken;
  final String refreshToken;

  const SessionTokens({
    required this.accessToken,
    required this.refreshToken,
  });
}

class SessionStorage {
  static const _accessTokenKey = 'lakbay_access_token';
  static const _refreshTokenKey = 'lakbay_refresh_token';

  final FlutterSecureStorage _storage;

  SessionStorage()
      : _storage = const FlutterSecureStorage();

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<SessionTokens?> read() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);

    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }

    return SessionTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
