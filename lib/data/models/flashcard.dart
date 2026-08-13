import 'package:equatable/equatable.dart';

/// A single flashcard (front question, back answer).
class Flashcard extends Equatable {
  const Flashcard({
    this.id,
    required this.materialId,
    required this.front,
    required this.back,
    this.mastered = false,
  });

  final int? id;
  final int materialId;
  final String front;
  final String back;
  final bool mastered;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'material_id': materialId,
      'front': front,
      'back': back,
      'mastered': mastered ? 1 : 0,
    };
  }

  factory Flashcard.fromMap(Map<String, Object?> map) {
    return Flashcard(
      id: map['id'] as int?,
      materialId: map['material_id'] as int,
      front: map['front'] as String,
      back: map['back'] as String,
      mastered: (map['mastered'] as int? ?? 0) == 1,
    );
  }

  @override
  List<Object?> get props => [id, materialId, front, back, mastered];
}