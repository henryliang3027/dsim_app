import 'dart:async';
import 'dart:io';
import 'package:dsim_app/core/command.dart';
import 'package:dsim_app/core/crc16_calculate.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bluetooth_enable_fork/bluetooth_enable_fork.dart';

enum ScanStatus {
  success,
  failure,
  disable,
}

class ScanReport {
  const ScanReport({
    required this.scanStatus,
    this.discoveredDevice,
  });

  final ScanStatus scanStatus;
  final DiscoveredDevice? discoveredDevice;
}

class ConnectionReport {
  const ConnectionReport({
    required this.connectionState,
    this.errorMessage = '',
  });

  final DeviceConnectionState connectionState;
  final String errorMessage;
}

class DsimRepository {
  DsimRepository() : _ble = FlutterReactiveBle() {
    _calculateCRCs();
  }
  final FlutterReactiveBle _ble;
  final scanDuration = 3; // sec
  late StreamController<ScanReport> _scanReportStreamController;
  StreamController<ConnectionReport> _connectionReportStreamController =
      StreamController<ConnectionReport>();
  StreamController<Map<String, String>> _characteristicDataStreamController =
      StreamController<Map<String, String>>();
  StreamSubscription<DiscoveredDevice>? _discoveredDeviceStreamSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionStreamSubscription;
  StreamSubscription<List<int>>? _characteristicStreamSubscription;

  final _name1 = 'ACI03170078';
  final _name2 = 'ACI01160006';
  final _aciPrefix = 'ACI';
  final _serviceId = 'ffe0';
  final _characteristicId = 'ffe1';
  final List<List<int>> _commandCollection = [];
  int _commandIndex = 0;
  final _characteristicDataKey = [
    'typeNo',
    'partNo',
  ];

  Stream<ScanReport> get scannedDevices async* {
    bool isPermissionGranted = await requestPermission();
    if (isPermissionGranted) {
      await BluetoothEnable.enableBluetooth;
      _scanReportStreamController = StreamController<ScanReport>();
      _discoveredDeviceStreamSubscription =
          _ble.scanForDevices(withServices: []).listen((device) {
        if (device.name.startsWith(_aciPrefix)) {
          if (!_scanReportStreamController.isClosed) {
            _scanReportStreamController.add(
              ScanReport(
                scanStatus: ScanStatus.success,
                discoveredDevice: device,
              ),
            );
            _connectDevice(device);
          }
        }
      }, onError: (_) {
        _scanReportStreamController.add(
          const ScanReport(
            scanStatus: ScanStatus.disable,
            discoveredDevice: null,
          ),
        );
      });
      yield* _scanReportStreamController.stream.timeout(
          Duration(
            seconds: scanDuration,
          ), onTimeout: (sink) {
        print('Stop Scanning');
        _scanReportStreamController.add(
          const ScanReport(
            scanStatus: ScanStatus.failure,
            discoveredDevice: null,
          ),
        );
      });
    } else {
      yield const ScanReport(
        scanStatus: ScanStatus.failure,
        discoveredDevice: null,
      );
    }
  }

  Stream<ConnectionReport> get connectionStateReport async* {
    yield* _connectionReportStreamController.stream;
  }

  Stream<Map<String, String>> get characteristicData async* {
    yield* _characteristicDataStreamController.stream;
  }

  Future<void> closeScanStream() async {
    print('closeScanStream');
    _scanReportStreamController.close();
    await _discoveredDeviceStreamSubscription?.cancel();
    _discoveredDeviceStreamSubscription = null;
  }

  Future<void> closeConnectionStream() async {
    print('close _characteristicStreamSubscription');

    await _characteristicStreamSubscription?.cancel();
    _characteristicStreamSubscription = null;

    // add delay to solve the following exception on ios
    // Error unsubscribing from notifications:
    // PlatformException(reactive_ble_mobile.PluginError:7, The operation couldn’t be completed.
    // (reactive_ble_mobile.PluginError error 7.), {}, null)
    await Future.delayed(const Duration(milliseconds: 1));

    print('close _connectionStreamSubscription');
    await _connectionStreamSubscription?.cancel();
    _connectionStreamSubscription = null;
  }

  void _connectDevice(DiscoveredDevice discoveredDevice) {
    print('connect to ${discoveredDevice.name}, ${discoveredDevice.id}');
    _connectionReportStreamController = StreamController<ConnectionReport>();
    _connectionStreamSubscription = _ble
        .connectToDevice(
            id: discoveredDevice.id,
            connectionTimeout: const Duration(
              seconds: 10,
            ))
        .listen((connectionStateUpdate) async {
      _connectionReportStreamController.add(ConnectionReport(
          connectionState: connectionStateUpdate.connectionState));

      if (connectionStateUpdate.connectionState ==
          DeviceConnectionState.connected) {
        // initialize _characteristicDataStreamController
        _characteristicDataStreamController =
            StreamController<Map<String, String>>();

        final qualifiedCharacteristic = QualifiedCharacteristic(
          serviceId: Uuid.parse(_serviceId),
          characteristicId: Uuid.parse(_characteristicId),
          deviceId: discoveredDevice.id,
        );

        _characteristicStreamSubscription = _ble
            .subscribeToCharacteristic(qualifiedCharacteristic)
            .listen((data) async {
          print('-----data received-----');
          print(data);

          List<int> rawData = data;
          String strData = parseRawData(rawData);
          _characteristicDataStreamController
              .add({_characteristicDataKey[_commandIndex]: strData});

          _commandIndex += 1;

          if (_commandIndex < _commandCollection.length) {
            await _ble.writeCharacteristicWithoutResponse(
              qualifiedCharacteristic,
              value: _commandCollection[_commandIndex],
            );
          } else {
            _characteristicDataStreamController.close();
          }
        });

        // start to write first command
        _commandIndex = 0;
        await _ble.writeCharacteristicWithoutResponse(
          qualifiedCharacteristic,
          value: _commandCollection[_commandIndex],
        );
      }
    }, onError: (error) {
      print('Error: $error');
      _connectionReportStreamController.add(ConnectionReport(
        connectionState: DeviceConnectionState.disconnected,
        errorMessage: error,
      ));
    });
  }

  String parseRawData(List<int> rawData) {
    switch (_commandIndex) {
      case 0:
        String typeNo = '';
        for (int i = 3; i < 15; i++) {
          typeNo += String.fromCharCode(rawData[i]);
        }
        return typeNo;
      case 1:
        String partNo = 'DSIM';
        for (int i = 3; i < 14; i++) {
          partNo += String.fromCharCode(rawData[i]);
        }
        return partNo;

      default:
        return '';
    }
  }

  void _calculateCRCs() {
    CRC16.calculateCRC16(command: Command.req00Cmd, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.req01Cmd, usDataLength: 6);
    _commandCollection.addAll([
      Command.req00Cmd,
      Command.req01Cmd,
    ]);

    print(_commandCollection[0]);
    print(_commandCollection[1]);
  }

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();

      if (statuses.values.contains(PermissionStatus.granted)) {
        return true;
      } else {
        return false;
      }
    } else if (Platform.isIOS) {
      return true;
    } else {
      // neither android nor ios
      return false;
    }
  }
}
