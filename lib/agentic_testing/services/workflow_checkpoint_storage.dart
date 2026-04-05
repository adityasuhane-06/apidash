import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workflow_context.dart';

const String _kAgenticWorkflowCheckpointLegacyKey =
    'agentic-testing-workflow-checkpoint-v1';
const String _kAgenticWorkflowCheckpointSessionPrefix =
    'agentic-testing-workflow-checkpoint-v2::';

class AgenticWorkflowCheckpointStorage {
  static const String defaultSessionKey = 'global';

  static String normalizeSessionKey(String? sessionKey) {
    final normalized = sessionKey?.trim();
    if (normalized == null || normalized.isEmpty) {
      return defaultSessionKey;
    }
    return normalized;
  }

  String _keyForSession(String sessionKey) {
    return '$_kAgenticWorkflowCheckpointSessionPrefix$sessionKey';
  }

  Future<void> save(AgenticWorkflowContext context) async {
    await _saveToKey(_kAgenticWorkflowCheckpointLegacyKey, context);
  }

  Future<void> saveForSession({
    required String sessionKey,
    required AgenticWorkflowContext context,
  }) async {
    final normalized = normalizeSessionKey(sessionKey);
    if (normalized == defaultSessionKey) {
      await save(context);
      return;
    }
    await _saveToKey(_keyForSession(normalized), context);
  }

  Future<void> _saveToKey(String key, AgenticWorkflowContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(context.toJson()));
  }

  Future<AgenticWorkflowContext?> load() async {
    return _loadFromKey(_kAgenticWorkflowCheckpointLegacyKey);
  }

  Future<AgenticWorkflowContext?> loadForSession({
    required String sessionKey,
  }) async {
    final normalized = normalizeSessionKey(sessionKey);
    if (normalized == defaultSessionKey) {
      return load();
    }

    final scoped = await _loadFromKey(_keyForSession(normalized));
    if (scoped != null) {
      return scoped;
    }

    final legacy = await load();
    if (legacy != null) {
      // One-time migration path for users upgrading from v1 global storage.
      await saveForSession(sessionKey: normalized, context: legacy);
      await clear();
    }
    return legacy;
  }

  Future<AgenticWorkflowContext?> _loadFromKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return _decodeContext(raw);
  }

  AgenticWorkflowContext? _decodeContext(String raw) {
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
    await _clearKey(_kAgenticWorkflowCheckpointLegacyKey);
  }

  Future<void> clearForSession({required String sessionKey}) async {
    final normalized = normalizeSessionKey(sessionKey);
    if (normalized == defaultSessionKey) {
      await clear();
      return;
    }
    await _clearKey(_keyForSession(normalized));
  }

  Future<void> _clearKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
