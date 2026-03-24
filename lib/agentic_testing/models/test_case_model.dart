enum TestReviewDecision { pending, approved, rejected }

extension TestReviewDecisionLabel on TestReviewDecision {
  String get label {
    switch (this) {
      case TestReviewDecision.pending:
        return 'Pending';
      case TestReviewDecision.approved:
        return 'Approved';
      case TestReviewDecision.rejected:
        return 'Rejected';
    }
  }
}

enum TestExecutionStatus { notRun, passed, failed, skipped }

extension TestExecutionStatusLabel on TestExecutionStatus {
  String get label {
    switch (this) {
      case TestExecutionStatus.notRun:
        return 'Not Run';
      case TestExecutionStatus.passed:
        return 'Passed';
      case TestExecutionStatus.failed:
        return 'Failed';
      case TestExecutionStatus.skipped:
        return 'Skipped';
    }
  }
}

enum TestFailureType {
  none,
  networkError,
  statusCodeMismatch,
  bodyValidationFailed,
  responseTimeExceeded,
  unsupportedAssertion,
  unknown,
}

extension TestFailureTypeLabel on TestFailureType {
  String get label {
    switch (this) {
      case TestFailureType.none:
        return 'None';
      case TestFailureType.networkError:
        return 'Network Error';
      case TestFailureType.statusCodeMismatch:
        return 'Status Code Mismatch';
      case TestFailureType.bodyValidationFailed:
        return 'Body Validation Failed';
      case TestFailureType.responseTimeExceeded:
        return 'Response Time Exceeded';
      case TestFailureType.unsupportedAssertion:
        return 'Unsupported Assertion';
      case TestFailureType.unknown:
        return 'Unknown';
    }
  }

  String get code {
    switch (this) {
      case TestFailureType.none:
        return 'none';
      case TestFailureType.networkError:
        return 'network_error';
      case TestFailureType.statusCodeMismatch:
        return 'status_code_mismatch';
      case TestFailureType.bodyValidationFailed:
        return 'body_validation_failed';
      case TestFailureType.responseTimeExceeded:
        return 'response_time_exceeded';
      case TestFailureType.unsupportedAssertion:
        return 'unsupported_assertion';
      case TestFailureType.unknown:
        return 'unknown';
    }
  }
}

enum TestHealingDecision { none, pending, approved, rejected, applied }

extension TestHealingDecisionLabel on TestHealingDecision {
  String get label {
    switch (this) {
      case TestHealingDecision.none:
        return 'None';
      case TestHealingDecision.pending:
        return 'Pending';
      case TestHealingDecision.approved:
        return 'Approved';
      case TestHealingDecision.rejected:
        return 'Rejected';
      case TestHealingDecision.applied:
        return 'Applied';
    }
  }

  String get code {
    switch (this) {
      case TestHealingDecision.none:
        return 'none';
      case TestHealingDecision.pending:
        return 'pending';
      case TestHealingDecision.approved:
        return 'approved';
      case TestHealingDecision.rejected:
        return 'rejected';
      case TestHealingDecision.applied:
        return 'applied';
    }
  }
}

class AgenticTestCase {
  const AgenticTestCase({
    required this.id,
    required this.title,
    required this.description,
    required this.method,
    required this.endpoint,
    required this.expectedOutcome,
    required this.assertions,
    this.confidence,
    this.decision = TestReviewDecision.pending,
    this.executionStatus = TestExecutionStatus.notRun,
    this.executionSummary,
    this.assertionReport = const <String>[],
    this.responseStatusCode,
    this.responseTimeMs,
    this.failureType = TestFailureType.none,
    this.healingSuggestion,
    this.healingAssertions = const <String>[],
    this.healingDecision = TestHealingDecision.none,
    this.healingIteration = 0,
  });

  final String id;
  final String title;
  final String description;
  final String method;
  final String endpoint;
  final String expectedOutcome;
  final List<String> assertions;
  final double? confidence;
  final TestReviewDecision decision;
  final TestExecutionStatus executionStatus;
  final String? executionSummary;
  final List<String> assertionReport;
  final int? responseStatusCode;
  final int? responseTimeMs;
  final TestFailureType failureType;
  final String? healingSuggestion;
  final List<String> healingAssertions;
  final TestHealingDecision healingDecision;
  final int healingIteration;

