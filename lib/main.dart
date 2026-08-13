import 'package:flutter/material.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/models/ai_settings.dart';
import 'data/repositories/study_repository.dart';
import 'data/services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.instance();
  final repository = StudyRepository(database: database);
  runApp(StudyBuddyApp(repository: repository));
  _rescheduleReminder();
}

Future<void> _rescheduleReminder() async {
  try {
    final settings = await AiSettings.load();
    if (!settings.reminderEnabled) return;
    await ReminderService.instance.init();
    await ReminderService.instance
        .scheduleDaily(settings.reminderHour, settings.reminderMinute);
  } catch (_) {
    // Reminders are best-effort; the user can re-enable them in Settings.
  }
}