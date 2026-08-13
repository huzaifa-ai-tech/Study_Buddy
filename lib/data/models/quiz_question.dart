import 'package:equatable/equatable.dart';

/// A multiple-choice quiz question.
class QuizQuestion extends Equatable {
  const QuizQuestion({
    this.id,
    required this.materialId,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  final int? id;
  final int materialId;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'material_id': materialId,
      'question': question,
      'options': _encodeList(options),
      'correct_index': correctIndex,
      'explanation': explanation,
    };
  }

  factory QuizQuestion.fromMap(Map<String, Object?> map) {
    return QuizQuestion(
      id: map['id'] as int?,
      materialId: map['material_id'] as int,
      question: map['question'] as String,
      options: _decodeList(map['options'] as String),
      correctIndex: map['correct_index'] as int,
      explanation: map['explanation'] as String?,
    );
  }

  static String _encodeList(List<String> list) => list.join('\u0001');
  static List<String> _decodeList(String raw) =>
      raw.isEmpty ? [] : raw.split('\u0001');

  @override
  List<Object?> get props => [id, materialId, question, options, correctIndex, explanation];
}