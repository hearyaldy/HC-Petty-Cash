import 'package:flutter/material.dart';

/// Deterministic label -> color mapping (Trello's fixed label palette),
/// so the same label text always renders the same color across the
/// board without needing a color picker or a model migration.
const List<Color> kanbanLabelPalette = [
  Color(0xFF61BD4F), // green
  Color(0xFFF2D600), // yellow
  Color(0xFFFF9F1A), // orange
  Color(0xFFEB5A46), // red
  Color(0xFFC377E0), // purple
  Color(0xFF0079BF), // blue
  Color(0xFF00C2E0), // sky
  Color(0xFF51E898), // lime
];

Color kanbanLabelColor(String label) {
  final hash = label.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
  return kanbanLabelPalette[hash % kanbanLabelPalette.length];
}
