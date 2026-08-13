import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../repositories/study_repository.dart';

/// Exports all StudyBuddy data to a shareable JSON file and restores it.
class BackupService {
  BackupService(this._repository);

  final StudyRepository _repository;

  static const _appTag = 'study_buddy';

  Future<File> export() async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    final file = File(p.join(dir.path, 'study_buddy_backup_$stamp.json'));

    final data = <String, Object?>{
      'app': _appTag,
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'materials': (await _repository.getMaterials())
          .map((m) => m.toMap())
          .toList(),
      'flashcards': (await _repository.getAllFlashcards())
          .map((c) => c.toMap())
          .toList(),
      'quiz_questions': (await _repository.getAllQuizQuestions())
          .map((q) => q.toMap())
          .toList(),
      'quiz_results': (await _repository.getAllQuizResults())
          .map((r) => r.toMap())
          .toList(),
      'study_plans': (await _repository.getAllStudyPlans())
          .map((s) => s.toMap())
          .toList(),
    };
    await file.writeAsString(jsonEncode(data));
    return file;
  }

  /// Restores a backup file. Returns the number of materials imported.
  Future<int> import(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map || decoded['app'] != _appTag) {
      throw const FormatException('Not a StudyBuddy backup file.');
    }
    List<Map<String, Object?>> asList(String key) {
      final value = decoded[key];
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }

    return _repository.restoreFromBackup(
      materials: asList('materials'),
      flashcards: asList('flashcards'),
      quizQuestions: asList('quiz_questions'),
      quizResults: asList('quiz_results'),
      studyPlans: asList('study_plans'),
    );
  }
}