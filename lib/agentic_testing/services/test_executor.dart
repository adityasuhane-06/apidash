import 'dart:convert';

import 'package:apidash_core/apidash_core.dart';

import '../models/test_case_model.dart';

typedef AgenticExecuteHttpRequest =
    Future<(Response?, Duration?, String?)> Function(
      String requestId,
      APIType apiType,
      HttpRequestModel requestModel,
    );

enum _AssertionResultType { passed, failed, skipped }

class _AssertionEvaluation {
  const _AssertionEvaluation({
    required this.type,
    required this.message,
    this.failureType = TestFailureType.none,
  });

  final _AssertionResultType type;
  final String message;
  final TestFailureType failureType;
}

class AgenticTestExecutor {
  AgenticTestExecutor({AgenticExecuteHttpRequest? executeHttpRequest})
    : _executeHttpRequest = executeHttpRequest ?? sendHttpRequest;

  final AgenticExecuteHttpRequest _executeHttpRequest;

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
            failureType: TestFailureType.none,
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
      final (response, duration, errorMessage) = await _executeHttpRequest(
        requestId,
        APIType.rest,
        requestModel,
      );

      if (response == null) {
        final failureMsg = errorMessage ?? 'Unknown network error';
        executed.add(
          testCase.copyWith(
            executionStatus: TestExecutionStatus.failed,
            executionSummary: 'Execution failed: $failureMsg',
            assertionReport: <String>['FAIL: request failed ($failureMsg)'],
            clearResponseStatusCode: true,
            clearResponseTimeMs: true,
            failureType: TestFailureType.networkError,
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
          .toList();
      final failed = evaluations
          .where((item) => item.type == _AssertionResultType.failed)
          .toList();
      final skipped = evaluations
          .where((item) => item.type == _AssertionResultType.skipped)
          .toList();

      final report = <String>[
        ...passed.map((item) => 'PASS: ${item.message}'),
        ...failed.map((item) => 'FAIL: ${item.message}'),
        ...skipped.map((item) => 'SKIP: ${item.message}'),
      ];

      final status = failed.isNotEmpty
          ? TestExecutionStatus.failed
          : passed.isNotEmpty
          ? TestExecutionStatus.passed
          : TestExecutionStatus.skipped;

      final failureType = _resolveFailureType(failed, skipped);
      final summary = switch (status) {
        TestExecutionStatus.failed =>
          'Failed ${failed.length}/${evaluations.length} checks (${failureType.code}).',
        TestExecutionStatus.passed =>
          'Passed ${passed.length}/${evaluations.length} checks.',
        TestExecutionStatus.skipped =>
          failureType == TestFailureType.unsupportedAssertion
              ? 'No auto-verifiable checks (${failureType.code}).'
              : 'No auto-verifiable checks for this test yet.',
        TestExecutionStatus.notRun => 'Not executed.',
      };

      executed.add(
        testCase.copyWith(
          executionStatus: status,
          executionSummary: summary,
          assertionReport: report,
          responseStatusCode: response.statusCode,
          responseTimeMs: responseTimeMs,
          failureType: failureType,
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
    final cleanedAssertions = assertions
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (cleanedAssertions.isEmpty) {
      final statusCode = response.statusCode;
      final ok = statusCode >= 200 && statusCode < 300;
      return [
        _AssertionEvaluation(
          type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
          failureType: ok
              ? TestFailureType.none
              : TestFailureType.statusCodeMismatch,
          message: 'Expected success status (2xx), got $statusCode.',
        ),
      ];
    }

    return cleanedAssertions
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

    if (_looksLikeStatusAssertion(normalized)) {
      return _evaluateStatusAssertion(assertion, normalized, statusCode);
    }

    if (_looksLikeResponseTimeAssertion(normalized)) {
      return _evaluateResponseTimeAssertion(
        assertion,
        normalized,
        responseTimeMs,
      );
    }

    if (_looksLikeBodyAssertion(normalized)) {
      return _evaluateBodyAssertion(assertion, normalized, body);
    }

    return _unsupported(assertion);
  }

  bool _looksLikeStatusAssertion(String normalized) {
    return normalized.contains('status') || normalized.contains('status_code');
  }

  bool _looksLikeResponseTimeAssertion(String normalized) {
    return normalized.contains('response time') ||
        normalized.contains('latency') ||
        normalized.contains('time');
  }

  bool _looksLikeBodyAssertion(String normalized) {
    return normalized.contains('body') ||
        normalized.contains('json') ||
        normalized.contains('array') ||
        normalized.contains('object');
  }

  _AssertionEvaluation _evaluateStatusAssertion(
    String assertion,
    String normalized,
    int statusCode,
  ) {
    if (normalized.contains('2xx')) {
      final ok = statusCode >= 200 && statusCode < 300;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.statusCodeMismatch,
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
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.statusCodeMismatch,
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
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.statusCodeMismatch,
        message: '$assertion (actual: $statusCode)',
      );
    }

    return _unsupported(assertion);
  }

  _AssertionEvaluation _evaluateResponseTimeAssertion(
    String assertion,
    String normalized,
    int? responseTimeMs,
  ) {
    final threshold = _extractFirstNumber(normalized);
    if (threshold == null || responseTimeMs == null) {
      return _unsupported('$assertion (unable to infer threshold)');
    }

    final wantsLess =
        normalized.contains('less than') ||
        normalized.contains('under') ||
        normalized.contains('within') ||
        normalized.contains('max');
    final wantsGreater =
        normalized.contains('greater than') ||
        normalized.contains('over') ||
        normalized.contains('more than') ||
        normalized.contains('min');
    final wantsAtLeast = normalized.contains('at least');
    final wantsAtMost = normalized.contains('at most');
    final wantsEqual =
        normalized.contains('equals') ||
        normalized.contains('exactly') ||
        normalized.contains('==');

    final ok = switch (true) {
      _ when wantsAtLeast => responseTimeMs >= threshold,
      _ when wantsAtMost => responseTimeMs <= threshold,
      _ when wantsGreater => responseTimeMs > threshold,
      _ when wantsEqual => responseTimeMs == threshold,
      _ => wantsLess ? responseTimeMs < threshold : responseTimeMs <= threshold,
    };

    return _AssertionEvaluation(
      type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
      failureType: ok
          ? TestFailureType.none
          : TestFailureType.responseTimeExceeded,
      message: '$assertion (actual: ${responseTimeMs}ms)',
    );
  }

  _AssertionEvaluation _evaluateBodyAssertion(
    String assertion,
    String normalized,
    String body,
  ) {
    final decoded = _tryDecodeJson(body);
    final codeLike = _evaluateCodeLikeJsonAssertion(
      assertion: assertion,
      normalized: normalized,
      decodedBody: decoded,
    );
    if (codeLike != null) {
      return codeLike;
    }

    final fieldName = _extractTopLevelFieldName(
      assertion: assertion,
      normalized: normalized,
    );
    if (fieldName != null) {
      final fieldCheck = _evaluateTopLevelFieldAssertion(
        assertion: assertion,
        normalized: normalized,
        decodedBody: decoded,
        fieldName: fieldName,
      );
      if (fieldCheck != null) {
        return fieldCheck;
      }
    }

    if (normalized.contains('not empty')) {
      final ok = body.trim().isNotEmpty;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: assertion,
      );
    }

    if (normalized.contains('empty')) {
      final ok = body.trim().isEmpty;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: assertion,
      );
    }

    if (normalized.contains('array')) {
      if (decoded is! List) {
        return _AssertionEvaluation(
          type: _AssertionResultType.failed,
          failureType: TestFailureType.bodyValidationFailed,
          message: '$assertion (actual: non-array body)',
        );
      }
      final lengthCheck = _evaluateLengthConstraint(
        assertion: assertion,
        normalized: normalized,
        actualLength: decoded.length,
      );
      return lengthCheck ??
          _AssertionEvaluation(
            type: _AssertionResultType.passed,
            message: assertion,
          );
    }

    if (normalized.contains('object') || normalized.contains('map')) {
      final ok = decoded is Map;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: assertion,
      );
    }

    if (normalized.contains('json')) {
      final ok = decoded != null;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: assertion,
      );
    }

