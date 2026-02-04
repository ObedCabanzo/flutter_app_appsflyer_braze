import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

Future<void> obtenerIDFV() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    String? idfv = iosInfo.identifierForVendor; // Este es el IDFV
    print('IDFV del Simulador: $idfv');
  } else {
    print('Esta plataforma no soporta IDFV');
  }
}