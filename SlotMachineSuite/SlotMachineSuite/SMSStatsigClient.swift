import Foundation
import Statsig

/// One launch decision per process. All state and callbacks belong to the main queue.
@objc(SMSStatsigClient)
final class SMSStatsigClient: NSObject {
    @objc(sharedClient) static let shared = SMSStatsigClient()
    private var started = false
    private var result: ([String: Any], String)?
    private var completions: [([String: Any], String) -> Void] = []

    @objc(fetchConfigurationWithCompletion:)
    func fetchConfiguration(completion: @escaping ([String: Any], String) -> Void) {
        DispatchQueue.main.async {
            if let result = self.result {
                completion(result.0, result.1)
                return
            }
            self.completions.append(completion)
            guard !self.started else { return }
            self.started = true
            let key = self.infoString("StatsigClientSDKKey")
            let configName = self.infoString("StatsigConfigName")
            guard key.hasPrefix("client-"), !configName.isEmpty else {
                self.finish([:], source: "missing_or_invalid_client_configuration")
                return
            }

            // No attribution, identity, country or reviewer rules are added here.
            // Configure a single default value for everyone in the Statsig console.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.finish([:], source: "timeout")
            }
            Statsig.initialize(sdkKey: key, user: nil) { error in
                DispatchQueue.main.async {
                    guard self.result == nil else { return }
                    guard error == nil else {
                        self.finish([:], source: "sdk_error")
                        return
                    }
                    let value = Statsig.getConfig(configName).value
                    self.finish(value, source: "statsig")
                }
            }
        }
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
