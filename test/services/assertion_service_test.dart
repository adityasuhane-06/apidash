import 'package:flutter_test/flutter_test.dart';
import 'package:apidash/models/assertion_model.dart';
import 'package:apidash/services/assertion_service.dart';
import 'package:better_networking/better_networking.dart';

void main() {
  group('AssertionService', () {
    late HttpResponseModel mockResponse;

    setUp(() {
      mockResponse = const HttpResponseModel(
        statusCode: 200,
        headers: {'Content-Type': 'application/json'},
        body: '{"user": {"id": 101, "name": "John"}, "items": [{"id": 1, "price": 25.50}]}',
        time: Duration(milliseconds: 250),
      );
    });

    test('should validate status code equals', () {
      final assertion = AssertionModel(
        id: '1',
        name: 'Status is 200',
        type: AssertionType.statusCode,
        path: 'statusCode',
        operator: AssertionOperator.equals,
        expectedValue: 200,
      );

      final result = AssertionService.executeAssertion(assertion, mockResponse);

      expect(result.passed, true);
      expect(result.actualValue, 200);
    });

    test('should validate response time less than', () {
      final assertion = AssertionModel(
        id: '2',
        name: 'Response under 500ms',
        type: AssertionType.responseTime,
        path: 'responseTime',
        operator: AssertionOperator.lessThan,
        expectedValue: 500,
      );

      final result = AssertionService.executeAssertion(assertion, mockResponse);

      expect(result.passed, true);
      expect(result.actualValue, 250);
    });

    test('should extract nested JSON property', () {
      final assertion = AssertionModel(
        id: '3',
        name: 'User ID is 101',
        type: AssertionType.body,
        path: 'body.user.id',
        operator: AssertionOperator.equals,
        expectedValue: 101,
      );

      final result = AssertionService.executeAssertion(assertion, mockResponse);

      expect(result.passed, true);
      expect(result.actualValue, 101);
    });

    test('should extract array element', () {
      final assertion = AssertionModel(
        id: '4',
        name: 'First item price',
        type: AssertionType.body,
        path: 'body.items[0].price',
        operator: AssertionOperator.equals,
        expectedValue: 25.50,
      );

      final result = AssertionService.executeAssertion(assertion, mockResponse);

      expect(result.passed, true);
      expect(result.actualValue, 25.50);
    });

    test('should validate string contains', () {
      final assertion = AssertionModel(
        id: '5',
        name: 'Name contains John',
        type: AssertionType.body,
        path: 'body.user.name',
        operator: AssertionOperator.contains,
        expectedValue: 'John',
      );

      final result = AssertionService.executeAssertion(assertion, mockResponse);

      expect(result.passed, true);
    });

    test('should fail when assertion does not match', () {
      final assertion = AssertionModel(
        id: '6',
        name: 'Status is 404',
        type: AssertionType.statusCode,
        path: 'statusCode',
        operator: AssertionOperator.equals,
        expectedValue: 404,
      );

      final result = AssertionService.executeAssertion(assertion, mockResponse);

      expect(result.passed, false);
      expect(result.errorMessage, isNotNull);
    });

    test('should execute multiple assertions', () {
      final assertions = [
        const AssertionModel(
          id: '7',
          name: 'Status is 200',
          type: AssertionType.statusCode,
          path: 'statusCode',
          operator: AssertionOperator.equals,
          expectedValue: 200,
        ),
        const AssertionModel(
          id: '8',
          name: 'Response under 500ms',
          type: AssertionType.responseTime,
          path: 'responseTime',
          operator: AssertionOperator.lessThan,
          expectedValue: 500,
        ),
      ];

      final results = AssertionService.executeAssertions(assertions, mockResponse);

      expect(results.length, 2);
      expect(results.every((r) => r.passed), true);
    });
  });
}
