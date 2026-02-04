import 'package:flutter/material.dart';
import 'package:flutter_app_appsflyer_braze/services/braze_service.dart';
import 'package:flutter_app_appsflyer_braze/services/appsflyer.dart';
import 'package:flutter_app_appsflyer_braze/services/identifiers.dart';
import 'package:flutter_app_appsflyer_braze/services/singular_service.dart';
import 'dart:io';


String getUserIdWithPlatform(String baseId) {
  if (Platform.isIOS) {
    return '${baseId}_ios';
  } else if (Platform.isAndroid) {
    return '${baseId}_android';
  }
  return baseId; // fallback para web u otras plataformas
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  obtenerIDFV();
  // Initialize Braze
  await BrazeService.instance.init();
  BrazeService.instance.setUserId(getUserIdWithPlatform('usuario_test'));

  // // Initialize AppsFlyer con OneLink
  // await AppsFlyerService.instance.initialize(
  //   devKey: "KhuJ4YG8vRPQ9ZswK6uYwe",
  //   appId: "6756940145", // iOS App Store ID
  //   isDebug: true,
  //   oneLinkID:
  //       "flutter-appsflyer-braze", // Tu OneLink template ID (ej: si tu link es tuapp.onelink.me)
  //   domains: ['flutter-appsflyer-braze.onelink.me'],
  // );

  // // Obtener AppsFlyer UID
  // final afId = await AppsFlyerService.instance.getAppsFlyerUID();
  // print("AppsFlyer ID: $afId");

  // // Set user ID consistente
  // AppsFlyerService.instance.setCustomerUserId(
  //   getUserIdWithPlatform('usuario_test'),
  // );

  SingularService.initializeSingularSDK(getUserIdWithPlatform('usuario_test'));

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    //suscribirse para futuros deep links
    _setupDeepLinkListener();
  }

  void _setupDeepLinkListener() {
    AppsFlyerService.instance.deepLinkStream.listen((deepLink) {
      print('[AppState] Deep Link recibido: $deepLink');
      final route = AppsFlyerService.instance.getRouteFromDeepLink(deepLink);

      if (route != null) {
        _navigatorKey.currentState?.pushNamed(route);
      }
    });
  }
  

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MyHomePage(title: 'Flutter Demo Home Page'),
        '/profile': (context) => const ProfilePage(),
        '/promo': (context) => const PromoPage(),
      },
      onGenerateRoute: (settings) {
        // Manejar rutas dinámicas como /product/:id
        final uri = Uri.parse(settings.name ?? '');

        if (uri.pathSegments.isNotEmpty &&
            uri.pathSegments.first == 'product') {
          final productId = uri.pathSegments.length > 1
              ? uri.pathSegments[1]
              : null;
          return MaterialPageRoute(
            builder: (context) => ProductPage(productId: productId),
          );
        }

        return null;
      },
    );
  }
}

// ============ Páginas de ejemplo ============

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  String? _lastDeepLink;

  @override
  void initState() {
    super.initState();

    // Escuchar deep links en esta página
    AppsFlyerService.instance.deepLinkStream.listen((data) {
      setState(() {
        _lastDeepLink = data.deepLinkValue;
      });
    });
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });

    // Ejemplo: trackear evento
    // AppsFlyerService.instance.logEvent('button_click', {
    //   'button_name': 'increment',
    //   'counter_value': _counter,R
    // });

    SingularService.trackEvent("button_click");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_lastDeepLink != null) ...[
              Text(
                'Último Deep Link: $_lastDeepLink',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
            ],
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/profile'),
              child: const Text('Ir a Profile'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/product/123'),
              child: const Text('Ver Producto 123'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Páginas placeholder
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('Profile Page')),
    );
  }
}

class ProductPage extends StatelessWidget {
  final String? productId;
  const ProductPage({super.key, this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Product $productId')),
      body: Center(child: Text('Product ID: $productId')),
    );
  }
}

class PromoPage extends StatelessWidget {
  const PromoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uri = ModalRoute.of(context)?.settings.name;
    final code = Uri.parse(uri ?? '').queryParameters['code'];

    return Scaffold(
      appBar: AppBar(title: const Text('Promo')),
      body: Center(child: Text('Promo Code: $code')),
    );
  }
}
