import 'dart:async';

import 'package:dsim_app/core/command.dart';
import 'package:dsim_app/core/form_status.dart';
import 'package:dsim_app/repositories/dsim_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_speed_chart/speed_chart.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required DsimRepository dsimRepository,
  })  : _dsimRepository = dsimRepository,
        super(const HomeState()) {
    on<SplashStateChanged>(_onSplashStateChanged);
    on<DiscoveredDeviceChanged>(_onDiscoveredDeviceChanged);
    on<DeviceRefreshed>(_onDeviceRefreshed);
    on<DeviceConnectionChanged>(_onDeviceConnectionChanged);
    on<DeviceCharacteristicChanged>(_onDeviceCharacteristicChanged);
    on<LoadingResultChanged>(_onLoadingResultChanged);
    on<DataExported>(_onDataExported);
    on<DataShared>(_onDataShared);

    add(const SplashStateChanged());
  }

  final DsimRepository _dsimRepository;
  StreamSubscription<ScanReport>? _scanStreamSubscription;
  StreamSubscription<ConnectionReport>? _connectionReportStreamSubscription;
  StreamSubscription<Map<DataKey, String>>?
      _characteristicDataStreamSubscription;

  StreamSubscription<DataKey>? _loadingResultStreamSubscription;

  // 進入首頁時播放動畫，動畫播完後掃描藍芽裝置
  Future<void> _onSplashStateChanged(
    SplashStateChanged event,
    Emitter<HomeState> emit,
  ) async {
    await Future.delayed(const Duration(seconds: 5));

    _scanStreamSubscription = _dsimRepository.scannedDevices.listen(
      (scanReport) {
        add(DiscoveredDeviceChanged(scanReport));
      },
    );

    emit(state.copyWith(
      showSplash: false,
      scanStatus: FormStatus.requestInProgress,
      connectionStatus: FormStatus.requestInProgress,
      eventRecordsLoadingStatus: FormStatus.requestInProgress,
      settingParametersLoading: FormStatus.requestInProgress,
    ));
  }

  Future<void> _onDiscoveredDeviceChanged(
    DiscoveredDeviceChanged event,
    Emitter<HomeState> emit,
  ) async {
    switch (event.scanReport.scanStatus) {
      case ScanStatus.success:
        emit(state.copyWith(
          scanStatus: FormStatus.requestSuccess,
          device: event.scanReport.discoveredDevice,
        ));

        _connectionReportStreamSubscription =
            _dsimRepository.connectionStateReport.listen((connectionReport) {
          add(DeviceConnectionChanged(connectionReport));
        });
        break;
      case ScanStatus.failure:
        emit(state.copyWith(
            scanStatus: FormStatus.requestFailure,
            connectionStatus: FormStatus.requestFailure,
            device: null,
            errorMassage: 'Device not found.'));
        break;
      case ScanStatus.disable:
        emit(state.copyWith(
            scanStatus: FormStatus.requestFailure,
            connectionStatus: FormStatus.requestFailure,
            device: null,
            errorMassage: 'Bluetooth is disabled.'));
        break;
    }

    await _dsimRepository.closeScanStream();
    await _scanStreamSubscription?.cancel();
    _scanStreamSubscription = null;
  }

  void _onDeviceConnectionChanged(
    DeviceConnectionChanged event,
    Emitter<HomeState> emit,
  ) {
    switch (event.connectionReport.connectionState) {
      case DeviceConnectionState.connecting:
        emit(state.copyWith(
          scanStatus: FormStatus.requestSuccess,
          connectionStatus: FormStatus.requestInProgress,
        ));
        break;
      case DeviceConnectionState.connected:
        emit(state.copyWith(
          scanStatus: FormStatus.requestSuccess,
          connectionStatus: FormStatus.requestSuccess,
        ));

        _characteristicDataStreamSubscription =
            _dsimRepository.characteristicData.listen(
          (data) {
            add(DeviceCharacteristicChanged(data.entries.first));
          },
          onDone: () {},
        );

        _loadingResultStreamSubscription =
            _dsimRepository.loadingResult.listen((data) {
          add(LoadingResultChanged(data));
        });

        break;
      case DeviceConnectionState.disconnecting:
        emit(state.copyWith(
          scanStatus: FormStatus.requestSuccess,
          connectionStatus: FormStatus.requestFailure,
        ));
        break;
      case DeviceConnectionState.disconnected:
        emit(state.copyWith(
          scanStatus: FormStatus.requestSuccess,
          connectionStatus: FormStatus.requestFailure,
        ));
        break;
    }
  }

  void _onDeviceCharacteristicChanged(
    DeviceCharacteristicChanged event,
    Emitter<HomeState> emit,
  ) {
    Map<DataKey, String> newCharacteristicData = {};
    newCharacteristicData.addEntries(state.characteristicData.entries);
    newCharacteristicData[event.dataMapEntry.key] = event.dataMapEntry.value;
    emit(state.copyWith(
      characteristicData: newCharacteristicData,
    ));
  }

  void _onLoadingResultChanged(
    LoadingResultChanged event,
    Emitter<HomeState> emit,
  ) {
    if (event.loadingResultDataKey == DataKey.eventRecordsLoadingComplete) {
      List<List<DateValuePair>> dateValueCollectionOfLog =
          _dsimRepository.getDateValueCollectionOfLogs();
      emit(state.copyWith(
        eventRecordsLoadingStatus: FormStatus.requestSuccess,
        dateValueCollectionOfLog: dateValueCollectionOfLog,
      ));
    } else if (event.loadingResultDataKey ==
        DataKey.settingParametersLoadingComplete) {
      emit(state.copyWith(
        settingParametersLoading: FormStatus.requestSuccess,
      ));
    } else {}
  }

  Future<void> _onDeviceRefreshed(
    DeviceRefreshed event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(
      scanStatus: FormStatus.requestInProgress,
      connectionStatus: FormStatus.requestInProgress,
      eventRecordsLoadingStatus: FormStatus.requestInProgress,
      settingParametersLoading: FormStatus.requestInProgress,
      dataExportStatus: FormStatus.none,
      device: null,
      characteristicData: const {},
    ));

    _dsimRepository.clearCache();
    print('cache cleaned');
    await _dsimRepository.closeConnectionStream();
    print('connectionStream closed');

    if (_connectionReportStreamSubscription != null) {
      await _connectionReportStreamSubscription?.cancel();
      _connectionReportStreamSubscription = null;
      print('connectionReportStreamSubscription closed');
    }

    if (_characteristicDataStreamSubscription != null) {
      await _characteristicDataStreamSubscription?.cancel();
      _characteristicDataStreamSubscription = null;
      print('_characteristicDataStreamSubscription closed');
    }

    _scanStreamSubscription =
        _dsimRepository.scannedDevices.listen((scanReport) async {
      add(DiscoveredDeviceChanged(scanReport));
    });
  }

  void _onDataExported(
    DataExported event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(
      dataShareStatus: FormStatus.none,
      dataExportStatus: FormStatus.requestInProgress,
    ));

    final List<dynamic> result = await _dsimRepository.exportRecords();

    if (result[0]) {
      emit(state.copyWith(
        dataExportStatus: FormStatus.requestSuccess,
        dataExportPath: result[1],
      ));
    } else {
      emit(state.copyWith(
        dataExportStatus: FormStatus.requestFailure,
        dataExportPath: result[1],
      ));
    }
  }

  void _onDataShared(
    DataShared event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(
      dataExportStatus: FormStatus.none,
      dataShareStatus: FormStatus.requestInProgress,
    ));

    final List<dynamic> result = await _dsimRepository.exportRecords();

    if (result[0]) {
      emit(state.copyWith(
        dataShareStatus: FormStatus.requestSuccess,
        dataExportPath: result[1],
      ));
    } else {
      emit(state.copyWith(
        dataShareStatus: FormStatus.requestFailure,
        dataExportPath: result[1],
      ));
    }
  }
}
