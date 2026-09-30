import 'dart:html' as html;

/// Web: triggers a browser download via an object URL, same mechanism as
/// csv_downloader_web.dart but for binary content (e.g. .xlsx bytes)
/// instead of UTF-8 text.
Future<String> downloadBytesFile(
  List<int> bytes,
  String filename,
  String mimeType,
) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return filename;
}
