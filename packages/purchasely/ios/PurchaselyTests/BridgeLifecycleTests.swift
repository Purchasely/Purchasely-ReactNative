//
//  BridgeLifecycleTests.swift
//  Unit tests for PurchaselyRN+Lifecycle.swift (Task 9). Only the methods
//  with behaviour observable without a live SDK are covered here — a method
//  whose whole body is a single SDK call (userLogin, allowDeeplink, ...) is
//  exercised by E2E instead, per the shared task shape.
//

import XCTest
@testable import react_native_purchasely

// Captures events sent through RCTEventEmitter, mirroring
// PurchaselyRNTests.swift's RecordingBridge but over the Swift skeleton, so
// `purchasePerformed`'s shouldEmit gate can be asserted without a full
// PLYPresentation double.
private final class RecordingBridge: PurchaselyRN {
    var lastEventName: String?
    var lastEventBody: NSDictionary?
    var sendEventCallCount = 0

    override func sendEvent(withName name: String!, body: Any!) {
        sendEventCallCount += 1
        lastEventName = name
        lastEventBody = body as? NSDictionary
    }
}

final class BridgeLifecycleTests: XCTestCase {

    // MARK: - mapPurposesFromStrings

    func testMapPurposesFromStringsMapsEachKebabPurpose() {
        let mapped = PurchaselyRN.mapPurposesFromStrings([
            "analytics", "identified-analytics", "campaigns", "personalization", "third-party-integration",
        ])
        XCTAssertEqual(mapped, [
            PLYDataProcessingPurpose.analytics,
            PLYDataProcessingPurpose.identifiedAnalytics,
            PLYDataProcessingPurpose.campaigns,
            PLYDataProcessingPurpose.personalization,
            PLYDataProcessingPurpose.thirdPartyIntegrations,
        ])
    }

    func testMapPurposesFromStringsAcceptsScreamingSnakeCasePluralAlias() {
        // PurchaselyRN.m:1225-1231: the other Purchasely SDKs send
        // SCREAMING_SNAKE_CASE plural ("THIRD_PARTY_INTEGRATIONS"); this
        // bridge's own wire strings are kebab-case singular. Both must map to
        // the same purpose.
        let kebab = PurchaselyRN.mapPurposesFromStrings(["third-party-integration"])
        let screamingSnakePlural = PurchaselyRN.mapPurposesFromStrings(["THIRD_PARTY_INTEGRATIONS"])
        XCTAssertEqual(kebab, [PLYDataProcessingPurpose.thirdPartyIntegrations])
        XCTAssertEqual(screamingSnakePlural, [PLYDataProcessingPurpose.thirdPartyIntegrations])
    }

    func testMapPurposesFromStringsAllNonEssentialsShortCircuitsToOnlyThatPurpose() {
        // PurchaselyRN.m:1241-1243: "all-non-essentials" returns immediately
        // with a single-element set, ignoring any other purpose in the array.
        let mapped = PurchaselyRN.mapPurposesFromStrings(["analytics", "all-non-essentials", "campaigns"])
        XCTAssertEqual(mapped, [PLYDataProcessingPurpose.allNonEssentials])
    }

    func testMapPurposesFromStringsIgnoresUnknownPurposes() {
        let mapped = PurchaselyRN.mapPurposesFromStrings(["not-a-real-purpose"])
        XCTAssertTrue(mapped.isEmpty)
    }

    func testMapPurposesFromStringsOfEmptyArrayIsEmpty() {
        XCTAssertTrue(PurchaselyRN.mapPurposesFromStrings([]).isEmpty)
    }

    // MARK: - setLogLevel / setThemeMode: the unknown-ordinal guard

    func testSetLogLevelWithUnknownOrdinalDoesNotCrash() {
        // PLYLogLevel(rawValue:) returns nil for an out-of-range ordinal
        // (Constraint 4); the guard-else logs and returns without touching
        // the SDK. Reaching this line without a live SDK started is itself
        // the proof the guard, not a force-unwrap, is what runs.
        let bridge = PurchaselyRN()
        bridge.setLogLevel(9999)
    }

    func testSetThemeModeWithUnknownOrdinalDoesNotCrash() {
        let bridge = PurchaselyRN()
        bridge.setThemeMode(9999)
    }

    // MARK: - handleDeeplink: the nil-deeplink rejection

    func testHandleDeeplinkWithNilDeeplinkRejectsSynchronouslyWithoutTouchingTheSDK() {
        // PurchaselyRN.m:663-676: a nil deeplink is rejected before the
        // dispatch_async to the SDK call, so this branch is fully testable
        // without a live SDK.
        //
        // Deliberately no XCTestExpectation/wait(for:) here: waiting would
        // also pass if the guard were (wrongly) moved inside
        // DispatchQueue.main.async, since the run loop would still fire the
        // reject before the timeout elapses. Asserting immediately, with no
        // run-loop pump in between, is what actually proves the rejection
        // happened on the calling thread before handleDeeplink returned.
        let bridge = PurchaselyRN()
        var resolveCalled = false
        var rejectedCode: String?
        var rejectedMessage: String?
        bridge.handleDeeplink(nil, resolve: { _ in
            resolveCalled = true
        }, reject: { code, message, _ in
            rejectedCode = code
            rejectedMessage = message
        })
        XCTAssertFalse(resolveCalled)
        XCTAssertEqual(rejectedCode, "-1")
        XCTAssertEqual(rejectedMessage, "Deeplink must not be null")
    }

    func testHandleDeeplinkWithMalformedURLResolvesFalseWithoutCallingTheSDK() {
        // Lifecycle.swift:215 — this is the port's only genuinely new code
        // path: `URL(string:)` returns nil for a malformed string, so a
        // non-optional Swift `URL` parameter has no nil to forward the way
        // the Objective-C original forwarded `NSURL URLWithString:`'s nil
        // straight into a `_Nonnull` SDK parameter. Instead of crashing, it
        // resolves `false`. An empty string is a value `URL(string:)` is
        // documented to reject — self-verified below so this test cannot
        // pass for the wrong reason on a Foundation where that changes.
        XCTAssertNil(URL(string: ""), "precondition: URL(string:) must reject an empty string")
        let bridge = PurchaselyRN()
        let resolved = expectation(description: "resolve called")
        var resolvedValue: Bool?
        bridge.handleDeeplink("", resolve: { value in
            resolvedValue = value as? Bool
            resolved.fulfill()
        }, reject: { _, _, _ in
            XCTFail("reject must not be called for a malformed deeplink")
        })
        wait(for: [resolved], timeout: 1.0)
        XCTAssertEqual(resolvedValue, false)
    }

    // MARK: - purchasePerformed: the shouldEmit gate

    func testPurchasePerformedEmitsPurchaseListenerWhenObserving() {
        let bridge = RecordingBridge()
        bridge.startObserving()
        bridge.purchasePerformed()
        XCTAssertEqual(bridge.lastEventName, "PURCHASE_LISTENER")
        XCTAssertEqual(bridge.lastEventBody, [:])
    }

    func testPurchasePerformedIsNoopWhenNotObserving() {
        let bridge = RecordingBridge()
        bridge.stopObserving()
        bridge.purchasePerformed()
        XCTAssertEqual(bridge.sendEventCallCount, 0)
    }
}
