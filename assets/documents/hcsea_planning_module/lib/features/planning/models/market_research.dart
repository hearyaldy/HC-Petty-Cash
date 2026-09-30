/// Step 4 — Format: Market Research.
///
/// From Workflow HC: "A) Submit 3 references from similar or related
/// programs. B) Choose: what platforms does the audience prefer?
/// C) Which style (podcast, documentary, shorts, talk shows, etc.)
/// D) 16:9 (landscape) / 9:16 (portrait)"
class ProgramReference {
  final String title;
  final String url;
  final String whatWorks;

  const ProgramReference({
    this.title = '',
    this.url = '',
    this.whatWorks = '',
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'url': url,
        'whatWorks': whatWorks,
      };

  factory ProgramReference.fromMap(Map<String, dynamic> map) {
    return ProgramReference(
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      whatWorks: map['whatWorks'] ?? '',
    );
  }
}

// Named `ProgramAspectRatio` (not `AspectRatio`) to avoid colliding
// with Flutter's own `AspectRatio` widget in package:flutter/widgets.dart.
enum ProgramAspectRatio { landscape169, portrait916 }

extension ProgramAspectRatioLabel on ProgramAspectRatio {
  String get label => this == ProgramAspectRatio.landscape169
      ? '16:9 (landscape)'
      : '9:16 (portrait)';

  String toStorageString() => this == ProgramAspectRatio.landscape169
      ? 'landscape_16_9'
      : 'portrait_9_16';

  static ProgramAspectRatio fromString(String? value) => value == 'portrait_9_16'
      ? ProgramAspectRatio.portrait916
      : ProgramAspectRatio.landscape169;
}

class MarketResearch {
  final List<ProgramReference> references; // Workflow HC asks for exactly 3
  final List<String> preferredPlatforms;
  final String style; // podcast, documentary, shorts, talk show, etc.
  final ProgramAspectRatio aspectRatio;

  const MarketResearch({
    this.references = const [],
    this.preferredPlatforms = const [],
    this.style = '',
    this.aspectRatio = ProgramAspectRatio.landscape169,
  });

  bool get isEmpty =>
      references.isEmpty && preferredPlatforms.isEmpty && style.isEmpty;

  MarketResearch copyWith({
    List<ProgramReference>? references,
    List<String>? preferredPlatforms,
    String? style,
    ProgramAspectRatio? aspectRatio,
  }) {
    return MarketResearch(
      references: references ?? this.references,
      preferredPlatforms: preferredPlatforms ?? this.preferredPlatforms,
      style: style ?? this.style,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }

  Map<String, dynamic> toMap() => {
        'references': references.map((r) => r.toMap()).toList(),
        'preferredPlatforms': preferredPlatforms,
        'style': style,
        'aspectRatio': aspectRatio.toStorageString(),
      };

  factory MarketResearch.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MarketResearch();
    return MarketResearch(
      references: (map['references'] as List? ?? const [])
          .map((r) => ProgramReference.fromMap(Map<String, dynamic>.from(r)))
          .toList(),
      preferredPlatforms: List<String>.from(map['preferredPlatforms'] ?? const []),
      style: map['style'] ?? '',
      aspectRatio: ProgramAspectRatioLabel.fromString(map['aspectRatio']),
    );
  }
}
