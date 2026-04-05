import 'dart:convert';
import 'package:better_networking/better_networking.dart';
import '../../models/models.dart';
import '../consts.dart';
import 'openai.dart';

class ZAIModel extends OpenAIModel {
  static final instance = ZAIModel();

  @override
  AIRequestModel get defaultAIRequestModel => kDefaultAiRequestModel.copyWith(
    modelApiProvider: ModelAPIProvider.zai,
    url: kZAIUrl,
  );

  @override
  HttpRequestModel? createRequest(AIRequestModel? aiRequestModel) {
    final baseRequest = super.createRequest(aiRequestModel);
    if (baseRequest == null || aiRequestModel == null) {
      return baseRequest;
    }

    // GLM-4.7 docs recommend explicit thinking mode for this model family.
    final modelId = (aiRequestModel.model ?? '').toLowerCase();
    if (!modelId.startsWith('glm-4.7')) {
      return baseRequest;
    }

    final rawBody = baseRequest.body;
    if (rawBody == null || rawBody.isEmpty) {
      return baseRequest;
    }

    final decoded = jsonDecode(rawBody);
    if (decoded is! Map<String, dynamic> || decoded.containsKey('thinking')) {
      return baseRequest;
    }

    decoded['thinking'] = const {'type': 'enabled'};
    return baseRequest.copyWith(body: kJsonEncoder.convert(decoded));
  }
}
