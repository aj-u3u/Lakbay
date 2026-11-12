import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/models/trip.dart';
import 'package:lakbay_plus/providers/trip_provider.dart';
import 'package:lakbay_plus/services/bookmark_storage.dart';

class _MemoryBookmarkStore implements BookmarkStore {
  List<int> ids = [];

  @override
  Future<List<int>> read() async => List<int>.from(ids);

  @override
  Future<void> write(Iterable<int> nextIds) async {
    ids = List<int>.from(nextIds);
  }
}

void main() {
  test('wishlist bookmarks are restored and persisted', () async {
    final storage = _MemoryBookmarkStore();
    final firstProvider = TripProvider(bookmarkStore: storage);

    expect(await firstProvider.toggleBookmark(8), isTrue);
    expect(storage.ids, [8]);

    final nextProvider = TripProvider(bookmarkStore: storage);
    await nextProvider.loadBookmarks();
    expect(nextProvider.bookmarkedDestinationIds, [8]);
    expect(nextProvider.isBookmarked(8), isTrue);

    expect(await nextProvider.toggleBookmark(8), isTrue);
    expect(storage.ids, isEmpty);
  });

  test('unsaved trips cannot report successful collaboration edits', () async {
    final provider = TripProvider(bookmarkStore: _MemoryBookmarkStore());
    final demoTrip = Trip.mockTrips.first;

    final taskAdded = await provider.addTaskToTrip(demoTrip, {
      'task': 'Book a room',
      'done': false,
    });
    final memoryAdded = await provider.addMemoryToTrip(
      demoTrip,
      filePath: 'memory.jpg',
      caption: 'Trip photo',
      location: 'Davao',
    );

    expect(taskAdded, isFalse);
    expect(memoryAdded, isFalse);
    expect(provider.errorMessage, contains('Save this trip'));
  });
}
