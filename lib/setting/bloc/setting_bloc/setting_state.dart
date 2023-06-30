part of 'setting_bloc.dart';

class SettingState extends Equatable {
  const SettingState({
    this.submissionStatus = SubmissionStatus.none,
    this.initialValues = const [],
    this.location = const Location.pure(),
    this.isGraphType = false,
    this.selectedTGCCableLength = const {
      '9': false,
      '18': false,
      '27': false,
    },
    this.selectedWorkingMode = const {
      'MGC': false,
      'AGC': false,
      'TGC': false,
    },
    this.logIntervalId = 1,
    this.pilotCode = '',
    this.pilotChannel = '',
    this.pilotMode = '',
    this.maxAttenuation = 3000,
    this.minAttenuation = 0,
    this.currentAttenuation = 0,
    this.centerAttenuation = 0,
    this.editMode = false,
    this.isInitialize = false,
  });

  final SubmissionStatus submissionStatus;
  final List<dynamic> initialValues;
  final Location location;
  final bool isGraphType;
  final Map<String, bool> selectedTGCCableLength;
  final Map<String, bool> selectedWorkingMode;
  final int logIntervalId;
  final String pilotCode;
  final String pilotChannel;
  final String pilotMode;
  final int maxAttenuation;
  final int minAttenuation;
  final int currentAttenuation;
  final int centerAttenuation;
  final bool editMode;
  final bool isInitialize;

  SettingState copyWith({
    SubmissionStatus? submissionStatus,
    List<dynamic>? initialValues,
    Location? location,
    bool? isGraphType,
    Map<String, bool>? selectedTGCCableLength,
    Map<String, bool>? selectedWorkingMode,
    int? logIntervalId,
    String? pilotCode,
    String? pilotChannel,
    String? pilotMode,
    int? maxAttenuation,
    int? minAttenuation,
    int? currentAttenuation,
    int? centerAttenuation,
    bool? editMode,
    bool? isInitialize,
  }) {
    return SettingState(
      submissionStatus: submissionStatus ?? this.submissionStatus,
      initialValues: initialValues ?? this.initialValues,
      location: location ?? this.location,
      isGraphType: isGraphType ?? this.isGraphType,
      selectedTGCCableLength:
          selectedTGCCableLength ?? this.selectedTGCCableLength,
      selectedWorkingMode: selectedWorkingMode ?? this.selectedWorkingMode,
      logIntervalId: logIntervalId ?? this.logIntervalId,
      pilotCode: pilotCode ?? this.pilotCode,
      pilotChannel: pilotChannel ?? this.pilotChannel,
      pilotMode: pilotMode ?? this.pilotMode,
      maxAttenuation: maxAttenuation ?? this.maxAttenuation,
      minAttenuation: minAttenuation ?? this.minAttenuation,
      currentAttenuation: currentAttenuation ?? this.currentAttenuation,
      centerAttenuation: centerAttenuation ?? this.centerAttenuation,
      editMode: editMode ?? this.editMode,
      isInitialize: isInitialize ?? this.isInitialize,
    );
  }

  @override
  List<Object?> get props => [
        submissionStatus,
        initialValues,
        location,
        isGraphType,
        selectedTGCCableLength,
        selectedWorkingMode,
        logIntervalId,
        pilotCode,
        pilotChannel,
        pilotMode,
        maxAttenuation,
        minAttenuation,
        currentAttenuation,
        centerAttenuation,
        editMode,
        isInitialize,
      ];
}
