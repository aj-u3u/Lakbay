class PlanningFeedbackFinding {
  final String code;
  final String category;
  final String severity;
  final String message;
  final List<int> destinationIds;

  const PlanningFeedbackFinding({
    required this.code,
    required this.category,
    required this.severity,
    required this.message,
    required this.destinationIds,
  });

  factory PlanningFeedbackFinding.fromJson(Map<String, dynamic> json) {
    final code = json['code']?.toString() ?? '';
    final category = json['category']?.toString() ?? '';
    final severity = json['severity']?.toString() ?? '';
    final message = json['message']?.toString() ?? '';
    if (code.isEmpty ||
        category.isEmpty ||
        !{'required', 'review', 'info'}.contains(severity) ||
        message.isEmpty) {
      throw const FormatException('Planning feedback finding is incomplete.');
    }
    return PlanningFeedbackFinding(
      code: code,
      category: category,
      severity: severity,
      message: message,
      destinationIds: (json['destination_ids'] as List? ?? const [])
          .whereType<int>()
          .toList(),
    );
  }
}

class PlanningFeedback {
  final int inputRevision;
  final String status;
  final bool? travelingWithChildren;
  final List<PlanningFeedbackFinding> findings;

  const PlanningFeedback({
    required this.inputRevision,
    required this.status,
    required this.travelingWithChildren,
    required this.findings,
  });

  bool get needsDetails => status == 'needs_details';

  factory PlanningFeedback.fromJson(Map<String, dynamic> json) {
    final revision = json['input_revision'];
    final rawFindings = json['findings'];
    if (revision is! int ||
        rawFindings is! List ||
        rawFindings.any((item) => item is! Map) ||
        json['preview'] is! Map ||
        !{
          'needs_details',
          'needs_review',
          'no_flagged_issues',
        }.contains(json['status'])) {
      throw const FormatException('Planning feedback is incomplete.');
    }
    final findings = rawFindings
        .map(
          (item) => PlanningFeedbackFinding.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    final status = json['status'] as String;
    if ((findings.any((item) => item.severity == 'required') &&
            status != 'needs_details') ||
        (findings.any((item) => item.severity == 'review') &&
            status == 'no_flagged_issues')) {
      throw const FormatException('Planning feedback status is inconsistent.');
    }
    return PlanningFeedback(
      inputRevision: revision,
      status: status,
      travelingWithChildren: json['traveling_with_children'] as bool?,
      findings: findings,
    );
  }
}
