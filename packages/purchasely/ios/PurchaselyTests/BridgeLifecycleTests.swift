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
private final class RecordingBridge: PurchaselyBridge {
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
        let mapped = PurchaselyBridge.mapPurposesFromStrings([
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
        let kebab = PurchaselyBridge.mapPurposesFromStrings(["third-party-integration"])
        let screamingSnakePlural = PurchaselyBridge.mapPurposesFromStrings(["THIRD_PARTY_INTEGRATIONS"])
        XCTAssertEqual(kebab, [PLYDataProcessingPurpose.thirdPartyIntegrations])
        XCTAssertEqual(screamingSnakePlural, [PLYDataProcessingPurpose.thirdPartyIntegrations])
    }

    func testMapPurposesFromStringsAllNonEssentialsShortCircuitsToOnlyThatPurpose() {
        // PurchaselyRN.m:1241-1243: "all-non-essentials" returns immediately
        // with a single-element set, ignoring any other purpose in the array.
        let mapped = PurchaselyBridge.mapPurposesFromStrings(["analytics", "all-non-essentials", "campaigns"])
        XCTAssertEqual(mapped, [PLYDataProcessingPurpose.allNonEssentials])
    }

    func testMapPurposesFromStringsIgnoresUnknownPurposes() {
        let mapped = PurchaselyBridge.mapPurposesFromStrings(["not-a-real-purpose"])
        XCTAssertTrue(mapped.isEmpty)
    }

    func testMapPurposesFromStringsOfEmptyArrayIsEmpty() {
        XCTAssertTrue(PurchaselyBridge.mapPurposesFromStrings([]).isEmpty)
    }

    // MARK: - setLogLevel / setThemeMode: the unknown-ordinal guard

    func testSetLogLevelWithUnknownOrdinalDoesNotCrash() {
        // PLYLogLevel(rawValue:) returns nil for an out-of-range ordinal
        // (Constraint 4); the guard-else logs and returns without touching
        // the SDK. Reaching this line without a live SDK started is itself
        // the proof the guard, not a force-unwrap, is what runs.
        let bridge = PurchaselyBridge()
        bridge.setLogLevel(9999)
    }

    func testSetThemeModeWithUnknownOrdinalDoesNotCrash() {
        let bridge = PurchaselyBridge()
        bridge.setThemeMode(9999)
    }

    // MARK: - handleDeeplink: the nil-deeplink rejection

    func testHandleDeeplinkWithNilDeeplinkRejectsSynchronouslyWithoutTouchingTheSDK() {
        // PurchaselyRN.m:663-676: a nil deeplink is rejected before the
        // dispatch_async to the SDK call, so this branch is fully testable
        // without a live SDK.
        let bridge = PurchaselyBridge()
        let rejected = expectation(description: "reject called")
        var rejectedCode: String?
        var rejectedMessage: String?
        bridge.handleDeeplink(nil, resolve: { _ in
            XCTFail("resolve must not be called for a nil deeplink")
        }, reject: { code, message, _ in
            rejectedCode = code
            rejectedMessage = message
            rejected.fulfill()
        })
        wait(for: [rejected], timeout: 1.0)
        XCTAssertEqual(rejectedCode, "-1")
        XCTAssertEqual(rejectedMessage, "Deeplink must not be null")
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
