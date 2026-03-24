import '../models/test_case_model.dart';

class AgenticTestHealingPlanner {
  const AgenticTestHealingPlanner();

  List<AgenticTestCase> generateHealingPlans({
    required List<AgenticTestCase> tests,
  }) {
    return tests.map(_planForTest).toList();
  }

  AgenticTestCase _planForTest(AgenticTestCase testCase) {
    if (testCase.executionStatus != TestExecutionStatus.failed) {
      return testCase.copyWith(
        healingDecision: TestHealingDecision.none,
        clearHealingSuggestion: true,
        healingAssertions: const <String>[],
      );
    }

    final plan = _buildPlan(testCase);
    return testCase.copyWith(
      healingSuggestion: plan.$1,
      healingAssertions: plan.$2,
      healingDecision: TestHealingDecision.pending,
    );
  }

  (String, List<String>) _buildPlan(AgenticTestCase testCase) {
    switch (testCase.failureType) {
      case TestFailureType.networkError:
        return (
          'Transient network failure detected. Retry this test once with the same assertions.',
          testCase.assertions,
        );
      case TestFailureType.statusCodeMismatch:
        final code = testCase.responseStatusCode;
        final statusAssertion = code == null
            ? 'status code is in 2xx range'
            : 'status code equals $code';
        return (
          'Update status assertion to align with observed response and re-run for confirmation.',
          _replaceStatusAssertions(testCase.assertions, statusAssertion),
        );
      case TestFailureType.bodyValidationFailed:
        return (
          'Body shape mismatch detected. Use JSON/body assertions that match the observed payload.',
          _replaceBodyAssertions(testCase.assertions, const <String>[
            'response body is json',
            'response body is not empty',
          ]),
        );
      case TestFailureType.responseTimeExceeded:
        final newThreshold = _getRelaxedThreshold(testCase);
        return (
          'Response time threshold appears too strict for current environment. Retry with a relaxed limit.',
          _replaceTimeAssertions(
            testCase.assertions,
            'response time less than ${newThreshold}ms',
          ),
        );
      case TestFailureType.unsupportedAssertion:
        final statusCode = testCase.responseStatusCode ?? 200;
        return (
          'Assertion could not be auto-verified. Replace with baseline, executable assertions.',
          <String>['status code equals $statusCode', 'response body is json'],
        );
      case TestFailureType.unknown:
      case TestFailureType.none:
        return (
          'Failure reason is ambiguous. Retry with baseline checks to gather clearer diagnostics.',
          <String>['status code is in 2xx range', 'response body is not empty'],
        );
    }
  }

  List<String> _replaceStatusAssertions(
    List<String> original,
    String statusAssertion,
  ) {
    final nonStatus = original
        .where((item) => !_isStatusAssertion(item.toLowerCase()))
        .toList();
    return <String>[statusAssertion, ...nonStatus];
  }

  List<String> _replaceBodyAssertions(
    List<String> original,
    List<String> replacement,
  ) {
    final nonBody = original
        .where((item) => !_isBodyAssertion(item.toLowerCase()))
        .toList();
    return <String>[...replacement, ...nonBody];
  }

  List<String> _replaceTimeAssertions(
    List<String> original,
    String replacement,
  ) {
    final nonTime = original
        .where((item) => !_isTimeAssertion(item.toLowerCase()))
        .toList();
    return <String>[replacement, ...nonTime];
  }

  bool _isStatusAssertion(String normalized) {
    return normalized.contains('status') || normalized.contains('status_code');
  }

  bool _isBodyAssertion(String normalized) {
    return normalized.contains('body') ||
        normalized.contains('json') ||
        normalized.contains('array') ||
        normalized.contains('object');
  }

  bool _isTimeAssertion(String normalized) {
    return normalized.contains('response time') ||
        normalized.contains('latency') ||
        normalized.contains('ms');
  }

  int _getRelaxedThreshold(AgenticTestCase testCase) {
    final measured = testCase.responseTimeMs ?? 1000;
    final relaxed = (measured * 1.25).round();
    return relaxed < 300 ? 300 : relaxed;
  }
}
