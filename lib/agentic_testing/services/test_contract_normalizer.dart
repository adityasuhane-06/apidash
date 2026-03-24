import 'dart:convert';

import 'package:apidash_core/apidash_core.dart';

import '../models/contract_context.dart';

class AgenticTestContractNormalizer {
  const AgenticTestContractNormalizer();

  AgenticContractContext? normalizeFromRequest({
    required HttpRequestModel requestModel,
    HttpResponseModel? responseModel,
    Map<String, dynamic>? openApiOperationMeta,
  }) {
    final rawUrl = requestModel.url.trim();
    if (rawUrl.isEmpty) {
      return null;
    }

    final normalizedFromMeta = _normalizeFromOpenApiMeta(
      requestModel: requestModel,
      responseModel: responseModel,
      openApiOperationMeta: openApiOperationMeta,
    );
    if (normalizedFromMeta != null) {
      return normalizedFromMeta;
    }

    final uri = _tryParseUri(rawUrl);
    final endpointPath = _extractEndpointPath(rawUrl, uri);
    final enabledHeaders = requestModel.enabledHeadersMap;
    final headerParams = _sortUniqueCaseInsensitive(enabledHeaders.keys);
    final queryParams = _extractQueryParams(requestModel, uri);
    final pathParams = _extractPathParams(endpointPath);

    final auth = _detectAuth(
      requestModel: requestModel,
      headers: enabledHeaders,
    );

    final requestBodySource = _preferredRequestBodySource(requestModel);
    final requestBodyJson = _tryDecodeJson(requestBodySource);
    final requestFields = _extractTopLevelJsonFields(requestBodyJson);

    final responseBodySource =
        (responseModel?.formattedBody ?? responseModel?.body)?.trim();
    final responseBodyJson = _tryDecodeJson(responseBodySource);
    final responseFields = _extractTopLevelJsonFields(responseBodyJson);

    final expectedStatusCodes = <int>[
      if (responseModel?.statusCode != null) responseModel!.statusCode!,
    ];

    return AgenticContractContext(
      source: 'request_inferred',
      method: requestModel.method.name.toUpperCase(),
      endpointPath: endpointPath,
      requestContentType: _inferRequestContentType(
        requestModel,
        enabledHeaders,
      ),
      responseContentType: responseModel?.contentType?.trim(),
      pathParameters: pathParams,
      queryParameters: queryParams,
      headerParameters: headerParams,
      requestJsonFields: requestFields,
      responseJsonFields: responseFields,
      expectedStatusCodes: expectedStatusCodes,
      requiresAuth: auth.$1,
      authHint: auth.$2,
    );
  }

  AgenticContractContext? _normalizeFromOpenApiMeta({
    required HttpRequestModel requestModel,
    required HttpResponseModel? responseModel,
    required Map<String, dynamic>? openApiOperationMeta,
  }) {
    if (openApiOperationMeta == null || openApiOperationMeta.isEmpty) {
      return null;
    }

    final method = _readString(openApiOperationMeta, 'method')?.toUpperCase();
    final path = _readString(openApiOperationMeta, 'path');
    if (method == null || method.isEmpty || path == null || path.isEmpty) {
      return null;
    }

    final parameters = openApiOperationMeta['parameters'];
    final pathParams = <String>[];
    final queryParams = <String>[];
    final headerParams = <String>[];
    if (parameters is List) {
      for (final item in parameters.whereType<Map>()) {
        final name = (item['name'] as String?)?.trim();
        final location = (item['in'] as String?)?.trim().toLowerCase();
        if (name == null || name.isEmpty) {
          continue;
        }
        switch (location) {
          case 'path':
            pathParams.add(name);
            break;
          case 'query':
            queryParams.add(name);
            break;
          case 'header':
            headerParams.add(name);
            break;
        }
      }
    }

    final reqBodyFields = _extractFromSchemaProperties(
      openApiOperationMeta['requestBodySchema'],
    );
    final respBodyFields = _extractFromSchemaProperties(
      openApiOperationMeta['responseBodySchema'],
    );

    final expectedStatusCodes = _extractStatusCodes(
      openApiOperationMeta['responses'],
    );
    if (expectedStatusCodes.isEmpty && responseModel?.statusCode != null) {
      expectedStatusCodes.add(responseModel!.statusCode!);
    }

    final auth = _detectAuth(
      requestModel: requestModel,
      headers: requestModel.enabledHeadersMap,
    );

    return AgenticContractContext(
      source: 'openapi_operation',
      method: method,
      endpointPath: path,
      requestContentType: _readString(
        openApiOperationMeta,
        'requestContentType',
      ),
      responseContentType: _readString(
        openApiOperationMeta,
        'responseContentType',
      ),
      pathParameters: _sortUniqueCaseInsensitive(pathParams),
      queryParameters: _sortUniqueCaseInsensitive(queryParams),
      headerParameters: _sortUniqueCaseInsensitive(headerParams),
      requestJsonFields: _sortUniqueCaseInsensitive(reqBodyFields),
      responseJsonFields: _sortUniqueCaseInsensitive(respBodyFields),
      expectedStatusCodes: expectedStatusCodes..sort(),
      requiresAuth: auth.$1,
      authHint: auth.$2,
    );
  }

