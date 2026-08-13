import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/study_material.dart';
import '../../../data/repositories/study_repository.dart';

class MaterialEvent extends Equatable {
  const MaterialEvent();

  @override
  List<Object?> get props => [];
}

class MaterialsLoaded extends MaterialEvent {
  const MaterialsLoaded();
}

class MaterialAdded extends MaterialEvent {
  const MaterialAdded(this.material);

  final StudyMaterial material;

  @override
  List<Object?> get props => [material];
}

class MaterialDeleted extends MaterialEvent {
  const MaterialDeleted(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

class MaterialSummaryUpdated extends MaterialEvent {
  const MaterialSummaryUpdated(this.material);

  final StudyMaterial material;

  @override
  List<Object?> get props => [material];
}

class MaterialEdited extends MaterialEvent {
  const MaterialEdited(this.material);

  final StudyMaterial material;

  @override
  List<Object?> get props => [material];
}

enum MaterialStatus { initial, loading, success, failure }

class MaterialsState extends Equatable {
  const MaterialsState({
    this.status = MaterialStatus.initial,
    this.materials = const [],
    this.stats = const {},
    this.errorMessage,
  });

  final MaterialStatus status;
  final List<StudyMaterial> materials;
  final Map<String, int> stats;
  final String? errorMessage;

  MaterialsState copyWith({
    MaterialStatus? status,
    List<StudyMaterial>? materials,
    Map<String, int>? stats,
    String? Function()? errorMessage,
  }) {
    return MaterialsState(
      status: status ?? this.status,
      materials: materials ?? this.materials,
      stats: stats ?? this.stats,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, materials, stats, errorMessage];
}

class MaterialBloc extends Bloc<MaterialEvent, MaterialsState> {
  // ignore: prefer_initializing_formals
  MaterialBloc({required StudyRepository repository}) : _repository = repository,
        super(const MaterialsState()) {
    on<MaterialsLoaded>(_onLoaded);
    on<MaterialAdded>(_onAdded);
    on<MaterialDeleted>(_onDeleted);
    on<MaterialSummaryUpdated>(_onSummaryUpdated);
    on<MaterialEdited>(_onEdited);
  }

  final StudyRepository _repository;

  Future<void> _onLoaded(MaterialsLoaded event, Emitter<MaterialsState> emit) async {
    emit(state.copyWith(status: MaterialStatus.loading));
    try {
      final materials = await _repository.getMaterials();
      final stats = await _repository.getStats();
      emit(state.copyWith(
        status: MaterialStatus.success,
        materials: materials,
        stats: stats,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: MaterialStatus.failure,
        errorMessage: () => '$e',
      ));
    }
  }

  Future<void> _onAdded(MaterialAdded event, Emitter<MaterialsState> emit) async {
    try {
      await _repository.insertMaterial(event.material);
      await _reload(emit);
    } catch (e) {
      emit(state.copyWith(errorMessage: () => '$e'));
    }
  }

  Future<void> _onDeleted(MaterialDeleted event, Emitter<MaterialsState> emit) async {
    try {
      await _repository.deleteMaterial(event.id);
      await _reload(emit);
    } catch (e) {
      emit(state.copyWith(errorMessage: () => '$e'));
    }
  }

  Future<void> _onSummaryUpdated(
    MaterialSummaryUpdated event,
    Emitter<MaterialsState> emit,
  ) async {
    await _update(event.material, emit);
  }

  Future<void> _onEdited(
    MaterialEdited event,
    Emitter<MaterialsState> emit,
  ) async {
    await _update(event.material, emit);
  }

  Future<void> _update(StudyMaterial material, Emitter<MaterialsState> emit) async {
    try {
      await _repository.updateMaterial(material);
      await _reload(emit);
    } catch (e) {
      emit(state.copyWith(errorMessage: () => '$e'));
    }
  }

  Future<void> _reload(Emitter<MaterialsState> emit) async {
    final materials = await _repository.getMaterials();
    final stats = await _repository.getStats();
    emit(state.copyWith(
      status: MaterialStatus.success,
      materials: materials,
      stats: stats,
    ));
  }
}