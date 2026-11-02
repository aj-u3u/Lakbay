import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lakbay_plus/models/destination.dart';
import 'package:lakbay_plus/models/grouped_destinations.dart';
import 'package:lakbay_plus/models/trip.dart';
import 'package:lakbay_plus/providers/nav_provider.dart';
import 'package:lakbay_plus/providers/trip_provider.dart';
import 'package:lakbay_plus/screens/trips/trips_screen.dart';
import 'package:lakbay_plus/services/api_service.dart';
import 'package:lakbay_plus/services/bookmark_storage.dart';

class _MemoryBookmarkStore implements BookmarkStore {
  @override
  Future<List<int>> read() async => [];

  @override
  Future<void> write(Iterable<int> ids) async {}
}

class _NotificationsApi extends ApiService {
  _NotificationsApi() : super.testing();

  bool saveSucceeds = false;

  @override
  Future<List<Map<String, dynamic>>?> fetchNotifications() async => [
    {
      'id': '1',
      'title': 'Task assigned',
      'body': 'Please reserve transport.',
      'isNew': true,
      'type': 'taskComplete',
      'tripId': '7',
    },
    {
      'id': '2',
      'title': 'Expense added',
      'body': 'A shared expense was added.',
      'isNew': true,
      'type': 'tripUpdate',
      'tripId': '7',
    },
  ];

  @override
  Future<bool> markNotificationAsRead(String id) async => saveSucceeds;

  @override
  Future<bool> markAllNotificationsAsRead() async => saveSucceeds;
}

class _TripsApi extends _NotificationsApi {
  bool failTrips = false;

  @override
  bool get isAuthenticated => true;

  @override
  Future<List<Destination>> fetchDestinations() async => [];

  @override
  Future<List<GroupedDestinations>> fetchGroupedDestinations({
    List<Destination>? source,
  }) async => [];

  @override
  Future<List<Trip>> fetchUserTrips() async {
    lastError = failTrips ? 'The server could not load trips.' : null;
    return failTrips ? [] : [Trip.mockTrips.first];
  }
}

void main() {
  test(
    'a failed trip refresh keeps the last server result and shows an error',
    () async {
      final api = _TripsApi();
      final provider = TripProvider(
        apiService: api,
        bookmarkStore: _MemoryBookmarkStore(),
      );

      await provider.loadInitialData();
      expect(provider.userTrips, hasLength(1));
      expect(provider.tripsError, isNull);

      api.failTrips = true;
      await provider.loadInitialData();
      expect(provider.userTrips, hasLength(1));
      expect(provider.tripsError, 'The server could not load trips.');
    },
  );

  test('notification failures leave unread state unchanged', () async {
    final api = _NotificationsApi();
    final provider = TripProvider(
      apiService: api,
      bookmarkStore: _MemoryBookmarkStore(),
    );

    expect(await provider.refreshNotifications(), isTrue);
    expect(provider.unreadNotificationCount, 2);
    expect(await provider.markNotificationAsRead('1'), isFalse);
    expect(provider.unreadNotificationCount, 2);
    expect(await provider.markAllNotificationsAsRead(), isFalse);
    expect(provider.unreadNotificationCount, 2);

    api.saveSucceeds = true;
    expect(await provider.markNotificationAsRead('1'), isTrue);
    expect(provider.unreadNotificationCount, 1);
    expect(await provider.markAllNotificationsAsRead(), isTrue);
    expect(provider.unreadNotificationCount, 0);
  });

  testWidgets('trip actions do not offer a fake link join', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => TripProvider(bookmarkStore: _MemoryBookmarkStore()),
          ),
          ChangeNotifierProvider(create: (_) => NavProvider()),
        ],
        child: const MaterialApp(home: TripsScreen()),
      ),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Manual Trip'), findsOneWidget);
    expect(find.text('Join via Link'), findsNothing);
  });
}
