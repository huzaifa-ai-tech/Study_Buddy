import 'package:equatable/equatable.dart';

/// A study material (notes pasted by the user or extracted from a PDF).
class StudyMaterial extends Equatable {
  const StudyMaterial({
    this.id,
    required this.title,
    required this.content,
    this.sourceType = 'text',
    this.fileName,
    this.summary,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String title;
  final String content;
  final String sourceType;
  final String? fileName;
  final String? summary;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get wordCount => content.trim().isEmpty ? 0 : content.trim().split(RegExp(r'\s+')).length;

  StudyMaterial copyWith({
    int? id,
    String? title,
    String? content,
    String? sourceType,
    String? Function()? fileName,
    String? Function()? summary,
    DateTime? Function()? createdAt,
    DateTime? Function()? updatedAt,
  }) {
    return StudyMaterial(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      sourceType: sourceType ?? this.sourceType,
      fileName: fileName != null ? fileName() : this.fileName,
      summary: summary != null ? summary() : this.summary,
      createdAt: createdAt != null ? createdAt() : this.createdAt,
      updatedAt: updatedAt != null ? updatedAt() : this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'content': content,
      'source_type': sourceType,
      'file_name': fileName,
      'summary': summary,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory StudyMaterial.fromMap(Map<String, Object?> map) {
    return StudyMaterial(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      sourceType: (map['source_type'] as String?) ?? 'text',
      fileName: map['file_name'] as String?,
      summary: map['summary'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
    );
  }

  @override
  List<Object?> get props =>
      [id, title, content, sourceType, fileName, summary, createdAt, updatedAt];
}