import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LLM provider configuration plus app preferences (theme, reminders).
class AiSettings extends Equatable {
  const AiSettings({
    this.apiKey = '',
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o-mini',
    this.themeMode = 'system',
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
  });

  final String apiKey;
  final String baseUrl;
  final String model;
  final String themeMode;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  AiSettings copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
    String? themeMode,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      themeMode: themeMode ?? this.themeMode,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }

  static const _kApiKey = 'ai_api_key';
  static const _kBaseUrl = 'ai_base_url';
  static const _kModel = 'ai_model';
  static const _kThemeMode = 'app_theme_mode';
  static const _kReminderEnabled = 'reminder_enabled';
  static const _kReminderHour = 'reminder_hour';
  static const _kReminderMinute = 'reminder_minute';

  Future<AiSettings> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKey, apiKey);
    await prefs.setString(_kBaseUrl, baseUrl);
    await prefs.setString(_kModel, model);
    await prefs.setString(_kThemeMode, themeMode);
    await prefs.setBool(_kReminderEnabled, reminderEnabled);
    await prefs.setInt(_kReminderHour, reminderHour);
    await prefs.setInt(_kReminderMinute, reminderMinute);
    return this;
  }

  static Future<AiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AiSettings(
      apiKey: prefs.getString(_kApiKey) ?? '',
      baseUrl: prefs.getString(_kBaseUrl) ?? 'https://api.openai.com/v1',
      model: prefs.getString(_kModel) ?? 'gpt-4o-mini',
      themeMode: prefs.getString(_kThemeMode) ?? 'system',
      reminderEnabled: prefs.getBool(_kReminderEnabled) ?? false,
      reminderHour: prefs.getInt(_kReminderHour) ?? 20,
      reminderMinute: prefs.getInt(_kReminderMinute) ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        apiKey,
        baseUrl,
        model,
        themeMode,
        reminderEnabled,
        reminderHour,
        reminderMinute,
      ];
}