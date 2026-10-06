import 'models/product.dart';

const String _prefix = 'toolstock:item:';

/// The text stored inside an item's QR code.
String qrPayloadFor(Product p) => '$_prefix${p.id}';

/// Returns the item id if [raw] is a ToolStock QR code, otherwise null.
String? itemIdFromPayload(String raw) {
  final s = raw.trim();
  return s.startsWith(_prefix) ? s.substring(_prefix.length) : null;
}