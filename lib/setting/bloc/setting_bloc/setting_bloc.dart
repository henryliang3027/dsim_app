import 'package:dsim_app/core/form_status.dart';
import 'package:dsim_app/setting/model/location.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'setting_event.dart';
part 'setting_state.dart';

class SettingBloc extends Bloc<SettingEvent, SettingState> {
  SettingBloc() : super(const SettingState()) {
    on<GraphViewToggled>(_onGraphViewToggled);
    on<ListViewToggled>(_onListViewToggled);
    on<LocationChanged>(_onLocationChanged);
    on<LocationSubmitted>(_onLocationSubmitted);
    on<TGCCableLengthChanged>(_onTGCCableLengthChanged);
    on<LogIntervalChanged>(_onLogIntervalChanged);
  }

  void _onGraphViewToggled(
    GraphViewToggled event,
    Emitter<SettingState> emit,
  ) {
    emit(state.copyWith(
      isGraphType: true,
    ));
  }

  void _onListViewToggled(
    ListViewToggled event,
    Emitter<SettingState> emit,
  ) {
    emit(state.copyWith(
      isGraphType: false,
    ));
  }

  void _onLocationChanged(
    LocationChanged event,
    Emitter<SettingState> emit,
  ) {
    final Location location = Location.dirty(event.location);

    emit(state.copyWith(
      location: location,
    ));
  }

  void _onTGCCableLengthChanged(
    TGCCableLengthChanged event,
    Emitter<SettingState> emit,
  ) {
    Map<String, bool> newSelectedTGCCableLength = {
      '9': false,
      '18': false,
      '27': false,
    };

    newSelectedTGCCableLength[event.tgcCableLength] = true;

    emit(state.copyWith(
      selectedTGCCableLength: newSelectedTGCCableLength,
    ));
  }

  void _onLogIntervalChanged(
    LogIntervalChanged event,
    Emitter<SettingState> emit,
  ) {
    emit(state.copyWith(
      logIntervalId: event.logIntervalId,
    ));
  }

  void _onLocationSubmitted(
    LocationSubmitted event,
    Emitter<SettingState> emit,
  ) {}
}
