import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_settings.dart';
import '../../../data/repositories/study_repository.dart';
import '../../../data/services/backup_service.dart';
import '../../../data/services/reminder_service.dart';
import '../../materials/state/material_bloc.dart';
import '../state/settings_bloc.dart';

/// AI provider settings. The user brings their own API key.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const _Header(),
          const SizedBox(height: 20),
          Text(
            'AI provider',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, settingsState) => _ProviderForm(
              key: ValueKey(settingsState.settings),
              settings: settingsState.settings,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          const _ThemeSelector(),
          const SizedBox(height: 24),
          Text(
            'Study reminders',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          const _ReminderSection(),
          const SizedBox(height: 24),
          Text(
            'Backup & restore',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          const _BackupSection(),
          const SizedBox(height: 24),
          Text(
            'About',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('StudyBuddy'),
            subtitle: Text(
              'v1.0.0 · AI-powered flashcards, quizzes and study plans.\n'
              'Your notes stay on this device. The AI only receives the '
              'content you choose to generate from.',
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final settings = state.settings;
        return SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'system',
              label: Text('Auto'),
              icon: Icon(Icons.brightness_auto_rounded),
            ),
            ButtonSegment(
              value: 'light',
              label: Text('Light'),
              icon: Icon(Icons.light_mode_rounded),
            ),
            ButtonSegment(
              value: 'dark',
              label: Text('Dark'),
              icon: Icon(Icons.dark_mode_rounded),
            ),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (selection) {
            final mode = selection.first;
            context.read<SettingsBloc>().add(SettingsSaved(
                  settings.copyWith(themeMode: mode),
                ));
          },
        );
      },
    );
  }
}

class _ReminderSection extends StatefulWidget {
  const _ReminderSection();

  @override
  State<_ReminderSection> createState() => _ReminderSectionState();
}

class _ReminderSectionState extends State<_ReminderSection> {
  bool _working = false;

  Future<void> _toggle(bool enabled) async {
    final settings = context.read<SettingsBloc>().state.settings;
    final settingsBloc = context.read<SettingsBloc>();
    final messenger = ScaffoldMessenger.of(context);
    if (_working) return;
    setState(() => _working = true);
    try {
      if (enabled) {
        final granted =
            await ReminderService.instance.requestPermission();
        if (!granted) {
          if (!mounted) return;
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text('Notifications are blocked. Enable them in '
                  'phone Settings to use reminders.'),
            ));
          return;
        }
        if (!mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: settings.reminderHour,
            minute: settings.reminderMinute,
          ),
        );
        if (time == null) return;
        await ReminderService.instance
            .scheduleDaily(time.hour, time.minute);
        settingsBloc.add(SettingsSaved(settings.copyWith(
              reminderEnabled: true,
              reminderHour: time.hour,
              reminderMinute: time.minute,
            )));
      } else {
        await ReminderService.instance.cancel();
        settingsBloc.add(SettingsSaved(
              settings.copyWith(reminderEnabled: false),
            ));
      }
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not save reminder: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pickTime() async {
    final settings = context.read<SettingsBloc>().state.settings;
    final settingsBloc = context.read<SettingsBloc>();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      ),
    );
    if (time == null) return;
    await ReminderService.instance.scheduleDaily(time.hour, time.minute);
    settingsBloc.add(SettingsSaved(settings.copyWith(
          reminderEnabled: true,
          reminderHour: time.hour,
          reminderMinute: time.minute,
        )));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final settings = state.settings;
        final time = TimeOfDay(
          hour: settings.reminderHour,
          minute: settings.reminderMinute,
        );
        return Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Daily reminder',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(settings.reminderEnabled
                    ? 'Reminds you at ${time.format(context)} every day'
                    : 'Get a notification to study every day'),
                value: settings.reminderEnabled,
                onChanged: _working ? null : _toggle,
              ),
              if (settings.reminderEnabled)
                ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Reminder time'),
                  subtitle: Text(time.format(context)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _working ? null : _pickTime,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BackupSection extends StatefulWidget {
  const _BackupSection();

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  bool _working = false;

  Future<void> _export() async {
    if (_working) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    try {
      final service = BackupService(context.read<StudyRepository>());
      final file = await service.export();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'StudyBuddy backup',
          text: 'StudyBuddy backup',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _import() async {
    if (_working) return;
    final messenger = ScaffoldMessenger.of(context);
    final materialBloc = context.read<MaterialBloc>();
    final repository = context.read<StudyRepository>();
    setState(() => _working = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final service = BackupService(repository);
      final imported = await service.import(File(path));
      materialBloc.add(const MaterialsLoaded());
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            imported == 0
                ? 'Nothing new to import — that material already exists.'
                : 'Imported $imported material${imported == 1 ? '' : 's'}!',
          ),
        ));
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file_rounded),
            title: const Text('Export backup',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text(
              'Save all your materials, flashcards and quiz history '
              'as a file you can share or keep on your PC.',
            ),
            isThreeLine: true,
            trailing: _working
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            onTap: _working ? null : _export,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('Import backup',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text(
              'Restore from a StudyBuddy backup file. Existing materials '
              'are kept.',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _working ? null : _import,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.key_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Bring your own API key',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your OpenAI (or compatible) key to enable AI generation. '
            'The key is stored only on this device.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderForm extends StatefulWidget {
  const _ProviderForm({super.key, required this.settings});

  final AiSettings settings;

  @override
  State<_ProviderForm> createState() => _ProviderFormState();
}

class _ProviderFormState extends State<_ProviderForm> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.settings.apiKey);
    _baseUrlController = TextEditingController(text: widget.settings.baseUrl);
    _modelController = TextEditingController(text: widget.settings.model);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configured = _apiKeyController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _apiKeyController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'API key',
            hintText: 'sk-...',
            prefixIcon: const Icon(Icons.key_rounded),
            suffixIcon: configured
                ? Icon(Icons.check_circle_rounded, color: Colors.green)
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _baseUrlController,
          decoration: const InputDecoration(
            labelText: 'Base URL',
            prefixIcon: Icon(Icons.link_rounded),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _modelController,
          decoration: const InputDecoration(
            labelText: 'Model',
            prefixIcon: Icon(Icons.memory_rounded),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            context.read<SettingsBloc>().add(SettingsSaved(AiSettings(
                  apiKey: _apiKeyController.text.trim(),
                  baseUrl: _baseUrlController.text.trim(),
                  model: _modelController.text.trim(),
                )));
            HapticFeedback.selectionClick();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Settings saved')));
          },
          icon: const Icon(Icons.save_rounded),
          label: const Text('Save settings'),
        ),
      ],
    );
  }
}