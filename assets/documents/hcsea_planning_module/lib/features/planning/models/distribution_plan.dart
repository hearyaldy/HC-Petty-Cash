/// Step 6 — Distribution (including the Editorial Calendar).
///
/// From Workflow HC: "Specify the distribution strategy on all
/// selected platforms. Define: Frequency of publication (time),
/// Format for each platform, Boosting Strategy (Pre/During/Post),
/// Organic/Paid traffic. The editorial calendar organizes the
/// production and publication of content, defining dates, themes,
/// formats, channels, responsible, status, and campaigns."
class EditorialCalendarEntry {
  final DateTime date;
  final String theme;
  final String format;
  final String channel;
  final String responsible;
  final String status; // free text to match the doc's own "status" column
  final String campaign;

  const EditorialCalendarEntry({
    required this.date,
    this.theme = '',
    this.format = '',
    this.channel = '',
    this.responsible = '',
    this.status = 'Planned',
    this.campaign = '',
  });

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'theme': theme,
        'format': format,
        'channel': channel,
        'responsible': responsible,
        'status': status,
        'campaign': campaign,
      };

  factory EditorialCalendarEntry.fromMap(Map<String, dynamic> map) {
    return EditorialCalendarEntry(
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      theme: map['theme'] ?? '',
      format: map['format'] ?? '',
      channel: map['channel'] ?? '',
      responsible: map['responsible'] ?? '',
      status: map['status'] ?? 'Planned',
      campaign: map['campaign'] ?? '',
    );
  }
}

class DistributionPlan {
  final String frequency;
  final Map<String, String> formatByPlatform; // platform -> format description
  final String boostStrategyPre;
  final String boostStrategyDuring;
  final String boostStrategyPost;
  final bool usesPaidTraffic;
  final List<EditorialCalendarEntry> editorialCalendar;

  const DistributionPlan({
    this.frequency = '',
    this.formatByPlatform = const {},
    this.boostStrategyPre = '',
    this.boostStrategyDuring = '',
    this.boostStrategyPost = '',
    this.usesPaidTraffic = false,
    this.editorialCalendar = const [],
  });

  bool get isEmpty => frequency.isEmpty && formatByPlatform.isEmpty;

  DistributionPlan copyWith({
    String? frequency,
    Map<String, String>? formatByPlatform,
    String? boostStrategyPre,
    String? boostStrategyDuring,
    String? boostStrategyPost,
    bool? usesPaidTraffic,
    List<EditorialCalendarEntry>? editorialCalendar,
  }) {
    return DistributionPlan(
      frequency: frequency ?? this.frequency,
      formatByPlatform: formatByPlatform ?? this.formatByPlatform,
      boostStrategyPre: boostStrategyPre ?? this.boostStrategyPre,
      boostStrategyDuring: boostStrategyDuring ?? this.boostStrategyDuring,
      boostStrategyPost: boostStrategyPost ?? this.boostStrategyPost,
      usesPaidTraffic: usesPaidTraffic ?? this.usesPaidTraffic,
      editorialCalendar: editorialCalendar ?? this.editorialCalendar,
    );
  }

  Map<String, dynamic> toMap() => {
        'frequency': frequency,
        'formatByPlatform': formatByPlatform,
        'boostStrategyPre': boostStrategyPre,
        'boostStrategyDuring': boostStrategyDuring,
        'boostStrategyPost': boostStrategyPost,
        'usesPaidTraffic': usesPaidTraffic,
        'editorialCalendar': editorialCalendar.map((e) => e.toMap()).toList(),
      };

  factory DistributionPlan.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const DistributionPlan();
    return DistributionPlan(
      frequency: map['frequency'] ?? '',
      formatByPlatform: Map<String, String>.from(map['formatByPlatform'] ?? const {}),
      boostStrategyPre: map['boostStrategyPre'] ?? '',
      boostStrategyDuring: map['boostStrategyDuring'] ?? '',
      boostStrategyPost: map['boostStrategyPost'] ?? '',
      usesPaidTraffic: map['usesPaidTraffic'] ?? false,
      editorialCalendar: (map['editorialCalendar'] as List? ?? const [])
          .map((e) => EditorialCalendarEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
