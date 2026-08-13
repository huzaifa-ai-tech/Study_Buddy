import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_settings.dart';
import '../models/quiz_question.dart';
import '../models/study_plan.dart';
import 'json_utils.dart';

/// Thrown when an AI request fails (network, HTTP error, or parsing).
class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Result of a flashcard generation request.
class FlashcardGeneration {
  const FlashcardGeneration({required this.front, required this.back});

  final String front;
  final String back;
}

/// AI provider interface - implemented by [OpenAiService] and faked in tests.
abstract class AiService {
  Future<String> generateSummary(String title, String content);

  Future<List<FlashcardGeneration>> generateFlashcards(
    String title,
    String content, {
    int count = 12,
  });

  Future<List<QuizQuestion>> generateQuiz(
    String title,
    String content, {
    int count = 8,
  });

  Future<StudyPlan> generateStudyPlan(String title, String content);

  /// Answers a question about a study material, with conversation context.
  Future<String> chatWithNotes(
    String title,
    String content,
    List<({String role, String text})> history,
    String question,
  );
}

/// OpenAI-compatible chat completions client.
///
/// Works with OpenAI, OpenRouter, Groq, Together and any provider exposing the
/// `/chat/completions` API (including Gemini via its OpenAI-compatible
/// endpoint).
class OpenAiService implements AiService {
  OpenAiService(this._settings, {http.Client? client})
      : _client = client ?? http.Client();

  final AiSettings _settings;
  final http.Client _client;

  static const _timeout = Duration(seconds: 90);

  @override
  Future<String> generateSummary(String title, String content) async {
    final response = await _chat([
      {
        'role': 'system',
        'content':
            'You are a professional study assistant. Summarize the given '
                'study notes into a clear, well-structured summary. Use '
                'headings and bullet points. Keep it concise but complete.',
      },
      {
        'role': 'user',
        'content':
            'Study material: "$title"\n\nNotes:\n${_clip(content, 12000)}',
      },
    ], temperature: 0.3);
    return response;
  }

  @override
  Future<List<FlashcardGeneration>> generateFlashcards(
    String title,
    String content, {
    int count = 12,
  }) async {
    final response = await _chat([
      {
        'role': 'system',
        'content':
            'You create high-quality study flashcards. Return ONLY a JSON '
                'array, no markdown, no commentary. Format:\n'
                '[{"front": "question or term", "back": "concise answer"}]',
      },
      {
        'role': 'user',
        'content':
            'Create $count flashcards covering the most important concepts '
                'from this study material. Study material: "$title"\n\n'
                'Notes:\n${_clip(content, 12000)}',
      },
    ], temperature: 0.4, preferJson: true);

    final json = JsonUtils.extractJson(response);
    final list = json is List ? json : const [];
    if (list.isEmpty) {
      throw const AiException(
        'The AI did not return flashcards. Please try again.',
      );
    }
    return list.take(count).map((item) {
      final map = item is Map ? Map<String, dynamic>.from(item) : {};
      return FlashcardGeneration(
        front: JsonUtils.asString(map['front']),
        back: JsonUtils.asString(map['back']),
      );
    }).where((c) => c.front.isNotEmpty && c.back.isNotEmpty).toList();
  }

  @override
  Future<List<QuizQuestion>> generateQuiz(
    String title,
    String content, {
    int count = 8,
  }) async {
    final response = await _chat([
      {
        'role': 'system',
        'content':
            'You are a quiz generator. Create multiple-choice questions with '
                'exactly 4 options. Return ONLY a JSON array, no markdown. '
                'Format:\n'
                '[{"question": "text", "options": ["a", "b", "c", "d"], '
                '"correctIndex": 0, "explanation": "why"}]',
      },
      {
        'role': 'user',
        'content':
            'Create $count questions covering the most important concepts '
                'from this study material. Study material: "$title"\n\n'
                'Notes:\n${_clip(content, 12000)}',
      },
    ], temperature: 0.4, preferJson: true);

    final json = JsonUtils.extractJson(response);
    final list = json is List ? json : const [];
    if (list.isEmpty) {
      throw const AiException(
        'The AI did not return quiz questions. Please try again.',
      );
    }
    final questions = <QuizQuestion>[];
    for (final item in list.take(count)) {
      final map = item is Map ? Map<String, dynamic>.from(item) : {};
      final options = JsonUtils.asStringList(map['options']);
      if (options.length < 2) continue;
      final correctIndex = JsonUtils.asInt(map['correctIndex'],
          fallback: JsonUtils.asInt(map['correct_index']));
      questions.add(QuizQuestion(
        materialId: 0,
        question: JsonUtils.asString(map['question']),
        options: options,
        correctIndex: correctIndex.clamp(0, options.length - 1),
        explanation: JsonUtils.asString(map['explanation']),
      ));
    }
    if (questions.isEmpty) {
      throw const AiException(
        'The AI did not return valid quiz questions. Please try again.',
      );
    }
    return questions;
  }

