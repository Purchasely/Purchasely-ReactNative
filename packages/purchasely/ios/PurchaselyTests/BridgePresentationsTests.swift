//
//  BridgePresentationsTests.swift
//  Unit tests for PurchaselyRN+Presentations.swift (Task 12). Only the
//  methods with behaviour observable without a live SDK are covered — a
//  method whose whole body is a single SDK call is exercised by E2E instead,
//  per the shared task shape.
//

import XCTest
@testable import react_native_purchasely
import Purchasely

// Minimal double for the `PLYPresentation` protocol, so `presentationToMap`
// and the emit helpers can be exercised without a live SDK presentation.
private final class FakePresentation: NSObject, PLYPresentation {
    var screenId: String = "screen-1"
    var language: String = "en"
    var placementId: String?
    var audienceId: String?
    var abTestId: String?
    var abTestVariantId: String?
    var campaignId: String?
    var flowId: String?
    var type: PLYPresentationType = .normal
    var controller: PLYPresentationViewController? { nil }
    var plans: [PLYPresentationPlan] = []
    var metadata: PLYPresentationMetadata? { nil }
    var backgroundColor: UIColor? { nil }
    var height: Int = 0
    var transition: PLYTransition { .fullScreen }
    var connections: Set<PLYConnection> = []
    var isFlow: Bool = false
    var onPresented: (((any PLYPresentation)?, Error?) -> Void)?
    var onCloseRequested: (() -> Void)?
    var onDismissed: ((PLYPresentationOutcome) -> Void)?

    func display(from sourceViewController: UIViewController?) {}
    func display(from sourceViewController: UIViewController?, transitionType: PLYTransition?) {}
    func close() {}
    func back() {}
    func executeConnection(_ connection: PLYConnection?) {}
    func preload(completion: @escaping ((any PLYPresentation)?, Error?) -> Void) {}
}

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

final class BridgePresentationsTests: XCTestCase {

    // MARK: - stringFromPresentationAction / presentationAction(from:)

    func testStringFromPresentationActionMapsEveryCase() {
        XCTAssertEqual(PurchaselyBridge.stringFromPresentationAction(.login), "login")
        XCTAssertEqual(PurchaselyBridge.stringFromPresentationAction(.purchase), "purchase")
        XCTAssertEqual(PurchaselyBridge.stringFromPresentationAction(.close), "close")
        XCTAssertEqual(PurchaselyBridge.stringFromPresentationAction(.closeAll), "closeAll")
        XCTAssertEqual(PurchaselyBridge.stringFromPresentationAction(.restore), "restore")
        XCTAssertEqual(PurchaselyBridge.stringFromPresentationAction(.navigate), "navigate")
        XCTAssertEqual(PurchaselyBridge.stringFromPresentationAction(.promoCode), "promoCode")
        XCTAssertEqual(PurchaselyBridge.stringFromPresentationAction(.openPresentation), "openPresentation")
        XCTAssertEqual(PurchaselyBridge.stringFromPresentationAction(.openPlacement), "openPlacement")
        XCTAssertEqual(PurchaselyBridge.stringFromPresentationAction(.webCheckout), "webCheckout")
    }

    func testPresentationActionFromStringRoundTripsAndRejectsUnknown() {
        XCTAssertEqual(PurchaselyBridge.presentationAction(from: "purchase"), .purchase)
        XCTAssertNil(PurchaselyBridge.presentationAction(from: "nonsense"))
        XCTAssertNil(PurchaselyBridge.presentationAction(from: nil))
    }

    // MARK: - stringFromWebCheckoutProvider

    func testStringFromWebCheckoutProviderMapsKnownAndFallsBackToUnknown() {
        XCTAssertEqual(PurchaselyBridge.stringFromWebCheckoutProvider(.stripe), "stripe")
        XCTAssertEqual(PurchaselyBridge.stringFromWebCheckoutProvider(.other), "other")
        XCTAssertEqual(PurchaselyBridge.stringFromWebCheckoutProvider(.none), "unknown")
    }

    // MARK: - closeReasonToRNString

    func testCloseReasonToRNStringMapsThreeReasonsAndNoneToNil() {
        XCTAssertEqual(PurchaselyBridge.closeReasonToRNString(.button), "button")
        XCTAssertEqual(PurchaselyBridge.closeReasonToRNString(.interactiveDismiss), "backSystem")
        XCTAssertEqual(PurchaselyBridge.closeReasonToRNString(.programmatic), "programmatic")
        XCTAssertNil(PurchaselyBridge.closeReasonToRNString(.none))
    }

    // MARK: - presentationErrorToMap

