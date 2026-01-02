import 'dart:async';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Datos parseados de un deep link
class DeepLinkData {
  final String? deepLinkValue;
  final String? campaign;
  final String? mediaSource;
  final Map<String, dynamic>? customParams;
  final bool isDeferred;
  final String? matchType;
  final String? rawLink;

  DeepLinkData({
    this.deepLinkValue,
    this.campaign,
    this.mediaSource,
    this.customParams,
    this.isDeferred = false,
    this.matchType,
    this.rawLink,
  });

  /// Obtiene un parámetro custom
  T? getParam<T>(String key) {
    return customParams?[key] as T?;
  }

  @override
  String toString() {
    return 'DeepLinkData(deepLinkValue: $deepLinkValue, campaign: $campaign, '
        'mediaSource: $mediaSource, isDeferred: $isDeferred, matchType: $matchType)';
  }
}

/// Resultado de la atribución de instalación
class InstallAttributionData {
  final String? mediaSource;
  final String? campaign;
  final String? adGroup;
  final String? adSet;
  final bool isOrganic;
  final Map<String, dynamic> rawData;

  InstallAttributionData({
    this.mediaSource,
    this.campaign,
    this.adGroup,
    this.adSet,
    required this.isOrganic,
    required this.rawData,
  });

  @override
  String toString() {
    return 'InstallAttributionData(mediaSource: $mediaSource, campaign: $campaign, isOrganic: $isOrganic)';
  }
}

class AppsFlyerService {
  static AppsFlyerService? _instance;
  static AppsflyerSdk? _appsflyerSdk;

  // Stream controllers para eventos
  final _deepLinkController = StreamController<DeepLinkData>.broadcast();
  final _attributionController =
      StreamController<InstallAttributionData>.broadcast();

  // Callbacks legacy (por compatibilidad)
  Function(DeepLinkData)? onDeepLinkFound;
  Function(InstallAttributionData)? onAttributionData;

  // Último deep link recibido (para casos donde se necesita acceso síncrono)
  DeepLinkData? _lastDeepLink;
  DeepLinkData? get lastDeepLink => _lastDeepLink;

  // Streams públicos
  Stream<DeepLinkData> get deepLinkStream => _deepLinkController.stream;
  Stream<InstallAttributionData> get attributionStream =>
      _attributionController.stream;

  AppsFlyerService._();

  static AppsFlyerService get instance {
    _instance ??= AppsFlyerService._();
    return _instance!;
  }

  AppsflyerSdk get sdk {
    if (_appsflyerSdk == null) {
      throw Exception(
        'AppsFlyerService no inicializado. Llama a initialize() primero.',
      );
    }
    return _appsflyerSdk!;
  }

  bool get isInitialized => _appsflyerSdk != null;

  Future<void> initialize({
    required String devKey,
    required String appId, // iOS App ID (sin el prefijo "id")
    bool isDebug = false,
    String? oneLinkID, // Tu OneLink template ID
    List<String>? domains, // Dominios personalizados para deep linking
  }) async {
    if (_appsflyerSdk != null) return;

    final options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: appId,
      showDebug: isDebug,
      timeToWaitForATTUserAuthorization: 10,
    );

    _appsflyerSdk = AppsflyerSdk(options);

    // Configurar OneLink ID si se proporciona
    if (oneLinkID != null) {
      _appsflyerSdk!.setOneLinkCustomDomain([oneLinkID]);
    }

    // Configurar dominios personalizados para resolución de deep links
    if (domains != null && domains.isNotEmpty) {
      _appsflyerSdk!.setOneLinkCustomDomain(domains);
    }

    // Configurar listeners antes de initSdk
    _setupDeepLinkListeners();

