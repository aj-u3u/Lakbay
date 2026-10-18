import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyName = 'user_name';
  static const String _keyEmail = 'user_email';
  static const String _keyRole = 'user_role';
  static const String _keyUserId = 'user_id';

  SessionManager._internal();
  static final SessionManager instance = SessionManager._internal();
  Future<void> _mutations = Future<void>.value();

  // Serialize writes so an older refresh cannot partially restore a cleared session.
  Future<T> _mutate<T>(Future<T> Function(SharedPreferences) action) {
    final result = _mutations.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      return action(preferences);
    });
    _mutations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _writeSession(
    SharedPreferences preferences, {
    required String token,
    required String name,
    required String email,
    required String role,
    required String userId,
    String? refreshToken,
  }) async {
    await preferences.setString(_keyToken, token);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await preferences.setString(_keyRefreshToken, refreshToken);
    } else {
      await preferences.remove(_keyRefreshToken);
    }
    await preferences.setString(_keyName, name);
    await preferences.setString(_keyEmail, email);
    await preferences.setString(_keyRole, role);
    await preferences.setString(_keyUserId, userId);
  }

  Future<void> saveSession({
    required String token,
    required String name,
    required String email,
    required String role,
    required String userId,
    String? refreshToken,
  }) => _mutate(
    (preferences) => _writeSession(
      preferences,
      token: token,
      name: name,
      email: email,
      role: role,
      userId: userId,
      refreshToken: refreshToken,
    ),
  );

  /// Check and replace inside the same serialized mutation, after any sign-out/sign-in.
  Future<bool> saveRefreshedSession({
    required String expectedRefreshToken,
    required String token,
    required String name,
    required String email,
    required String role,
    required String userId,
    String? refreshToken,
  }) => _mutate((preferences) async {
    if (preferences.getString(_keyRefreshToken) != expectedRefreshToken) {
      return false;
    }
    await _writeSession(
      preferences,
      token: token,
      name: name,
      email: email,
      role: role,
      userId: userId,
      refreshToken: refreshToken,
    );
    return true;
  });

  Future<void> clearSession() => _mutate((preferences) async {
    for (final key in [
      _keyToken,
      _keyRefreshToken,
      _keyName,
      _keyEmail,
      _keyRole,
      _keyUserId,
    ]) {
      await preferences.remove(key);
    }
  });

  Future<SharedPreferences> _read() async {
    await _mutations;
    return SharedPreferences.getInstance();
  }

  Future<bool> isLoggedIn() async {
    final preferences = await _read();
    return (preferences.getString(_keyToken)?.isNotEmpty ?? false) &&
        preferences.getString(_keyRole) == 'admin';
  }

  Future<String?> getToken() async => (await _read()).getString(_keyToken);
  Future<String?> getRefreshToken() async =>
      (await _read()).getString(_keyRefreshToken);
  Future<String> getName() async =>
      (await _read()).getString(_keyName) ?? 'Lakbay Admin';
  Future<String> getEmail() async => (await _read()).getString(_keyEmail) ?? '';
  Future<String> getRole() async => (await _read()).getString(_keyRole) ?? '';
  Future<String> getUserId() async =>
      (await _read()).getString(_keyUserId) ?? '';

  Future<void> updateProfile({required String name, required String email}) =>
      _mutate((preferences) async {
        await preferences.setString(_keyName, name);
        await preferences.setString(_keyEmail, email);
      });
}
