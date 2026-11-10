import Foundation
import Statsig

/// One launch decision per process. All state and callbacks belong to the main queue.
@objc(SMSStatsigClient)
public final class SMSStatsigClient: NSObject {
    @objc(sharedClient) public static let shared = SMSStatsigClient()
    private var started = false
    private var result: ([String: Any], String)?
    private var completions: [([String: Any], String) -> Void] = []

    @objc(fetchConfigurationWithCompletion:)
    public func fetchConfiguration(completion: @escaping ([String: Any], String) -> Void) {
        DispatchQueue.main.async {
            if let result = self.result {
                completion(result.0, result.1)
                return
            }
            self.completions.append(completion)
            guard !self.started else { return }
            self.started = true
            let key = self.infoString("StatsigClientSDKKey")
            guard key.hasPrefix("client-") else {
                self.finish([:], source: "missing_or_invalid_client_configuration")
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.finish([:], source: "timeout")
            }
            let options = StatsigOptions(initTimeout: 4, disableCurrentVCLogging: true)
            Statsig.initialize(sdkKey: key, user: nil, options: options) { error in
                DispatchQueue.main.async {
                    guard self.result == nil else { return }
                    guard error == nil else {
                        self.finish([:], source: "sdk_error")
                        return
                    }
                    // A cached open=true must never authorize a new launch by itself.
                    // NetworkNotModified is a successful server validation of SDK cache.
                    guard let source = Statsig.getEvaluationSource(),
                          source == .Network || source == .NetworkNotModified else {
                        self.finish([:], source: "no_fresh_configuration")
                        return
                    }
                    var stores: [String: Any] = [:]
                    for name in ["csc_info", "us_info"] {
                        stores[name] = self.readStore(name)
                    }
                    self.finish(stores, source: "statsig_parameter_stores")
                }
            }
        }
    }

    private func readStore(_ name: String) -> [String: Any] {
        let store = Statsig.getParameterStore(name)
        var values: [String: Any] = [
            "open": store.getValue(forKey: "open", defaultValue: false),
            "preShowAtt": store.getValue(forKey: "preShowAtt", defaultValue: false),
            "source": store.getValue(forKey: "source", defaultValue: false)
        ]
        for key in ["url", "title", "adjEnvironment", "adjustStartEvent", "adjustToken",
                    "apfDevKey", "apfAppId"] {
            values[key] = store.getValue(forKey: key, defaultValue: "")
        }
        for key in store.keys where key.hasPrefix("adjustEvent_") {
            values[key] = store.getValue(forKey: key, defaultValue: "")
        }
        values["allowed_hosts"] = store.getValue(forKey: "allowed_hosts", defaultValue: [String]())
        values["query_params"] = store.getValue(forKey: "query_params", defaultValue: [String: Any]())
        return values
    }

    private func infoString(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func finish(_ value: [String: Any], source: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard result == nil else { return }
        result = (value, source)
        let callbacks = completions
        completions.removeAll()
        callbacks.forEach { $0(value, source) }
    }
}
