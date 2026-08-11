import Foundation
import SwiftUI
import UIKit

#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif

#if canImport(AdjustSdk)
import AdjustSdk
#elseif canImport(Adjust)
import Adjust
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AttributionManager.shared.configure()
        return true
    }

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        AttributionManager.shared.handleOpenURL(url, options: options)
        return true
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        AttributionManager.shared.continueUserActivity(userActivity, restorationHandler: restorationHandler)
    }
}

final class AttributionManager {
    static let shared = AttributionManager()

    private var didConfigure = false

    private init() {}

    func configure() {
        guard !didConfigure else { return }
        didConfigure = true

        configureAppsFlyer()
        configureAdjust()
    }

    func logEvent(_ name: String, values: [String: Any] = [:]) {
        guard !name.isEmpty else { return }

#if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().logEvent(name, withValues: values)
#endif

#if canImport(AdjustSdk) || canImport(Adjust)
        if let eventToken = values["adjust_event_token"] as? String, !eventToken.isEmpty {
            let event = ADJEvent(eventToken: eventToken)
            Adjust.trackEvent(event)
        }
#endif
    }

    func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) {
#if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().handleOpen(url, options: options)
#endif
    }

    func continueUserActivity(
        _ userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
#if canImport(AppsFlyerLib)
        return AppsFlyerLib.shared().continue(userActivity, restorationHandler: restorationHandler)
#else
        return false
#endif
    }

    private func configureAppsFlyer() {
#if canImport(AppsFlyerLib)
        let devKey = infoString("AppsFlyerDevKey")
        let appID = infoString("AppsFlyerAppID")

        guard !devKey.isEmpty, !appID.isEmpty else {
            NSLog("[AppsFlyer] configure skipped: missing AppsFlyerDevKey or AppsFlyerAppID in Info.plist.")
            return
        }

        let appsFlyer = AppsFlyerLib.shared()
        appsFlyer.initialize(devKey: devKey, appId: appID)
#if DEBUG
        appsFlyer.isDebug = true
#endif
        appsFlyer.start()
#endif
    }

    private func configureAdjust() {
#if canImport(AdjustSdk) || canImport(Adjust)
        let appToken = infoString("AdjustAppToken")
        guard !appToken.isEmpty else {
            NSLog("[Adjust] configure skipped: missing AdjustAppToken in Info.plist.")
            return
        }

        let environmentValue = infoString("AdjustEnvironment").lowercased()
        let environment = environmentValue == "sandbox" ? ADJEnvironmentSandbox : ADJEnvironmentProduction
        guard let config = ADJConfig(appToken: appToken, environment: environment) else {
            NSLog("[Adjust] configure skipped: invalid Adjust app token.")
            return
        }

#if DEBUG
        config.logLevel = ADJLogLevelVerbose
#else
        config.logLevel = ADJLogLevelSuppress
#endif
        Adjust.initSdk(config)
#endif
    }

    private func infoString(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