  Uri? _tryParseUri(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      if (uri.path.isNotEmpty || uri.hasAuthority) {
        return uri;
      }
    } catch (_) {}
    return null;
  }

  String _extractEndpointPath(String rawUrl, Uri? uri) {
    if (uri == null) {
      return _stripQuery(rawUrl);
    }
    final path = uri.path.isEmpty
        ? '/'
        : '/${uri.pathSegments.map(Uri.decodeComponent).join('/')}';
    return path;
  }

  String _stripQuery(String input) {
    final idx = input.indexOf('?');
    if (idx == -1) {
      return input;
    }
    return input.substring(0, idx);
  }

  List<String> _extractPathParams(String endpointPath) {
    final names = <String>{};
    for (final m in RegExp(r'\{([^}]+)\}').allMatches(endpointPath)) {
      final name = m.group(1)?.trim();
      if (name != null && name.isNotEmpty) {
        names.add(name);
      }
    }
    for (final m in RegExp(r'/:([A-Za-z0-9_]+)').allMatches(endpointPath)) {
      final name = m.group(1)?.trim();
      if (name != null && name.isNotEmpty) {
        names.add(name);
      }
    }
    return names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> _extractQueryParams(HttpRequestModel requestModel, Uri? uri) {
    final names = <String>{};
    for (final name in requestModel.enabledParamsMap.keys) {
      final clean = name.trim();
      if (clean.isNotEmpty) {
        names.add(clean);
      }
    }
    if (uri != null) {
      for (final name in uri.queryParametersAll.keys) {
        final clean = name.trim();
        if (clean.isNotEmpty) {
          names.add(clean);
        }
      }
    }
    return names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  (bool, String?) _detectAuth({
    required HttpRequestModel requestModel,
    required Map<String, String> headers,
  }) {
    final authType = requestModel.authModel?.type ?? APIAuthType.none;
    if (authType != APIAuthType.none) {
      return (true, authType.name);
    }

    String? authorization;
    for (final entry in headers.entries) {
      if (entry.key.trim().toLowerCase() == 'authorization') {
        authorization = entry.value.trim();
        break;
      }
    }

    if (authorization == null || authorization.isEmpty) {
      return (false, null);
    }
    final normalized = authorization.toLowerCase();
    if (normalized.startsWith('bearer ')) {
      return (true, 'bearer_header');
    }
    if (normalized.startsWith('basic ')) {
      return (true, 'basic_header');
    }
    return (true, 'authorization_header');
  }

  String? _preferredRequestBodySource(HttpRequestModel requestModel) {
    if (requestModel.hasJsonData) {
      return requestModel.body?.trim();
    }
    if (requestModel.hasTextData) {
      return requestModel.body?.trim();
    }
    if (requestModel.hasFormData) {
      final map = <String, String>{};
      for (final row in requestModel.formDataList) {
        if (row.name.trim().isEmpty) {
          continue;
        }
        map[row.name.trim()] = row.value;
      }
      if (map.isNotEmpty) {
        return jsonEncode(map);
      }
    }
    return requestModel.body?.trim();
  }

  String? _inferRequestContentType(
    HttpRequestModel requestModel,
    Map<String, String> headers,
  ) {
    for (final entry in headers.entries) {
      if (entry.key.trim().toLowerCase() == 'content-type') {
        final value = entry.value.trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return switch (requestModel.bodyContentType) {
      ContentType.json => 'application/json',
      ContentType.formdata => 'multipart/form-data',
      ContentType.text => 'text/plain',
    };
  }

  Object? _tryDecodeJson(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  List<String> _extractTopLevelJsonFields(Object? jsonObject) {
    if (jsonObject is Map) {
      return _sortUniqueCaseInsensitive(
        jsonObject.keys.map((key) => key.toString()),
      );
    }
    if (jsonObject is List &&
        jsonObject.isNotEmpty &&
        jsonObject.first is Map) {
      return _sortUniqueCaseInsensitive(
        (jsonObject.first as Map).keys.map((key) => key.toString()),
      );
    }
    return const <String>[];
  }

  List<String> _extractFromSchemaProperties(Object? value) {
    if (value is Map) {
      final properties = value['properties'];
      if (properties is Map) {
        return _sortUniqueCaseInsensitive(
          properties.keys.map((key) => key.toString()),
        );
      }
    }
    return const <String>[];
  }

  List<int> _extractStatusCodes(Object? responsesRaw) {
    if (responsesRaw is! Map) {
      return <int>[];
    }
    final statusCodes = <int>{};
    for (final key in responsesRaw.keys) {
      final raw = key.toString().trim();
      final parsed = int.tryParse(raw);
      if (parsed != null) {
        statusCodes.add(parsed);
      }
    }
    return statusCodes.toList();
  }

  String? _readString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  List<String> _sortUniqueCaseInsensitive(Iterable<String> values) {
    final set = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        set.add(trimmed);
      }
    }
    final result = set.toList();
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }
}
