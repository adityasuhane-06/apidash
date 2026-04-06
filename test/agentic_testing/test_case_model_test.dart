import 'package:apidash/agentic_testing/agentic_testing.dart';
import 'package:test/test.dart';

void main() {
  group('AgenticTestCase.fromJson', () {
    test('parses decision from decision key', () {
      final testCase = AgenticTestCase.fromJson(
        <String, dynamic>{
          'id': 't1',
          'title': 'Status test',
          'description': 'desc',
          'method': 'GET',
          'endpoint': 'https://api.apidash.dev/users/1',
          'expected_outcome': 'status ok',
          'assertions': <String>['status code is 200'],
          'decision': 'approved',
        },
        fallbackId: 'fallback',
        fallbackEndpoint: 'https://api.apidash.dev/users/1',
        fallbackMethod: 'GET',
      );

      expect(testCase.decision, TestReviewDecision.approved);
    });

    test('parses decision from review_decision key for compatibility', () {
      final testCase = AgenticTestCase.fromJson(
        <String, dynamic>{
          'id': 't2',
          'title': 'Body test',
          'description': 'desc',
          'method': 'GET',
          'endpoint': 'https://api.apidash.dev/users/1',
          'expected_outcome': 'body ok',
          'assertions': <String>['response body is valid json'],
          'review_decision': 'rejected',
        },
        fallbackId: 'fallback',
        fallbackEndpoint: 'https://api.apidash.dev/users/1',
        fallbackMethod: 'GET',
      );

      expect(testCase.decision, TestReviewDecision.rejected);
    });
  });
}
