import 'dart:async';
import 'dart:io';
import 'package:dsim_app/core/command.dart';
import 'package:dsim_app/core/crc16_calculate.dart';
import 'package:dsim_app/core/custom_style.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:location/location.dart' as GPS;
import 'package:permission_handler/permission_handler.dart';
import 'package:bluetooth_enable_fork/bluetooth_enable_fork.dart';

enum ScanStatus {
  success,
  failure,
  disable,
}

enum Alarm {
  success,
  danger,
  medium,
}

class Log {
  const Log({
    required this.time,
    required this.temperature,
    required this.attenuation,
    required this.voltage,
    required this.voltageRipple,
  });

  final int time;
  final double temperature;
  final int attenuation;
  final double voltage;
  final int voltageRipple;
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
  StreamController<Map<DataKey, String>> _characteristicDataStreamController =
      StreamController<Map<DataKey, String>>();
  StreamController<Map<DataKey, String>> _settingResultStreamController =
      StreamController<Map<DataKey, String>>();

  StreamSubscription<DiscoveredDevice>? _discoveredDeviceStreamSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionStreamSubscription;
  StreamSubscription<List<int>>? _characteristicStreamSubscription;
  late QualifiedCharacteristic _qualifiedCharacteristic;

  final _name1 = 'ACI03170078';
  final _name2 = 'ACI01160006';
  final _aciPrefix = 'ACI';
  final _serviceId = 'ffe0';
  final _characteristicId = 'ffe1';

  final List<List<int>> _commandCollection = [];
  int commandIndex = 0;
  int endIndex = 29;

  String _tempLocation = '';
  int _basicModeID = 0;
  String _basicCurrentPilot = '';
  int _basicCurrentPilotMode = 0;
  int _currentSettingMode = 0;
  int _alarmR = 0;
  int _alarmT = 0;
  int _alarmP = 0;
  String _basicInterval = '';
  final List<int> _rawLog = [];
  final int _totalBytesPerCommand = 261;
  final List<Log> _logs = [];

