// Assertion Types
enum AssertionType {
  statusCode,
  responseTime,
  bodyJson,
  bodyText,
  header,
}

// Assertion Operators
enum AssertionOperator {
  equals,
  notEquals,
  greaterThan,
  lessThan,
  greaterThanOrEqual,
  lessThanOrEqual,
  contains,
  notContains,
  exists,
  notExists,
}

// Assertion Model
class Assertion {
  final String id;
  final String name;
  final AssertionType type;
  final String path;
  final AssertionOperator operator;
  final dynamic expectedValue;
  final bool enabled;

  Assertion({
    required this.id,
    required this.name,
    required this.type,
    required this.path,
    required this.operator,
    this.expectedValue,
    this.enabled = true,
  });
}

// HTTP Response Model
class HttpResponse {
  final int? statusCode;
  final String? body;
  final Duration? responseTime;
  final Map<String, String>? headers;

  HttpResponse({
    this.statusCode,
    this.body,
    this.responseTime,
    this.headers,
  });
}

// Assertion Result Model
class AssertionResult {
  final String assertionId;
  final String assertionName;
  final bool passed;
  final dynamic actualValue;
  final dynamic expectedValue;
  final String? errorMessage;

  AssertionResult({
    required this.assertionId,
    required this.assertionName,
    required this.passed,
    this.actualValue,
    this.expectedValue,
    this.errorMessage,
  });
}
