import 'package:flutter/services.dart';

class DeepLinkHandler {
  static const _channel = MethodChannel('com.example.app/deeplink');

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final String uri = call.arguments;
        print('=> [Flutter] Deep link received: $uri');
        // Aquí puedes procesar el deep link o pasarlo a AppsFlyer
      }
    });
  }
}