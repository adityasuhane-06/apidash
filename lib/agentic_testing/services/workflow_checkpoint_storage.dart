import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workflow_context.dart';

const String _kAgenticWorkflowCheckpointKey =
    'agentic-testing-workflow-checkpoint-v1';

class AgenticWorkflowCheckpointStorage {
  Future<void> save(AgenticWorkflowContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kAgenticWorkflowCheckpointKey,
      jsonEncode(context.toJson()),
    );
  }

  Future<AgenticWorkflowContext?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAgenticWorkflowCheckpointKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AgenticWorkflowContext.fromJson(decoded);
      }
      if (decoded is Map) {
        return AgenticWorkflowContext.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAgenticWorkflowCheckpointKey);
  }
}
