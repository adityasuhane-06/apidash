import 'dart:convert';

/// Lightweight JSON parser helper to avoid adding dependencies.
/// Intended for parsing AI agent structured outputs that may be wrapped
/// in markdown code fences or include extra prose.
class MessageJson {
  static Map<String, dynamic> safeParse(String input) {
    final candidates = <String>[input];
    final sliced = _sliceFirstJsonObject(input);
    if (sliced != null && sliced != input) {
      candidates.add(sliced);
    }

    for (final candidate in candidates) {
      try {
        return _parseJson(candidate);
      } catch (_) {
        final repaired = _repairCommonJsonIssues(candidate);
        if (repaired == candidate) {
          continue;
        }
        try {
          return _parseJson(repaired);
        } catch (_) {
          // Try next candidate.
        }
      }
    }
    throw const FormatException('Invalid JSON');
  }

  static Map<String, dynamic> _parseJson(String s) {
    final decoded = jsonDecode(s);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is String) {
      final nested = jsonDecode(decoded);
      if (nested is Map<String, dynamic>) {
        return nested;
      }
      if (nested is Map) {
        return Map<String, dynamic>.from(nested);
      }
    }
    return {};
  }

  static String? _sliceFirstJsonObject(String input) {
    final start = input.indexOf('{');
    final end = input.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      return null;
    }
    return input.substring(start, end + 1);
  }

  static String _repairCommonJsonIssues(String input) {
    final sb = StringBuffer();
    var inString = false;
    var escaped = false;
    var changed = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (!inString) {
        sb.write(char);
        if (char == '"') {
          inString = true;
          escaped = false;
        }
        continue;
      }

      if (escaped) {
        if (!_isJsonEscapeChar(char)) {
          // Keep the original backslash and escape it so invalid \x becomes \\x.
          sb.write('\\');
          changed = true;
        }
        sb.write(char);
        escaped = false;
        continue;
      }

      if (char == '\\') {
        sb.write(char);
        escaped = true;
        continue;
      }

      if (char == '"') {
        sb.write(char);
        inString = false;
        continue;
      }

      if (char == '\n') {
        sb.write(r'\n');
        changed = true;
        continue;
      }
      if (char == '\r') {
        sb.write(r'\r');
        changed = true;
        continue;
      }
      if (char == '\t') {
        sb.write(r'\t');
        changed = true;
        continue;
      }

      sb.write(char);
    }

    if (escaped) {
      sb.write('\\');
      changed = true;
    }

    return changed ? sb.toString() : input;
  }

  static bool _isJsonEscapeChar(String char) {
    return char == '"' ||
        char == '\\' ||
        char == '/' ||
        char == 'b' ||
        char == 'f' ||
        char == 'n' ||
        char == 'r' ||
        char == 't' ||
        char == 'u';
  }
}
