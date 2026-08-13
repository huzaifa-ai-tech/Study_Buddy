import 'package:flutter_test/flutter_test.dart';
import 'package:study_buddy/data/models/study_plan.dart';

void main() {
  group('StudyPlan', () {
    test('toMap writes valid JSON that fromMap can read back', () {
      final plan = StudyPlan(
        id: 1,
        materialId: 2,
        title: 'My plan',
        items: const [
          PlanItem(
            topic: 'Photosynthesis',
            durationMinutes: 25,
            activities: ['Memorize equation', 'Diagram reactions'],
          ),
          PlanItem(
            topic: 'Respiration',
            durationMinutes: 30,
            activities: ['Review Krebs cycle'],
          ),
        ],
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );

      final restored = StudyPlan.fromMap(plan.toMap());

      expect(restored.id, 1);
      expect(restored.materialId, 2);
      expect(restored.title, 'My plan');
      expect(restored.items.length, 2);
      expect(restored.items[0].topic, 'Photosynthesis');
      expect(restored.items[0].durationMinutes, 25);
      expect(restored.items[0].activities,
          ['Memorize equation', 'Diagram reactions']);
      expect(restored.items[1].topic, 'Respiration');
      expect(restored.createdAt,
          DateTime.fromMillisecondsSinceEpoch(1000));
    });

    test('fromMap salvages legacy unquoted map format without throwing', () {
      const legacy = '{topic: Photosynthesis Basics & Light, '
          'durationMinutes: 25, activities: [Memorize the equation, '
          'Diagram reactions, Review photolysis]}\u0001'
          '{topic: Calvin Cycle, durationMinutes: 30, activities: [Study]';

      final plan = StudyPlan.fromMap({
        'id': 7,
        'material_id': 1,
        'title': 'Legacy plan',
        'items': legacy,
        'created_at': 1000,
      });

      expect(plan.items.length, 2);
      expect(plan.items[0].topic, 'Photosynthesis Basics & Light');
      expect(plan.items[0].durationMinutes, 25);
      expect(plan.items[0].activities.length, 3);
      expect(plan.items[1].topic, 'Calvin Cycle');
      expect(plan.items[1].durationMinutes, 30);
    });

    test('fromMap returns a default session for empty items', () {
      final plan = StudyPlan.fromMap({
        'id': 1,
        'material_id': 1,
        'title': 'Empty plan',
        'items': '',
        'created_at': null,
      });

      expect(plan.items.length, 1);
      expect(plan.items.first.topic, 'Study session');
      expect(plan.items.first.durationMinutes, 30);
    });
  });
}
