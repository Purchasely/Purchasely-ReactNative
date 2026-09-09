//
//  PurchaselyRNTests.swift
//  PurchaselyRNTests
//
//  Unit tests for PurchaselyRN native module.
//
//  Ported from PurchaselyRNTests.m (Task 6): the suite must exercise the
//  Objective-C PurchaselyRN unchanged, so any behaviour drift caused by the
//  later Swift port (Tasks 8-14) shows up as a test failure instead of being
//  masked by the language change happening at the same time as the port.
//
//  Four tests were dropped, not ported: testSharedViewControllerInitialization,
//  testSharedViewControllerSingleton and testSetSharedViewController exercised
//  `+sharedViewController`, and testShouldReopenPaywallDefault exercised
//  `shouldReopenPaywall` — Task 7 deletes both members (along with
//  presentedPresentationViewController, which had no dedicated test), so a
//  test for either would not compile against the surface Task 7 leaves
//  behind.
//

import XCTest
@testable import react_native_purchasely

// Captures events sent through RCTEventEmitter so
// `emitPresentationCloseRequested(forId:)` (the native onCloseRequested -> JS
// bridge wired at preload/display time, see PurchaselyRN.m) can be asserted
// without a full PLYPresentation double: the helper never touches a
// presentation instance, only `_sharedEmitter`/`shouldEmit`.
//
// `sendEvent(withName:body:)` is RCTEventEmitter's override point
// (RCTEventEmitter.h:33), imported with implicitly-unwrapped-optional
// parameters since the header carries no nullability annotations.
private final class RecordingBridge: PurchaselyRN {
    var lastEventName: String?
    var lastEventBody: NSDictionary?

    override func sendEvent(withName name: String!, body: Any!) {
        lastEventName = name
        lastEventBody = body as? NSDictionary
    }
}

final class PurchaselyRNTests: XCTestCase {

    var purchaselyModule: PurchaselyRN!

    override func setUp() {
        super.setUp()
        purchaselyModule = PurchaselyRN()
    }

    override func tearDown() {
        purchaselyModule = nil
        super.tearDown()
    }

    /// `constantsToExport` is an optional protocol requirement, not a member of
    /// `PurchaselyRN.h` (RCTBridgeModule.h:358, `@optional`), so it must be
    /// reached through the protocol rather than called directly on the
    /// concrete type — a direct call does not compile. Mirrors
    /// `BridgeExportContractTests.liveConstants()`.
    private func constants() -> [String: Any] {
        guard let bridgeModule = purchaselyModule as? RCTBridgeModule,
              let constants = bridgeModule.constantsToExport?() else {
            XCTFail("PurchaselyRN does not export constants")
            return [:]
        }
        return constants as? [String: Any] ?? [:]
    }

    // MARK: - Module Initialization Tests

    func testModuleInitialization() {
        XCTAssertNotNil(purchaselyModule, "PurchaselyRN module should initialize")
    }

    // MARK: - Default presentation dismiss handler

    func testSupportedEventsIncludesDefaultPresentationDismissed() {
        let events = purchaselyModule.supportedEvents() as? [String] ?? []
        XCTAssertTrue(events.contains("PURCHASELY_DEFAULT_PRESENTATION_DISMISSED"),
                      "supportedEvents should expose the global default-dismiss event")
    }

    func testDefaultPresentationDismissHandlerIsBridged() {
        // RCT_EXPORT_METHOD generates a `setDefaultPresentationDismissHandler`
        // method on the module, forwarding straight to
        // `[Purchasely setDefaultPresentationDismissHandler:]` (available since
        // the native v6 rename — no respondsToSelector guard needed). Not
        // declared on the header, so reached via NSSelectorFromString rather
        // than #selector.
        XCTAssertTrue(purchaselyModule.responds(to: NSSelectorFromString("setDefaultPresentationDismissHandler")),
                      "setDefaultPresentationDismissHandler should be exported to the bridge")
    }

    func testRemoveDefaultPresentationDismissHandlerIsBridged() {
        XCTAssertTrue(purchaselyModule.responds(to: NSSelectorFromString("removeDefaultPresentationDismissHandler")),
                      "removeDefaultPresentationDismissHandler should be exported to the bridge")
    }

    // MARK: - Constants Export Tests

