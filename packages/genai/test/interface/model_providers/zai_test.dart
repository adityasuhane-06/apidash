import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genai/interface/consts.dart';
import 'package:genai/interface/model_providers/zai.dart';
import 'package:genai/models/ai_request_model.dart';

void main() {
  group('ZAIModel', () {
    test('should return default AIRequestModel with Z.AI endpoint', () {
      final defaultModel = ZAIModel.instance.defaultAIRequestModel;

      expect(defaultModel.modelApiProvider, equals(ModelAPIProvider.zai));
      expect(defaultModel.url, equals(kZAIUrl));
      expect(defaultModel.modelConfigs.length, greaterThan(0));
    });

    test(
      'should create OpenAI-compatible request with thinking for GLM-4.7',
      () {
        const req = AIRequestModel(
          modelApiProvider: ModelAPIProvider.zai,
          url: kZAIUrl,
          model: 'glm-4.7-flash',
          apiKey: 'zai-token',
          userPrompt: 'Hello',
          systemPrompt: 'System',
        );

        final httpReq = ZAIModel.instance.createRequest(req)!;
        final body = jsonDecode(httpReq.body!);

        expect(httpReq.url, equals(kZAIUrl));
        expect(httpReq.authModel?.bearer?.token, equals('zai-token'));
        expect(body['model'], equals('glm-4.7-flash'));
        expect(body['thinking'], equals({'type': 'enabled'}));
      },
    );

    test('should skip thinking for non GLM-4.7 models', () {
      const req = AIRequestModel(
        modelApiProvider: ModelAPIProvider.zai,
        url: kZAIUrl,
        model: 'glm-5',
        apiKey: 'zai-token',
        userPrompt: 'Hello',
        systemPrompt: 'System',
      );

      final httpReq = ZAIModel.instance.createRequest(req)!;
      final body = jsonDecode(httpReq.body!);

      expect(body.containsKey('thinking'), isFalse);
    });
  });
}
