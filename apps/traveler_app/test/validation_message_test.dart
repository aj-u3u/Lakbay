import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/services/validation_message.dart';

void main() {
  test('formats field-level validation entries', () {
    final message = validationMessage([
      {
        'loc': ['body', 'trip_name'],
        'msg': 'Field required',
      },
      {
        'loc': ['body', 'email'],
        'msg': 'Value error, Enter a valid email',
      },
    ]);
    expect(message, 'Trip name: field required\nEmail: enter a valid email');
  });

  test('returns null when nothing is usable', () {
    expect(validationMessage([]), isNull);
    expect(validationMessage(['x']), isNull);
  });
}