  Stream<ScanReport> get scannedDevices async* {
    // close connection before start scanning new device,
    // it is to solve device is not successfully disconnected after the app is closed
    await closeConnectionStream();

    GPS.Location location = GPS.Location();
    bool ison = await location.serviceEnabled();
    if (!ison) {
      //if defvice is off
      bool isTurnedOn = await location.requestService();
      if (isTurnedOn) {
        print("GPS device is turned ON");
      } else {
        print("GPS Device is still OFF");
      }
    }

    bool isPermissionGranted = await _requestPermission();
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
      }, onError: (error) {
        print('Scan Error $error');
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
      print('bluetooth disable');
      yield const ScanReport(
        scanStatus: ScanStatus.failure,
        discoveredDevice: null,
      );
    }
  }

  Stream<ConnectionReport> get connectionStateReport async* {
    yield* _connectionReportStreamController.stream;
  }

  Stream<Map<DataKey, String>> get characteristicData async* {
    yield* _characteristicDataStreamController.stream;
  }

  Stream<Map<DataKey, String>> get settingResult async* {
    yield* _settingResultStreamController.stream;
  }

  void clearCache() {
    _logs.clear();
    _rawLog.clear();
    commandIndex = 0;
    endIndex = 29;
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
            StreamController<Map<DataKey, String>>();

        // initialize _settingResultStreamController
        _settingResultStreamController =
            StreamController<Map<DataKey, String>>();

        _qualifiedCharacteristic = QualifiedCharacteristic(
          serviceId: Uuid.parse(_serviceId),
          characteristicId: Uuid.parse(_characteristicId),
          deviceId: discoveredDevice.id,
        );

        _characteristicStreamSubscription = _ble
            .subscribeToCharacteristic(_qualifiedCharacteristic)
            .listen((data) async {
          bool writeNextCommand = false;
          // print('-----# ${_commandIndex} data received-----');
          // print(data);

          List<int> rawData = data;
          print(commandIndex);

          if (commandIndex <= 13) {
            _parseRawData(rawData);
            if (commandIndex <= endIndex) {
              writeNextCommand = true;
            }
          } else if (commandIndex >= 14 && commandIndex <= 29) {
            _rawLog.addAll(rawData);
            // 一個 log command 總共會接收 261 bytes, 每一次傳回 16 bytes
            if (_rawLog.length == _totalBytesPerCommand) {
              _rawLog.removeRange(_rawLog.length - 2, _rawLog.length);
              _rawLog.removeRange(0, 3);
              _parseLog();
              _rawLog.clear();
              writeNextCommand = true;
            }
          } else if (commandIndex >= 30 && commandIndex <= 33) {
            _parseSetLocation(rawData);
          } else if (commandIndex == 34) {
            _parseSetTGCCableLength(rawData);
          }

          if (writeNextCommand) {
            if (commandIndex + 1 <= endIndex) {
              commandIndex += 1;
              await _ble.writeCharacteristicWithoutResponse(
                _qualifiedCharacteristic,
                value: _commandCollection[commandIndex],
              );
            } else {
              // print('logs length: ${_logs.length}');
              // for (Log log in _logs) {
              //   print(
              //       '${log.time}, ${log.temperature}, ${log.attenuation}, ${log.voltage}, ${log.voltageRipple}');
              // }

              // _characteristicDataStreamController.close();
            }
          }
        });

        // start to write first command
        commandIndex = 0;
        await _ble.writeCharacteristicWithoutResponse(
          _qualifiedCharacteristic,
          value: _commandCollection[commandIndex],
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

  void _parseLog() {
    for (var i = 0; i < 16; i++) {
      int time = _rawLog[i * 16] * 256 + _rawLog[i * 16 + 1];
      double temperature =
          (_rawLog[i * 16 + 2] * 256 + _rawLog[i * 16 + 3]) / 10;
      int attenuation = _rawLog[i * 16 + 4] * 256 + _rawLog[i * 16 + 5];
      double voltage = (_rawLog[i * 16 + 8] * 256 + _rawLog[i * 16 + 9]) / 10;
      int voltageRipple = _rawLog[i * 16 + 10] * 256 + _rawLog[i * 16 + 11];

      if (time < 0xFFF0) {
        //# 20210128 做2補數
        if (temperature > 32767) {
          temperature = -(65535 - temperature + 1).abs();
        }

        _logs.add(Log(
            time: time,
            temperature: temperature,
            attenuation: attenuation,
            voltage: voltage,
            voltageRipple: voltageRipple));
      }
    }

    if (commandIndex == 29) {
      // get min temperature
      double minTemperature = _logs
          .map((log) => log.temperature)
          .reduce((min, current) => min < current ? min : current);

      // get max temperature
      double maxTemperature = _logs
          .map((log) => log.temperature)
          .reduce((max, current) => max > current ? max : current);

      // get min attenuation
      int historicalMinAttenuation = _logs
          .map((log) => log.attenuation)
          .reduce((min, current) => min < current ? min : current);

      // get max attenuation
      int historicalMaxAttenuation = _logs
          .map((log) => log.attenuation)
          .reduce((max, current) => max > current ? max : current);

      // get min voltage
      double minVoltage = _logs
          .map((log) => log.voltage)
          .reduce((min, current) => min < current ? min : current);

      // get max voltage
      double maxVoltage = _logs
          .map((log) => log.voltage)
          .reduce((max, current) => max > current ? max : current);

      // get min voltage ripple
      int minVoltageRipple = _logs
          .map((log) => log.voltageRipple)
          .reduce((min, current) => min < current ? min : current);

      // get max voltage ripple
      int maxVoltageRipple = _logs
          .map((log) => log.voltageRipple)
          .reduce((max, current) => max > current ? max : current);

      String minTemperatureF =
          _convertToFahrenheit(minTemperature).toStringAsFixed(1) +
              CustomStyle.fahrenheitUnit;

      String maxTemperatureF =
          _convertToFahrenheit(maxTemperature).toStringAsFixed(1) +
              CustomStyle.fahrenheitUnit;

      String minTemperatureC =
          minTemperature.toString() + CustomStyle.celciusUnit;

      String maxTemperatureC =
          maxTemperature.toString() + CustomStyle.celciusUnit;

      _characteristicDataStreamController
          .add({DataKey.minTemperatureF: minTemperatureF});
      _characteristicDataStreamController
          .add({DataKey.maxTemperatureF: maxTemperatureF});
      _characteristicDataStreamController
          .add({DataKey.minTemperatureC: minTemperatureC});
      _characteristicDataStreamController
          .add({DataKey.maxTemperatureC: maxTemperatureC});
      _characteristicDataStreamController.add({
        DataKey.historicalMinAttenuation: historicalMinAttenuation.toString()
      });
      _characteristicDataStreamController.add({
        DataKey.historicalMaxAttenuation: historicalMaxAttenuation.toString()
      });
      _characteristicDataStreamController
          .add({DataKey.minVoltage: minVoltage.toString()});
      _characteristicDataStreamController
          .add({DataKey.maxVoltage: maxVoltage.toString()});
      _characteristicDataStreamController
          .add({DataKey.minVoltageRipple: minVoltageRipple.toString()});
      _characteristicDataStreamController
          .add({DataKey.maxVoltageRipple: maxVoltageRipple.toString()});
    }
  }

  void _parseRawData(List<int> rawData) {
    switch (commandIndex) {
      case 0:
        String typeNo = '';
        for (int i = 3; i < 15; i++) {
          typeNo += String.fromCharCode(rawData[i]);
        }
        typeNo = typeNo.trim();
        _characteristicDataStreamController.add({DataKey.typeNo: typeNo});
        break;
      case 1:
        String partNo = 'DSIM';
        for (int i = 3; i < 15; i++) {
          partNo += String.fromCharCode(rawData[i]);
        }
        partNo = partNo.trim();
        _characteristicDataStreamController.add({DataKey.partNo: partNo});
        break;
      case 2:
        String serialNumber = '';
        for (int i = 3; i < 15; i++) {
          serialNumber += String.fromCharCode(rawData[i]);
        }
        serialNumber = serialNumber.trim();
        _characteristicDataStreamController
            .add({DataKey.serialNumber: serialNumber});
        break;
      case 3:
        int number = rawData[10]; // hardware status 4 bytes last bute

        // bit 0: RF detect Max, bit 1 : RF detect Min
        _alarmR = (number & 0x01) + (number & 0x02);

        // bit 6: Temperature Max, bit 7 : Temperature Min
        _alarmT = (number & 0x40) + (number & 0x80);

        // bit 4: Voltage 24v Max, bit 5 : Voltage 24v Min
        _alarmP = (number & 0x10) + (number & 0x20);

        _basicInterval = rawData[13].toString(); //time interval

        String firmwareVersion = '';
        for (int i = 3; i < 6; i++) {
          firmwareVersion += String.fromCharCode(rawData[i]);
        }

        _characteristicDataStreamController
            .add({DataKey.logInterval: _basicInterval});

        _characteristicDataStreamController
            .add({DataKey.firmwareVersion: firmwareVersion});
        break;
      case 4:
        //MGC Value 2Bytes
        int currentAttenuator = rawData[4] * 256 + rawData[5];

        _currentSettingMode = rawData[3];

        _basicCurrentPilot = rawData[7].toString();
        _basicCurrentPilotMode = rawData[8];

        String basicTGCCableLength = rawData[6].toString();

        _characteristicDataStreamController
            .add({DataKey.currentAttenuation: currentAttenuator.toString()});
        _characteristicDataStreamController.add({DataKey.minAttenuation: '0'});
        _characteristicDataStreamController
            .add({DataKey.maxAttenuation: '3000'});
        _characteristicDataStreamController
            .add({DataKey.tgcCableLength: basicTGCCableLength});
        break;

      case 5:
        String dsimMode = '';
        String currentPilot = '';
        Alarm alarmRServerity = Alarm.medium;
        Alarm alarmTServerity = Alarm.medium;
        Alarm alarmPServerity = Alarm.medium;
        double currentTemperatureC;
        double currentTemperatureF;
        double current24V;
        String pilotMode = '';
        switch (rawData[3]) //working mode
        {
          case 1:
            {
              _basicModeID = 1;
              dsimMode = "Align";
              break;
            }
          case 2:
            {
              _basicModeID = 2;
              dsimMode = "AGC";
              break;
            }
          case 3:
            {
              _basicModeID = 3;
              dsimMode = "TGC";
              break;
            }
          case 4:
            {
              _basicModeID = 4;
              dsimMode = "MGC";
              break;
            }
        }

        if (rawData[3] > 2) {
          // medium
          alarmRServerity = Alarm.medium;
        } else {
          if (_alarmR > 0) {
            // danger
            alarmRServerity = Alarm.danger;
          } else {
            // success
            alarmRServerity = Alarm.success;
          }
        }
        if (rawData[3] == 3) {
          if (_currentSettingMode == 1 || _currentSettingMode == 2) {
            // danger
            alarmRServerity = Alarm.danger;
          }
        }

        if (alarmRServerity == Alarm.danger) {
          currentPilot = 'Loss';
        } else {
          currentPilot = _basicCurrentPilot;
          if (_basicCurrentPilotMode == 1) {
            // currentPilot += ' IRC';
            pilotMode = 'IRC';
          } else {
            // currentPilot += ' DIG';
            pilotMode = 'DIG';
          }
        }

        alarmTServerity = _alarmT > 0 ? Alarm.danger : Alarm.success;
        alarmPServerity = _alarmP > 0 ? Alarm.danger : Alarm.success;

        //Temperature
        currentTemperatureC = (rawData[10] * 256 + rawData[11]) / 10;
        currentTemperatureF = _convertToFahrenheit(currentTemperatureC);
        String strCurrentTemperatureF =
            currentTemperatureF.toStringAsFixed(1) + CustomStyle.fahrenheitUnit;
        String strCurrentTemperatureC =
            currentTemperatureC.toString() + CustomStyle.celciusUnit;

        //24V
        current24V = (rawData[8] * 256 + rawData[9]) / 10;

        _characteristicDataStreamController.add({DataKey.dsimMode: dsimMode});
        _characteristicDataStreamController
            .add({DataKey.currentPilot: currentPilot});
        _characteristicDataStreamController
            .add({DataKey.currentPilotMode: pilotMode});
        _characteristicDataStreamController
            .add({DataKey.alarmRServerity: alarmRServerity.name});
        _characteristicDataStreamController
            .add({DataKey.alarmTServerity: alarmTServerity.name});
        _characteristicDataStreamController
            .add({DataKey.alarmPServerity: alarmPServerity.name});
        _characteristicDataStreamController
            .add({DataKey.currentTemperatureF: strCurrentTemperatureF});
        _characteristicDataStreamController
            .add({DataKey.currentTemperatureC: strCurrentTemperatureC});
        _characteristicDataStreamController
            .add({DataKey.currentVoltage: current24V.toString()});

        break;
      case 6:
        int centerAttenuation = rawData[11] * 256 + rawData[12];
        int currentVoltageRipple = rawData[9] * 256 + rawData[10]; //24VR

        _characteristicDataStreamController
            .add({DataKey.centerAttenuation: centerAttenuation.toString()});
        _characteristicDataStreamController.add(
            {DataKey.currentVoltageRipple: currentVoltageRipple.toString()});

        break;
      case 7:
        // no logic
        break;
      case 8:
        // no logic
        break;
      case 9:
        for (int i = 3; i < 15; i++) {
          if (rawData[i] == 0) {
            break;
          }
          _tempLocation += String.fromCharCode(rawData[i]);
        }
        break;
      case 10:
        for (int i = 3; i < 15; i++) {
          if (rawData[i] == 0) {
            break;
          }
          _tempLocation += String.fromCharCode(rawData[i]);
        }
        break;
      case 11:
        for (int i = 3; i < 15; i++) {
          if (rawData[i] == 0) {
            break;
          }
          _tempLocation += String.fromCharCode(rawData[i]);
        }
        break;
      case 12:
        for (int i = 3; i < 7; i++) {
          if (rawData[i] == 0) {
            break;
          }
          _tempLocation += String.fromCharCode(rawData[i]);
        }

        _characteristicDataStreamController
            .add({DataKey.location: _tempLocation});

        _tempLocation = '';
        break;
      case 13:
        break;
      case 14:
        break;
      case 15:
        break;
      case 16:
        break;
      case 17:
        break;
      case 18:
        break;
      case 19:
        break;
      case 20:
        break;
      case 21:
        break;
      case 22:
        break;
      case 23:
        break;
      case 24:
        break;
      case 25:
        break;
      case 26:
        break;
      case 27:
        break;
      case 28:
        break;
      case 29:
        break;
      default:
        break;
    }
  }

  void _calculateCRCs() {
    CRC16.calculateCRC16(command: Command.req00Cmd, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.req01Cmd, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.req02Cmd, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.req03Cmd, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.req04Cmd, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.req05Cmd, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.req06Cmd, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.req07Cmd, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.req08Cmd, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.location1, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.location2, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.location3, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.location4, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.req0DCmd, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataE8, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataE9, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataEA, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataEB, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataEC, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataED, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataEE, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataEF, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataF0, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataF1, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataF2, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataF3, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataF4, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataF5, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataF6, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataF7, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataF8, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataF9, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataFA, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataFB, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataFC, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataFD, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataFE, usDataLength: 6);
    CRC16.calculateCRC16(command: Command.ddataFF, usDataLength: 6);

    _commandCollection.addAll([
      Command.req00Cmd,
      Command.req01Cmd,
      Command.req02Cmd,
      Command.req03Cmd,
      Command.req04Cmd,
      Command.req05Cmd,
      Command.req06Cmd,
      Command.req07Cmd,
      Command.req08Cmd,
      Command.location1,
      Command.location2,
      Command.location3,
      Command.location4,
      Command.req0DCmd,
      Command.ddataE8, // #14
      Command.ddataE9,
      Command.ddataEA,
      Command.ddataEB,
      Command.ddataEC,
      Command.ddataED,
      Command.ddataEE,
      Command.ddataEF,
      Command.ddataF0,
      Command.ddataF1,
      Command.ddataF2,
      Command.ddataF3,
      Command.ddataF4,
      Command.ddataF5,
      Command.ddataF6,
      Command.ddataF7, // #29
      // Command.ddataF8,
      // Command.ddataF9,
      // Command.ddataFA,
      // Command.ddataFB,
      // Command.ddataFC,
      // Command.ddataFD,
      // Command.ddataFE,
      // Command.ddataFF,
    ]);
  }

  Future<void> _parseSetTGCCableLength(List<int> rawData) async {
    if (commandIndex == 34) {
      if ((rawData[0] == 0xB0) &&
          (rawData[1] == 0x10) &&
          (rawData[2] == 0x00) &&
          (rawData[3] == 0x04) &&
          (rawData[4] == 0x00) &&
          (rawData[5] == 0x06)) {
        print('TGC cable length Set');
      }
    }
  }

  Future<void> _parseSetLocation(List<int> rawData) async {
    if (commandIndex == 30) {
      if ((rawData[0] == 0xB0) &&
          (rawData[1] == 0x10) &&
          (rawData[2] == 0x00) &&
          (rawData[3] == 0x09) &&
          (rawData[4] == 0x00) &&
          (rawData[5] == 0x06)) {
        print('Location09 Set');
        commandIndex = 31;
        await _writeSetCommandToCharacteristic(
          Command.setLocACmd,
        );
      } else {
        _characteristicDataStreamController.add({DataKey.locationSet: '0'});
      }
    } else if (commandIndex == 31) {
      if ((rawData[0] == 0xB0) &&
          (rawData[1] == 0x10) &&
          (rawData[2] == 0x00) &&
          (rawData[3] == 0x0A) &&
          (rawData[4] == 0x00) &&
          (rawData[5] == 0x06)) {
        print('Location0A Set');
        commandIndex = 32;
        await _writeSetCommandToCharacteristic(
          Command.setLocBCmd,
        );
      } else {
        _settingResultStreamController.add({DataKey.locationSet: '0'});
      }
    } else if (commandIndex == 32) {
      if ((rawData[0] == 0xB0) &&
          (rawData[1] == 0x10) &&
          (rawData[2] == 0x00) &&
          (rawData[3] == 0x0B) &&
          (rawData[4] == 0x00) &&
          (rawData[5] == 0x06)) {
        print('Location0B Set');
        commandIndex = 33;
        await _writeSetCommandToCharacteristic(
          Command.setLocCCmd,
        );
      } else {
        _settingResultStreamController.add({DataKey.locationSet: '0'});
      }
    } else if (commandIndex == 33) {
      if ((rawData[0] == 0xB0) &&
          (rawData[1] == 0x10) &&
          (rawData[2] == 0x00) &&
          (rawData[3] == 0x0C) &&
          (rawData[4] == 0x00) &&
          (rawData[5] == 0x06)) {
        print('Location0C Set');
        _settingResultStreamController.add({DataKey.locationSet: '1'});
        commandIndex = 9;
        endIndex = 12;
        await _ble.writeCharacteristicWithoutResponse(
          _qualifiedCharacteristic,
          value: _commandCollection[commandIndex],
        );
      }
    } else {
      _settingResultStreamController.add({DataKey.locationSet: '0'});
    }
  }

  Future<void> setLocation(String location) async {
    int newLength = location.length;
    int imod;
    int index;
    for (var i = 0; i < 12; i++) {
      Command.setLoc9Cmd[7 + i] = 0;
      Command.setLocACmd[7 + i] = 0;
      Command.setLocBCmd[7 + i] = 0;
      Command.setLocCCmd[7 + i] = 0;
    }

    if (newLength >= 40) newLength = 40;

    imod = newLength % 12;
    index = (newLength - imod) ~/ 12;
    if (imod > 0) index += 1;
    if (imod == 0) imod = 12;
    if (index == 4) {
      for (var i = 0; i < 12; i++) {
        Command.setLoc9Cmd[7 + i] = location.codeUnitAt(i);
      }
      for (var i = 12; i < 24; i++) {
        Command.setLocACmd[7 + i - 12] = location.codeUnitAt(i);
      }
      for (var i = 24; i < 36; i++) {
        Command.setLocBCmd[7 + i - 24] = location.codeUnitAt(i);
      }
      if (imod > 4) {
        imod = 4;
      }
      for (var i = 36; i < 36 + imod; i++) {
        Command.setLocCCmd[7 + i - 36] = location.codeUnitAt(i);
      }
    } //4
    if (index == 3) {
      for (var i = 0; i < 12; i++) {
        Command.setLoc9Cmd[7 + i] = location.codeUnitAt(i);
      }

      for (var i = 12; i < 24; i++) {
        Command.setLocACmd[7 + i - 12] = location.codeUnitAt(i);
      }
      for (var i = 24; i < 24 + imod; i++) {
        Command.setLocBCmd[7 + i - 24] = location.codeUnitAt(i);
      }
    } //3
    if (index == 2) {
      for (var i = 0; i < 12; i++) {
        Command.setLoc9Cmd[7 + i] = location.codeUnitAt(i);
      }
      for (var i = 12; i < 12 + imod; i++) {
        Command.setLocACmd[7 + i - 12] = location.codeUnitAt(i);
      }
    } //2
    if (index == 1) {
      for (var i = 0; i < imod; i++) {
        Command.setLoc9Cmd[7 + i] = location.codeUnitAt(i);
      }
    } //1

    // _calculateLocationCRCs
    CRC16.calculateCRC16(command: Command.setLoc9Cmd, usDataLength: 19);
    CRC16.calculateCRC16(command: Command.setLocACmd, usDataLength: 19);
    CRC16.calculateCRC16(command: Command.setLocBCmd, usDataLength: 19);
    CRC16.calculateCRC16(command: Command.setLocCCmd, usDataLength: 19);

    commandIndex = 30;
    endIndex = 33;

    print('set location');
    await _writeSetCommandToCharacteristic(
      Command.setLoc9Cmd,
    );
  }

  int getWorkingModeID(String workingMode) {
    switch (workingMode) {
      case 'Align':
        return 1;
      case 'AGC':
        return 2;
      case 'TGC':
        return 3;
      case 'MGC':
        return 4;
      default:
        return 2;
    }
  }

  Future<void> setTGCCableLength({
    required String workingMode,
    required int currentAttenuation,
    required int tgcCableLength,
    required int currentPilot,
    required int logIntervalID,
  }) async {
    Command.set04Cmd[7] = getWorkingModeID(workingMode); //3 TGC
    Command.set04Cmd[8] = currentAttenuation ~/ 256; //MGC Value 2Bytes
    Command.set04Cmd[9] = currentAttenuation % 256; //MGC Value
    Command.set04Cmd[10] = tgcCableLength; //TGC Cable length
    Command.set04Cmd[11] = currentPilot; //AGC Channel 1Byte
    Command.set04Cmd[12] = _basicCurrentPilotMode; //AGC channel Mode 1 Byte
    Command.set04Cmd[13] = logIntervalID; //Log Minutes 1Byte
    Command.set04Cmd[14] = 0x03; //AGC Channel 2 1Byte
    Command.set04Cmd[15] = 0x02; //AGC Channel 2 Mode 1Byte
    CRC16.calculateCRC16(command: Command.set04Cmd, usDataLength: 19);

    commandIndex = 34;
    endIndex = 34;
    _writeSetCommandToCharacteristic(Command.set04Cmd);
  } //set04CL

  // iOS 跟  Android 的 set command 方式不一樣
  Future<void> _writeSetCommandToCharacteristic(List<dynamic> value) async {
    if (Platform.isAndroid) {
      await _ble.writeCharacteristicWithResponse(
        _qualifiedCharacteristic,
        value: value,
      );
    } else if (Platform.isIOS) {
      await _ble.writeCharacteristicWithoutResponse(
        _qualifiedCharacteristic,
        value: value,
      );
    } else {}
  }

  double _convertToFahrenheit(double celcius) {
    double fahrenheit = (celcius * 1.8) + 32;
    return fahrenheit;
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.location,
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
