import 'dart:convert';
import 'package:better_networking/better_networking.dart';
import '../models/assertion_model.dart';

/// Service for executing assertions against HTTP responses
class AssertionService {
  /// Execute a single assertion
  static AssertionResult executeAssertion(
    AssertionModel assertion,
    HttpResponseModel response,
  ) {
    try {
      final actualValue = _extractValue(assertion, response);
      final passed = _compareValues(
        actualValue,
        assertion.expectedValue,
        assertion.operator,
      );

      return AssertionResult(
        assertionId: assertion.id,
        passed: passed,
        actualValue: actualValue,
        expectedValue: assertion.expectedValue,
        errorMessage: passed ? null : _generateErrorMessage(assertion, actualValue),
      );
    } catch (e) {
      return AssertionResult(
        assertionId: assertion.id,
        passed: false,
        actualValue: null,
        expectedValue: assertion.expectedValue,
        errorMessage: 'Error: $e',
      );
    }
  }

  /// Execute multiple assertions
  static List<AssertionResult> executeAssertions(
    List<AssertionModel> assertions,
    HttpResponseModel response,
  ) {
    return assertions
        .where((a) => a.enabled)
        .map((a) => executeAssertion(a, response))
        .toList();
  }

  /// Extract value from response
  static dynamic _extractValue(
    AssertionModel assertion,
    HttpResponseModel response,
  ) {
    switch (assertion.type) {
      case AssertionType.statusCode:
        return response.statusCode;
      case AssertionType.responseTime:
        return response.time?.inMilliseconds;
      case AssertionType.body:
        if (assertion.path == 'body') {
          return response.body;
        }
        return _extractJsonPath(response.body, assertion.path);
    }
  }

  /// Extract JSON path
  static dynamic _extractJsonPath(String? jsonString, String path) {
    if (jsonString == null || jsonString.isEmpty) return null;

    try {
      dynamic data = jsonDecode(jsonString);
      final cleanPath = path.startsWith('body.') ? path.substring(5) : path;
      final segments = cleanPath.split('.');

      for (final segment in segments) {
        if (data == null) return null;

        // Handle array index
        if (segment.contains('[') && segment.contains(']')) {
          final arrayName = segment.substring(0, segment.indexOf('['));
          final indexStr = segment.substring(
            segment.indexOf('[') + 1,
            segment.indexOf(']'),
          );

          if (arrayName.isNotEmpty) {
            data = data[arrayName];
          }

          if (data is List) {
            final index = int.tryParse(indexStr);
            if (index != null && index < data.length) {
              data = data[index];
            } else {
              return null;
            }
          }
        } else {
          // Regular property
          if (data is Map) {
            data = data[segment];
          } else {
            return null;
          }
        }
      }

      return data;
    } catch (e) {
      return null;
    }
  }

  /// Compare values
  static bool _compareValues(
    dynamic actual,
    dynamic expected,
    AssertionOperator operator,
  ) {
    switch (operator) {
      case AssertionOperator.equals:
        return actual == expected;
      case AssertionOperator.contains:
        if (actual is String && expected is String) {
          return actual.contains(expected);
        }
        return false;
      case AssertionOperator.greaterThan:
        if (actual is num && expected is num) {
          return actual > expected;
        }
        return false;
      case AssertionOperator.lessThan:
        if (actual is num && expected is num) {
          return actual < expected;
        }
        return false;
    }
  }

  /// Generate error message
  static String _generateErrorMessage(
    AssertionModel assertion,
    dynamic actualValue,
  ) {
    final op = _operatorToText(assertion.operator);
    return 'Expected ${assertion.path} to $op ${assertion.expectedValue}, but got $actualValue';
  }

  /// Operator to text
  static String _operatorToText(AssertionOperator operator) {
    switch (operator) {
      case AssertionOperator.equals:
        return 'equal';
      case AssertionOperator.contains:
        return 'contain';
      case AssertionOperator.greaterThan:
        return 'be greater than';
      case AssertionOperator.lessThan:
        return 'be less than';
    }
  }
}