  AgenticTestCase copyWith({
    String? id,
    String? title,
    String? description,
    String? method,
    String? endpoint,
    String? expectedOutcome,
    List<String>? assertions,
    double? confidence,
    TestReviewDecision? decision,
    TestExecutionStatus? executionStatus,
    String? executionSummary,
    List<String>? assertionReport,
    int? responseStatusCode,
    int? responseTimeMs,
    TestFailureType? failureType,
    String? healingSuggestion,
    List<String>? healingAssertions,
    TestHealingDecision? healingDecision,
    int? healingIteration,
    bool clearExecutionSummary = false,
    bool clearResponseStatusCode = false,
    bool clearResponseTimeMs = false,
    bool clearHealingSuggestion = false,
  }) {
    return AgenticTestCase(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      method: method ?? this.method,
      endpoint: endpoint ?? this.endpoint,
      expectedOutcome: expectedOutcome ?? this.expectedOutcome,
      assertions: assertions ?? this.assertions,
      confidence: confidence ?? this.confidence,
      decision: decision ?? this.decision,
      executionStatus: executionStatus ?? this.executionStatus,
      executionSummary: clearExecutionSummary
          ? null
          : (executionSummary ?? this.executionSummary),
      assertionReport: assertionReport ?? this.assertionReport,
      responseStatusCode: clearResponseStatusCode
          ? null
          : (responseStatusCode ?? this.responseStatusCode),
      responseTimeMs: clearResponseTimeMs
          ? null
          : (responseTimeMs ?? this.responseTimeMs),
      failureType: failureType ?? this.failureType,
      healingSuggestion: clearHealingSuggestion
          ? null
          : (healingSuggestion ?? this.healingSuggestion),
      healingAssertions: healingAssertions ?? this.healingAssertions,
      healingDecision: healingDecision ?? this.healingDecision,
      healingIteration: healingIteration ?? this.healingIteration,
    );
  }

  factory AgenticTestCase.fromJson(
    Map<String, dynamic> json, {
    required String fallbackId,
    required String fallbackEndpoint,
    required String fallbackMethod,
  }) {
    final assertionsRaw = json['assertions'];
    final assertions = assertionsRaw is List
        ? assertionsRaw
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : const <String>[];

    return AgenticTestCase(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? (json['id'] as String).trim()
          : fallbackId,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Generated test case',
      description: (json['description'] as String?)?.trim().isNotEmpty == true
          ? (json['description'] as String).trim()
          : 'No description provided.',
      method: (json['method'] as String?)?.trim().isNotEmpty == true
          ? (json['method'] as String).trim().toUpperCase()
          : fallbackMethod.toUpperCase(),
      endpoint: (json['endpoint'] as String?)?.trim().isNotEmpty == true
          ? (json['endpoint'] as String).trim()
          : fallbackEndpoint,
      expectedOutcome:
          (json['expected_outcome'] as String?)?.trim().isNotEmpty == true
          ? (json['expected_outcome'] as String).trim()
          : (json['expectedOutcome'] as String?)?.trim().isNotEmpty == true
          ? (json['expectedOutcome'] as String).trim()
          : 'Request behaves as expected.',
      assertions: assertions,
      confidence: _parseConfidence(json['confidence']),
      executionStatus: _parseExecutionStatus(json['execution_status']),
      executionSummary: (json['execution_summary'] as String?)?.trim(),
      assertionReport: _parseStringList(json['assertion_report']),
      responseStatusCode: _parseInt(json['response_status_code']),
      responseTimeMs: _parseInt(json['response_time_ms']),
      failureType: _parseFailureType(json['failure_type']),
      healingSuggestion: (json['healing_suggestion'] as String?)?.trim(),
      healingAssertions: _parseStringList(json['healing_assertions']),
      healingDecision: _parseHealingDecision(json['healing_decision']),
      healingIteration: _parseInt(json['healing_iteration']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'method': method,
      'endpoint': endpoint,
      'expected_outcome': expectedOutcome,
      'assertions': assertions,
      'confidence': confidence,
      'decision': decision.name,
      'execution_status': executionStatus.name,
      'execution_summary': executionSummary,
      'assertion_report': assertionReport,
      'response_status_code': responseStatusCode,
      'response_time_ms': responseTimeMs,
      'failure_type': failureType.code,
      'healing_suggestion': healingSuggestion,
      'healing_assertions': healingAssertions,
      'healing_decision': healingDecision.code,
      'healing_iteration': healingIteration,
    };
  }

  static TestExecutionStatus _parseExecutionStatus(dynamic value) {
    final raw = value?.toString().trim().toLowerCase();
    return TestExecutionStatus.values.firstWhere(
      (status) => status.name.toLowerCase() == raw,
      orElse: () => TestExecutionStatus.notRun,
    );
  }

  static TestFailureType _parseFailureType(dynamic value) {
    final raw = value?.toString().trim().toLowerCase();
    return switch (raw) {
      'none' => TestFailureType.none,
      'network_error' => TestFailureType.networkError,
      'status_code_mismatch' => TestFailureType.statusCodeMismatch,
      'body_validation_failed' => TestFailureType.bodyValidationFailed,
      'response_time_exceeded' => TestFailureType.responseTimeExceeded,
      'unsupported_assertion' => TestFailureType.unsupportedAssertion,
      'unknown' => TestFailureType.unknown,
      _ => TestFailureType.none,
    };
  }

  static TestHealingDecision _parseHealingDecision(dynamic value) {
    final raw = value?.toString().trim().toLowerCase();
    return switch (raw) {
      'none' => TestHealingDecision.none,
      'pending' => TestHealingDecision.pending,
      'approved' => TestHealingDecision.approved,
      'rejected' => TestHealingDecision.rejected,
      'applied' => TestHealingDecision.applied,
      _ => TestHealingDecision.none,
    };
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static double? _parseConfidence(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }
}
