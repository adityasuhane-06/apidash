import 'package:apidash/agentic_testing/agentic_testing.dart';
import 'package:apidash_core/apidash_core.dart';
import 'package:test/test.dart';

void main() {
  group('AgenticTestContractNormalizer', () {
    const normalizer = AgenticTestContractNormalizer();

    test('infers contract hints from selected request and response', () {
      final request = HttpRequestModel(
        method: HTTPVerb.post,
        url: 'https://api.example.com/users/{userId}?expand=true',
        headers: const [
          NameValueModel(name: 'Authorization', value: 'Bearer token'),
          NameValueModel(name: 'Content-Type', value: 'application/json'),
        ],
        isHeaderEnabledList: const [true, true],
        params: const [NameValueModel(name: 'limit', value: '20')],
        isParamEnabledList: const [true],
        bodyContentType: ContentType.json,
        body: '{"name":"Alice","email":"alice@example.com"}',
      );

      final response = const HttpResponseModel(
        statusCode: 201,
        headers: {'content-type': 'application/json'},
        body: '{"id":"u_1","name":"Alice"}',
        formattedBody: '{"id":"u_1","name":"Alice"}',
      );

      final context = normalizer.normalizeFromRequest(
        requestModel: request,
        responseModel: response,
      );

      expect(context, isNotNull);
      expect(context!.source, 'request_inferred');
      expect(context.method, 'POST');
      expect(context.endpointPath, '/users/{userId}');
      expect(context.pathParameters, contains('userId'));
      expect(context.queryParameters, containsAll(['expand', 'limit']));
      expect(context.requiresAuth, isTrue);
      expect(context.authHint, 'bearer_header');
      expect(context.requestJsonFields, containsAll(['email', 'name']));
      expect(context.responseJsonFields, containsAll(['id', 'name']));
      expect(context.expectedStatusCodes, [201]);
    });

    test('prefers openapi operation metadata when provided', () {
      final request = const HttpRequestModel(
        method: HTTPVerb.get,
        url: 'https://api.example.com/fallback',
      );

      final context = normalizer.normalizeFromRequest(
        requestModel: request,
        openApiOperationMeta: {
          'method': 'get',
          'path': '/pets/{petId}',
          'requestContentType': 'application/json',
          'responseContentType': 'application/json',
          'parameters': [
            {'name': 'petId', 'in': 'path'},
            {'name': 'include', 'in': 'query'},
            {'name': 'x-trace-id', 'in': 'header'},
          ],
          'responses': {'200': {}, '404': {}},
          'requestBodySchema': {
            'properties': {'name': {}, 'breed': {}},
          },
          'responseBodySchema': {
            'properties': {'id': {}, 'name': {}},
          },
        },
      );

      expect(context, isNotNull);
      expect(context!.source, 'openapi_operation');
      expect(context.method, 'GET');
      expect(context.endpointPath, '/pets/{petId}');
      expect(context.pathParameters, ['petId']);
      expect(context.queryParameters, ['include']);
      expect(context.headerParameters, ['x-trace-id']);
      expect(context.expectedStatusCodes, [200, 404]);
      expect(context.requestJsonFields, containsAll(['breed', 'name']));
      expect(context.responseJsonFields, containsAll(['id', 'name']));
    });
  });
}
