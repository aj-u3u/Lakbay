import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:final_adminlakbay/services/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('cached traveler sessions cannot unlock the admin workspace', () async {
    final session = SessionManager.instance;
    await session.saveSession(
      token: 'traveler-token',
      name: 'Traveler',
      email: 'traveler@example.test',
      role: 'user',
      userId: '10',
    );
    expect(await session.isLoggedIn(), isFalse);
    await session.saveSession(
      token: 'admin-token',
      refreshToken: 'refresh',
      name: 'Administrator',
      email: 'admin@example.test',
      role: 'admin',
      userId: '11',
    );
    expect(await session.isLoggedIn(), isTrue);
    await session.clearSession();
    expect(await session.isLoggedIn(), isFalse);
    expect(await session.getRefreshToken(), isNull);
  });

  test('a queued sign-out wins against an older refresh replacement', () async {
    final session = SessionManager.instance;
    await session.saveSession(
      token: 'expired',
      refreshToken: 'old-refresh',
      name: 'Admin',
      email: 'admin@example.test',
      role: 'admin',
      userId: '11',
    );
    final clearing = session.clearSession();
    final refreshing = session.saveRefreshedSession(
      expectedRefreshToken: 'old-refresh',
      token: 'rotated',
      refreshToken: 'new-refresh',
      name: 'Admin',
      email: 'admin@example.test',
      role: 'admin',
      userId: '11',
    );
    await clearing;
    expect(await refreshing, isFalse);
    expect(await session.getToken(), isNull);
    expect(await session.isLoggedIn(), isFalse);
  });
}
