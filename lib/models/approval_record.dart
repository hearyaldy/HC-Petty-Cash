class ApprovalRecord {
  final String approverId;
  final String approverName;
  final DateTime timestamp;
  final String action; // 'approved' or 'rejected'
  final String? comments;

  ApprovalRecord({
    required this.approverId,
    required this.approverName,
    required this.timestamp,
    required this.action,
    this.comments,
  });

  Map<String, dynamic> toJson() {
    return {
      'approverId': approverId,
      'approverName': approverName,
      'timestamp': timestamp.toIso8601String(),
      'action': action,
      'comments': comments,
    };
  }

  factory ApprovalRecord.fromJson(Map<String, dynamic> json) {
    return ApprovalRecord(
      approverId: json['approverId'] as String,
      approverName: json['approverName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      action: json['action'] as String,
      comments: json['comments'] as String?,
    );
  }
}
