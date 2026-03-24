import 'dart:convert';

import 'package:apidash_core/apidash_core.dart';

import '../models/test_case_model.dart';

enum _AssertionResultType { passed, failed, skipped }

class _AssertionEvaluation {
  const _AssertionEvaluation({required this.type, required this.message});

  final _AssertionResultType type;
  final String message;
}

class AgenticTestExecutor {
  const AgenticTestExecutor();

  Future<List<AgenticTestCase>> executeTests({
    required List<AgenticTestCase> tests,
    required Map<String, String> defaultHeaders,
    String? requestBody,
  }) async {
    final executed = <AgenticTestCase>[];
    for (final testCase in tests) {
      if (testCase.decision != TestReviewDecision.approved) {
        executed.add(
          testCase.copyWith(
            executionStatus: TestExecutionStatus.skipped,
            executionSummary: 'Skipped because test is not approved.',
            assertionReport: const <String>[],
            clearResponseStatusCode: true,
            clearResponseTimeMs: true,
          ),
        );
        continue;
      }

      final requestModel = _buildRequestModel(
        testCase: testCase,
        defaultHeaders: defaultHeaders,
        requestBody: requestBody,
      );

      final requestId = 'agentic_test_${DateTime.now().microsecondsSinceEpoch}';
      final (response, duration, errorMessage) = await sendHttpRequest(
        requestId,
        APIType.rest,
        requestModel,
      );

      if (response == null) {
        executed.add(
          testCase.copyWith(
            executionStatus: TestExecutionStatus.failed,
            executionSummary:
                'Execution failed: ${errorMessage ?? 'Unknown network error'}',
            assertionReport: const <String>[],
            clearResponseStatusCode: true,
            clearResponseTimeMs: true,
          ),
        );
        continue;
      }

      final responseTimeMs = duration?.inMilliseconds;
      final evaluations = _evaluateAssertions(
        assertions: testCase.assertions,
        response: response,
        responseTimeMs: responseTimeMs,
      );

      final passed = evaluations
          .where((item) => item.type == _AssertionResultType.passed)
          .map((item) => item.message)
          .toList();
      final failed = evaluations
          .where((item) => item.type == _AssertionResultType.failed)
          .map((item) => item.message)
          .toList();
      final skipped = evaluations
          .where((item) => item.type == _AssertionResultType.skipped)
          .map((item) => item.message)
          .toList();

      final report = <String>[
        ...passed.map((line) => 'PASS: $line'),
        ...failed.map((line) => 'FAIL: $line'),
        ...skipped.map((line) => 'SKIP: $line'),
      ];

      final status = failed.isNotEmpty
          ? TestExecutionStatus.failed
          : passed.isNotEmpty
          ? TestExecutionStatus.passed
          : TestExecutionStatus.skipped;

      final summary = status == TestExecutionStatus.failed
          ? 'Failed ${failed.length}/${evaluations.length} checks.'
          : status == TestExecutionStatus.passed
          ? 'Passed ${passed.length}/${evaluations.length} checks.'
          : 'No auto-verifiable checks for this test yet.';

      executed.add(
        testCase.copyWith(
          executionStatus: status,
          executionSummary: summary,
          assertionReport: report,
          responseStatusCode: response.statusCode,
          responseTimeMs: responseTimeMs,
        ),
      );
    }
    return executed;
  }

  HttpRequestModel _buildRequestModel({
    required AgenticTestCase testCase,
    required Map<String, String> defaultHeaders,
    String? requestBody,
  }) {
    final method = _parseMethod(testCase.method);
    final headers = defaultHeaders.entries
        .map((entry) => NameValueModel(name: entry.key, value: entry.value))
        .toList();
    final hasBody = _methodSupportsBody(method);
    return HttpRequestModel(
      method: method,
      url: testCase.endpoint,
      headers: headers.isEmpty ? null : headers,
      isHeaderEnabledList: headers.isEmpty
          ? null
          : List<bool>.filled(headers.length, true),
      body: hasBody ? requestBody : null,
    );
  }

  HTTPVerb _parseMethod(String rawMethod) {
    final normalized = rawMethod.trim().toUpperCase();
    return switch (normalized) {
      'GET' => HTTPVerb.get,
      'POST' => HTTPVerb.post,
      'PUT' => HTTPVerb.put,
      'PATCH' => HTTPVerb.patch,
      'DELETE' => HTTPVerb.delete,
      'HEAD' => HTTPVerb.head,
      'OPTIONS' => HTTPVerb.options,
      _ => HTTPVerb.get,
    };
  }

