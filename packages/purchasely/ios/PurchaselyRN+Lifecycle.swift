//
//  PurchaselyRN+Lifecycle.swift
//  start, identity, deeplinks, language, log level, theme, consent, synchronize.
//
//  Ported from PurchaselyRN.m:536-1295 (Task 9 of the Swift bridge migration
//  plan). Transliteration only — see the plan's Global Constraints before
//  touching anything here.
//

import Foundation
import Purchasely

/// Bridge-local running-mode ordinals. Mirrors `PLYRNRunningMode`
/// (PurchaselyRN.m:249-252), a bridge-only enum with no SDK equivalent —
/// `PLYRunningMode.observer` / `.full` have different raw values (2 / 3).
private enum PLYRNRunningMode: Int {
    case observer = 1
    case full = 4
}

/// Map a JS running-mode ordinal to a native `PLYRunningMode`. Any
/// unknown/unset value falls back to Observer, exactly as
/// `runningModeFromOrdinal` (PurchaselyRN.m:258-265).
private func runningModeFromOrdinal(_ ordinal: Int) -> PLYRunningMode {
    ordinal == PLYRNRunningMode.full.rawValue ? .full : .observer
}

extension PurchaselyBridge {

    // MARK: - start

    @objc(start:stores:storeKit1:userId:logLevel:runningMode:purchaselySdkVersion:startOptions:initialized:reject:)
    func start(
        _ apiKey: String?,
        stores: [Any]?,
        storeKit1: Bool,
        userId: String?,
        logLevel: Int,
        runningMode: Int,
        purchaselySdkVersion: String?,
        startOptions: NSDictionary?,
        initialized resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        // Constraint 4: `logLevel` is a raw ordinal from JS and may be
        // anything. PLYLogLevel(rawValue:) never force-unwraps; unlike
        // setLogLevel (below), this call site cannot just "keep the current
        // value and return" because the builder needs a value now, so an
        // out-of-range ordinal falls back to .debug.
        let level = PLYLogger.PLYLogLevel(rawValue: logLevel) ?? .debug

        // Constraint 4: `apiKey` is an object-typed parameter, so it is
        // Optional here even though the ObjC annotation says `_Nonnull` — the
        // nullability check is `#if RCT_DEBUG` only. Same nil -> "" shape as
        // `userLogin`, below.
        var builder = Purchasely.apiKey(apiKey ?? "")
            .appUserId(userId)
            .runningMode(runningModeFromOrdinal(runningMode))
            .storekitSettings(storeKit1 ? .storeKit1 : .storeKit2)
            .logLevel(level)
            .appTechnology(.reactNative)
            .sdkBridgeVersion(purchaselySdkVersion)

        // Applied on the builder chain — before start() — so these take
        // effect atomically with configuration (PurchaselyRN.m:551-604).
        var appHandlesRedemptionAlert = false
        if let options = startOptions {
            if let allowDeeplink = options["allowDeeplink"] as? NSNumber {
                builder = builder.allowDeeplink(allowDeeplink.boolValue)
            }
            if let allowCampaigns = options["allowCampaigns"] as? NSNumber {
                builder = builder.allowCampaigns(allowCampaigns.boolValue)
            }
            // JS has no UUID type: the id crosses the bridge as a string and
            // is parsed here. Reject a bad value loudly and skip the
            // modifier; the SDK still starts.
            if let anonymousUserId = options["anonymousUserId"] as? String {
                if let parsed = UUID(uuidString: anonymousUserId) {
                    let override = (options["anonymousUserIdOverride"] as? NSNumber)?.boolValue ?? false
                    builder = builder.appAnonymousUserId(parsed, override: override)
                } else {
                    PLYRNLogWarn(
                        "[Purchasely] `anonymousUserId` must be a canonical UUID string, for "
                            + "example \"3f2504e0-4f89-11d3-9a0c-0305e82c3301\". Received \"\(anonymousUserId)\". "
                            + "The anonymous user id is not applied."
                    )
                }
            }
            // Three states, not interchangeable: key absent leaves the SDK's
            // current setting alone, NSNull clears the proxy, a String sets it.
            let proxyApi = options["proxy"]
            if proxyApi is NSNull {
                builder = builder.proxy(api: nil)
            } else if let proxyString = proxyApi as? String {
                if let proxyUrl = URL(string: proxyString) {
                    builder = builder.proxy(api: proxyUrl)
                } else {
                    PLYRNLogWarn(
                        "[Purchasely] `proxy` must be an https base URL, for example "
                            + "\"https://svc.purchasely.io\". Received \"\(proxyString)\". "
                            + "The proxy is not applied."
                    )
                }
            }
            if let handlesAlert = options["appHandlesRedemptionAlert"] as? NSNumber {
                appHandlesRedemptionAlert = handlesAlert.boolValue
            }
        }

        // Registered unconditionally: no runtime setter exists on purpose, a
        // redemption can settle during start() (PurchaselyRN.m:596-601).
        builder = builder.webRedemptionDelegate(self, appHandlesRedemptionAlert: appHandlesRedemptionAlert)

        builder.start { error in
            if let error {
                Self.reject(reject, with: error)
            } else {
                resolve(true)
            }
        }

        // Constraint 9: registered AFTER start() returns (it's a call, not a
        // completion), alongside the two delegate setters — never move this
        // inside the `initialized` closure above.
        Purchasely.setEventDelegate(self)
        Purchasely.setUserAttributeDelegate(self)
        NotificationCenter.default.addObserver(
            self, selector: #selector(purchasePerformed),
            name: Notification.Name("ply_purchasedSubscription"), object: nil
        )
    }