    func testConstantsExport() {
        // Ported from testConstantsExport in PurchaselyRNTests.m, which
        // asserted both "not nil" and "is a dictionary". `constants()`
        // already returns a non-Optional `[String: Any]`, so an
        // XCTAssertNotNil on it can never fail — the Swift type system
        // proves both of those for free. The one thing it does NOT prove is
        // that constantsToExport() actually populated the dictionary rather
        // than silently falling back to the helper's `[:]` default, so
        // assert that instead.
        let constants = constants()
        XCTAssertFalse(constants.isEmpty, "Constants should not be empty")
    }

    func testLogLevelConstants() {
        let constants = constants()

        XCTAssertNotNil(constants["logLevelDebug"], "logLevelDebug should exist")
        XCTAssertNotNil(constants["logLevelInfo"], "logLevelInfo should exist")
        XCTAssertNotNil(constants["logLevelWarn"], "logLevelWarn should exist")
        XCTAssertNotNil(constants["logLevelError"], "logLevelError should exist")

        XCTAssertTrue(constants["logLevelDebug"] is NSNumber, "logLevelDebug should be a number")
        XCTAssertTrue(constants["logLevelInfo"] is NSNumber, "logLevelInfo should be a number")
        XCTAssertTrue(constants["logLevelWarn"] is NSNumber, "logLevelWarn should be a number")
        XCTAssertTrue(constants["logLevelError"] is NSNumber, "logLevelError should be a number")
    }

    func testProductResultConstants() {
        let constants = constants()

        XCTAssertEqual(constants["productResultPurchased"] as? Int, 0,
                       "purchased must preserve the JS ProductResult ordinal")
        XCTAssertEqual(constants["productResultCancelled"] as? Int, 1,
                       "cancelled must preserve the JS ProductResult ordinal")
        XCTAssertEqual(constants["productResultRestored"] as? Int, 2,
                       "restored must preserve the JS ProductResult ordinal")
    }

    func testSubscriptionSourceConstants() {
        let constants = constants()

        XCTAssertNotNil(constants["sourceAppStore"], "sourceAppStore should exist")
        XCTAssertNotNil(constants["sourcePlayStore"], "sourcePlayStore should exist")
        XCTAssertNotNil(constants["sourceHuaweiAppGallery"], "sourceHuaweiAppGallery should exist")
        XCTAssertNotNil(constants["sourceAmazonAppstore"], "sourceAmazonAppstore should exist")
        // [RN-W-04 / ENM-07] Android's constantsToExport already includes
        // sourceNone; iOS was missing it entirely.
        XCTAssertNotNil(constants["sourceNone"], "sourceNone should exist")
    }

    func testAttributeConstants() {
        let constants = constants()

        // Marketing attribution constants
        XCTAssertNotNil(constants["firebaseAppInstanceId"], "firebaseAppInstanceId should exist")
        XCTAssertNotNil(constants["airshipChannelId"], "airshipChannelId should exist")
        XCTAssertNotNil(constants["airshipUserId"], "airshipUserId should exist")
        XCTAssertNotNil(constants["batchInstallationId"], "batchInstallationId should exist")
        XCTAssertNotNil(constants["adjustId"], "adjustId should exist")
        XCTAssertNotNil(constants["appsflyerId"], "appsflyerId should exist")
        // [ENM-04 / REC-11] onesignalPlayerId removed (no Android equivalent);
        // replaced by the two OneSignal attributes both natives support.
        XCTAssertNotNil(constants["oneSignalExternalId"], "oneSignalExternalId should exist")
        XCTAssertNotNil(constants["oneSignalUserId"], "oneSignalUserId should exist")
        XCTAssertNotNil(constants["mixpanelDistinctId"], "mixpanelDistinctId should exist")
        XCTAssertNotNil(constants["clevertapId"], "clevertapId should exist")
        XCTAssertNotNil(constants["sendinblueUserEmail"], "sendinblueUserEmail should exist")
        XCTAssertNotNil(constants["iterableUserId"], "iterableUserId should exist")
        XCTAssertNotNil(constants["iterableUserEmail"], "iterableUserEmail should exist")
        XCTAssertNotNil(constants["atInternetIdClient"], "atInternetIdClient should exist")
        XCTAssertNotNil(constants["amplitudeUserId"], "amplitudeUserId should exist")
        XCTAssertNotNil(constants["amplitudeDeviceId"], "amplitudeDeviceId should exist")
        XCTAssertNotNil(constants["mparticleUserId"], "mparticleUserId should exist")
        XCTAssertNotNil(constants["customerIoUserId"], "customerIoUserId should exist")
        XCTAssertNotNil(constants["customerIoUserEmail"], "customerIoUserEmail should exist")
        XCTAssertNotNil(constants["branchUserDeveloperIdentity"], "branchUserDeveloperIdentity should exist")
        XCTAssertNotNil(constants["moEngageUniqueId"], "moEngageUniqueId should exist")
        XCTAssertNotNil(constants["batchCustomUserId"], "batchCustomUserId should exist")
    }

