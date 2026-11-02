import 'dart:io';
import 'package:flutter/services.dart';

class PdfExportService {
  static const _channel = MethodChannel('lakbay_plus/pdf_export');

  Future<bool> saveTripReport(String tripId, List<int> bytes) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('PDF saving is available in the Android app.');
    }
    final saved = await _channel.invokeMethod<bool>('savePdf', {
      'filename': 'lakbay-trip-$tripId-report.pdf',
      'bytes': Uint8List.fromList(bytes),
    });
    return saved == true;
  }
}
