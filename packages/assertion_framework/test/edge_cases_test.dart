import 'package:flutter_test/flutter_test.dart';
import 'package:assertion_framework/assertion_framework.dart';

void main() {
  group('Edge Cases - Null and Empty Values', () {
    test('should handle null response body', () {
      final assertion = Assertion(
        id: '1',
        name: 'Body should not exist',
        type: AssertionType.bodyJson,
        path: 'data',
        operator: AssertionOperator.notExists,
        expectedValue: null,
      );

      final response = HttpResponse(body: null);
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });

    test('should handle empty JSON object', () {
      final assertion = Assertion(
        id: '2',
        name: 'Field should not exist',
        type: AssertionType.bodyJson,
        path: 'nonexistent',
        operator: AssertionOperator.notExists,
        expectedValue: null,
      );

      final response = HttpResponse(body: '{}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });

    test('should handle empty string body', () {
      final assertion = Assertion(
        id: '3',
        name: 'Body is empty',
        type: AssertionType.bodyText,
        path: 'body',
        operator: AssertionOperator.equals,
        expectedValue: '',
      );

      final response = HttpResponse(body: '');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });

    test('should handle null status code', () {
      final assertion = Assertion(
        id: '4',
        name: 'Status code should not exist',
        type: AssertionType.statusCode,
        path: 'statusCode',
        operator: AssertionOperator.notExists,
        expectedValue: null,
      );

      final response = HttpResponse(statusCode: null);
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });

    test('should handle null response time', () {
      final assertion = Assertion(
        id: '5',
        name: 'Response time should not exist',
        type: AssertionType.responseTime,
        path: 'responseTime',
        operator: AssertionOperator.notExists,
        expectedValue: null,
      );

      final response = HttpResponse(responseTime: null);
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });
  });

  group('Edge Cases - Invalid JSON', () {
    test('should handle malformed JSON gracefully', () {
      final assertion = Assertion(
        id: '6',
        name: 'Extract from invalid JSON',
        type: AssertionType.bodyJson,
        path: 'user.name',
        operator: AssertionOperator.equals,
        expectedValue: 'John',
      );

      final response = HttpResponse(body: '{invalid json}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, false);
      expect(result.actualValue, null);
    });

    test('should handle incomplete JSON', () {
      final assertion = Assertion(
        id: '7',
        name: 'Extract from incomplete JSON',
        type: AssertionType.bodyJson,
        path: 'data',
        operator: AssertionOperator.exists,
        expectedValue: null,
      );

      final response = HttpResponse(body: '{"data":');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, false);
    });
  });

  group('Edge Cases - Array Boundaries', () {
    test('should handle negative array index', () {
      final assertion = Assertion(
        id: '8',
        name: 'Negative index',
        type: AssertionType.bodyJson,
        path: 'items[-1]',
        operator: AssertionOperator.exists,
        expectedValue: null,
      );

      final response = HttpResponse(body: '{"items": [1, 2, 3]}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, false);
      expect(result.actualValue, null);
    });

    test('should handle out of bounds array index', () {
      final assertion = Assertion(
        id: '9',
        name: 'Out of bounds',
        type: AssertionType.bodyJson,
        path: 'items[10]',
        operator: AssertionOperator.exists,
        expectedValue: null,
      );

      final response = HttpResponse(body: '{"items": [1, 2, 3]}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, false);
      expect(result.actualValue, null);
    });

    test('should handle empty array', () {
      final assertion = Assertion(
        id: '10',
        name: 'Empty array access',
        type: AssertionType.bodyJson,
        path: 'items[0]',
        operator: AssertionOperator.exists,
        expectedValue: null,
      );

      final response = HttpResponse(body: '{"items": []}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, false);
    });

    test('should handle non-numeric array index', () {
      final assertion = Assertion(
        id: '11',
        name: 'Non-numeric index',
        type: AssertionType.bodyJson,
        path: 'items[abc]',
        operator: AssertionOperator.exists,
        expectedValue: null,
      );

      final response = HttpResponse(body: '{"items": [1, 2, 3]}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, false);
    });
  });

  group('Edge Cases - Deep Nesting', () {
    test('should handle deeply nested paths', () {
      final assertion = Assertion(
        id: '12',
        name: 'Deep nesting',
        type: AssertionType.bodyJson,
        path: 'level1.level2.level3.level4.value',
        operator: AssertionOperator.equals,
        expectedValue: 'deep',
      );

      final response = HttpResponse(
        body: '{"level1": {"level2": {"level3": {"level4": {"value": "deep"}}}}}',
      );
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });

    test('should handle broken path in deep nesting', () {
      final assertion = Assertion(
        id: '13',
        name: 'Broken deep path',
        type: AssertionType.bodyJson,
        path: 'level1.level2.missing.level4.value',
        operator: AssertionOperator.exists,
        expectedValue: null,
      );

      final response = HttpResponse(
        body: '{"level1": {"level2": {"level3": {"level4": {"value": "deep"}}}}}',
      );
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, false);
    });
  });

  group('Edge Cases - Special Characters', () {
    test('should handle special characters in JSON values', () {
      final assertion = Assertion(
        id: '14',
        name: 'Special chars',
        type: AssertionType.bodyJson,
        path: 'message',
        operator: AssertionOperator.contains,
        expectedValue: '\n',
      );

      final response = HttpResponse(body: '{"message": "Line 1\\nLine 2"}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });

    test('should handle unicode characters', () {
      final assertion = Assertion(
        id: '15',
        name: 'Unicode',
        type: AssertionType.bodyJson,
        path: 'name',
        operator: AssertionOperator.equals,
        expectedValue: '日本語',
      );

      final response = HttpResponse(body: '{"name": "日本語"}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });
  });

  group('Edge Cases - Type Mismatches', () {
    test('should handle comparing number to string', () {
      final assertion = Assertion(
        id: '16',
        name: 'Number vs string',
        type: AssertionType.bodyJson,
        path: 'id',
        operator: AssertionOperator.equals,
        expectedValue: '123',
      );

      final response = HttpResponse(body: '{"id": 123}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, false); // 123 != "123"
    });

    test('should handle boolean values', () {
      final assertion = Assertion(
        id: '17',
        name: 'Boolean check',
        type: AssertionType.bodyJson,
        path: 'active',
        operator: AssertionOperator.equals,
        expectedValue: true,
      );

      final response = HttpResponse(body: '{"active": true}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });

    test('should handle null values in JSON', () {
      final assertion = Assertion(
        id: '18',
        name: 'Null value',
        type: AssertionType.bodyJson,
        path: 'data',
        operator: AssertionOperator.equals,
        expectedValue: null,
      );

      final response = HttpResponse(body: '{"data": null}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });
  });

  group('Edge Cases - Complex Scenarios', () {
    test('should handle mixed array and object navigation', () {
      final assertion = Assertion(
        id: '19',
        name: 'Mixed navigation',
        type: AssertionType.bodyJson,
        path: 'users[0].orders[1].items[0].name',
        operator: AssertionOperator.equals,
        expectedValue: 'Product A',
      );

      final response = HttpResponse(
        body: '''
        {
          "users": [
            {
              "orders": [
                {"id": 1},
                {
                  "items": [
                    {"name": "Product A"},
                    {"name": "Product B"}
                  ]
                }
              ]
            }
          ]
        }
        ''',
      );
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });

    test('should handle array of primitives', () {
      final assertion = Assertion(
        id: '20',
        name: 'Array of numbers',
        type: AssertionType.bodyJson,
        path: 'scores[2]',
        operator: AssertionOperator.equals,
        expectedValue: 95,
      );

      final response = HttpResponse(body: '{"scores": [85, 90, 95, 100]}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });
  });

  group('Edge Cases - Disabled Assertions', () {
    test('should skip disabled assertions in batch', () {
      final assertions = [
        Assertion(
          id: '1',
          name: 'Enabled',
          type: AssertionType.statusCode,
          path: 'statusCode',
          operator: AssertionOperator.equals,
          expectedValue: 200,
          enabled: true,
        ),
        Assertion(
          id: '2',
          name: 'Disabled - should fail',
          type: AssertionType.statusCode,
          path: 'statusCode',
          operator: AssertionOperator.equals,
          expectedValue: 404,
          enabled: false,
        ),
        Assertion(
          id: '3',
          name: 'Enabled',
          type: AssertionType.statusCode,
          path: 'statusCode',
          operator: AssertionOperator.greaterThan,
          expectedValue: 100,
          enabled: true,
        ),
      ];

      final response = HttpResponse(statusCode: 200);
      final results = AssertionEngine.executeAll(assertions, response);

      expect(results.length, 2); // Only enabled ones
      expect(results.every((r) => r.passed), true);
      expect(results.any((r) => r.assertionId == '2'), false);
    });
  });
}
