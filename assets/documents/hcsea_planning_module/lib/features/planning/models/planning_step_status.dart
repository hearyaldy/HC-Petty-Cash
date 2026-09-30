/// Status of a single Planning step (Workflow HC, Stage 1).
///
/// Mirrors the "Status" column used in the Pre-production Approval
/// Checklist table in Workflow HC, so the same three states can be
/// reused for both the Planning approvals list and any later stage.
enum PlanningStepStatus {
  notStarted,
  inProgress,
  complete;

  String get label {
    switch (this) {
      case PlanningStepStatus.notStarted:
        return 'Not started';
      case PlanningStepStatus.inProgress:
        return 'In progress';
      case PlanningStepStatus.complete:
        return 'Complete';
    }
  }

  static PlanningStepStatus fromString(String? value) {
    switch (value) {
      case 'inProgress':
        return PlanningStepStatus.inProgress;
      case 'complete':
        return PlanningStepStatus.complete;
      default:
        return PlanningStepStatus.notStarted;
    }
  }

  String toStorageString() => name;
}
