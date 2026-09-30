import 'binary_file_downloader_stub.dart'
    if (dart.library.html) 'binary_file_downloader_web.dart'
    as impl;

/// Downloads/saves binary file content (e.g. an .xlsx workbook's encoded
/// bytes). On web this triggers a browser download; elsewhere it saves to
/// the app's documents directory and returns that path.
Future<String> downloadBytesFile(
  List<int> bytes,
  String filename,
  String mimeType,
) =>
    impl.downloadBytesFile(bytes, filename, mimeType);
