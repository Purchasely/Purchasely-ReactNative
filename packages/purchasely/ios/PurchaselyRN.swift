//
//  PurchaselyRN.swift
//  The React Native bridge module. Split across PurchaselyRN+*.swift by
//  domain; this file holds the class, its shared state and the RCTEventEmitter
//  overrides.
//
//  Exported to JS as `Purchasely` via the RCT_EXTERN_REMAP_MODULE shim in
//  PurchaselyRN.m. @objc(PurchaselyRN) is what the Objective-C shim's
//  forward declaration binds to at runtime.
//

import Foundation
import Purchasely

@objc(PurchaselyRN)
class PurchaselyRN: RCTEventEmitter,
                        PLYEventDelegate,
                        PLYUserAttributeDelegate,
                        PLYWebRedemptionDelegate {
    // The three conformances are declared HERE, in Task 8, because `start`
    // (Task 9) passes `self` as all three (PurchaselyRN.m:617, :628, :630).
    // Their method bodies are Task 12's. Until Task 12 lands, satisfy the
    // protocols with stubs that call PLYRNLogWarn and nothing else, so the
    // class compiles at every commit boundary.

    // MARK: - shared state
    //
    // Ported from the file-scope statics at PurchaselyRN.m:41-50. Swift
    // initializes a static lazily and exactly once, thread-safely, so
    // ensurePresentationState() and its dispatch_once are gone.

    /// requestId → the captured presentation, so events can replay it.
    static var presentationsByRequest: [String: any PLYPresentation] = [:]
    /// callbackId → the completion to call when JS replies with an InterceptResult.
    static var interceptorCallbacks: [String: (String) -> Void] = [:]
    /// Which interceptor kinds JS has registered.
    static var interceptorKinds: Set<String> = []

    /// Serialises every access to the three collections above. Bridge methods
    /// run on a background queue while the interceptor completions run on the
    /// main queue.
    ///
    /// `NSLock` is NOT reentrant and `@synchronized` was. So: one `withState`
    /// per original `@synchronized` block, never nested, and never wrapping an
    /// SDK call or a callback invocation. `closePresentation` is the case that
    /// proves it — it takes the lock twice with an SDK close in between.
    private static let stateLock = NSLock()

    static func withState<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    /// Mirrors the Android bridge's INTERCEPTOR_TIMEOUT_MS = 30_000L.
    static let interceptorTimeoutSeconds: TimeInterval = 30

    // MARK: - init
    //
    // `-init` calls `setAppTechnology:PLYAppTechnologyReactNative`
    // (PurchaselyRN.m:461) and sets shouldEmit = NO. Both must survive: the app
    // technology is what tags every event this SDK sends as React Native.

    override init() {
        super.init()
        Purchasely.setAppTechnology(.reactNative)
    }

    /// Weak, as `_sharedEmitter` was at PurchaselyRN.m:371.
    static weak var sharedEmitter: PurchaselyRN?

    /// Gate from PurchaselyRN.m: drop events before startObserving. Declared
    /// `Boolean` in the old header, which imported into Swift as `UInt8`; a
    /// real `Bool` here is the one type change in the port.
    var shouldEmit = false

    // MARK: - RCTEventEmitter

    override static func requiresMainQueueSetup() -> Bool {
        // PurchaselyRN.m:1441 returns YES. Do NOT "align" this with
        // PurchaselyViewManager.swift:20, which returns false on purpose for a
        // different reason — Global Constraint 11, and commit 81c5a65.
        true
    }

    override func supportedEvents() -> [String]! {
        [
            "PURCHASELY_EVENTS",
            "PURCHASE_LISTENER",
            "USER_ATTRIBUTE_SET_LISTENER",
            "USER_ATTRIBUTE_REMOVED_LISTENER",
            "WEB_REDEMPTION_LISTENER",
            // cross-platform bridge events; the names mirror the Android bridge.
            "PURCHASELY_PRESENTATION_LOADED",
            "PURCHASELY_PRESENTATION_PRESENTED",
            "PURCHASELY_PRESENTATION_CLOSE_REQUESTED",
            "PURCHASELY_PRESENTATION_DISMISSED",
            "PURCHASELY_DEFAULT_PRESENTATION_DISMISSED",
            "PURCHASELY_ACTION_INTERCEPTED",
        ]
    }

    override func constantsToExport() -> [AnyHashable: Any]! {
        // 60 keys. enums.ts builds the JS enums from them, so every key and
        // every value is a client contract. `.rawValue` on every enum
        // (constraint 5) — a bare enum value would be dropped by the bridge.
        // Note the QUALIFIED enum names. `PLYLogLevel` is nested under
        // `PLYLogger` (.swiftinterface:1458); `PLYAttribute` and `PLYThemeMode`
        // are nested under `Purchasely` (:1337, :1368). The unqualified names
        // do not compile. Every enum here was read off the .swiftinterface —
        // see the task report for the exact rg/awk commands.
        //
        // `runningModeObserver` / `runningModeFull` are NOT SDK symbols: they
        // mirror `PLYRNRunningMode`, a bridge-local NS_ENUM declared in
        // PurchaselyRN.m (Observer = 1, Full = 4), so they stay literal ints.
        [
            "logLevelDebug": PLYLogger.PLYLogLevel.debug.rawValue,
            "logLevelInfo": PLYLogger.PLYLogLevel.info.rawValue,
            "logLevelWarn": PLYLogger.PLYLogLevel.warn.rawValue,
            "logLevelError": PLYLogger.PLYLogLevel.error.rawValue,
            "productResultPurchased": Self.purchaseResultOrdinal(.purchased) ?? 0,
            "productResultCancelled": Self.purchaseResultOrdinal(.cancelled) ?? 1,
            "productResultRestored": Self.purchaseResultOrdinal(.restored) ?? 2,
            "sourceAppStore": PLYSubscriptionSource.appleAppStore.rawValue,
            "sourcePlayStore": PLYSubscriptionSource.googlePlayStore.rawValue,
            "sourceHuaweiAppGallery": PLYSubscriptionSource.huaweiAppGallery.rawValue,
            "sourceAmazonAppstore": PLYSubscriptionSource.amazonAppstore.rawValue,
            "sourceStripe": PLYSubscriptionSource.stripe.rawValue,
            "sourceNone": PLYSubscriptionSource.none.rawValue,
            "firebaseAppInstanceId": Purchasely.PLYAttribute.firebaseAppInstanceId.rawValue,
            "airshipChannelId": Purchasely.PLYAttribute.airshipChannelId.rawValue,
            "airshipUserId": Purchasely.PLYAttribute.airshipUserId.rawValue,
            "batchInstallationId": Purchasely.PLYAttribute.batchInstallationId.rawValue,
            "adjustId": Purchasely.PLYAttribute.adjustId.rawValue,
            "appsflyerId": Purchasely.PLYAttribute.appsflyerId.rawValue,
            "oneSignalExternalId": Purchasely.PLYAttribute.oneSignalExternalId.rawValue,
            "oneSignalUserId": Purchasely.PLYAttribute.oneSignalUserId.rawValue,
            "mixpanelDistinctId": Purchasely.PLYAttribute.mixpanelDistinctId.rawValue,
            "clevertapId": Purchasely.PLYAttribute.clevertapId.rawValue,
            "sendinblueUserEmail": Purchasely.PLYAttribute.sendinblueUserEmail.rawValue,
            "iterableUserId": Purchasely.PLYAttribute.iterableUserId.rawValue,
            "iterableUserEmail": Purchasely.PLYAttribute.iterableUserEmail.rawValue,
            "atInternetIdClient": Purchasely.PLYAttribute.atInternetIdClient.rawValue,
            "amplitudeUserId": Purchasely.PLYAttribute.amplitudeUserId.rawValue,
            "amplitudeDeviceId": Purchasely.PLYAttribute.amplitudeDeviceId.rawValue,
            // JS-facing key stays "mparticleUserId" (enums.ts contract); the
            // Swift case is `.mParticleUserId` (capital P — .swiftinterface:1337).
            "mparticleUserId": Purchasely.PLYAttribute.mParticleUserId.rawValue,
            // JS-facing key stays "customerIoUserId"/"customerIoUserEmail"; the
            // Swift case is `.customerioUserId`/`.customerioUserEmail` (lowercase o).
            "customerIoUserId": Purchasely.PLYAttribute.customerioUserId.rawValue,
            "customerIoUserEmail": Purchasely.PLYAttribute.customerioUserEmail.rawValue,
            "branchUserDeveloperIdentity": Purchasely.PLYAttribute.branchUserDeveloperIdentity.rawValue,
            // JS-facing key stays "moEngageUniqueId"; the Swift case is
            // `.moengageUniqueId` (lowercase e — .swiftinterface:1337).
            "moEngageUniqueId": Purchasely.PLYAttribute.moengageUniqueId.rawValue,
            "batchCustomUserId": Purchasely.PLYAttribute.batchCustomUserId.rawValue,
            "consumable": PLYPlanType.consumable.rawValue,
            "nonConsumable": PLYPlanType.nonConsumable.rawValue,
            "autoRenewingSubscription": PLYPlanType.autoRenewingSubscription.rawValue,
            "nonRenewingSubscription": PLYPlanType.nonRenewingSubscription.rawValue,
            "unknown": PLYPlanType.unknown.rawValue,
            "runningModeObserver": 1,
            "runningModeFull": 4,
            "presentationTypeNormal": PLYPresentationType.normal.rawValue,
            "presentationTypeFallback": PLYPresentationType.fallback.rawValue,
            "presentationTypeDeactivated": PLYPresentationType.deactivated.rawValue,
            "presentationTypeClient": PLYPresentationType.client.rawValue,
            "themeLight": Purchasely.PLYThemeMode.light.rawValue,
            "themeDark": Purchasely.PLYThemeMode.dark.rawValue,
            "themeSystem": Purchasely.PLYThemeMode.system.rawValue,
            "userAttributeSourcePurchasely": PLYUserAttributeSource.purchasely.rawValue,
            "userAttributeSourceClient": PLYUserAttributeSource.client.rawValue,
            "userAttributeString": PLYUserAttributeType.string.rawValue,
            "userAttributeBoolean": PLYUserAttributeType.bool.rawValue,
            "userAttributeInt": PLYUserAttributeType.int.rawValue,
            "userAttributeFloat": PLYUserAttributeType.double.rawValue,
            "userAttributeDate": PLYUserAttributeType.date.rawValue,
            "userAttributeStringArray": PLYUserAttributeType.stringArray.rawValue,
            "userAttributeIntArray": PLYUserAttributeType.intArray.rawValue,
            "userAttributeFloatArray": PLYUserAttributeType.doubleArray.rawValue,
            "userAttributeBooleanArray": PLYUserAttributeType.boolArray.rawValue,
        ]
    }

    override func startObserving() {
        shouldEmit = true
        Self.sharedEmitter = self
    }

    override func stopObserving() {
        shouldEmit = false
    }

    /// Wrapper around sendEvent that honours the shouldEmit gate.
    func emitPresentationEvent(_ name: String, body: [String: Any]?) {
        guard shouldEmit else { return }
        sendEvent(withName: name, body: body ?? [:])
    }

    // MARK: - errors

    /// Ported from `-reject:with:` (PurchaselyRN.m:1448-1450), made `static`
    /// on purpose: it reads no instance state, so the 18 closures that called
    /// it capture nothing and the whole [weak self] question disappears.
    ///
    /// The error stays Optional: `PurchaselyRN.m:1449` messages a nil error and
    /// gets code "0" with a nil message. Reproduce that, do not force-unwrap
    /// and do not return early.
    static func reject(_ reject: RCTPromiseRejectBlock, with error: Error?) {
        let nsError = error as NSError?
        reject("\(nsError?.code ?? 0)", nsError?.localizedDescription, error)
    }

    /// Ported from `purchaseResultOrdinal` (PurchaselyRN.m:177-185).
    ///
    /// Returns **nil** for `.none`, exactly as the Objective-C function did.
    /// `PLYPurchaseResult` has four cases (`.swiftinterface:806`), and a
    /// dismissal with no purchase is `.none`. Mapping it to a number would put
    /// `purchaseResult: 1` — cancelled — on the wire for every plain dismissal.
    /// The call sites rely on `dict[key] = nil` removing the key.
    ///
    /// Do not copy the fallback in `PurchaselyView.swift:282`; it answers a
    /// different question.
    static func purchaseResultOrdinal(_ result: PLYPurchaseResult) -> NSNumber? {
        switch result {
        case .purchased: return 0
        case .cancelled: return 1
        case .restored: return 2
        case .none: return nil
        @unknown default: return nil
        }
    }

    // MARK: - PLYEventDelegate / PLYUserAttributeDelegate / PLYWebRedemptionDelegate
    //
    // Bodies live in PurchaselyRN+Presentations.swift (Task 12), which
    // replaces the stubs Task 8 put here so `start` (Task 9) could pass
    // `self` as all three delegates while the class kept compiling at every
    // commit boundary in between.
    //
    // PLYUserAttributeDelegate declares TWO onUserAttributeSet overloads (4-arg
    // and 5-arg — .swiftinterface, awk '/protocol PLYUserAttributeDelegate/,/^}/').
    // The Objective-C module implements ONLY the 5-argument one
    // (PurchaselyRN.m:1351-1355) and puts processingLegalBasis into the
    // USER_ATTRIBUTE_SET_LISTENER body (:1367). Implementing the 4-arg
    // overload instead would silently drop processingLegalBasis from that
    // event, so only the 5-arg overload is implemented — never both.
}
