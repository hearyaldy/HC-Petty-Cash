import 'dart:convert';
import 'dart:html' as html;

void downloadFile(String content, String filename, String mimeType) {
  final bytes = utf8.encode(mimeType.contains('csv') ? '﻿$content' : content);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