    func testPlanTypeConstants() {
        let constants = constants()

        XCTAssertNotNil(constants["consumable"], "consumable should exist")
        XCTAssertNotNil(constants["nonConsumable"], "nonConsumable should exist")
        XCTAssertNotNil(constants["autoRenewingSubscription"], "autoRenewingSubscription should exist")
        XCTAssertNotNil(constants["nonRenewingSubscription"], "nonRenewingSubscription should exist")
        XCTAssertNotNil(constants["unknown"], "unknown should exist")
    }

    func testRunningModeConstants() {
        let constants = constants()

        // [ENM-06 / REC-17] The v5 runningModeTransactionOnly / runningModePaywallObserver
        // constants were removed — only Observer / Full remain in v6.
        XCTAssertNotNil(constants["runningModeObserver"], "runningModeObserver should exist")
        XCTAssertNotNil(constants["runningModeFull"], "runningModeFull should exist")
    }

    func testPresentationTypeConstants() {
        let constants = constants()

        XCTAssertNotNil(constants["presentationTypeNormal"], "presentationTypeNormal should exist")
        XCTAssertNotNil(constants["presentationTypeFallback"], "presentationTypeFallback should exist")
        XCTAssertNotNil(constants["presentationTypeDeactivated"], "presentationTypeDeactivated should exist")
        XCTAssertNotNil(constants["presentationTypeClient"], "presentationTypeClient should exist")
    }

    func testThemeModeConstants() {
        let constants = constants()

        XCTAssertNotNil(constants["themeLight"], "themeLight should exist")
        XCTAssertNotNil(constants["themeDark"], "themeDark should exist")
        XCTAssertNotNil(constants["themeSystem"], "themeSystem should exist")
    }

    func testUserAttributeConstants() {
        let constants = constants()

        // Source constants
        XCTAssertNotNil(constants["userAttributeSourcePurchasely"], "userAttributeSourcePurchasely should exist")
        XCTAssertNotNil(constants["userAttributeSourceClient"], "userAttributeSourceClient should exist")

        // Type constants
        XCTAssertNotNil(constants["userAttributeString"], "userAttributeString should exist")
        XCTAssertNotNil(constants["userAttributeBoolean"], "userAttributeBoolean should exist")
        XCTAssertNotNil(constants["userAttributeInt"], "userAttributeInt should exist")
        XCTAssertNotNil(constants["userAttributeFloat"], "userAttributeFloat should exist")
        XCTAssertNotNil(constants["userAttributeDate"], "userAttributeDate should exist")
        XCTAssertNotNil(constants["userAttributeStringArray"], "userAttributeStringArray should exist")
        XCTAssertNotNil(constants["userAttributeIntArray"], "userAttributeIntArray should exist")
        XCTAssertNotNil(constants["userAttributeFloatArray"], "userAttributeFloatArray should exist")
        XCTAssertNotNil(constants["userAttributeBooleanArray"], "userAttributeBooleanArray should exist")
    }

    // MARK: - Constants Count Test

    func testConstantsCount() {
        let constants = constants()

        // Based on the source code, we expect at least 55 constants
        // Log levels (4) + Product results (3) + Sources (5, incl. sourceNone) + Attributes (22,
        // onesignalPlayerId removed, oneSignalExternalId/oneSignalUserId added) + Plan types (5)
        // + Running modes (2, v5 TransactionOnly/PaywallObserver removed)
        // + Presentation types (4) + Theme modes (3) + User attribute sources (2)
        // + User attribute types (9) = 59 constants
        XCTAssertGreaterThanOrEqual(constants.count, 50, "Should export at least 50 constants")
    }

    // MARK: - Module Properties Tests

    func testShouldEmitDefault() {
        // `Boolean shouldEmit` (PurchaselyRN.h:38) bridges as Swift `Bool` in
        // this toolchain (verified by the compiler, not by the plan's note
        // that `Boolean` imports as UInt8 — the interface wins).
        XCTAssertFalse(purchaselyModule.shouldEmit, "shouldEmit should default to NO")
    }

    // MARK: - Constants Values Tests

