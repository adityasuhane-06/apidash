class AgenticContractContext {
  const AgenticContractContext({
    required this.source,
    required this.method,
    required this.endpointPath,
    this.requestContentType,
    this.responseContentType,
    this.pathParameters = const <String>[],
    this.queryParameters = const <String>[],
    this.headerParameters = const <String>[],
    this.requestJsonFields = const <String>[],
    this.responseJsonFields = const <String>[],
    this.expectedStatusCodes = const <int>[],
    this.requiresAuth = false,
    this.authHint,
  });

  final String source;
  final String method;
  final String endpointPath;
  final String? requestContentType;
  final String? responseContentType;
  final List<String> pathParameters;
  final List<String> queryParameters;
  final List<String> headerParameters;
  final List<String> requestJsonFields;
  final List<String> responseJsonFields;
  final List<int> expectedStatusCodes;
  final bool requiresAuth;
  final String? authHint;

  bool get hasAnyHints {
    return pathParameters.isNotEmpty ||
        queryParameters.isNotEmpty ||
        headerParameters.isNotEmpty ||
        requestJsonFields.isNotEmpty ||
        responseJsonFields.isNotEmpty ||
        expectedStatusCodes.isNotEmpty ||
        requestContentType != null ||
        responseContentType != null ||
        requiresAuth;
  }

  String toPromptSection() {
    final lines = <String>[
      '- Source: $source',
      '- Operation: $method $endpointPath',
      '- Requires Auth: ${requiresAuth ? 'yes' : 'no'}${authHint == null ? '' : ' ($authHint)'}',
      '- Expected Status Codes: ${expectedStatusCodes.isEmpty ? 'unknown' : expectedStatusCodes.join(', ')}',
      '- Request Content-Type: ${requestContentType ?? 'unknown'}',
      '- Response Content-Type: ${responseContentType ?? 'unknown'}',
      '- Path Params: ${pathParameters.isEmpty ? 'none' : pathParameters.join(', ')}',
      '- Query Params: ${queryParameters.isEmpty ? 'none' : queryParameters.join(', ')}',
      '- Header Params: ${headerParameters.isEmpty ? 'none' : headerParameters.join(', ')}',
      '- Request JSON Fields: ${requestJsonFields.isEmpty ? 'none' : requestJsonFields.join(', ')}',
      '- Response JSON Fields: ${responseJsonFields.isEmpty ? 'none' : responseJsonFields.join(', ')}',
    ];
    return lines.join('\n');
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'method': method,
      'endpoint_path': endpointPath,
      'request_content_type': requestContentType,
      'response_content_type': responseContentType,
      'path_parameters': pathParameters,
      'query_parameters': queryParameters,
      'header_parameters': headerParameters,
      'request_json_fields': requestJsonFields,
      'response_json_fields': responseJsonFields,
      'expected_status_codes': expectedStatusCodes,
      'requires_auth': requiresAuth,
      'auth_hint': authHint,
    };
  }

  factory AgenticContractContext.fromJson(Map<String, dynamic> json) {
    List<String> readStrings(String key) {
      final value = json[key];
      if (value is! List) {
        return const <String>[];
      }
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    List<int> readInts(String key) {
      final value = json[key];
      if (value is! List) {
        return const <int>[];
      }
      final parsed = <int>[];
      for (final item in value) {
        final number = switch (item) {
          int v => v,
          num v => v.toInt(),
          String v => int.tryParse(v.trim()),
          _ => null,
        };
        if (number != null) {
          parsed.add(number);
        }
      }
      return parsed;
    }

    return AgenticContractContext(
      source: (json['source'] as String?)?.trim().isNotEmpty == true
          ? (json['source'] as String).trim()
          : 'unknown',
      method: (json['method'] as String?)?.trim().toUpperCase() ?? 'GET',
      endpointPath:
          (json['endpoint_path'] as String?)?.trim().isNotEmpty == true
          ? (json['endpoint_path'] as String).trim()
          : '/',
      requestContentType: (json['request_content_type'] as String?)?.trim(),
      responseContentType: (json['response_content_type'] as String?)?.trim(),
      pathParameters: readStrings('path_parameters'),
      queryParameters: readStrings('query_parameters'),
      headerParameters: readStrings('header_parameters'),
      requestJsonFields: readStrings('request_json_fields'),
      responseJsonFields: readStrings('response_json_fields'),
      expectedStatusCodes: readInts('expected_status_codes'),
      requiresAuth: json['requires_auth'] == true,
      authHint: (json['auth_hint'] as String?)?.trim(),
    );
  }
}
