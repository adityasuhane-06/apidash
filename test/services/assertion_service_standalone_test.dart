import 'package:flutter_test/flutter_test.dart';
import 'package:apidash/models/assertion_model.dart';
import 'package:apidash/services/assertion_service.dart';

// Mock response model to avoid better_networking dependency
class MockHttpResponse {
  final int? statusCode;
  final Map<String, String>? headers;
  final String? body;
  final Duration? time;

  const MockHttpResponse({
    this.statusCode,
    this.headers,
    this.body,
    this.time,
  });
}

void main() {
  group('AssertionService - Standalone Tests', () {
    test('AssertionModel can be created', () {
      final assertion = AssertionModel(
        id: '1',
        name: 'Test Assertion',
        type: AssertionType.statusCode,
        path: 'statusCode',
        operator: AssertionOperator.equals,
        expectedValue: 200,
      );

      expect(assertion.id, '1');
      expect(assertion.name, 'Test Assertion');
      expect(assertion.type, AssertionType.statusCode);
      expect(assertion.operator, AssertionOperator.equals);
      expect(assertion.expectedValue, 200);
    });

    test('AssertionType enum has correct values', () {
      expect(AssertionType.values.length, 3);
      expect(AssertionType.values, contains(AssertionType.statusCode));
      expect(AssertionType.values, contains(AssertionType.responseTime));
      expect(AssertionType.values, contains(AssertionType.body));
    });

    test('AssertionOperator enum has correct values', () {
      expect(AssertionOperator.values.length, 4);
      expect(AssertionOperator.values, contains(AssertionOperator.equals));
      expect(AssertionOperator.values, contains(AssertionOperator.contains));
      expect(AssertionOperator.values, contains(AssertionOperator.greaterThan));
      expect(AssertionOperator.values, contains(AssertionOperator.lessThan));
    });

    test('AssertionResult can be created', () {
      final result = AssertionResult(
        assertionId: '1',
        passed: true,
        actualValue: 200,
        expectedValue: 200,
      );

      expect(result.assertionId, '1');
      expect(result.passed, true);
      expect(result.actualValue, 200);
      expect(result.expectedValue, 200);
      expect(result.errorMessage, isNull);
    });

    test('AssertionResult can include error message', () {
      final result = AssertionResult(
        assertionId: '1',
        passed: false,
        actualValue: 404,
        expectedValue: 200,
        errorMessage: 'Status code mismatch',
      );

      expect(result.passed, false);
      expect(result.errorMessage, 'Status code mismatch');
    });
  });
}
