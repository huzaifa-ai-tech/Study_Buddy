import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/ai_settings.dart';

class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class SettingsLoaded extends SettingsEvent {
  const SettingsLoaded();
}

class SettingsSaved extends SettingsEvent {
  const SettingsSaved(this.settings);

  final AiSettings settings;

  @override
  List<Object?> get props => [settings];
}

class SettingsState extends Equatable {
  const SettingsState({
    this.settings = const AiSettings(),
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final AiSettings settings;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  SettingsState copyWith({
    AiSettings? settings,
    bool? isLoading,
    bool? isSaving,
    String? Function()? errorMessage,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [settings, isLoading, isSaving, errorMessage];
}

/// Holds AI settings and keeps an external [ValueNotifier] in sync so the
/// AI service can read the latest configuration without re-creating providers.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({required this.settingsNotifier}) : super(const SettingsState()) {
    on<SettingsLoaded>(_onLoaded);
    on<SettingsSaved>(_onSaved);
  }

  final ValueNotifier<AiSettings> settingsNotifier;

  Future<void> _onLoaded(SettingsLoaded event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isLoading: true));
    final settings = await AiSettings.load();
    settingsNotifier.value = settings;
    emit(state.copyWith(isLoading: false, settings: settings));
  }

  Future<void> _onSaved(SettingsSaved event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isSaving: true, errorMessage: () => null));
    try {
      final saved = await event.settings.save();
      settingsNotifier.value = saved;
      emit(state.copyWith(isSaving: false, settings: saved));
    } catch (e) {
      emit(state.copyWith(
        isSaving: false,
        errorMessage: () => 'Could not save settings: $e',
      ));
    }
  }
}