    func testPresentationErrorToMapIsNilForNilError() {
        XCTAssertNil(PurchaselyBridge.presentationErrorToMap(nil))
    }

    func testPresentationErrorToMapCarriesCodeDomainAndMessage() {
        let error = NSError(domain: "io.purchasely.test", code: 42,
                             userInfo: [NSLocalizedDescriptionKey: "boom"])
        let map = PurchaselyBridge.presentationErrorToMap(error)
        XCTAssertEqual(map?["code"] as? Int, 42)
        XCTAssertEqual(map?["domain"] as? String, "io.purchasely.test")
        XCTAssertEqual(map?["message"] as? String, "boom")
    }

    // MARK: - presentationToMap

    func testPresentationToMapOmitsNilOptionalFieldsAndSetsIdAlias() {
        let presentation = FakePresentation()
        presentation.screenId = "screen-42"
        presentation.language = "fr"

        let map = PurchaselyBridge.presentationToMap(presentation)

        XCTAssertEqual(map["screenId"] as? String, "screen-42")
        XCTAssertEqual(map["id"] as? String, "screen-42")
        XCTAssertEqual(map["language"] as? String, "fr")
        XCTAssertEqual(map["type"] as? Int, PLYPresentationType.normal.rawValue)
        XCTAssertEqual(map["height"] as? Int, 0)
        XCTAssertNil(map["placementId"], "nil placementId must be an absent key, not NSNull")
        XCTAssertNil(map["audienceId"])
        XCTAssertNil(map["campaignId"])
        XCTAssertNil(map["metadata"], "metadata is nil on the fake, so the key must be absent")
    }

    func testPresentationToMapIncludesOptionalFieldsWhenPresent() {
        let presentation = FakePresentation()
        presentation.placementId = "PLACEMENT"
        presentation.campaignId = "CAMPAIGN"

        let map = PurchaselyBridge.presentationToMap(presentation)

        XCTAssertEqual(map["placementId"] as? String, "PLACEMENT")
        XCTAssertEqual(map["campaignId"] as? String, "CAMPAIGN")
    }

    // MARK: - webRedemptionBody (exact shape asserted, same five keys as PurchaselyRNTests)

    func testWebRedemptionBodySuccessWithNoContextIsNSNull() {
        let body = PurchaselyBridge.webRedemptionBody(
            withSuccess: true, hasContext: false, subscription: nil,
            replay: false, errorCode: nil, errorMessage: nil
        )
        XCTAssertEqual(body.count, 5)
        XCTAssertEqual(body["isSuccess"] as? Bool, true)
        XCTAssertTrue(body["context"] is NSNull)
        XCTAssertTrue(body["errorCode"] is NSNull)
        XCTAssertTrue(body["errorMessage"] is NSNull)
    }

    func testWebRedemptionBodyKeepsAPresentContextWithNoSubscriptionDistinctFromNoContext() {
        let body = PurchaselyBridge.webRedemptionBody(
            withSuccess: true, hasContext: true, subscription: nil,
            replay: false, errorCode: nil, errorMessage: nil
        )
        let context = body["context"] as? NSDictionary
        XCTAssertNotNil(context, "a present context must stay a dictionary")
        XCTAssertTrue(context?["subscription"] is NSNull)
    }

    func testWebRedemptionBodyNestsTheSubscription() {
        let subscription: [String: String] = ["purchaseToken": "token-123"]
        let body = PurchaselyBridge.webRedemptionBody(
            withSuccess: true, hasContext: true, subscription: subscription,
            replay: false, errorCode: nil, errorMessage: nil
        )
        let context = body["context"] as? NSDictionary
        XCTAssertEqual(context?["subscription"] as? [String: String], subscription)
    }

    func testWebRedemptionBodyFailureCarriesErrorCodeAndMessage() {
        let body = PurchaselyBridge.webRedemptionBody(
            withSuccess: false, hasContext: false, subscription: nil,
            replay: false, errorCode: "EXPIRED_REDEMPTION_TOKEN", errorMessage: "Redemption link has expired."
        )
        XCTAssertEqual(body["isSuccess"] as? Bool, false)
        XCTAssertEqual(body["errorCode"] as? String, "EXPIRED_REDEMPTION_TOKEN")
        XCTAssertEqual(body["errorMessage"] as? String, "Redemption link has expired.")
    }

    // MARK: - extractPresentationTargets

