import 'planning_step_status.dart';

/// Step 8 — Approvals.
///
/// Mirrors the "Pre-production Approval Checklist" table structure
/// from Workflow HC (Item | Status | Owner | Notes), applied here to
/// the Planning stage so the same widget/pattern can be reused for
/// the Pre-production checklist later.
class ApprovalItem {
  final String item;
  final PlanningStepStatus status;
  final String owner;
  final String notes;

  const ApprovalItem({
    required this.item,
    this.status = PlanningStepStatus.notStarted,
    this.owner = '',
    this.notes = '',
  });

  /// The eight Planning steps, pre-populated as the default checklist
  /// so a new project starts with the right rows instead of a blank list.
  static List<ApprovalItem> defaultPlanningChecklist() => const [
        ApprovalItem(item: 'General objective defined'),
        ApprovalItem(item: 'Audience defined'),
        ApprovalItem(item: 'Strategic intent defined'),
        ApprovalItem(item: 'Market research completed (3 references)'),
        ApprovalItem(item: 'Program identity approved'),
        ApprovalItem(item: 'Distribution plan and editorial calendar drafted'),
        ApprovalItem(item: 'Budget allocated by phase'),
        ApprovalItem(item: 'Planning stage signed off'),
      ];

  ApprovalItem copyWith({
    String? item,
    PlanningStepStatus? status,
    String? owner,
    String? notes,
  }) {
    return ApprovalItem(
      item: item ?? this.item,
      status: status ?? this.status,
      owner: owner ?? this.owner,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'item': item,
        'status': status.toStorageString(),
        'owner': owner,
        'notes': notes,
      };

  factory ApprovalItem.fromMap(Map<String, dynamic> map) {
    return ApprovalItem(
      item: map['item'] ?? '',
      status: PlanningStepStatus.fromString(map['status']),
      owner: map['owner'] ?? '',
      notes: map['notes'] ?? '',
    );
  }
}
