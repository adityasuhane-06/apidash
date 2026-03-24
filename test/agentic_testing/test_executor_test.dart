import 'package:apidash/agentic_testing/agentic_testing.dart';
import 'package:apidash_core/apidash_core.dart';
import 'package:test/test.dart';

AgenticTestCase _approvedTestCase({
  List<String> assertions = const <String>['status_code equals 200'],
}) {
  return AgenticTestCase(
    id: 't1',
    title: 'Executor test',
    description: 'executor classification test',
    method: 'GET',
    endpoint: 'https://api.apidash.dev/users',
    expectedOutcome: 'Expected behavior',
    assertions: assertions,
    decision: TestReviewDecision.approved,
  );
}

void main() {
  group('AgenticTestExecutor', () {
    test('classifies network errors', () async {
      final executor = AgenticTestExecutor(
        executeHttpRequest: (requestId, apiType, requestModel) async {
          return (null, null, 'timeout');
        },
      );

      final results = await executor.executeTests(
        tests: <AgenticTestCase>[_approvedTestCase()],
        defaultHeaders: const <String, String>{},
      );

      expect(results.single.executionStatus, TestExecutionStatus.failed);
      expect(results.single.failureType, TestFailureType.networkError);
    });

    test('classifies status code mismatch', () async {
      final executor = AgenticTestExecutor(
        executeHttpRequest: (requestId, apiType, requestModel) async {
          return (Response('[]', 500), const Duration(milliseconds: 120), null);
        },
      );

      final results = await executor.executeTests(
        tests: <AgenticTestCase>[
          _approvedTestCase(assertions: const <String>['status code 200']),
        ],
        defaultHeaders: const <String, String>{},
      );

      expect(results.single.executionStatus, TestExecutionStatus.failed);
      expect(results.single.failureType, TestFailureType.statusCodeMismatch);
    });

    test('classifies body validation failures', () async {
      final executor = AgenticTestExecutor(
        executeHttpRequest: (requestId, apiType, requestModel) async {
          return (
            Response('{"ok":true}', 200),
            const Duration(milliseconds: 90),
            null,
          );
        },
      );

      final results = await executor.executeTests(
        tests: <AgenticTestCase>[
          _approvedTestCase(
            assertions: const <String>['response body is an array'],
          ),
        ],
        defaultHeaders: const <String, String>{},
      );

      expect(results.single.executionStatus, TestExecutionStatus.failed);
      expect(results.single.failureType, TestFailureType.bodyValidationFailed);
    });

    test('classifies response-time failures', () async {
      final executor = AgenticTestExecutor(
        executeHttpRequest: (requestId, apiType, requestModel) async {
          return (
            Response('[]', 200),
            const Duration(milliseconds: 1200),
            null,
          );
        },
      );

      final results = await executor.executeTests(
        tests: <AgenticTestCase>[
          _approvedTestCase(
            assertions: const <String>['response time less than 800ms'],
          ),
        ],
        defaultHeaders: const <String, String>{},
      );

      expect(results.single.executionStatus, TestExecutionStatus.failed);
      expect(results.single.failureType, TestFailureType.responseTimeExceeded);
    });

    test('classifies unsupported assertions as skipped', () async {
      final executor = AgenticTestExecutor(
        executeHttpRequest: (requestId, apiType, requestModel) async {
          return (Response('[]', 200), const Duration(milliseconds: 50), null);
        },
      );

      final results = await executor.executeTests(
        tests: <AgenticTestCase>[
          _approvedTestCase(
            assertions: const <String>['database index should exist'],
          ),
        ],
        defaultHeaders: const <String, String>{},
      );

      expect(results.single.executionStatus, TestExecutionStatus.skipped);
      expect(results.single.failureType, TestFailureType.unsupportedAssertion);
    });

    test('marks passing assertions with no failure type', () async {
      final executor = AgenticTestExecutor(
        executeHttpRequest: (requestId, apiType, requestModel) async {
          return (Response('[]', 200), const Duration(milliseconds: 60), null);
        },
      );

      final results = await executor.executeTests(
        tests: <AgenticTestCase>[
          _approvedTestCase(assertions: const <String>['status code 200']),
        ],
        defaultHeaders: const <String, String>{},
      );

      expect(results.single.executionStatus, TestExecutionStatus.passed);
      expect(results.single.failureType, TestFailureType.none);
    });
  });
}
