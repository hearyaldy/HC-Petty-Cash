/// Step 5 — Program Identity.
///
/// From Workflow HC: "A) Program description (briefing), Program
/// Naming. B) Design visual board (elements). C) Font/Logo/Color
/// Palette. D) Key Visual (KV). E) Derivations (mockup): Thumbnail
/// YouTube, Reel, Square Post, Carousel, Story."
class ProgramIdentity {
  final String briefing;
  final String programName;
  final List<String> moodboardRefs; // links or asset IDs
  final String fontChoice;
  final String colorPalette; // hex list or description
  final String keyVisualDescription;
  final List<String> derivationsNeeded; // e.g. Thumbnail, Reel, Square Post

  const ProgramIdentity({
    this.briefing = '',
    this.programName = '',
    this.moodboardRefs = const [],
    this.fontChoice = '',
    this.colorPalette = '',
    this.keyVisualDescription = '',
    this.derivationsNeeded = const [
      'Thumbnail (YouTube)',
      'Reel',
      'Square Post',
      'Carousel',
      'Story',
    ],
  });

  bool get isEmpty => briefing.isEmpty && programName.isEmpty;

  ProgramIdentity copyWith({
    String? briefing,
    String? programName,
    List<String>? moodboardRefs,
    String? fontChoice,
    String? colorPalette,
    String? keyVisualDescription,
    List<String>? derivationsNeeded,
  }) {
    return ProgramIdentity(
      briefing: briefing ?? this.briefing,
      programName: programName ?? this.programName,
      moodboardRefs: moodboardRefs ?? this.moodboardRefs,
      fontChoice: fontChoice ?? this.fontChoice,
      colorPalette: colorPalette ?? this.colorPalette,
      keyVisualDescription: keyVisualDescription ?? this.keyVisualDescription,
      derivationsNeeded: derivationsNeeded ?? this.derivationsNeeded,
    );
  }

  Map<String, dynamic> toMap() => {
        'briefing': briefing,
        'programName': programName,
        'moodboardRefs': moodboardRefs,
        'fontChoice': fontChoice,
        'colorPalette': colorPalette,
        'keyVisualDescription': keyVisualDescription,
        'derivationsNeeded': derivationsNeeded,
      };

  factory ProgramIdentity.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ProgramIdentity();
    return ProgramIdentity(
      briefing: map['briefing'] ?? '',
      programName: map['programName'] ?? '',
      moodboardRefs: List<String>.from(map['moodboardRefs'] ?? const []),
      fontChoice: map['fontChoice'] ?? '',
      colorPalette: map['colorPalette'] ?? '',
      keyVisualDescription: map['keyVisualDescription'] ?? '',
      derivationsNeeded: List<String>.from(
        map['derivationsNeeded'] ??
            const ['Thumbnail (YouTube)', 'Reel', 'Square Post', 'Carousel', 'Story'],
      ),
    );
  }
}