    return _unsupported(assertion);
  }

  _AssertionEvaluation? _evaluateCodeLikeJsonAssertion({
    required String assertion,
    required String normalized,
    required dynamic decodedBody,
  }) {
    if (!normalized.contains('response.json')) {
      return null;
    }

    if (normalized.contains('array.isarray(response.json())')) {
      final ok = decodedBody is List;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: ok ? assertion : '$assertion (actual: non-array body)',
      );
    }

    final isinstanceBodyMatch = RegExp(
      r'isinstance\(\s*response\.json\(\)\s*,\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\)',
      caseSensitive: false,
    ).firstMatch(assertion);
    if (isinstanceBodyMatch != null) {
      final typeToken = (isinstanceBodyMatch.group(1) ?? '').toLowerCase();
      final ok = _matchesExpectedType(decodedBody, typeToken);
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: ok ? assertion : '$assertion (actual: incompatible type)',
      );
    }

    if (decodedBody is! Map) {
      return _AssertionEvaluation(
        type: _AssertionResultType.failed,
        failureType: TestFailureType.bodyValidationFailed,
        message: '$assertion (actual: non-object body)',
      );
    }

    final inMatch = RegExp(
      r"""['"]([^'"]+)['"]\s+(not\s+)?in\s+response\.json\(\)""",
      caseSensitive: false,
    ).firstMatch(assertion);
    if (inMatch != null) {
      final field = inMatch.group(1)?.trim() ?? '';
      final negated = (inMatch.group(2) ?? '').trim().isNotEmpty;
      if (field.isEmpty) {
        return _unsupported(assertion);
      }
      final key = _resolveFieldKey(decodedBody, field);
      final present = key != null;
      final ok = negated ? !present : present;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: ok
            ? assertion
            : '$assertion (actual: ${present ? 'field present' : 'field missing'})',
      );
    }

    final getValueMatch = RegExp(
      r'''response\.json\(\)\.get\(\s*['"]([^'"]+)['"]\s*\)(?:\s*([=!]=)\s*(.+))?$''',
      caseSensitive: false,
    ).firstMatch(assertion.trim());
    if (getValueMatch != null) {
      final field = (getValueMatch.group(1) ?? '').trim();
      if (field.isEmpty) {
        return _unsupported(assertion);
      }
      final key = _resolveFieldKey(decodedBody, field);
      if (key == null) {
        return _AssertionEvaluation(
          type: _AssertionResultType.failed,
          failureType: TestFailureType.bodyValidationFailed,
          message: "$assertion (actual: missing field '$field')",
        );
      }
      final actual = decodedBody[key];
      final operator = (getValueMatch.group(2) ?? '').trim();
      final rawExpected = (getValueMatch.group(3) ?? '').trim();
      if (operator.isEmpty || rawExpected.isEmpty) {
        return _AssertionEvaluation(
          type: _AssertionResultType.passed,
          failureType: TestFailureType.none,
          message: assertion,
        );
      }
      final expected = _parseExpectedLiteral(rawExpected);
      final equal = actual == expected;
      final ok = operator == '!=' ? !equal : equal;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: '$assertion (actual: $actual)',
      );
    }

    final bracketValueMatch = RegExp(
      r'''response\.json\(\)\[['"]([^'"]+)['"]\](?:\s*([=!]=)\s*(.+))?$''',
      caseSensitive: false,
    ).firstMatch(assertion.trim());
    if (bracketValueMatch != null) {
      final field = (bracketValueMatch.group(1) ?? '').trim();
      final key = _resolveFieldKey(decodedBody, field);
      if (key == null) {
        return _AssertionEvaluation(
          type: _AssertionResultType.failed,
          failureType: TestFailureType.bodyValidationFailed,
          message: "$assertion (actual: missing field '$field')",
        );
      }
      final actual = decodedBody[key];
      final operator = (bracketValueMatch.group(2) ?? '').trim();
      final rawExpected = (bracketValueMatch.group(3) ?? '').trim();
      if (operator.isEmpty || rawExpected.isEmpty) {
        return _AssertionEvaluation(
          type: _AssertionResultType.passed,
          failureType: TestFailureType.none,
          message: assertion,
        );
      }
      final expected = _parseExpectedLiteral(rawExpected);
      final equal = actual == expected;
      final ok = operator == '!=' ? !equal : equal;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: '$assertion (actual: $actual)',
      );
    }

    final isinstanceFieldMatch = RegExp(
      r'''isinstance\(\s*response\.json\(\)\.get\(\s*['"]([^'"]+)['"]\s*\)\s*,\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\)''',
      caseSensitive: false,
    ).firstMatch(assertion);
    if (isinstanceFieldMatch != null) {
      final field = (isinstanceFieldMatch.group(1) ?? '').trim();
      final expectedType = (isinstanceFieldMatch.group(2) ?? '')
          .trim()
          .toLowerCase();
      final key = _resolveFieldKey(decodedBody, field);
      if (key == null) {
        return _AssertionEvaluation(
          type: _AssertionResultType.failed,
          failureType: TestFailureType.bodyValidationFailed,
          message: "$assertion (actual: missing field '$field')",
        );
      }
      final actual = decodedBody[key];
      final ok = _matchesExpectedType(actual, expectedType);
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: ok ? assertion : '$assertion (actual: $actual)',
      );
    }

    return null;
  }

  dynamic _parseExpectedLiteral(String rawExpected) {
    final normalized = rawExpected.trim().replaceAll(RegExp(r'[;,]+$'), '');
    if (normalized.isEmpty) {
      return normalized;
    }
    final quoted = RegExp(r'''^['"](.+?)['"]$''').firstMatch(normalized);
    if (quoted != null) {
      return quoted.group(1) ?? '';
    }
    if (normalized.toLowerCase() == 'true') {
      return true;
    }
    if (normalized.toLowerCase() == 'false') {
      return false;
    }
    if (normalized.toLowerCase() == 'null') {
      return null;
    }
    final numeric = num.tryParse(normalized);
    if (numeric != null) {
      return numeric;
    }
    return normalized;
  }

  bool _matchesExpectedType(dynamic value, String expectedType) {
    return switch (expectedType.toLowerCase()) {
      'int' || 'integer' => value is int,
      'float' || 'double' || 'number' || 'num' => value is num,
      'str' || 'string' => value is String,
      'bool' || 'boolean' => value is bool,
      'list' || 'array' => value is List,
      'dict' || 'map' || 'object' => value is Map,
      _ => false,
    };
  }

  String? _extractTopLevelFieldName({
    required String assertion,
    required String normalized,
  }) {
    if (!normalized.contains('field') && !normalized.contains('key')) {
      return null;
    }

    final singleQuoted = RegExp(r"'([^']+)'").firstMatch(assertion);
    if (singleQuoted != null) {
      final value = singleQuoted.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    final doubleQuoted = RegExp(r'"([^"]+)"').firstMatch(assertion);
    if (doubleQuoted != null) {
      final value = doubleQuoted.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    final namedMatch = RegExp(
      r'(?:field|key)\s+named\s+([a-zA-Z0-9_.-]+)',
    ).firstMatch(normalized);
    if (namedMatch != null) {
      final value = namedMatch.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    final suffixMatch = RegExp(
      r'([a-zA-Z0-9_.-]+)\s+field',
    ).firstMatch(normalized);
    if (suffixMatch != null) {
      final value = suffixMatch.group(1)?.trim();
      if (value != null &&
          value.isNotEmpty &&
          value != 'response' &&
          value != 'body') {
        return value;
      }
    }

    return null;
  }

  _AssertionEvaluation? _evaluateTopLevelFieldAssertion({
    required String assertion,
    required String normalized,
    required dynamic decodedBody,
    required String fieldName,
  }) {
    if (decodedBody is! Map) {
      return _AssertionEvaluation(
        type: _AssertionResultType.failed,
        failureType: TestFailureType.bodyValidationFailed,
        message: '$assertion (actual: non-object body)',
      );
    }

    final resolvedKey = _resolveFieldKey(decodedBody, fieldName);
    if (resolvedKey == null) {
      return _AssertionEvaluation(
        type: _AssertionResultType.failed,
        failureType: TestFailureType.bodyValidationFailed,
        message: "$assertion (actual: missing field '$fieldName')",
      );
    }

    final fieldValue = decodedBody[resolvedKey];
    if (normalized.contains('array')) {
      final ok = fieldValue is List;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: ok ? assertion : "$assertion (actual: non-array field value)",
      );
    }

    if (normalized.contains('object') || normalized.contains('map')) {
      final ok = fieldValue is Map;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: ok ? assertion : "$assertion (actual: non-object field value)",
      );
    }

    if (normalized.contains('string')) {
      final ok = fieldValue is String;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: ok ? assertion : "$assertion (actual: non-string field value)",
      );
    }

    if (normalized.contains('number') ||
        normalized.contains('integer') ||
        normalized.contains('int') ||
        normalized.contains('float') ||
        normalized.contains('double')) {
      final ok = fieldValue is num;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: ok ? assertion : "$assertion (actual: non-number field value)",
      );
    }

    if (normalized.contains('boolean') || normalized.contains('bool')) {
      final ok = fieldValue is bool;
      return _AssertionEvaluation(
        type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
        failureType: ok
            ? TestFailureType.none
            : TestFailureType.bodyValidationFailed,
        message: ok
            ? assertion
            : "$assertion (actual: non-boolean field value)",
      );
    }

    if (_looksLikeFieldPresenceAssertion(normalized)) {
      return _AssertionEvaluation(
        type: _AssertionResultType.passed,
        failureType: TestFailureType.none,
        message: assertion,
      );
    }

    return null;
  }

  bool _looksLikeFieldPresenceAssertion(String normalized) {
    return normalized.contains('has') ||
        normalized.contains('contains') ||
        normalized.contains('exists') ||
        normalized.contains('field named') ||
        normalized.contains('top-level field') ||
        normalized.contains('top level field');
  }

  String? _resolveFieldKey(Map<dynamic, dynamic> object, String expectedField) {
    if (object.containsKey(expectedField)) {
      return expectedField;
    }
    final expectedLower = expectedField.toLowerCase();
    for (final key in object.keys) {
      final keyString = key.toString();
      if (keyString.toLowerCase() == expectedLower) {
        return keyString;
      }
    }
    return null;
  }

  _AssertionEvaluation? _evaluateLengthConstraint({
    required String assertion,
    required String normalized,
    required int actualLength,
  }) {
    if (!normalized.contains('length')) {
      return null;
    }
    final target = _extractFirstNumber(normalized);
    if (target == null) {
      return _unsupported('$assertion (unable to infer length target)');
    }

    final wantsGreater =
        normalized.contains('greater than') ||
        normalized.contains('more than') ||
        normalized.contains('over');
    final wantsLess =
        normalized.contains('less than') || normalized.contains('under');
    final wantsAtLeast = normalized.contains('at least');
    final wantsAtMost = normalized.contains('at most');
    final wantsEqual =
        normalized.contains('equals') ||
        normalized.contains('exactly') ||
        normalized.contains('==');

    final ok = switch (true) {
      _ when wantsAtLeast => actualLength >= target,
      _ when wantsAtMost => actualLength <= target,
      _ when wantsGreater => actualLength > target,
      _ when wantsLess => actualLength < target,
      _ when wantsEqual => actualLength == target,
      _ => actualLength == target,
    };

    return _AssertionEvaluation(
      type: ok ? _AssertionResultType.passed : _AssertionResultType.failed,
      failureType: ok
          ? TestFailureType.none
          : TestFailureType.bodyValidationFailed,
      message: '$assertion (actual length: $actualLength)',
    );
  }

  TestFailureType _resolveFailureType(
    List<_AssertionEvaluation> failed,
    List<_AssertionEvaluation> skipped,
  ) {
    if (failed.isNotEmpty) {
      final classified = failed.firstWhere(
        (item) => item.failureType != TestFailureType.none,
        orElse: () => failed.first,
      );
      return classified.failureType == TestFailureType.none
          ? TestFailureType.unknown
          : classified.failureType;
    }

    if (skipped.isNotEmpty &&
        skipped.every(
          (item) => item.failureType == TestFailureType.unsupportedAssertion,
        )) {
      return TestFailureType.unsupportedAssertion;
    }

    return TestFailureType.none;
  }

  _AssertionEvaluation _unsupported(String assertion) {
    return _AssertionEvaluation(
      type: _AssertionResultType.skipped,
      failureType: TestFailureType.unsupportedAssertion,
      message: '$assertion (not auto-verifiable yet)',
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
