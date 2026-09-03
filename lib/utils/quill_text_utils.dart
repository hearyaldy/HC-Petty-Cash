import 'dart:convert';
import 'package:flutter/material.dart';

/// Shared helper for fields that may hold Quill Delta JSON (rich text)
/// or plain legacy text.

/// Renders [text] preserving bold/italic/underline from Quill Delta JSON,
/// falling back to plain text if it isn't Delta JSON. Wraps within its
/// parent's width.
Widget buildQuillRichText(String text, TextStyle baseStyle) {
  if (text.startsWith('[')) {
    try {
      final ops = jsonDecode(text) as List;
      final spans = <TextSpan>[];
      for (final op in ops) {
        if (op is! Map) continue;
        final insert = op['insert'];
        if (insert is! String) continue;
        final attrs = (op['attributes'] as Map?) ?? {};
        spans.add(TextSpan(
          text: insert,
          style: TextStyle(
            fontWeight: attrs['bold'] == true ? FontWeight.bold : FontWeight.normal,
            fontStyle: attrs['italic'] == true ? FontStyle.italic : FontStyle.normal,
            decoration: attrs['underline'] == true
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ));
      }
      if (spans.isNotEmpty) {
        return Text.rich(TextSpan(style: baseStyle, children: spans), softWrap: true);
      }
    } catch (_) {}
  }
  return Text(text, style: baseStyle, softWrap: true);
}
