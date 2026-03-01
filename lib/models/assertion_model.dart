/// Types of assertions for API responses
enum AssertionType {
  statusCode,
  responseTime,
  body,
}

/// Comparison operators
enum AssertionOperator {
  equals,
  contains,
  greaterThan,
  lessThan,
}

/// Simple assertion model - MVP version
class AssertionModel {
  final String id;
  final String name;
  final AssertionType type;
  final String path;
  final AssertionOperator operator;
  final dynamic expectedValue;
  final bool enabled;

  const AssertionModel({
    required this.id,
    required this.name,
    required this.type,
    required this.path,
    required this.operator,
    required this.expectedValue,
    this.enabled = true,
  });
}

/// Assertion execution result
class AssertionResult {
  final String assertionId;
  final bool passed;
  final dynamic actualValue;
  final dynamic expectedValue;
  final String? errorMessage;

  const AssertionResult({
    required this.assertionId,
    required this.passed,
    required this.actualValue,
    required this.expectedValue,
    this.errorMessage,
  });
}
