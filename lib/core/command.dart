enum DataKey {
  typeNo,
  partNo,
  serialNumber,
  firmwareVersion,
  location,
  dsimMode,
  currentPilot,
  logInterval,
  alarmRServerity,
  alarmTServerity,
  alarmPServerity,
  currentAttenuation,
  minAttenuation,
  normalAttenuation,
  maxAttenuation,
  historicalMinAttenuation,
  historicalMaxAttenuation,
  currentTemperatureF,
  minTemperatureF,
  maxTemperatureF,
  currentTemperatureC,
  minTemperatureC,
  maxTemperatureC,
  currentVoltage,
  minVoltage,
  maxVoltage,
  currentVoltageRipple,
  minVoltageRipple,
  maxVoltageRipple,
}

class Command {
  // 0xDE, 0x29
  static List<int> req00Cmd = [0xB0, 0x03, 0x00, 0x00, 0x00, 0x06, 0, 0]; //0
  static List<int> req01Cmd = [0xB0, 0x03, 0x00, 0x01, 0x00, 0x06, 0, 0]; //1
  static List<int> req02Cmd = [0xB0, 0x03, 0x00, 0x02, 0x00, 0x06, 0, 0]; //2
  static List<int> req03Cmd = [0xB0, 0x03, 0x00, 0x03, 0x00, 0x06, 0, 0]; //3
  static List<int> req04Cmd = [0xB0, 0x03, 0x00, 0x04, 0x00, 0x06, 0, 0]; //4
  static List<int> req05Cmd = [0xB0, 0x03, 0x00, 0x05, 0x00, 0x06, 0, 0]; //5
  static List<int> req06Cmd = [0xB0, 0x03, 0x00, 0x06, 0x00, 0x06, 0, 0]; //6
  static List<int> req07Cmd = [0xB0, 0x03, 0x00, 0x07, 0x00, 0x06, 0, 0]; //7
  static List<int> req08Cmd = [0xB0, 0x03, 0x00, 0x08, 0x00, 0x06, 0, 0]; //8
  static List<int> location1 = [0xB0, 0x03, 0x00, 0x09, 0x00, 0x06, 0, 0]; //9
  static List<int> location2 = [0xB0, 0x03, 0x00, 0x0A, 0x00, 0x06, 0, 0]; //10
  static List<int> location3 = [0xB0, 0x03, 0x00, 0x0B, 0x00, 0x06, 0, 0]; //11
  static List<int> location4 = [0xB0, 0x03, 0x00, 0x0C, 0x00, 0x06, 0, 0]; //12
  static List<int> req0DCmd = [0xB0, 0x03, 0x00, 0x0D, 0x00, 0x06, 0, 0]; //13

  static List<int> ddataE8 = [0xB0, 0x03, 0xE8, 0x00, 0x00, 0x80, 0, 0]; //0
  static List<int> ddataE9 = [0xB0, 0x03, 0xE9, 0x00, 0x00, 0x80, 0, 0]; //1
  static List<int> ddataEA = [0xB0, 0x03, 0xEA, 0x00, 0x00, 0x80, 0, 0]; //2
  static List<int> ddataEB = [0xB0, 0x03, 0xEB, 0x00, 0x00, 0x80, 0, 0]; //3
  static List<int> ddataEC = [0xB0, 0x03, 0xEC, 0x00, 0x00, 0x80, 0, 0]; //4
  static List<int> ddataED = [0xB0, 0x03, 0xED, 0x00, 0x00, 0x80, 0, 0]; //5
  static List<int> ddataEE = [0xB0, 0x03, 0xEE, 0x00, 0x00, 0x80, 0, 0]; //6
  static List<int> ddataEF = [0xB0, 0x03, 0xEF, 0x00, 0x00, 0x80, 0, 0]; //7

  static List<int> ddataF0 = [0xB0, 0x03, 0xF0, 0x00, 0x00, 0x80, 0, 0]; //8
  static List<int> ddataF1 = [0xB0, 0x03, 0xF1, 0x00, 0x00, 0x80, 0, 0]; //9
  static List<int> ddataF2 = [0xB0, 0x03, 0xF2, 0x00, 0x00, 0x80, 0, 0]; //10
  static List<int> ddataF3 = [0xB0, 0x03, 0xF3, 0x00, 0x00, 0x80, 0, 0]; //11
  static List<int> ddataF4 = [0xB0, 0x03, 0xF4, 0x00, 0x00, 0x80, 0, 0]; //12
  static List<int> ddataF5 = [0xB0, 0x03, 0xF5, 0x00, 0x00, 0x80, 0, 0]; //13
  static List<int> ddataF6 = [0xB0, 0x03, 0xF6, 0x00, 0x00, 0x80, 0, 0]; //14
  static List<int> ddataF7 = [0xB0, 0x03, 0xF7, 0x00, 0x00, 0x80, 0, 0]; //15
  static List<int> ddataF8 = [0xB0, 0x03, 0xF8, 0x00, 0x00, 0x80, 0, 0]; //16
  static List<int> ddataF9 = [0xB0, 0x03, 0xF9, 0x00, 0x00, 0x80, 0, 0]; //17
  static List<int> ddataFA = [0xB0, 0x03, 0xFA, 0x00, 0x00, 0x80, 0, 0]; //18
  static List<int> ddataFB = [0xB0, 0x03, 0xFB, 0x00, 0x00, 0x80, 0, 0]; //19
  static List<int> ddataFC = [0xB0, 0x03, 0xFC, 0x00, 0x00, 0x80, 0, 0]; //20
  static List<int> ddataFD = [0xB0, 0x03, 0xFD, 0x00, 0x00, 0x80, 0, 0]; //21
  static List<int> ddataFE = [0xB0, 0x03, 0xFE, 0x00, 0x00, 0x80, 0, 0]; //22
  static List<int> ddataFF = [0xB0, 0x03, 0xFF, 0x00, 0x00, 0x80, 0, 0]; //23

  static List<int> set04Cmd = [
    0xB0,
    0x10,
    0x00,
    0x04,
    0x00,
    0x06,
    0x0C,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00
  ]; // set 04
  static List<int> setLoc9Cmd = [
    0xB0,
    0x10,
    0x00,
    0x09,
    0x00,
    0x06,
    0x0C,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00
  ];
  static List<int> setLocACmd = [
    0xB0,
    0x10,
    0x00,
    0x0A,
    0x00,
    0x06,
    0x0C,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00
  ];
  static List<int> setLocBCmd = [
    0xB0,
    0x10,
    0x00,
    0x0B,
    0x00,
    0x06,
    0x0C,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00
  ];
  static List<int> setLocCCmd = [
    0xB0,
    0x10,
    0x00,
    0x0C,
    0x00,
    0x06,
    0x0C,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00
  ];
}
