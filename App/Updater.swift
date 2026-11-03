import Foundation
import GlintPlatform
import Sparkle

/// Sparkle 2 auto-updates (F-14, ADR-003). Starts only when the build carries an EdDSA public key and a feed
/// URL that is HTTPS (or a localhost test feed in DEBUG builds), so unsigned dev builds never show Sparkle errors.
@MainActor
final class Updater {
    private let controller: SPUStandardUpdaterController

    init?(bundle: Bundle) {
        guard Self.isConfigured(
            feedURL: bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            publicKey: bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        ) else {
            GlintLog.logger(.update).info("updater disabled: no feed URL or public key in this build")
            return nil
        }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    /// G-SEC-09: HTTPS only, except a localhost feed for the local update test in DEBUG.
    nonisolated static func isConfigured(feedURL: String?, publicKey: String?) -> Bool {
        guard let feedURL, let url = URL(string: feedURL), let publicKey, !publicKey.isEmpty else { return false }
        if url.scheme == "https" {
            return true
        }
        #if DEBUG
            return url.scheme == "http" && (url.host == "127.0.0.1" || url.host == "localhost")
        #else
            return false
        #endif
    }
}