  bool _methodSupportsBody(HTTPVerb method) {
    return switch (method) {
      HTTPVerb.post ||
      HTTPVerb.put ||
      HTTPVerb.patch ||
      HTTPVerb.delete ||
      HTTPVerb.options => true,
      _ => false,
    };
  }

  List<_AssertionEvaluation> _evaluateAssertions({
    required List<String> assertions,
    required Response response,
    required int? responseTimeMs,
  }) {
    final normalizedAssertions = assertions
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (normalizedAssertions.isEmpty) {
      final statusCode = response.statusCode;
      final passed = statusCode >= 200 && statusCode < 300;
      return [
        _AssertionEvaluation(
          type: passed
              ? _AssertionResultType.passed
              : _AssertionResultType.failed,
          message: 'Expected success status (2xx), got $statusCode.',
        ),
      ];
    }

    return normalizedAssertions
        .map(
          (assertion) => _evaluateSingleAssertion(
            assertion: assertion,
            response: response,
            responseTimeMs: responseTimeMs,
          ),
        )
        .toList();
  }

  _AssertionEvaluation _evaluateSingleAssertion({
    required String assertion,
    required Response response,
    required int? responseTimeMs,
  }) {
    final normalized = assertion.toLowerCase();
    final statusCode = response.statusCode;
    final body = response.body;

    if (normalized.contains('status')) {
      if (normalized.contains('2xx')) {
        final ok = statusCode >= 200 && statusCode < 300;
        return _AssertionEvaluation(
          type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
          message: '$assertion (actual: $statusCode)',
        );
      }

      final betweenMatch = RegExp(
        r'between\s+(\d{3})\s+and\s+(\d{3})',
      ).firstMatch(normalized);
      if (betweenMatch != null) {
        final minCode = int.parse(betweenMatch.group(1)!);
        final maxCode = int.parse(betweenMatch.group(2)!);
        final ok = statusCode >= minCode && statusCode <= maxCode;
        return _AssertionEvaluation(
          type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
          message: '$assertion (actual: $statusCode)',
        );
      }

      final codes = RegExp(r'\b\d{3}\b')
          .allMatches(normalized)
          .map((match) => int.parse(match.group(0)!))
          .toList();
      if (codes.isNotEmpty) {
        final ok = codes.contains(statusCode);
        return _AssertionEvaluation(
          type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
          message: '$assertion (actual: $statusCode)',
        );
      }
    }

    if (normalized.contains('response time') ||
        normalized.contains('latency')) {
      final threshold = _extractFirstNumber(normalized);
      if (threshold == null || responseTimeMs == null) {
        return _AssertionEvaluation(
          type: _AssertionResultType.skipped,
          message: '$assertion (unable to infer threshold).',
        );
      }
      final wantsLess =
          normalized.contains('less than') || normalized.contains('under');
      final wantsGreater =
          normalized.contains('greater than') || normalized.contains('over');
      final ok = wantsGreater
          ? responseTimeMs > threshold
          : wantsLess
          ? responseTimeMs < threshold
          : responseTimeMs <= threshold;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        message: '$assertion (actual: ${responseTimeMs}ms)',
      );
    }

    if (normalized.contains('body')) {
      if (normalized.contains('not empty')) {
        final ok = body.trim().isNotEmpty;
        return _AssertionEvaluation(
          type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
          message: assertion,
        );
      }

      if (normalized.contains('empty')) {
        final ok = body.trim().isEmpty;
        return _AssertionEvaluation(
          type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
          message: assertion,
        );
      }

      if (normalized.contains('array')) {
        final decoded = _tryDecodeJson(body);
        final ok = decoded is List;
        return _AssertionEvaluation(
          type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
          message: assertion,
        );
      }

      if (normalized.contains('json')) {
        final decoded = _tryDecodeJson(body);
        final ok = decoded != null;
        return _AssertionEvaluation(
          type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
          message: assertion,
        );
      }
    }

    return _AssertionEvaluation(
      type: _AssertionResultType.skipped,
      message: '$assertion (not auto-verifiable yet).',
    );
  }

  dynamic _tryDecodeJson(String rawBody) {
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  int? _extractFirstNumber(String input) {
    final match = RegExp(r'(\d+)').firstMatch(input);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }
}
