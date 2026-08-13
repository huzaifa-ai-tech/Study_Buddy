import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:study_buddy/data/models/ai_settings.dart';
import 'package:study_buddy/data/services/ai_service.dart';

void main() {
  const settings = AiSettings(
    apiKey: 'sk-test',
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-4o-mini',
  );

  http.Response chatResponse(String content, {int status = 200}) =>
      http.Response(
        jsonEncode({
          'choices': [
            {'message': {'content': content}},
          ],
        }),
        status,
        headers: {'content-type': 'application/json'},
      );

  test('generateFlashcards parses a JSON array', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(),
          'https://api.openai.com/v1/chat/completions');
      expect(request.headers['Authorization'], 'Bearer sk-test');
      return chatResponse(
          '[{"front": "Term", "back": "Definition"}, '
          '{"front": "X", "back": "Y"}]');
    });
    final service = OpenAiService(settings, client: client);

    final cards = await service.generateFlashcards('T', 'C');
    expect(cards, hasLength(2));
    expect(cards.first.front, 'Term');
    expect(cards.first.back, 'Definition');
  });

  test('generateQuiz parses questions with options', () async {
    final client = MockClient((request) async => chatResponse(
        '[{"question": "Q?", "options": ["a", "b", "c", "d"], '
        '"correctIndex": 2, "explanation": "because"}]'));
    final service = OpenAiService(settings, client: client);

    final questions = await service.generateQuiz('T', 'C');
    expect(questions, hasLength(1));
    expect(questions.first.correctIndex, 2);
    expect(questions.first.options, ['a', 'b', 'c', 'd']);
  });

  test('generateStudyPlan parses plan items', () async {
    final client = MockClient((request) async => chatResponse(
        '{"title": "Week 1", "items": [{"topic": "Basics", '
        '"durationMinutes": 30, "activities": ["Read", "Quiz"]}]}'));
    final service = OpenAiService(settings, client: client);

    final plan = await service.generateStudyPlan('T', 'C');
    expect(plan.title, 'Week 1');
    expect(plan.items, hasLength(1));
    expect(plan.items.first.durationMinutes, 30);
    expect(plan.totalMinutes, 30);
  });

  test('handles markdown-wrapped JSON', () async {
    final client = MockClient((request) async => chatResponse(
        '```json\n[{"front": "A", "back": "B"}]\n```'));
    final service = OpenAiService(settings, client: client);

    final cards = await service.generateFlashcards('T', 'C');
    expect(cards, hasLength(1));
  });

  test('throws AiException on HTTP error', () async {
    final client = MockClient(
        (request) async => chatResponse('{"error": {"message": "bad key"}}',
            status: 401));
    final service = OpenAiService(settings, client: client);

    expect(
      () => service.generateSummary('T', 'C'),
      throwsA(isA<AiException>().having(
          (e) => e.message, 'message', contains('401'))),
    );
  });

  test('throws when no API key is configured', () async {
    final service = OpenAiService(const AiSettings(), client: MockClient((_) async => chatResponse('')));
    expect(
      () => service.generateSummary('T', 'C'),
      throwsA(isA<AiException>().having(
          (e) => e.message, 'message', contains('API key'))),
    );
  });
}