  @override
  Future<StudyPlan> generateStudyPlan(String title, String content) async {
    final response = await _chat([
      {
        'role': 'system',
        'content':
            'You are a study coach. Create a structured study plan. '
                'Return ONLY a JSON object, no markdown. Format:\n'
                '{"title": "plan name", "items": [{"topic": "session topic", '
                '"durationMinutes": 25, "activities": ["action 1", "action 2"]}]}',
      },
      {
        'role': 'user',
        'content':
            'Create a study plan with 4-6 sessions for this study material. '
                'Study material: "$title"\n\nNotes:\n${_clip(content, 12000)}',
      },
    ], temperature: 0.5, preferJson: true);

    final json = JsonUtils.extractJson(response);
    final map = json is Map ? Map<String, dynamic>.from(json) : null;
    if (map == null || map['items'] is! List) {
      throw const AiException(
        'The AI did not return a study plan. Please try again.',
      );
    }
    final items = <PlanItem>[];
    for (final raw in (map['items'] as List).take(8)) {
      final item = raw is Map ? Map<String, dynamic>.from(raw) : null;
      if (item == null) continue;
      items.add(PlanItem(
        topic: JsonUtils.asString(item['topic']),
        durationMinutes:
            JsonUtils.asInt(item['durationMinutes'], fallback: 30),
        activities: JsonUtils.asStringList(item['activities']),
      ));
    }
    if (items.isEmpty) {
      throw const AiException(
        'The AI did not return a valid study plan. Please try again.',
      );
    }
    return StudyPlan(
      materialId: 0,
      title: JsonUtils.asString(map['title']),
      items: items,
    );
  }

  @override
  Future<String> chatWithNotes(
    String title,
    String content,
    List<({String role, String text})> history,
    String question,
  ) async {
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content':
            'You are a helpful study tutor. Answer questions using ONLY the '
                'provided study material. If the material does not contain the '
                'answer, say so and suggest what to look up. Be clear and '
                'concise.\n\nStudy material "$title":\n${_clip(content, 15000)}',
      },
      for (final entry in history.length > 8
          ? history.sublist(history.length - 8)
          : history)
        {'role': entry.role, 'content': entry.text},
      {'role': 'user', 'content': question},
    ];
    return _chat(messages, temperature: 0.4);
  }

  Future<String> _chat(
    List<Map<String, String>> messages, {
    double temperature = 0.4,
    bool preferJson = false,
  }) async {
    if (!_settings.isConfigured) {
      throw const AiException(
        'No API key configured. Add your key in Settings first.',
      );
    }

    final uri = Uri.parse('${_settings.baseUrl.trimRight()}/chat/completions');
    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_settings.apiKey.trim()}',
            },
            body: jsonEncode({
              'model': _settings.model,
              'messages': messages,
              'temperature': temperature,
              if (preferJson) 'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AiException('The AI request timed out. Please try again.');
    } catch (e) {
      throw AiException('Network error: $e');
    }

    if (response.statusCode != 200) {
      final body = _readBody(response.body);
      throw AiException(
        'AI request failed (HTTP ${response.statusCode}): $body',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      final content = decoded['choices']?[0]?['message']?['content'];
      if (content is! String || content.trim().isEmpty) {
        throw const AiException('The AI returned an empty response.');
      }
      return content.trim();
    } catch (e) {
      if (e is AiException) rethrow;
      throw const AiException('Could not read the AI response.');
    }
  }

  String _readBody(String body) {
    try {
      final decoded = jsonDecode(body);
      final message = decoded['error']?['message'] ?? decoded['message'];
      if (message is String && message.isNotEmpty) {
        return message.length > 300
            ? '${message.substring(0, 300)}...'
            : message;
      }
    } catch (_) {}
    return body.length > 200 ? '${body.substring(0, 200)}...' : body;
  }

  String _clip(String text, int maxChars) {
    final trimmed = text.trim();
    if (trimmed.length <= maxChars) return trimmed;
    return '${trimmed.substring(0, maxChars)}\n[...]';
  }
}