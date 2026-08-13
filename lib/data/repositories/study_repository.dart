import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/flashcard.dart';
import '../models/quiz_question.dart';
import '../models/quiz_result.dart';
import '../models/study_material.dart';
import '../models/study_plan.dart';

/// Repository for all StudyBuddy persistence backed by SQLite.
class StudyRepository {
  // ignore: prefer_initializing_formals
  StudyRepository({Database? database}) : _database = database;

  final Database? _database;

  Future<Database> get _db async => _database ?? await AppDatabase.instance();

  // ─── Materials ────────────────────────────────────────────────

  Future<List<StudyMaterial>> getMaterials() async {
    final db = await _db;
    final rows = await db.query('materials', orderBy: 'created_at DESC');
    return rows.map(StudyMaterial.fromMap).toList();
  }

  Future<StudyMaterial?> getMaterial(int id) async {
    final db = await _db;
    final rows = await db.query('materials', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : StudyMaterial.fromMap(rows.first);
  }

  Future<int> insertMaterial(StudyMaterial material) async {
    final db = await _db;
    final now = DateTime.now();
    return db.insert(
      'materials',
      material
          .copyWith(createdAt: () => material.createdAt ?? now, updatedAt: () => now)
          .toMap(),
    );
  }

  Future<int> updateMaterial(StudyMaterial material) async {
    final db = await _db;
    return db.update(
      'materials',
      material.copyWith(updatedAt: () => DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [material.id],
    );
  }

  Future<void> deleteMaterial(int id) async {
    final db = await _db;
    await db.delete('materials', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Flashcard>> getAllFlashcards() async {
    final db = await _db;
    final rows = await db.query('flashcards');
    return rows.map(Flashcard.fromMap).toList();
  }

  Future<List<QuizQuestion>> getAllQuizQuestions() async {
    final db = await _db;
    final rows = await db.query('quiz_questions');
    return rows.map(QuizQuestion.fromMap).toList();
  }

  Future<List<QuizResult>> getAllQuizResults() async {
    final db = await _db;
    final rows = await db.query('quiz_results');
    return rows.map(QuizResult.fromMap).toList();
  }

  Future<List<StudyPlan>> getAllStudyPlans() async {
    final db = await _db;
    final rows = await db.query('study_plans');
    return rows.map(StudyPlan.fromMap).toList();
  }

  /// Restores exported data. Materials that already exist (same title and
  /// content) are skipped; returns the number of materials imported.
  Future<int> restoreFromBackup({
    required List<Map<String, Object?>> materials,
    required List<Map<String, Object?>> flashcards,
    required List<Map<String, Object?>> quizQuestions,
    required List<Map<String, Object?>> quizResults,
    required List<Map<String, Object?>> studyPlans,
  }) async {
    final db = await _db;
    var imported = 0;
    await db.transaction((txn) async {
      final idMap = <int, int>{};
      for (final raw in materials) {
        final material = StudyMaterial.fromMap(raw);
        final existing = await txn.query(
          'materials',
          columns: ['id'],
          where: 'title = ? AND content = ?',
          whereArgs: [material.title, material.content],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final existingId = existing.first['id'] as int;
          if (raw['id'] is int) idMap[raw['id'] as int] = existingId;
          continue;
        }
        final newId = await txn.insert('materials', material.toMap());
        if (raw['id'] is int) idMap[raw['id'] as int] = newId;
        imported++;
      }
      for (final raw in flashcards) {
        final newMaterialId = idMap[raw['material_id']];
        if (newMaterialId == null) continue;
        await txn.insert(
          'flashcards',
          Map.of(raw)..remove('id')..['material_id'] = newMaterialId,
        );
      }
      for (final raw in quizQuestions) {
        final newMaterialId = idMap[raw['material_id']];
        if (newMaterialId == null) continue;
        await txn.insert(
          'quiz_questions',
          Map.of(raw)..remove('id')..['material_id'] = newMaterialId,
        );
      }
      for (final raw in quizResults) {
        final newMaterialId = idMap[raw['material_id']];
        if (newMaterialId == null) continue;
        await txn.insert(
          'quiz_results',
          Map.of(raw)..remove('id')..['material_id'] = newMaterialId,
        );
      }
      for (final raw in studyPlans) {
        final newMaterialId = idMap[raw['material_id']];
        if (newMaterialId == null) continue;
        await txn.insert(
          'study_plans',
          Map.of(raw)..remove('id')..['material_id'] = newMaterialId,
        );
      }
    });
    return imported;
  }

  // ─── Flashcards ───────────────────────────────────────────────

  Future<List<Flashcard>> getFlashcards(int materialId) async {
    final db = await _db;
    final rows = await db.query(
      'flashcards',
      where: 'material_id = ?',
      whereArgs: [materialId],
    );
    return rows.map(Flashcard.fromMap).toList();
  }

  Future<List<Flashcard>> getWeakFlashcards(int materialId) async {
    final db = await _db;
    final rows = await db.query(
      'flashcards',
      where: 'material_id = ? AND mastered = 0',
      whereArgs: [materialId],
    );
    return rows.map(Flashcard.fromMap).toList();
  }

  Future<int> getFlashcardMasteredCount(int materialId) async {
    final db = await _db;
    final value = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM flashcards WHERE material_id = ? AND mastered = 1',
      [materialId],
    ));
    return value ?? 0;
  }

  Future<void> updateFlashcardMastery(int id, bool mastered) async {
    final db = await _db;
    await db.update(
      'flashcards',
      {'mastered': mastered ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> replaceFlashcards(int materialId, List<Flashcard> cards) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('flashcards', where: 'material_id = ?', whereArgs: [materialId]);
      for (final card in cards) {
        await txn.insert('flashcards', card.toMap());
      }
    });
  }

  // ─── Quiz ─────────────────────────────────────────────────────

  Future<List<QuizQuestion>> getQuizQuestions(int materialId) async {
    final db = await _db;
    final rows = await db.query(
      'quiz_questions',
      where: 'material_id = ?',
      whereArgs: [materialId],
    );
    return rows.map(QuizQuestion.fromMap).toList();
  }

  Future<List<QuizQuestion>> getQuizQuestionsByIds(
    int materialId,
    List<int> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.query(
      'quiz_questions',
      where: 'material_id = ? AND id IN ($placeholders)',
      whereArgs: [materialId, ...ids],
    );
    return rows.map(QuizQuestion.fromMap).toList();
  }

  Future<List<int>> getWrongQuestionIds(int materialId) async {
    final db = await _db;
    final rows = await db.query(
      'quiz_results',
      columns: ['wrong_ids'],
      where: 'material_id = ? AND wrong_ids IS NOT NULL',
      whereArgs: [materialId],
    );
    final ids = <int>{};
    for (final row in rows) {
      final raw = row['wrong_ids'] as String?;
      if (raw == null || raw.isEmpty) continue;
      ids.addAll(raw.split(',').where((e) => e.isNotEmpty).map(int.parse));
    }
    return ids.toList();
  }

  Future<void> replaceQuizQuestions(int materialId, List<QuizQuestion> questions) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('quiz_questions', where: 'material_id = ?', whereArgs: [materialId]);
      for (final q in questions) {
        await txn.insert('quiz_questions', q.toMap());
      }
    });
  }

  Future<List<QuizResult>> getQuizResults({int? materialId}) async {
    final db = await _db;
    final rows = await db.query(
      'quiz_results',
      where: materialId != null ? 'material_id = ?' : null,
      whereArgs: materialId != null ? [materialId] : null,
      orderBy: 'date DESC',
    );
    return rows.map(QuizResult.fromMap).toList();
  }

  Future<int> insertQuizResult(QuizResult result) async {
    final db = await _db;
    return db.insert('quiz_results', result.toMap());
  }

  // ─── Study plans ──────────────────────────────────────────────

  Future<StudyPlan?> getLatestPlan(int materialId) async {
    final db = await _db;
    final rows = await db.query(
      'study_plans',
      where: 'material_id = ?',
      whereArgs: [materialId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : StudyPlan.fromMap(rows.first);
  }

  Future<int> insertPlan(StudyPlan plan) async {
    final db = await _db;
    return db.insert('study_plans', plan.toMap());
  }

  Future<void> replacePlan(int materialId, StudyPlan plan) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('study_plans', where: 'material_id = ?', whereArgs: [materialId]);
      await txn.insert('study_plans', plan.toMap());
    });
  }

  // ─── Dashboard stats ──────────────────────────────────────────

  Future<Map<String, int>> getStats() async {
    final db = await _db;
    final materials = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM materials'),
    );
    final cards = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM flashcards'),
    );
    final quizzes = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM quiz_results'),
    );
    return {
      'materials': materials ?? 0,
      'flashcards': cards ?? 0,
      'quizzes': quizzes ?? 0,
    };
  }
}