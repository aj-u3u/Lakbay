import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/services/api_service.dart';

void main() {
  late HttpServer server;
  late Directory tempDir;
  late String previousBaseUrl;
  var isRead = false;
  final paths = <String>[];

  setUpAll(() async {
    previousBaseUrl = ApiService.baseUrl;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiService.baseUrl = 'http://127.0.0.1:${server.port}/api/v1';
    tempDir = await Directory.systemTemp.createTemp('lakbay-media-test-');
    server.listen((request) async {
      paths.add('${request.method} ${request.uri.path}');
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer test-token',
      );
      final path = request.uri.path;
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'POST' &&
          path == '/api/v1/trips/7/memories/upload') {
        expect(request.headers.contentType?.mimeType, 'multipart/form-data');
        final body = await latin1.decoder.bind(request).join();
        expect(body, contains('name="file"'));
        request.response.write(
          jsonEncode({
            'image_url':
                'https://res.cloudinary.com/demo/image/upload/photo.png',
            'cloudinary_public_id': 'lakbay/trips/7/memories/photo',
          }),
        );
      } else if (request.method == 'POST' &&
          path == '/api/v1/trips/7/memories') {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['cloudinary_public_id'], 'lakbay/trips/7/memories/photo');
        request.response.statusCode = 201;
        request.response.write(
          jsonEncode({
            'trip_memory_id': 12,
            'image_url': body['image_url'],
            'caption': body['caption'],
            'location_tag': body['location_tag'],
            'cloudinary_public_id': body['cloudinary_public_id'],
          }),
        );
      } else if (request.method == 'GET' &&
          path == '/api/v1/trips/7/memories') {
        request.response.write(
          jsonEncode([
            {
              'trip_memory_id': 12,
              'image_url':
                  'https://res.cloudinary.com/demo/image/upload/photo.png',
              'caption': 'Davao day',
              'location_tag': 'Davao',
            },
          ]),
        );
      } else if (request.method == 'GET' && path == '/api/v1/notifications') {
        request.response.write(
          jsonEncode([
            {
              'notification_id': 9,
              'event_type': 'task_assigned',
              'title': 'Task assigned',
              'message': 'Book transport',
              'is_read': isRead,
              'trip_id': 7,
            },
          ]),
        );
      } else if (request.method == 'PATCH' &&
          path == '/api/v1/notifications/9/read') {
        isRead = true;
        request.response.write('{}');
      } else if (request.method == 'GET' &&
          path == '/api/v1/trips/7/reports/pdf') {
        request.response.headers.contentType = ContentType(
          'application',
          'pdf',
        );
        request.response.add(ascii.encode('%PDF-1.4\n%%EOF'));
      } else {
        request.response.statusCode = 404;
        request.response.write('{"detail":"Unavailable"}');
      }
      await request.response.close();
    });
  });

  tearDownAll(() async {
    ApiService.baseUrl = previousBaseUrl;
    await server.close(force: true);
    await tempDir.delete(recursive: true);
  });

  test('photo upload creates a memory and a later fetch reloads it', () async {
    final file = File('${tempDir.path}/photo.png');
    await file.writeAsBytes([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0,
      0,
      0,
      0,
    ]);
    final api = ApiService.testing()..setToken('test-token');
    final upload = await api.uploadTripMemoryImage('7', file.path);
    expect(upload?['image_url'], contains('cloudinary.com'));
    final created = await api.createTripMemory(
      '7',
      imageUrl: upload!['image_url'] as String,
      cloudinaryPublicId: upload['cloudinary_public_id'] as String,
      caption: 'Davao day',
      locationTag: 'Davao',
    );
    expect(created?['memory_id'], '12');
    final reloaded = await api.fetchTripMemories('7');
    expect(reloaded, hasLength(1));
    expect(reloaded.single['caption'], 'Davao day');
    expect(paths, contains('GET /api/v1/trips/7/memories'));
  });

  test('notification read state survives reload', () async {
    final api = ApiService.testing()..setToken('test-token');
    final first = await api.fetchNotifications();
    expect(first?.single['isNew'], true);
    expect(await api.markNotificationAsRead('9'), true);
    final second = await api.fetchNotifications();
    expect(second?.single['isNew'], false);
  });

  test('PDF download uses the report endpoint and returns PDF bytes', () async {
    final api = ApiService.testing()..setToken('test-token');
    final bytes = await api.downloadTripReportPdf('7');
    expect(ascii.decode(bytes!), startsWith('%PDF-'));
    expect(paths, contains('GET /api/v1/trips/7/reports/pdf'));
  });
}
