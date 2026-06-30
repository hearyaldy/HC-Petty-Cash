import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Loads and caches the manager signature image from assets.
/// All PDF services share this static cache so the image is only read once.
class PdfSignatureHelper {
  PdfSignatureHelper._();

  static pw.MemoryImage? _signatureImage;
  static bool _loaded = false;

  /// Set to false to suppress the signature in the next PDF export.
  /// Persists only for the current app session; reset manually if needed.
  static bool includeSignature = true;

  /// Call once per PDF generation session (or in _loadAssets).
  /// Returns null if the file is missing – boxes fall back to blank space.
  static Future<pw.MemoryImage?> load() async {
    if (_loaded) return _signatureImage;
    try {
      final data = await rootBundle.load('assets/images/signature.png');
      _signatureImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      _signatureImage = null; // file not found – silent fallback
    }
    _loaded = true;
    return _signatureImage;
  }

  /// Whether a signature image has been successfully loaded.
  static bool get hasSignature => _signatureImage != null;

  /// A widget that renders the signature image (or blank space if missing
  /// or if [includeSignature] is false). Drop this inside any signature
  /// box above the underline. Uses the same rendering pattern as logos.
  static pw.Widget slot({double width = 100, double height = 40}) {
    if (_signatureImage == null || !includeSignature) {
      return pw.SizedBox(height: height);
    }
    return pw.Image(
      _signatureImage!,
      width: width,
      height: height,
      fit: pw.BoxFit.contain,
    );
  }
}
