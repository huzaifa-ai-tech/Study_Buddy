import 'package:equatable/equatable.dart';

/// A completed quiz attempt.
class QuizResult extends Equatable {
  const QuizResult({
    this.id,
    required this.materialId,
    required this.total,
    required this.correct,
    this.date,
    this.wrongIds = const [],
  });

  final int? id;
  final int materialId;
  final int total;
  final int correct;
  final DateTime? date;
  final List<int> wrongIds;

  double get score => total == 0 ? 0 : correct / total;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'material_id': materialId,
      'total': total,
      'correct': correct,
      'date': (date ?? DateTime.now()).millisecondsSinceEpoch,
      'wrong_ids': wrongIds.isEmpty ? null : wrongIds.join(','),
    };
  }

  factory QuizResult.fromMap(Map<String, Object?> map) {
    return QuizResult(
      id: map['id'] as int?,
      materialId: map['material_id'] as int,
      total: map['total'] as int,
      correct: map['correct'] as int,
      date: map['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date'] as int)
          : null,
      wrongIds: (map['wrong_ids'] as String?)
              ?.split(',')
              .where((e) => e.isNotEmpty)
              .map(int.parse)
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [id, materialId, total, correct, date, wrongIds];
}