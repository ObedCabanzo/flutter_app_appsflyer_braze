import 'package:singular_flutter_sdk/singular.dart';
import 'package:singular_flutter_sdk/singular_config.dart';
import 'package:singular_flutter_sdk/singular_link_params.dart';

class SingularService {
  static void initializeSingularSDK(String userId) {
    SingularConfig config = SingularConfig(
      'minders_6abd2f15',
      'cd99416ad34e47acc1a79d2e22fe3f93',
    );

    config.customUserId = userId;
    config.limitDataSharing = false;
    config.shortLinkResolveTimeOut = 10.0;
    config.enableLogging = true;
    config.logLevel = 4;
    config.sessionTimeout = 60.0;

    // SKAdNetwork settings (iOS)
    config.skAdNetworkEnabled = true;
    config.manualSkanConversionManagement = false;
    config.waitForTrackingAuthorizationWithTimeoutInterval = 30;
  

    // Handler en config
    config.singularLinksHandler = (SingularLinkParams params) {
      print('========== SINGULAR DEEP LINK ==========');
      print('Deep link: ${params.deeplink}');
      print('Passthrough: ${params.passthrough}');
      print('Is deferred: ${params.isDeferred}');
      print('=========================================');
    };

    Singular.start(config);
    print('Singular SDK initialized.');
  }

  static void trackEvent(String eventName) {
    Singular.event(eventName);
    print('Event tracked: $eventName');
  }
}
