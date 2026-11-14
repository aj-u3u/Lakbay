/// Turns FastAPI validation entries (`[{loc, msg}, ...]`) into readable lines
/// such as "Email: value is not a valid email address". Returns null when the
/// list has no usable entries so callers can keep their generic message.
String? validationMessage(List<dynamic> entries) {
  final lines = <String>[];
  for (final item in entries) {
    if (item is! Map) continue;
    final loc = item['loc'];
    final parts = loc is List
        ? loc
              .where((p) => p is! String || !const {'body', 'query', 'path'}.contains(p))
              .map((p) => p.toString())
              .toList()
        : <String>[];
    var field = parts.isEmpty ? 'Value' : parts.join(' / ');
    field = field.replaceAll('_', ' ');
    field = field[0].toUpperCase() + field.substring(1);
    var msg = (item['msg'] ?? 'is invalid').toString();
    if (msg.startsWith('Value error, ')) msg = msg.substring(13);
    if (msg.isNotEmpty) msg = msg[0].toLowerCase() + msg.substring(1);
    final line = '$field: $msg';
    if (!lines.contains(line)) lines.add(line);
  }
  return lines.isEmpty ? null : lines.join('\n');
}
