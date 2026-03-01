import 'dart:convert';
import 'models.dart';

class AssertionEngine {
  static AssertionResult execute(Assertion assertion, HttpResponse response) {
    try {
      final actualValue = _extractValue(assertion, response);
      final passed = _evaluateAssertion(assertion.operator, actualValue, assertion.expectedValue);

      return AssertionResult(
        assertionId: assertion.id,
        assertionName: assertion.name,
        passed: passed,
        actualValue: actualValue,
        expectedValue: assertion.expectedValue,
        errorMessage: passed
            ? null
            : 'Expected ${assertion.path} ${assertion.operator.name} ${assertion.expectedValue}, got $actualValue',
      );
    } catch (e) {
      return AssertionResult(
        assertionId: assertion.id,
        assertionName: assertion.name,
        passed: false,
        actualValue: null,
        expectedValue: assertion.expectedValue,
        errorMessage: e.toString(),
      );
    }
  }

  static List<AssertionResult> executeAll(List<Assertion> assertions, HttpResponse response) {
    return assertions
        .where((assertion) => assertion.enabled)
        .map((assertion) => execute(assertion, response))
        .toList();
  }

  static dynamic _extractValue(Assertion assertion, HttpResponse response) {
    switch (assertion.type) {
      case AssertionType.statusCode:
        return response.statusCode;
      case AssertionType.responseTime:
        return response.responseTime?.inMilliseconds;
      case AssertionType.bodyText:
        return response.body;
      case AssertionType.bodyJson:
        return _extractJsonPath(response.body, assertion.path);
      case AssertionType.header:
        return response.headers?[assertion.path];
    }
  }

  static dynamic _extractJsonPath(String? body, String path) {
    if (body == null) return null;
    
    try {
      final json = jsonDecode(body);
      return _navigatePath(json, path);
    } catch (e) {
      return null;
    }
  }

  static dynamic _navigatePath(dynamic data, String path) {
    if (path == 'body') return data;
    if (path.startsWith('body.')) {
      path = path.substring(5);
    }
    
    final parts = _parsePath(path);
    dynamic current = data;

    for (final part in parts) {
      if (current == null) return null;

      if (part.isArray) {
        if (current is! List) return null;
        if (part.index! < 0 || part.index! >= current.length) return null;
        current = current[part.index!];
      } else {
        if (current is! Map) return null;
        current = current[part.key];
      }
    }

    return current;
  }

  static List<_PathPart> _parsePath(String path) {
    final parts = <_PathPart>[];
    final segments = path.split('.');

    for (final segment in segments) {
      final arrayMatch = RegExp(r'^(.+)\[(\d+)\]$').firstMatch(segment);
      if (arrayMatch != null) {
        parts.add(_PathPart(key: arrayMatch.group(1)!, isArray: false));
        parts.add(_PathPart(index: int.parse(arrayMatch.group(2)!), isArray: true));
      } else {
        parts.add(_PathPart(key: segment, isArray: false));
      }
    }

    return parts;
  }

  static bool _evaluateAssertion(AssertionOperator operator, dynamic actual, dynamic expected) {
    switch (operator) {
      case AssertionOperator.equals:
        return actual == expected;
      case AssertionOperator.notEquals:
        return actual != expected;
      case AssertionOperator.greaterThan:
        return actual != null && expected != null && actual > expected;
      case AssertionOperator.lessThan:
        return actual != null && expected != null && actual < expected;
      case AssertionOperator.greaterThanOrEqual:
        return actual != null && expected != null && actual >= expected;
      case AssertionOperator.lessThanOrEqual:
        return actual != null && expected != null && actual <= expected;
      case AssertionOperator.contains:
        return actual != null && actual.toString().contains(expected.toString());
      case AssertionOperator.notContains:
        return actual != null && !actual.toString().contains(expected.toString());
      case AssertionOperator.exists:
        return actual != null;
      case AssertionOperator.notExists:
        return actual == null;
    }
  }
}

class _PathPart {
  final String? key;
  final int? index;
  final bool isArray;

  _PathPart({this.key, this.index, required this.isArray});
}
