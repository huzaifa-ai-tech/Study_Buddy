import 'dart:convert';

/// Helpers for extracting structured data from LLM responses.
class JsonUtils {
  JsonUtils._();

  /// Extracts the first JSON array or object from [text], tolerating
  /// markdown fences, code blocks and surrounding prose.
  static dynamic extractJson(String text) {
    final stripped = text
        .replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '')
        .replaceAll('```', '');
    final trimmed = stripped.trim();
    if (trimmed.isEmpty) return null;

    final firstBracket = trimmed.indexOf('[');
    final firstBrace = trimmed.indexOf('{');
    final String? startChar;
    if (firstBracket < 0 && firstBrace < 0) return null;
    if (firstBrace < 0) {
      startChar = '[';
    } else if (firstBracket < 0) {
      startChar = '{';
    } else {
      startChar = firstBracket < firstBrace ? '[' : '{';
    }

    final start = trimmed.indexOf(startChar);
    for (var depth = 0, i = start; i < trimmed.length; i++) {
      final c = trimmed[i];
      if (c == startChar) depth++;
      if (c == (startChar == '[' ? ']' : '}')) {
        depth--;
        if (depth == 0) {
          final candidate = trimmed.substring(start, i + 1);
          try {
            return jsonDecode(candidate);
          } catch (_) {
            break;
          }
        }
      }
    }
    return null;
  }

  static String asString(dynamic value) => value?.toString().trim() ?? '';

  static int asInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  static List<String> asStringList(dynamic value) {
    if (value is List) return value.map((e) => asString(e)).toList();
    return const [];
  }
}