    func testLogLevelOrdering() {
        let constants = constants()

        let debug = (constants["logLevelDebug"] as? NSNumber)?.intValue ?? 0
        let info = (constants["logLevelInfo"] as? NSNumber)?.intValue ?? 0
        let warn = (constants["logLevelWarn"] as? NSNumber)?.intValue ?? 0
        let error = (constants["logLevelError"] as? NSNumber)?.intValue ?? 0

        // Verify logical ordering (debug < info < warn < error in most logging systems)
        // Or at least they are all different
        let uniqueValues = Set([debug, info, warn, error])
        XCTAssertEqual(uniqueValues.count, 4, "All log levels should have unique values")
    }

    func testProductResultsUnique() {
        let constants = constants()

        let purchased = (constants["productResultPurchased"] as? NSNumber)?.intValue ?? 0
        let cancelled = (constants["productResultCancelled"] as? NSNumber)?.intValue ?? 0
        let restored = (constants["productResultRestored"] as? NSNumber)?.intValue ?? 0

        let uniqueValues = Set([purchased, cancelled, restored])
        XCTAssertEqual(uniqueValues.count, 3, "All product results should have unique values")
    }

    func testSubscriptionSourcesUnique() {
        let constants = constants()

        let appStore = (constants["sourceAppStore"] as? NSNumber)?.intValue ?? 0
        let playStore = (constants["sourcePlayStore"] as? NSNumber)?.intValue ?? 0
        let huawei = (constants["sourceHuaweiAppGallery"] as? NSNumber)?.intValue ?? 0
        let amazon = (constants["sourceAmazonAppstore"] as? NSNumber)?.intValue ?? 0
        let none = (constants["sourceNone"] as? NSNumber)?.intValue ?? 0

        let uniqueValues = Set([appStore, playStore, huawei, amazon, none])
        XCTAssertEqual(uniqueValues.count, 5, "All subscription sources should have unique values")
    }

    func testPlanTypesUnique() {
        let constants = constants()

        let consumable = (constants["consumable"] as? NSNumber)?.intValue ?? 0
        let nonConsumable = (constants["nonConsumable"] as? NSNumber)?.intValue ?? 0
        let autoRenewing = (constants["autoRenewingSubscription"] as? NSNumber)?.intValue ?? 0
        let nonRenewing = (constants["nonRenewingSubscription"] as? NSNumber)?.intValue ?? 0
        let unknown = (constants["unknown"] as? NSNumber)?.intValue ?? 0

        let uniqueValues = Set([consumable, nonConsumable, autoRenewing, nonRenewing, unknown])
        XCTAssertEqual(uniqueValues.count, 5, "All plan types should have unique values")
    }

    func testRunningModesUnique() {
        let constants = constants()

        let observer = (constants["runningModeObserver"] as? NSNumber)?.intValue ?? 0
        let full = (constants["runningModeFull"] as? NSNumber)?.intValue ?? 0

        let uniqueValues = Set([observer, full])
        XCTAssertEqual(uniqueValues.count, 2, "All running modes should have unique values")
    }

    func testThemeModesUnique() {
        let constants = constants()

        let light = (constants["themeLight"] as? NSNumber)?.intValue ?? 0
        let dark = (constants["themeDark"] as? NSNumber)?.intValue ?? 0
        let system = (constants["themeSystem"] as? NSNumber)?.intValue ?? 0

        let uniqueValues = Set([light, dark, system])
        XCTAssertEqual(uniqueValues.count, 3, "All theme modes should have unique values")
    }

    func testUserAttributeTypesUnique() {
        let constants = constants()

        let stringType = (constants["userAttributeString"] as? NSNumber)?.intValue ?? 0
        let boolType = (constants["userAttributeBoolean"] as? NSNumber)?.intValue ?? 0
        let intType = (constants["userAttributeInt"] as? NSNumber)?.intValue ?? 0
        let floatType = (constants["userAttributeFloat"] as? NSNumber)?.intValue ?? 0
        let dateType = (constants["userAttributeDate"] as? NSNumber)?.intValue ?? 0
        let stringArrayType = (constants["userAttributeStringArray"] as? NSNumber)?.intValue ?? 0
        let intArrayType = (constants["userAttributeIntArray"] as? NSNumber)?.intValue ?? 0
        let floatArrayType = (constants["userAttributeFloatArray"] as? NSNumber)?.intValue ?? 0
        let boolArrayType = (constants["userAttributeBooleanArray"] as? NSNumber)?.intValue ?? 0

        let uniqueValues = Set([
            stringType, boolType, intType, floatType, dateType,
            stringArrayType, intArrayType, floatArrayType, boolArrayType,
        ])
        XCTAssertEqual(uniqueValues.count, 9, "All user attribute types should have unique values")
    }

