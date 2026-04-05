import 'package:apidash/agentic_testing/agentic_testing.dart';
import 'package:apidash_core/apidash_core.dart';
import 'package:test/test.dart';

void main() {
  group('AgenticTestGenerator contract context', () {
    test('injects contract hints into system prompt when provided', () async {
      AIRequestModel? capturedRequest;
      final generator = AgenticTestGenerator(
        readDefaultModel: () => const AIRequestModel().toJson(),
        generateAiRequest: (request) async {
          capturedRequest = request;
          return '''
{
  "tests": [
    {
      "title": "Get pet by id",
      "description": "Validates GET pet endpoint",
      "method": "GET",
      "endpoint": "https://api.example.com/pets/1",
      "expected_outcome": "Status code 200",
      "assertions": ["Response status is 200"],
      "confidence": 0.8
    }
  ]
}
''';
        },
      );

      final contractContext = const AgenticContractContext(
        source: 'openapi_operation',
        method: 'GET',
        endpointPath: '/pets/{petId}',
        pathParameters: ['petId'],
        queryParameters: ['include'],
        expectedStatusCodes: [200, 404],
        requestContentType: 'application/json',
        responseContentType: 'application/json',
        requiresAuth: true,
        authHint: 'bearer_header',
      );

      final tests = await generator.generateTests(
        endpoint: 'https://api.example.com/pets/1',
        method: 'GET',
        contractContext: contractContext,
      );

      expect(tests, hasLength(1));
      expect(capturedRequest, isNotNull);
      final systemPrompt = capturedRequest!.systemPrompt;
      expect(systemPrompt, contains('Contract Context'));
      expect(systemPrompt, contains('/pets/{petId}'));
      expect(systemPrompt, contains('Expected Status Codes: 200, 404'));
      expect(systemPrompt, contains('Requires Auth: yes'));
    });

    test('fallback tests use clear endpoint-specific titles', () async {
      final generator = AgenticTestGenerator(
        readDefaultModel: () => const AIRequestModel().toJson(),
        generateAiRequest: (request) async => 'not valid json',
      );

      final tests = await generator.generateTests(
        endpoint: 'https://api.apidash.dev/users',
        method: 'GET',
      );

      expect(tests, hasLength(3));
      expect(tests[0].title, 'GET /users returns success for valid request');
      expect(tests[1].title, 'GET /users rejects missing or invalid auth');
      expect(tests[2].title, 'GET /users validates malformed input');
    });
  });
}