    func testExtractPresentationTargetsReadsAllFourFields() {
        let targets = PurchaselyBridge.extractPresentationTargets([
            "placementId": "P1", "presentationId": "S1", "contentId": "C1", "isDefault": true,
        ])
        XCTAssertEqual(targets.placementId, "P1")
        XCTAssertEqual(targets.presentationId, "S1")
        XCTAssertEqual(targets.contentId, "C1")
        XCTAssertTrue(targets.isDefault)
    }

    func testExtractPresentationTargetsTreatsNSNullAsAbsent() {
        // The bridge sends explicit NSNull for an unset JS field; it must not
        // be mistaken for a real value (mirrors payload[@"x"] != [NSNull null]).
        let targets = PurchaselyBridge.extractPresentationTargets([
            "placementId": NSNull(), "isDefault": NSNull(),
        ])
        XCTAssertNil(targets.placementId)
        XCTAssertFalse(targets.isDefault)
    }

    func testExtractPresentationTargetsOfNilPayloadIsAllAbsent() {
        let targets = PurchaselyBridge.extractPresentationTargets(nil)
        XCTAssertNil(targets.placementId)
        XCTAssertNil(targets.presentationId)
        XCTAssertNil(targets.contentId)
        XCTAssertFalse(targets.isDefault)
    }

    // MARK: - transition(from:)

    func testTransitionFromNilMapIsNil() {
        XCTAssertNil(PurchaselyBridge.transition(from: nil))
    }

    func testTransitionFromMapParsesTypeAndPixelHeight() {
        let transition = PurchaselyBridge.transition(from: [
            "type": "drawer",
            "height": ["type": "pixel", "value": 320],
        ])
        XCTAssertEqual(transition?.type, .drawer)
        XCTAssertEqual(transition?.height, .value(320))
    }

    func testTransitionFromMapParsesPercentageWidthAndDismissible() {
        let transition = PurchaselyBridge.transition(from: [
            "width": ["type": "percentage", "value": 0.5],
            "dismissible": false,
        ])
        XCTAssertEqual(transition?.width, .percentage(0.5))
        XCTAssertEqual(transition?.dismissible, false)
    }

    func testTransitionFromMapDefaultsToFullScreenForUnknownType() {
        let transition = PurchaselyBridge.transition(from: ["type": "not-a-real-type"])
        XCTAssertEqual(transition?.type, .fullScreen)
    }

    // MARK: - presentationAction / registry helpers

    func testLoadedPresentationForRequestIdIsNilWhenUnregistered() {
        XCTAssertNil(PurchaselyBridge.loadedPresentation(forRequestId: "no-such-request"))
    }

    func testEvictPresentationRequestOfNilIsANoop() {
        // Must not crash — mirrors evictPresentationRequestId:(nullable ...).
        PurchaselyBridge.evictPresentationRequest(nil)
    }

    func testEvictPresentationRequestRemovesTheEntry() {
        let presentation = FakePresentation()
        PurchaselyBridge.withState { PurchaselyBridge.presentationsByRequest["req-evict"] = presentation }
        PurchaselyBridge.evictPresentationRequest("req-evict")
        XCTAssertNil(PurchaselyBridge.loadedPresentation(forRequestId: "req-evict"))
    }

    // MARK: - emitPresentationCloseRequested

    func testEmitPresentationCloseRequestedSendsEventWhenObserving() {
        let recorder = RecordingBridge()
        recorder.startObserving()

        PurchaselyBridge.emitPresentationCloseRequested(forId: "req-close-1")

        XCTAssertEqual(recorder.lastEventName, "PURCHASELY_PRESENTATION_CLOSE_REQUESTED")
        XCTAssertEqual(recorder.lastEventBody?["requestId"] as? String, "req-close-1")
        recorder.stopObserving()
    }

    func testEmitPresentationCloseRequestedIsNoopWhenNotObserving() {
        let recorder = RecordingBridge()
        recorder.startObserving()
        recorder.stopObserving()

        PurchaselyBridge.emitPresentationCloseRequested(forId: "req-close-2")

        XCTAssertNil(recorder.lastEventName)
    }

    // MARK: - closePresentation: proves the two-block lock shape does not deadlock

    func testClosePresentationTakesTheLockTwiceWithoutDeadlocking() {
        // No SDK presentation is registered under this requestId, so this
        // drives the `else` branch — which still acquires the lock twice,
        // once to look up and once to remove. If an executor hoisted
        // lock()/defer to the closure, this times out.
        let bridge = PurchaselyBridge()
        let done = expectation(description: "closePresentation returned")
        DispatchQueue.main.async {
            bridge.closePresentation("no-such-request")
            DispatchQueue.main.async {
                done.fulfill()
            }
        }
        wait(for: [done], timeout: 2.0)
    }
}