    // MARK: - CLOSE_REQUESTED semantics (native-initiated only, not request.close())

    func testClosePresentationIsBridged() {
        XCTAssertTrue(purchaselyModule.responds(to: NSSelectorFromString("closePresentation:")),
                      "closePresentation: should be exported to the bridge")
    }

    // MARK: - Web2App redemption (6.1.0)

    func testSupportedEventsIncludesWebRedemptionListener() {
        let events = purchaselyModule.supportedEvents() as? [String] ?? []
        XCTAssertTrue(events.contains("WEB_REDEMPTION_LISTENER"),
                      "supportedEvents should expose the web redemption event")
    }

    func testModuleConformsToWebRedemptionDelegate() {
        // The bridge registers itself on the start chain
        // (`webRedemptionDelegate:appHandlesRedemptionAlert:`), so it must conform.
        XCTAssertTrue(purchaselyModule.conforms(to: PLYWebRedemptionDelegate.self),
                      "PurchaselyRN should conform to PLYWebRedemptionDelegate")
    }

    func testWebRedemptionCompletedIsImplemented() {
        // Swift `webRedemptionCompleted(result:)` bridges to this selector.
        XCTAssertTrue(purchaselyModule.responds(to: NSSelectorFromString("webRedemptionCompletedWithResult:")),
                      "the web redemption delegate callback should be implemented")
    }

    /// The five keys must be present on every branch. A JS listener reads the same
    /// shape whether the redemption succeeded or failed.
    private func assertWebRedemptionShape(_ body: [String: Any]) {
        XCTAssertEqual(body.count, 5, "the body must always carry exactly five keys")
        for key in ["isSuccess", "context", "replay", "errorCode", "errorMessage"] {
            XCTAssertNotNil(body[key], "\(key) must be present")
        }
    }

    func testWebRedemptionBodySuccessWithNoContext() {
        let body = PurchaselyRN.webRedemptionBody(
            withSuccess: true, hasContext: false, subscription: nil,
            replay: false, errorCode: nil, errorMessage: nil
        )

        assertWebRedemptionShape(body)
        XCTAssertEqual(body["isSuccess"] as? Bool, true)
        XCTAssertTrue(body["context"] is NSNull,
                      "no context at all must be NSNull, not an empty dictionary")
        XCTAssertEqual(body["replay"] as? Bool, false)
        XCTAssertTrue(body["errorCode"] is NSNull)
        XCTAssertTrue(body["errorMessage"] is NSNull)
    }

    /// A present context with no subscription is NOT the same as no context. Both
    /// levels stay separately nullable, matching the Android bridge.
    func testWebRedemptionBodyKeepsAPresentContextWithNoSubscription() {
        let body = PurchaselyRN.webRedemptionBody(
            withSuccess: true, hasContext: true, subscription: nil,
            replay: false, errorCode: nil, errorMessage: nil
        )

        assertWebRedemptionShape(body)
        XCTAssertTrue(body["context"] is NSDictionary, "a present context must stay a dictionary")
        let context = body["context"] as? NSDictionary
        XCTAssertTrue(context?["subscription"] is NSNull)
    }

    func testWebRedemptionBodyNestsTheSubscription() {
        let subscription: [String: String] = ["purchaseToken": "token-123"]
        let body = PurchaselyRN.webRedemptionBody(
            withSuccess: true, hasContext: true, subscription: subscription,
            replay: false, errorCode: nil, errorMessage: nil
        )

        assertWebRedemptionShape(body)
        let context = body["context"] as? NSDictionary
        XCTAssertEqual(context?["subscription"] as? [String: String], subscription)
    }

    func testWebRedemptionBodyReportsAReplayedToken() {
        let body = PurchaselyRN.webRedemptionBody(
            withSuccess: true, hasContext: true, subscription: nil,
            replay: true, errorCode: nil, errorMessage: nil
        )

        XCTAssertEqual(body["replay"] as? Bool, true)
        XCTAssertEqual(body["isSuccess"] as? Bool, true, "a replay is still a success")
    }