    /// Called by selector from the notification centre registered in
    /// `start`, above — keeps `@objc` even though no Swift code calls it.
    @objc func purchasePerformed() {
        emitPresentationEvent("PURCHASE_LISTENER", body: [:])
    }

    // MARK: - log level, theme

    // Constraint 4: `logLevel` stays a primitive Int; PLYLogLevel(rawValue:)
    // returns nil for an unknown ordinal, which is never force-unwrapped.
    // PLYLogLevel is nested under PLYLogger and the setter is a function,
    // not an assignable `Purchasely.logLevel` (.swiftinterface:1256, :1458).
    @objc(setLogLevel:)
    func setLogLevel(_ logLevel: Int) {
        guard let level = PLYLogger.PLYLogLevel(rawValue: logLevel) else {
            PLYRNLogWarn("Unknown log level \(logLevel), keeping the current one")
            return
        }
        Purchasely.setLogLevel(level)
    }

    @objc(setThemeMode:)
    func setThemeMode(_ mode: Int) {
        guard let theme = Purchasely.PLYThemeMode(rawValue: mode) else {
            PLYRNLogWarn("Unknown theme mode \(mode), keeping the current one")
            return
        }
        Purchasely.setThemeMode(theme)
    }

    // MARK: - identity

    @objc(userLogin:resolve:reject:)
    func userLogin(
        _ userId: String?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        Purchasely.userLogin(with: userId ?? "") { shouldRefresh in
            resolve(shouldRefresh)
        }
    }

    // [PAR-30] clearUserAttributes is always sent explicitly by the JS
    // wrapper (which defaults it to true), so no native-side default here.
    @objc(userLogout:)
    func userLogout(_ clearUserAttributes: Bool) {
        Purchasely.userLogout(clearUserAttributes)
    }

    @objc(isAnonymous:reject:)
    func isAnonymous(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        resolve(Purchasely.isAnonymous())
    }

    @objc(getAnonymousUserId:reject:)
    func getAnonymousUserId(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        resolve(Purchasely.anonymousUserId)
    }

    // MARK: - deeplinks

    @objc(handleDeeplink:resolve:reject:)
    func handleDeeplink(
        _ deeplink: String?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let deeplink else {
            let userInfo = [NSLocalizedDescriptionKey: NSLocalizedString("Deeplink must not be null", comment: "")]
            let error = NSError(domain: "", code: -1, userInfo: userInfo)
            Self.reject(reject, with: error)
            return
        }
        DispatchQueue.main.async {
            // `NSURL URLWithString:` returns nil for a malformed string and the
            // Objective-C original passed that nil straight into a `_Nonnull`
            // SDK parameter (unchecked at the ObjC call site). Swift's
            // imported `handleDeeplink(_ url: URL)` takes a non-optional URL,
            // so there is no nil to pass here; a malformed deeplink is
            // reported as "not handled" (false) instead, without crashing.
            guard let url = URL(string: deeplink) else {
                resolve(false)
                return
            }
            resolve(Purchasely.handleDeeplink(url))
        }
    }