    await _appsflyerSdk!.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: false,
      registerOnDeepLinkingCallback: true,
    );

    _log('AppsFlyer SDK inicializado');
  }

  void _setupDeepLinkListeners() {
    
    // Conversion Data (datos de instalación/atribución)
    _appsflyerSdk!.onInstallConversionData((data) {
      _log('Conversion Data recibido: $data');

      final status = data['status'] as String?;
      if (status == 'success') {
        final conversionData = data['data'] as Map<String, dynamic>? ?? {};
        final attribution = InstallAttributionData(
          mediaSource: conversionData['media_source'] as String?,
          campaign: conversionData['campaign'] as String?,
          adGroup: conversionData['adgroup'] as String?,
          adSet: conversionData['adset'] as String?,
          isOrganic: conversionData['af_status'] == 'Organic',
          rawData: conversionData,
        );

        _attributionController.add(attribution);
        onAttributionData?.call(attribution);

        // Si es deferred deep link, procesar
        final deepLinkValue = conversionData['deep_link_value'] as String?;
        if (deepLinkValue != null) {
          final deepLink = DeepLinkData(
            deepLinkValue: deepLinkValue,
            campaign: conversionData['campaign'] as String?,
            mediaSource: conversionData['media_source'] as String?,
            customParams: conversionData,
            isDeferred: true,
          );
          _handleDeepLink(deepLink);
        }
      }
    });

    // App Open Attribution (re-engagement via link)
    _appsflyerSdk!.onAppOpenAttribution((data) {
      _log('App Open Attribution recibido: $data');

      if (data['status'] == 'success') {
        final attrData = data['data'] as Map<String, dynamic>? ?? {};
        final deepLink = DeepLinkData(
          deepLinkValue: attrData['deep_link_value'] as String?,
          campaign: attrData['campaign'] as String?,
          mediaSource: attrData['media_source'] as String?,
          customParams: attrData,
          isDeferred: false,
          rawLink: attrData['link'] as String?,
        );
        _handleDeepLink(deepLink);
      }
    });

    // Unified Deep Linking (UDL) - Método principal recomendado
    _appsflyerSdk!.onDeepLinking((DeepLinkResult result) {
      _log('Deep Link Result - Status: ${result.status}');

      switch (result.status) {
        case Status.FOUND:
          final deepLink = result.deepLink;
          if (deepLink != null) {
            final data = DeepLinkData(
              deepLinkValue: deepLink.deepLinkValue,
              campaign: deepLink.campaign,
              mediaSource: deepLink.mediaSource,
              customParams: deepLink.clickEvent,
              isDeferred: deepLink.isDeferred ?? false,
              matchType: deepLink.matchType,
            );
            _handleDeepLink(data);
          }
          break;

        case Status.NOT_FOUND:
          _log('Deep Link no encontrado');
          break;

        case Status.ERROR:
          _log('Error en Deep Link: ${result.error}');
          break;

        case Status.PARSE_ERROR:
          _log('Error parseando Deep Link');
          break;
      }
    });
  }

  void _handleDeepLink(DeepLinkData data) {
    _log('Procesando Deep Link: $data');
    _lastDeepLink = data;
    _deepLinkController.add(data);
    onDeepLinkFound?.call(data);
  }

  // ============ Métodos de navegación basados en deep link ============

  /// Parsea el deep_link_value y retorna la ruta de navegación
  String? getRouteFromDeepLink(DeepLinkData data) {
    final value = data.deepLinkValue;

    if (value == null) return null;
    // Ejemplo de mapeo de deep_link_value a rutas
    // Personaliza según tu estructura de OneLink
    switch (value) {
      case 'home':
        return '/home';
      case 'profile':
        return '/profile';
      case 'product':
        final productId = data.getParam<String>('product_id');
        return productId != null ? '/product/$productId' : '/products';
      case 'promo':
        final promoCode = data.getParam<String>('promo_code');
        return '/promo?code=$promoCode';
      default:
        // Si el value parece una ruta, usarla directamente
        if (value.startsWith('/')) {
          return value;
        }
        return '/$value';
    }
  }

  // ============ Métodos de tracking ============

  /// Registra un evento en AppsFlyer
  Future<void> logEvent(
    String eventName, [
    Map<String, dynamic>? eventValues,
  ]) async {
    await sdk.logEvent(eventName, eventValues ?? {});
    _log('Evento registrado: $eventName');
  }

  /// Eventos predefinidos comunes
  Future<void> logPurchase({
    required double revenue,
    required String currency,
    String? contentId,
    String? contentType,
    int? quantity,
  }) async {
    await logEvent('af_purchase', {
      'af_revenue': revenue,
      'af_currency': currency,
      if (contentId != null) 'af_content_id': contentId,
      if (contentType != null) 'af_content_type': contentType,
      if (quantity != null) 'af_quantity': quantity,
    });
  }

  Future<void> logAddToCart({
    required String contentId,
    double? price,
    String? currency,
    int? quantity,
  }) async {
    await logEvent('af_add_to_cart', {
      'af_content_id': contentId,
      if (price != null) 'af_price': price,
      if (currency != null) 'af_currency': currency,
      if (quantity != null) 'af_quantity': quantity,
    });
  }

  Future<void> logLogin({String? method}) async {
    await logEvent('af_login', {if (method != null) 'af_login_method': method});
  }

  Future<void> logSignUp({String? method}) async {
    await logEvent('af_complete_registration', {
      if (method != null) 'af_registration_method': method,
    });
  }

  // ============ Métodos de identificación ============

  void setCustomerUserId(String userId) {
    sdk.setCustomerUserId(userId);
    _log('Customer User ID establecido: $userId');
  }

  Future<String?> getAppsFlyerUID() async {
    return await sdk.getAppsFlyerUID();
  }

  // ============ Métodos de utilidad ============

  /// Genera un OneLink programáticamente
  Future<String?> generateOneLink({
    required String oneLinkID,
    required String channel,
    Map<String, String>? params,
  }) async {
    // AppsFlyer SDK no tiene método directo para generar links
    // Debes usar la API de AppsFlyer o construir el URL manualmente
    final baseUrl = 'https://$oneLinkID.onelink.me';
    final queryParams = {'pid': channel, ...?params};
    final query = queryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '$baseUrl?$query';
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[AppsFlyer] $message');
    }
  }

  /// Limpia recursos
  void dispose() {
    _deepLinkController.close();
    _attributionController.close();
  }
}
