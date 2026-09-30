import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Non-web fallback: saves to the app's documents directory and returns
/// the path so the caller can tell the user where the file landed (no
/// share/open sheet — this codebase has no share_plus/open_file
/// dependency, and this app's only real deploy target today is web).
Future<String> downloadBytesFile(
  List<int> bytes,
  String filename,
  String mimeType,
) async {
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/$filename';
  final file = File(filePath);
  await file.writeAsBytes(bytes);
  return filePath;
}