    @objc(readyToOpenDeeplink:)
    func readyToOpenDeeplink(_ ready: Bool) {
        allowDeeplink(ready)
    }

    @objc(allowDeeplink:)
    func allowDeeplink(_ allow: Bool) {
        DispatchQueue.main.async {
            Purchasely.allowDeeplink(allow)
        }
    }

    @objc(allowCampaigns:)
    func allowCampaigns(_ allow: Bool) {
        DispatchQueue.main.async {
            Purchasely.allowCampaigns(allow)
        }
    }

    // MARK: - language, debug mode, content consumption

    // Constraint 4: `language` is a String, so it is Optional despite the
    // ObjC `_Nonnull` annotation. `Purchasely.setLanguage(from:)` takes an
    // Optional Locale, so a nil language degrades to an empty identifier
    // rather than trapping.
    @objc(setLanguage:)
    func setLanguage(_ language: String?) {
        Purchasely.setLanguage(from: Locale(identifier: language ?? ""))
    }

    @objc(setDebugMode:)
    func setDebugMode(_ enabled: Bool) {
        DispatchQueue.main.async {
            Purchasely.setDebugMode(enabled: enabled)
        }
    }

    @objc(userDidConsumeSubscriptionContent)
    func userDidConsumeSubscriptionContent() {
        Purchasely.userDidConsumeSubscriptionContent()
    }

    // MARK: - consent

    // [REC-15 / ENM-12] RN's own wire strings are kebab-case singular (e.g.
    // "third-party-integration"), while the other Purchasely SDKs use
    // SCREAMING_SNAKE_CASE plural. Widened to accept either, without changing
    // behaviour for the existing kebab strings (PurchaselyRN.m:1232-1259).
    static func mapPurposesFromStrings(_ strings: [String]) -> Set<PLYDataProcessingPurpose> {
        var result: Set<PLYDataProcessingPurpose> = []
        for purpose in strings {
            var p = purpose.lowercased().replacingOccurrences(of: "_", with: "-")
            if p == "third-party-integrations" {
                p = "third-party-integration"
            }
            if p == "all-non-essentials" {
                return [PLYDataProcessingPurpose.allNonEssentials]
            }
            switch p {
            case "analytics": result.insert(PLYDataProcessingPurpose.analytics)
            case "identified-analytics": result.insert(PLYDataProcessingPurpose.identifiedAnalytics)
            case "campaigns": result.insert(PLYDataProcessingPurpose.campaigns)
            case "personalization": result.insert(PLYDataProcessingPurpose.personalization)
            case "third-party-integration": result.insert(PLYDataProcessingPurpose.thirdPartyIntegrations)
            default: break
            }
        }
        return result
    }

    // Constraint 4: `purposes` is `NSArray<NSString *> * _Nonnull` in the
    // ObjC annotation, but an array parameter is Optional in Swift
    // regardless. A non-string element (which ObjC would have thrown an
    // NSInvalidArgumentException on at `purpose.lowercaseString`, since
    // `NSString` messages don't exist on other classes) is silently dropped
    // here via `compactMap` instead of trapping.
    @objc(revokeDataProcessingConsent:)
    func revokeDataProcessingConsent(_ purposes: [Any]?) {
        let mapped = Self.mapPurposesFromStrings((purposes ?? []).compactMap { $0 as? String })
        if !mapped.isEmpty {
            Purchasely.revokeDataProcessingConsent(for: mapped)
        } else {
            // PurchaselyRN.m:1269 logs this with NSLog, not RCTLogWarn/
            // PLYRNLogWarn — restore that destination (a Release build
            // filters RCTLogWarn out). Unwrap `purposes` before formatting;
            // interpolating the Optional directly (`\(purposes)`) printed
            // "Optional([...])" instead of the array's own description.
            NSLog("[Purchasely] revokeDataProcessingConsent called with no valid purposes: %@", (purposes ?? []) as NSArray)
        }
    }

    // MARK: - synchronize

    @objc(synchronize:reject:)
    func synchronize(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            Purchasely.synchronize(success: {
                resolve(true)
            }, failure: { error in
                Self.reject(reject, with: error)
            })
        }
    }
}
