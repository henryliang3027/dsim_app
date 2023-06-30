part of 'home_bloc.dart';

class HomeState extends Equatable {
  const HomeState({
    this.scanStatus = FormStatus.none,
    this.connectionStatus = FormStatus.none,
    this.submissionStatus = SubmissionStatus.none,
    this.eventRecordsLoadingStatus = FormStatus.none,
    this.settingParametersLoading = FormStatus.none,
    this.dataExportStatus = FormStatus.none,
    this.dataShareStatus = FormStatus.none,
    this.showSplash = true,
    this.device,
    this.characteristicData = const {},
    // this.settingResultData = const {
    //   DataKey.locationSet: '-1',
    //   DataKey.tgcCableLengthSet: '-1',
    //   DataKey.logIntervalSet: '-1',
    // },
    this.errorMassage = '',
    this.dataExportPath = '',
    this.dateValueCollectionOfLog = const [],
  });

  final FormStatus scanStatus;
  final FormStatus connectionStatus;
  final FormStatus eventRecordsLoadingStatus;
  final FormStatus settingParametersLoading;
  final FormStatus dataExportStatus;
  final FormStatus dataShareStatus;
  final SubmissionStatus submissionStatus;
  final bool showSplash;
  final DiscoveredDevice? device;
  final Map<DataKey, String> characteristicData;
  // final Map<DataKey, String> settingResultData;
  final String errorMassage;
  final String dataExportPath;
  final List<List<DateValuePair>> dateValueCollectionOfLog;

  HomeState copyWith({
    FormStatus? scanStatus,
    FormStatus? connectionStatus,
    FormStatus? eventRecordsLoadingStatus,
    FormStatus? settingParametersLoading,
    FormStatus? dataExportStatus,
    FormStatus? dataShareStatus,
    SubmissionStatus? submissionStatus,
    bool? showSplash,
    DiscoveredDevice? device,
    Map<DataKey, String>? characteristicData,
    // Map<DataKey, String>? settingResultData,
    String? errorMassage,
    String? dataExportPath,
    List<List<DateValuePair>>? dateValueCollectionOfLog,
  }) {
    return HomeState(
      scanStatus: scanStatus ?? this.scanStatus,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      eventRecordsLoadingStatus:
          eventRecordsLoadingStatus ?? this.eventRecordsLoadingStatus,
      settingParametersLoading:
          settingParametersLoading ?? this.settingParametersLoading,
      dataExportStatus: dataExportStatus ?? this.dataExportStatus,
      dataShareStatus: dataShareStatus ?? this.dataShareStatus,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      showSplash: showSplash ?? this.showSplash,
      device: device ?? this.device,
      characteristicData: characteristicData ?? this.characteristicData,
      // settingResultData: settingResultData ?? this.settingResultData,
      errorMassage: errorMassage ?? this.errorMassage,
      dataExportPath: dataExportPath ?? this.dataExportPath,
      dateValueCollectionOfLog:
          dateValueCollectionOfLog ?? this.dateValueCollectionOfLog,
    );
  }

  @override
  List<Object?> get props => [
        scanStatus,
        connectionStatus,
        eventRecordsLoadingStatus,
        settingParametersLoading,
        dataExportStatus,
        dataShareStatus,
        submissionStatus,
        showSplash,
        device,
        characteristicData,
        // settingResultData,
        errorMassage,
        dataExportPath,
        dateValueCollectionOfLog,
      ];
}
