import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

String getMessageLocalization({
  required String msg,
  required BuildContext context,
}) {
  if (msg == 'Device not found.') {
    return AppLocalizations.of(context).dialogMaessageDeviceNotFound;
  } else if (msg == 'Bluetooth is disabled.') {
    return AppLocalizations.of(context).dialogMaessageBluetoothDisabled;
  } else {
    return msg;
  }
}