    func testWebRedemptionBodyFailureKeepsTheShapeStable() {
        let body = PurchaselyRN.webRedemptionBody(
            withSuccess: false, hasContext: false, subscription: nil,
            replay: false, errorCode: "EXPIRED_REDEMPTION_TOKEN",
            errorMessage: "Redemption link has expired."
        )

        assertWebRedemptionShape(body)
        XCTAssertEqual(body["isSuccess"] as? Bool, false)
        XCTAssertTrue(body["context"] is NSNull)
        XCTAssertEqual(body["replay"] as? Bool, false,
                       "a failure still reports replay, so the shape never changes")
        XCTAssertEqual(body["errorCode"] as? String, "EXPIRED_REDEMPTION_TOKEN")
        XCTAssertEqual(body["errorMessage"] as? String, "Redemption link has expired.")
    }

    /// A transport or parsing failure never reached the server, so it carries no code.
    func testWebRedemptionBodyFailureWithNoErrorCode() {
        let body = PurchaselyRN.webRedemptionBody(
            withSuccess: false, hasContext: false, subscription: nil,
            replay: false, errorCode: nil, errorMessage: "Redemption could not be completed."
        )

        assertWebRedemptionShape(body)
        XCTAssertTrue(body["errorCode"] is NSNull)
        XCTAssertEqual(body["errorMessage"] as? String, "Redemption could not be completed.")
    }

    func testSupportedEventsIncludesCloseRequested() {
        let events = purchaselyModule.supportedEvents() as? [String] ?? []
        XCTAssertTrue(events.contains("PURCHASELY_PRESENTATION_CLOSE_REQUESTED"),
                      "supportedEvents should expose the native close-requested event")
    }

    func testEmitPresentationCloseRequestedForIdSendsEventWhenObserving() {
        let recorder = RecordingBridge()
        recorder.startObserving()

        PurchaselyRN.emitPresentationCloseRequested(forId: "req-close-1")

        XCTAssertEqual(recorder.lastEventName, "PURCHASELY_PRESENTATION_CLOSE_REQUESTED")
        XCTAssertEqual(recorder.lastEventBody?["requestId"] as? String, "req-close-1")

        recorder.stopObserving()
    }

    func testEmitPresentationCloseRequestedForIdIsNoopWhenNotObserving() {
        let recorder = RecordingBridge()
        // Actually exercise the shouldEmit guard: go through the full observing
        // lifecycle so `_sharedEmitter` is this recorder with `shouldEmit == NO`,
        // instead of relying on `_sharedEmitter` being nil by happenstance
        // (stopObserving flips shouldEmit back off but never clears _sharedEmitter).
        recorder.startObserving()
        recorder.stopObserving()

        PurchaselyRN.emitPresentationCloseRequested(forId: "req-close-2")

        XCTAssertNil(recorder.lastEventName,
                     "emitPresentationCloseRequestedForId: should drop the event once the recorder has stopped observing")
    }

    func testClosePresentationNeverEmitsCloseRequestedItself() {
        // [Fix B] The core breaking-change guarantee of 40fcfa1a: closePresentation:
        // (the JS-programmatic close path) must never itself emit CLOSE_REQUESTED —
        // that event is reserved for the native SDK asking to close on its own via
        // the onCloseRequested hook wired at preload/display time.
        // `startObserving` sets the class-wide `_sharedEmitter` static to
        // `self` (PurchaselyRN.m:1305), so the recorder observes whichever
        // instance last started observing — not necessarily the instance a
        // caller invokes a method on. The original Objective-C test
        // exercised that: it called closePresentation: on a PLAIN
        // `self.purchaselyModule`, a different instance from the recorder,
        // to prove the emission path routes through the shared emitter
        // rather than through `self`. Match that here instead of invoking
        // on the recorder itself, which would trivially pass regardless of
        // whether the shared-emitter routing is right.
        let recorder = RecordingBridge()
        recorder.startObserving()

        // closePresentation: is an RCT_EXPORT_METHOD, not declared on the
        // @interface (see the responds(to:) check above), so a direct message
        // send won't compile — invoke it via its IMP instead.
        typealias ClosePresentationFn = @convention(c) (AnyObject, Selector, NSString) -> Void
        let selector = NSSelectorFromString("closePresentation:")
        let imp = purchaselyModule.method(for: selector)
        let closePresentation = unsafeBitCast(imp, to: ClosePresentationFn.self)
        closePresentation(purchaselyModule, selector, "req-programmatic-close")

        // closePresentation: dispatches its work onto the main queue; enqueue a
        // second block after it to drain the queue in order before asserting.
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async {
            drained.fulfill()
        }
        wait(for: [drained], timeout: 1.0)

        XCTAssertNil(recorder.lastEventName,
                     "closePresentation: must never emit CLOSE_REQUESTED itself")

        recorder.stopObserving()
    }
}
