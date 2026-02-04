// AppDelegate FINAL
import AppsFlyerLib
import BrazeKit
import BrazeUI
import Flutter
import UIKit
import UserNotifications
import braze_plugin
import singular_flutter_sdk

@main
@objc class AppDelegate: FlutterAppDelegate, BrazeInAppMessageUIDelegate, BrazeDelegate {

  static var braze: Braze? = nil
  var contentCardsSubscription: Braze.Cancellable?
  var pushEventsSubscription: Braze.Cancellable?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // --- Setup Braze ---
    let configuration = Braze.Configuration(
      apiKey: "67a3c9a4-a65b-4f1e-a1f7-89ea607fb9c3",
      endpoint: "sdk.iad-06.braze.com"
    )
    configuration.triggerMinimumTimeInterval = 0
    configuration.logger.level = .debug

    let braze = BrazePlugin.initBraze(configuration)
    AppDelegate.braze = braze
    braze.delegate = self

    // --- Setup InAppMessage UI ---
    AppDelegate.braze?.inAppMessagePresenter = BrazeInAppMessageUI()
    if let presenter = AppDelegate.braze?.inAppMessagePresenter as? BrazeInAppMessageUI {
      presenter.delegate = self
    }


    // --- Notification Authorization ---
    application.registerForRemoteNotifications()
    let center = UNUserNotificationCenter.current()
    center.setNotificationCategories(Braze.Notifications.categories)
    center.delegate = self
    center.requestAuthorization(options: [.badge, .sound, .alert]) { granted, error in
      print("Notification authorization, granted: \(granted)")
    }

    // --- Suscripciones Braze ---
    contentCardsSubscription = braze.contentCards.subscribeToUpdates { contentCards in
      BrazePlugin.processContentCards(contentCards)
    }
    pushEventsSubscription = braze.notifications.subscribeToUpdates { payload in
      BrazePlugin.processPushEvent(payload)
    }

    // --- Setup Singular ---

    if let singularAppDelegate = SingularAppDelegate.shared() {
      singularAppDelegate.launchOptions = launchOptions
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - BrazeDelegate

  func braze(_ braze: Braze, shouldOpenURL context: Braze.URLContext) -> Bool {
    let url = context.url
    let urlString = url.absoluteString

    print("=> [BrazeDelegate] shouldOpenURL: \(urlString)")

    if urlString.contains("onelink.me") {
      print("=> [BrazeDelegate] Intercepting OneLink")
      if let singularAppDelegate = SingularAppDelegate.shared() {
        singularAppDelegate.handleOpen(url, options: [:])
      }
      return false
    }

    return true
  }

  // MARK: - Remote Notifications

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    AppDelegate.braze?.notifications.register(deviceToken: deviceToken)
  }

  // MARK: - URL Scheme

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    print("=> [URL Scheme] Received: \(url.absoluteString)")
    //AppsFlyerLib.shared().handleOpen(url, options: options)
    if let singularAppDelegate = SingularAppDelegate.shared() {
      singularAppDelegate.handleOpen(url, options: options)
    }
    return true
  }

  // MARK: - Universal Links

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
      let url = userActivity.webpageURL
    {
      print("=> [Universal Link] URL: \(url.absoluteString)")
      if let singularAppDelegate = SingularAppDelegate.shared() {
            singularAppDelegate.continueUserActivity(userActivity, restorationHandler:nil)
        }
      // AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
      return true
    }
    
    return super.application(
      application, continue: userActivity, restorationHandler: restorationHandler)
  }

  // MARK: - Push Notification Tap

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("=> [Push Tap] userInfo: \(userInfo)")

    // Extraer deep link del payload
    let deepLink = extractDeepLink(from: userInfo)

    if let link = deepLink, let url = URL(string: link) {
      SingularAppDelegate.shared()?.handleOpen(url, options: [:])
    }

    completionHandler()
  }

  // MARK: - Helper

  private func extractDeepLink(from userInfo: [AnyHashable: Any]) -> String? {
    if let uri = userInfo["uri"] as? String, !uri.isEmpty { return uri }
    if let abUri = userInfo["ab_uri"] as? String, !abUri.isEmpty { return abUri }
    if let link = userInfo["link"] as? String, !link.isEmpty { return link }
    if let ab = userInfo["ab"] as? [AnyHashable: Any] {
      return ab["uri"] as? String ?? ab["link"] as? String
    }
    return nil
  }
}
