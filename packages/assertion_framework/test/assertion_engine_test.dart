import 'package:flutter_test/flutter_test.dart';
import 'package:assertion_framework/assertion_framework.dart';

void main() {
  group('AssertionEngine - Status Code', () {
    test('should pass when status code equals expected', () {
      final assertion = Assertion(
        id: '1',
        name: 'Status is 200',
        type: AssertionType.statusCode,
        path: 'statusCode',
        operator: AssertionOperator.equals,
        expectedValue: 200,
      );

      final response = HttpResponse(statusCode: 200);
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
      expect(result.actualValue, 200);
    });

    test('should fail when status code does not match', () {
      final assertion = Assertion(
        id: '2',
        name: 'Status is 200',
        type: AssertionType.statusCode,
        path: 'statusCode',
        operator: AssertionOperator.equals,
        expectedValue: 200,
      );

      final response = HttpResponse(statusCode: 404);
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, false);
      expect(result.actualValue, 404);
      expect(result.errorMessage, contains('404'));
    });
  });

  group('AssertionEngine - Response Time', () {
    test('should pass when response time is less than threshold', () {
      final assertion = Assertion(
        id: '3',
        name: 'Response under 500ms',
        type: AssertionType.responseTime,
        path: 'responseTime',
        operator: AssertionOperator.lessThan,
        expectedValue: 500,
      );

      final response = HttpResponse(responseTime: Duration(milliseconds: 300));
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
      expect(result.actualValue, 300);
    });

    test('should fail when response time exceeds threshold', () {
      final assertion = Assertion(
        id: '4',
        name: 'Response under 500ms',
        type: AssertionType.responseTime,
        path: 'responseTime',
        operator: AssertionOperator.lessThan,
        expectedValue: 500,
      );

      final response = HttpResponse(responseTime: Duration(milliseconds: 800));
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, false);
      expect(result.actualValue, 800);
    });
  });

  group('AssertionEngine - JSON Body', () {
    test('should extract simple JSON property', () {
      final assertion = Assertion(
        id: '5',
        name: 'User ID is 123',
        type: AssertionType.bodyJson,
        path: 'userId',
        operator: AssertionOperator.equals,
        expectedValue: 123,
      );

      final response = HttpResponse(body: '{"userId": 123, "name": "John"}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
      expect(result.actualValue, 123);
    });

    test('should extract nested JSON property', () {
      final assertion = Assertion(
        id: '6',
        name: 'User name is John',
        type: AssertionType.bodyJson,
        path: 'user.name',
        operator: AssertionOperator.equals,
        expectedValue: 'John',
      );

      final response = HttpResponse(
        body: '{"user": {"name": "John", "age": 30}}',
      );
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
      expect(result.actualValue, 'John');
    });

    test('should extract array element', () {
      final assertion = Assertion(
        id: '7',
        name: 'First item price is 29.99',
        type: AssertionType.bodyJson,
        path: 'items[0].price',
        operator: AssertionOperator.equals,
        expectedValue: 29.99,
      );

      final response = HttpResponse(
        body: '{"items": [{"price": 29.99}, {"price": 39.99}]}',
      );
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
      expect(result.actualValue, 29.99);
    });

    test('should handle body prefix in path', () {
      final assertion = Assertion(
        id: '8',
        name: 'Status is success',
        type: AssertionType.bodyJson,
        path: 'body.status',
        operator: AssertionOperator.equals,
        expectedValue: 'success',
      );

      final response = HttpResponse(body: '{"status": "success"}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
      expect(result.actualValue, 'success');
    });

    test('should handle contains operator for strings', () {
      final assertion = Assertion(
        id: '9',
        name: 'Message contains error',
        type: AssertionType.bodyJson,
        path: 'message',
        operator: AssertionOperator.contains,
        expectedValue: 'error',
      );

      final response = HttpResponse(body: '{"message": "An error occurred"}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });

    test('should return null for invalid JSON path', () {
      final assertion = Assertion(
        id: '10',
        name: 'Invalid path',
        type: AssertionType.bodyJson,
        path: 'nonexistent.path',
        operator: AssertionOperator.equals,
        expectedValue: 'value',
      );

      final response = HttpResponse(body: '{"status": "ok"}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, false);
      expect(result.actualValue, null);
    });
  });

  group('AssertionEngine - Headers', () {
    test('should validate header value', () {
      final assertion = Assertion(
        id: '11',
        name: 'Content-Type is JSON',
        type: AssertionType.header,
        path: 'content-type',
        operator: AssertionOperator.contains,
        expectedValue: 'application/json',
      );

      final response = HttpResponse(
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });
  });

  group('AssertionEngine - Batch Execution', () {
    test('should execute multiple assertions', () {
      final assertions = [
        Assertion(
          id: '1',
          name: 'Status is 200',
          type: AssertionType.statusCode,
          path: 'statusCode',
          operator: AssertionOperator.equals,
          expectedValue: 200,
        ),
        Assertion(
          id: '2',
          name: 'Response under 1000ms',
          type: AssertionType.responseTime,
          path: 'responseTime',
          operator: AssertionOperator.lessThan,
          expectedValue: 1000,
        ),
        Assertion(
          id: '3',
          name: 'User ID exists',
          type: AssertionType.bodyJson,
          path: 'userId',
          operator: AssertionOperator.exists,
          expectedValue: null,
        ),
      ];

      final response = HttpResponse(
        statusCode: 200,
        responseTime: Duration(milliseconds: 500),
        body: '{"userId": 123}',
      );

      final results = AssertionEngine.executeAll(assertions, response);

      expect(results.length, 3);
      expect(results.every((r) => r.passed), true);
    });

    test('should skip disabled assertions', () {
      final assertions = [
        Assertion(
          id: '1',
          name: 'Enabled assertion',
          type: AssertionType.statusCode,
          path: 'statusCode',
          operator: AssertionOperator.equals,
          expectedValue: 200,
          enabled: true,
        ),
        Assertion(
          id: '2',
          name: 'Disabled assertion',
          type: AssertionType.statusCode,
          path: 'statusCode',
          operator: AssertionOperator.equals,
          expectedValue: 404,
          enabled: false,
        ),
      ];

      final response = HttpResponse(statusCode: 200);
      final results = AssertionEngine.executeAll(assertions, response);

      expect(results.length, 1);
      expect(results.first.assertionId, '1');
    });
  });

  group('AssertionEngine - Advanced Operators', () {
    test('should handle notEquals operator', () {
      final assertion = Assertion(
        id: '1',
        name: 'Status is not 404',
        type: AssertionType.statusCode,
        path: 'statusCode',
        operator: AssertionOperator.notEquals,
        expectedValue: 404,
      );

      final response = HttpResponse(statusCode: 200);
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });

    test('should handle greaterThanOrEqual operator', () {
      final assertion = Assertion(
        id: '2',
        name: 'Status >= 200',
        type: AssertionType.statusCode,
        path: 'statusCode',
        operator: AssertionOperator.greaterThanOrEqual,
        expectedValue: 200,
      );

      final response = HttpResponse(statusCode: 200);
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });

    test('should handle exists operator', () {
      final assertion = Assertion(
        id: '3',
        name: 'User name exists',
        type: AssertionType.bodyJson,
        path: 'user.name',
        operator: AssertionOperator.exists,
        expectedValue: null,
      );

      final response = HttpResponse(body: '{"user": {"name": "John"}}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });

    test('should handle notExists operator', () {
      final assertion = Assertion(
        id: '4',
        name: 'Error should not exist',
        type: AssertionType.bodyJson,
        path: 'error',
        operator: AssertionOperator.notExists,
        expectedValue: null,
      );

      final response = HttpResponse(body: '{"status": "ok"}');
      final result = AssertionEngine.execute(assertion, response);

      expect(result.passed, true);
    });
  });
}
