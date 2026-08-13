import 'dart:convert';

import 'package:equatable/equatable.dart';

/// A generated study plan with ordered sessions.
class StudyPlan extends Equatable {
  const StudyPlan({
    this.id,
    required this.materialId,
    required this.title,
    required this.items,
    this.createdAt,
  });

  final int? id;
  final int materialId;
  final String title;
  final List<PlanItem> items;
  final DateTime? createdAt;

  int get totalMinutes =>
      items.fold(0, (sum, item) => sum + item.durationMinutes);

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'material_id': materialId,
      'title': title,
      'items': items.map((e) => jsonEncode(e.toJson())).join('\u0001'),
      'created_at': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
    };
  }

  factory StudyPlan.fromMap(Map<String, Object?> map) {
    final raw = (map['items'] as String?) ?? '';
    return StudyPlan(
      id: map['id'] as int?,
      materialId: map['material_id'] as int,
      title: map['title'] as String? ?? '',
      items: _parseItems(raw),
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : null,
    );
  }

  static List<PlanItem> _parseItems(String raw) {
    final chunks = raw
        .split('\u0001')
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (chunks.isEmpty) {
      return const [PlanItem(topic: 'Study session', durationMinutes: 30, activities: [])];
    }
    return chunks.map(_parseItem).toList();
  }

  static PlanItem _parseItem(String chunk) {
    try {
      return PlanItem.fromJson(
        (jsonDecode(chunk) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      final topic = RegExp(r'topic:\s*([^,]+)')
              .firstMatch(chunk)
              ?.group(1)
              ?.trim() ??
          '';
      final minutes = int.tryParse(
            RegExp(r'durationMinutes:\s*(\d+)').firstMatch(chunk)?.group(1) ??
                '',
          ) ??
          30;
      final activities = RegExp(r'activities:\s*\[(.*?)\]', dotAll: true)
              .firstMatch(chunk)
              ?.group(1)
              ?.split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];
      return PlanItem(
        topic: topic.isEmpty ? 'Study session' : topic,
        durationMinutes: minutes,
        activities: activities,
      );
    }
  }

  @override
  List<Object?> get props => [id, materialId, title, items, createdAt];
}

/// A single session inside a [StudyPlan].
class PlanItem extends Equatable {
  const PlanItem({
    required this.topic,
    required this.durationMinutes,
    required this.activities,
  });

  final String topic;
  final int durationMinutes;
  final List<String> activities;

  Map<String, Object?> toJson() => {
        'topic': topic,
        'durationMinutes': durationMinutes,
        'activities': activities,
      };

  factory PlanItem.fromJson(Map<String, Object?> json) => PlanItem(
        topic: (json['topic'] as String?) ?? 'Study session',
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
        activities: ((json['activities'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  @override
  List<Object?> get props => [topic, durationMinutes, activities];
}