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

private final class RecordingBridge: PurchaselyRN {
    var lastEventName: String?
    var lastEventBody: NSDictionary?
    var sendEventCallCount = 0
    // Accumulates every event, in order — needed for preloadPresentation /
    // displayPresentation, which can emit more than one event (loaded,
    // presented, dismissed) from a single call.
    var recordedEvents: [(name: String, body: NSDictionary?)] = []

    override func sendEvent(withName name: String!, body: Any!) {
        sendEventCallCount += 1
        lastEventName = name
        lastEventBody = body as? NSDictionary
        recordedEvents.append((name, body as? NSDictionary))
    }
}

final class BridgePresentationsTests: XCTestCase {

    // MARK: - stringFromPresentationAction / presentationAction(from:)

    func testStringFromPresentationActionMapsEveryCase() {
        XCTAssertEqual(PurchaselyRN.stringFromPresentationAction(.login), "login")
        XCTAssertEqual(PurchaselyRN.stringFromPresentationAction(.purchase), "purchase")
        XCTAssertEqual(PurchaselyRN.stringFromPresentationAction(.close), "close")
        XCTAssertEqual(PurchaselyRN.stringFromPresentationAction(.closeAll), "closeAll")
        XCTAssertEqual(PurchaselyRN.stringFromPresentationAction(.restore), "restore")
        XCTAssertEqual(PurchaselyRN.stringFromPresentationAction(.navigate), "navigate")
        XCTAssertEqual(PurchaselyRN.stringFromPresentationAction(.promoCode), "promoCode")
        XCTAssertEqual(PurchaselyRN.stringFromPresentationAction(.openPresentation), "openPresentation")
        XCTAssertEqual(PurchaselyRN.stringFromPresentationAction(.openPlacement), "openPlacement")
        XCTAssertEqual(PurchaselyRN.stringFromPresentationAction(.webCheckout), "webCheckout")
    }

    func testPresentationActionFromStringRoundTripsAndRejectsUnknown() {
        XCTAssertEqual(PurchaselyRN.presentationAction(from: "purchase"), .purchase)
        XCTAssertNil(PurchaselyRN.presentationAction(from: "nonsense"))
        XCTAssertNil(PurchaselyRN.presentationAction(from: nil))
    }

    // MARK: - stringFromWebCheckoutProvider

    func testStringFromWebCheckoutProviderMapsKnownAndFallsBackToUnknown() {
        XCTAssertEqual(PurchaselyRN.stringFromWebCheckoutProvider(.stripe), "stripe")
        XCTAssertEqual(PurchaselyRN.stringFromWebCheckoutProvider(.other), "other")
        XCTAssertEqual(PurchaselyRN.stringFromWebCheckoutProvider(.none), "unknown")
    }

    // MARK: - closeReasonToRNString

    func testCloseReasonToRNStringMapsThreeReasonsAndNoneToNil() {
        XCTAssertEqual(PurchaselyRN.closeReasonToRNString(.button), "button")
        XCTAssertEqual(PurchaselyRN.closeReasonToRNString(.interactiveDismiss), "backSystem")
        XCTAssertEqual(PurchaselyRN.closeReasonToRNString(.programmatic), "programmatic")
        XCTAssertNil(PurchaselyRN.closeReasonToRNString(.none))
    }

    // MARK: - presentationErrorToMap

    func testPresentationErrorToMapIsNilForNilError() {
        XCTAssertNil(PurchaselyRN.presentationErrorToMap(nil))
    }

    func testPresentationErrorToMapCarriesCodeDomainAndMessage() {
        let error = NSError(domain: "io.purchasely.test", code: 42,
                             userInfo: [NSLocalizedDescriptionKey: "boom"])
        let map = PurchaselyRN.presentationErrorToMap(error)
        XCTAssertEqual(map?["code"] as? Int, 42)
        XCTAssertEqual(map?["domain"] as? String, "io.purchasely.test")
        XCTAssertEqual(map?["message"] as? String, "boom")
    }

    // MARK: - presentationToMap

    func testPresentationToMapOmitsNilOptionalFieldsAndSetsIdAlias() {
        let presentation = FakePresentation()
        presentation.screenId = "screen-42"
        presentation.language = "fr"

        let map = PurchaselyRN.presentationToMap(presentation)

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

        let map = PurchaselyRN.presentationToMap(presentation)

        XCTAssertEqual(map["placementId"] as? String, "PLACEMENT")
        XCTAssertEqual(map["campaignId"] as? String, "CAMPAIGN")
    }

    // MARK: - webRedemptionBody (exact shape asserted, same five keys as PurchaselyRNTests)

    func testWebRedemptionBodySuccessWithNoContextIsNSNull() {
        let body = PurchaselyRN.webRedemptionBody(
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
        let body = PurchaselyRN.webRedemptionBody(
            withSuccess: true, hasContext: true, subscription: nil,
            replay: false, errorCode: nil, errorMessage: nil
        )
        let context = body["context"] as? NSDictionary
        XCTAssertNotNil(context, "a present context must stay a dictionary")
        XCTAssertTrue(context?["subscription"] is NSNull)
    }

    func testWebRedemptionBodyNestsTheSubscription() {
        let subscription: [String: String] = ["purchaseToken": "token-123"]
        let body = PurchaselyRN.webRedemptionBody(
            withSuccess: true, hasContext: true, subscription: subscription,
            replay: false, errorCode: nil, errorMessage: nil
        )
        let context = body["context"] as? NSDictionary
        XCTAssertEqual(context?["subscription"] as? [String: String], subscription)
    }

    func testWebRedemptionBodyFailureCarriesErrorCodeAndMessage() {
        let body = PurchaselyRN.webRedemptionBody(
            withSuccess: false, hasContext: false, subscription: nil,
            replay: false, errorCode: "EXPIRED_REDEMPTION_TOKEN", errorMessage: "Redemption link has expired."
        )
        XCTAssertEqual(body["isSuccess"] as? Bool, false)
        XCTAssertEqual(body["errorCode"] as? String, "EXPIRED_REDEMPTION_TOKEN")
        XCTAssertEqual(body["errorMessage"] as? String, "Redemption link has expired.")
    }

    // MARK: - extractPresentationTargets

    func testExtractPresentationTargetsReadsAllFourFields() {
        let targets = PurchaselyRN.extractPresentationTargets([
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
        let targets = PurchaselyRN.extractPresentationTargets([
            "placementId": NSNull(), "isDefault": NSNull(),
        ])
        XCTAssertNil(targets.placementId)
        XCTAssertFalse(targets.isDefault)
    }

    func testExtractPresentationTargetsOfNilPayloadIsAllAbsent() {
        let targets = PurchaselyRN.extractPresentationTargets(nil)
        XCTAssertNil(targets.placementId)
        XCTAssertNil(targets.presentationId)
        XCTAssertNil(targets.contentId)
        XCTAssertFalse(targets.isDefault)
    }

    // MARK: - transition(from:)

    func testTransitionFromNilMapIsNil() {
        XCTAssertNil(PurchaselyRN.transition(from: nil))
    }

    func testTransitionFromMapParsesTypeAndPixelHeight() {
        let transition = PurchaselyRN.transition(from: [
            "type": "drawer",
            "height": ["type": "pixel", "value": 320],
        ])
        XCTAssertEqual(transition?.type, .drawer)
        XCTAssertEqual(transition?.height, .value(320))
    }

    func testTransitionFromMapParsesPercentageWidthAndDismissible() {
        let transition = PurchaselyRN.transition(from: [
            "width": ["type": "percentage", "value": 0.5],
            "dismissible": false,
        ])
        XCTAssertEqual(transition?.width, .percentage(0.5))
        XCTAssertEqual(transition?.dismissible, false)
    }

    func testTransitionFromMapDefaultsToFullScreenForUnknownType() {
        let transition = PurchaselyRN.transition(from: ["type": "not-a-real-type"])
        XCTAssertEqual(transition?.type, .fullScreen)
    }

    // MARK: - presentationAction / registry helpers

    func testLoadedPresentationForRequestIdIsNilWhenUnregistered() {
        XCTAssertNil(PurchaselyRN.loadedPresentation(forRequestId: "no-such-request"))
    }

    func testEvictPresentationRequestOfNilIsANoop() {
        // Must not crash — mirrors evictPresentationRequestId:(nullable ...).
        PurchaselyRN.evictPresentationRequest(nil)
    }

    func testEvictPresentationRequestRemovesTheEntry() {
        let presentation = FakePresentation()
        PurchaselyRN.withState { PurchaselyRN.presentationsByRequest["req-evict"] = presentation }
        PurchaselyRN.evictPresentationRequest("req-evict")
        XCTAssertNil(PurchaselyRN.loadedPresentation(forRequestId: "req-evict"))
    }

    // MARK: - emitPresentationCloseRequested

    func testEmitPresentationCloseRequestedSendsEventWhenObserving() {
        let recorder = RecordingBridge()
        recorder.startObserving()

        PurchaselyRN.emitPresentationCloseRequested(forId: "req-close-1")

        XCTAssertEqual(recorder.lastEventName, "PURCHASELY_PRESENTATION_CLOSE_REQUESTED")
        XCTAssertEqual(recorder.lastEventBody?["requestId"] as? String, "req-close-1")
        recorder.stopObserving()
    }

    func testEmitPresentationCloseRequestedIsNoopWhenNotObserving() {
        let recorder = RecordingBridge()
        recorder.startObserving()
        recorder.stopObserving()

        PurchaselyRN.emitPresentationCloseRequested(forId: "req-close-2")

        XCTAssertNil(recorder.lastEventName)
    }

    // MARK: - emitPresentationDismissed(forId:outcome:) — every key, its
    // value type, and its per-field absence policy read from
    // PurchaselyRN.m:405-436.

    func testEmitPresentationDismissedOmitsRequestIdKeyWhenIdIsNil() {
        // Fix 2: PurchaselyRN.m:416 is a mutable-dict subscript assignment
        // (`body[@"requestId"] = routingId;`), which OMITS the key on nil —
        // it must not become "".
        let recorder = RecordingBridge()
        recorder.startObserving()
        let outcome = PLYPresentationOutcome(purchaseResult: .none, plan: nil, presentation: nil, closeReason: .none, error: nil)

        PurchaselyRN.emitPresentationDismissed(forId: nil, outcome: outcome)

        XCTAssertNil(recorder.lastEventBody?["requestId"], "a nil requestId must be an absent key, not \"\"")
        recorder.stopObserving()
    }

    func testEmitPresentationDismissedCarriesRequestIdWhenPresent() {
        let recorder = RecordingBridge()
        recorder.startObserving()
        let outcome = PLYPresentationOutcome(purchaseResult: .none, plan: nil, presentation: nil, closeReason: .none, error: nil)

        PurchaselyRN.emitPresentationDismissed(forId: "req-1", outcome: outcome)

        XCTAssertEqual(recorder.lastEventName, "PURCHASELY_PRESENTATION_DISMISSED")
        XCTAssertEqual(recorder.lastEventBody?["requestId"] as? String, "req-1")
        recorder.stopObserving()
    }

    func testEmitPresentationDismissedOmitsPresentationWhenBothOutcomeAndRegistryAreNil() {
        let recorder = RecordingBridge()
        recorder.startObserving()
        let outcome = PLYPresentationOutcome(purchaseResult: .none, plan: nil, presentation: nil, closeReason: .none, error: nil)

        PurchaselyRN.emitPresentationDismissed(forId: "req-no-presentation", outcome: outcome)

        XCTAssertNil(recorder.lastEventBody?["presentation"])
        recorder.stopObserving()
    }

    func testEmitPresentationDismissedFallsBackToTheRegistryWhenOutcomeHasNoPresentation() {
        // PurchaselyRN.m:409-413: if the outcome carries no presentation,
        // look it up in `kPresentationsByRequest` by the same request id.
        let recorder = RecordingBridge()
        recorder.startObserving()
        let presentation = FakePresentation()
        presentation.screenId = "screen-registry"
        PurchaselyRN.withState { PurchaselyRN.presentationsByRequest["req-registry"] = presentation }
        let outcome = PLYPresentationOutcome(purchaseResult: .none, plan: nil, presentation: nil, closeReason: .none, error: nil)

        PurchaselyRN.emitPresentationDismissed(forId: "req-registry", outcome: outcome)

        let body = (recorder.lastEventBody?["presentation"] as? NSDictionary)
        XCTAssertEqual(body?["screenId"] as? String, "screen-registry")
        recorder.stopObserving()
    }

    func testEmitPresentationDismissedRemovesTheRequestFromTheRegistry() {
        let recorder = RecordingBridge()
        recorder.startObserving()
        let presentation = FakePresentation()
        PurchaselyRN.withState { PurchaselyRN.presentationsByRequest["req-evict-2"] = presentation }
        let outcome = PLYPresentationOutcome(purchaseResult: .none, plan: nil, presentation: nil, closeReason: .none, error: nil)

        PurchaselyRN.emitPresentationDismissed(forId: "req-evict-2", outcome: outcome)

        XCTAssertNil(PurchaselyRN.loadedPresentation(forRequestId: "req-evict-2"))
        recorder.stopObserving()
    }

    func testEmitPresentationDismissedOmitsPurchaseResultForNoneOutcome() {
        // PLYPurchaseResult.none maps to nil (purchaseResultOrdinal), so the
        // key must be absent, never a "none" ordinal.
        let recorder = RecordingBridge()
        recorder.startObserving()
        let outcome = PLYPresentationOutcome(purchaseResult: .none, plan: nil, presentation: nil, closeReason: .none, error: nil)

        PurchaselyRN.emitPresentationDismissed(forId: "req-2", outcome: outcome)

        XCTAssertNil(recorder.lastEventBody?["purchaseResult"])
        recorder.stopObserving()
    }

    func testEmitPresentationDismissedCarriesThePurchasedOrdinalAndPlan() {
        let recorder = RecordingBridge()
        recorder.startObserving()
        let plan = try! SerializationFixtures.plan(populated: true)
        let outcome = PLYPresentationOutcome(purchaseResult: .purchased, plan: plan, presentation: nil, closeReason: .none, error: nil)

        PurchaselyRN.emitPresentationDismissed(forId: "req-3", outcome: outcome)

        XCTAssertEqual(recorder.lastEventBody?["purchaseResult"] as? Int, 0)
        // Value type: "plan" is `[outcome.plan asDictionary]`, an NSDictionary
        // (PurchaselyRN.m:424), never a boxed PLYPlan.
        let planBody = recorder.lastEventBody?["plan"] as? NSDictionary
        XCTAssertNotNil(planBody, "\"plan\" must be a dictionary")
        XCTAssertEqual(planBody?["vendorId"] as? String, "PLAN_MONTHLY")
        recorder.stopObserving()
    }

    func testEmitPresentationDismissedOmitsPlanWhenOutcomeHasNone() {
        // PurchaselyRN.m:421-423: `if (outcome.plan != nil) { body[@"plan"]
        // = ...; }` — no assignment at all when nil, so the key is absent,
        // never NSNull.
        let recorder = RecordingBridge()
        recorder.startObserving()
        let outcome = PLYPresentationOutcome(purchaseResult: .purchased, plan: nil, presentation: nil, closeReason: .none, error: nil)

        PurchaselyRN.emitPresentationDismissed(forId: "req-3-no-plan", outcome: outcome)

        XCTAssertNil(recorder.lastEventBody?["plan"])
        recorder.stopObserving()
    }

    func testEmitPresentationDismissedCarriesErrorAndOmitsCloseReasonWhenErrorPresent() {
        // Exclusion rule (PurchaselyRN.m:427-434): closeReason is surfaced
        // only when there is no error.
        let recorder = RecordingBridge()
        recorder.startObserving()
        let error = NSError(domain: "io.purchasely.test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        let outcome = PLYPresentationOutcome(purchaseResult: .none, plan: nil, presentation: nil, closeReason: .button, error: error)

        PurchaselyRN.emitPresentationDismissed(forId: "req-4", outcome: outcome)

        // Value type: "error" is presentationErrorToMap(error), an
        // NSDictionary with code/domain/message, never the boxed NSError.
        let errorBody = recorder.lastEventBody?["error"] as? NSDictionary
        XCTAssertNotNil(errorBody, "\"error\" must be a dictionary")
        XCTAssertEqual(errorBody?["code"] as? Int, 1)
        XCTAssertEqual(errorBody?["domain"] as? String, "io.purchasely.test")
        XCTAssertEqual(errorBody?["message"] as? String, "boom")
        XCTAssertNil(recorder.lastEventBody?["closeReason"])
        recorder.stopObserving()
    }

    func testEmitPresentationDismissedCarriesCloseReasonWhenNoError() {
        let recorder = RecordingBridge()
        recorder.startObserving()
        let outcome = PLYPresentationOutcome(purchaseResult: .none, plan: nil, presentation: nil, closeReason: .button, error: nil)

        PurchaselyRN.emitPresentationDismissed(forId: "req-5", outcome: outcome)

        XCTAssertEqual(recorder.lastEventBody?["closeReason"] as? String, "button")
        XCTAssertNil(recorder.lastEventBody?["error"])
        recorder.stopObserving()
    }

    func testEmitPresentationDismissedOmitsCloseReasonForNoneReasonAndNoError() {
        let recorder = RecordingBridge()
        recorder.startObserving()
        let outcome = PLYPresentationOutcome(purchaseResult: .none, plan: nil, presentation: nil, closeReason: .none, error: nil)

        PurchaselyRN.emitPresentationDismissed(forId: "req-6", outcome: outcome)

        XCTAssertNil(recorder.lastEventBody?["closeReason"])
        XCTAssertNil(recorder.lastEventBody?["error"])
        recorder.stopObserving()
    }

    func testEmitPresentationDismissedIsNoopWhenNotObserving() {
        let recorder = RecordingBridge()
        recorder.startObserving()
        recorder.stopObserving()
        let outcome = PLYPresentationOutcome(purchaseResult: .none, plan: nil, presentation: nil, closeReason: .none, error: nil)

        PurchaselyRN.emitPresentationDismissed(forId: "req-7", outcome: outcome)

        XCTAssertNil(recorder.lastEventName)
        recorder.stopObserving()
    }

    // MARK: - eventTriggered(_:properties:) — PurchaselyRN.m:1332-1341

    func testEventTriggeredOmitsPropertiesKeyWhenNil() {
        // The Objective-C guard forwards `nil` properties by building a
        // one-key dictionary literal, never `properties: NSNull`.
        let recorder = RecordingBridge()
        recorder.startObserving()

        recorder.eventTriggered(.appStarted, properties: nil)

        XCTAssertEqual(recorder.lastEventName, "PURCHASELY_EVENTS")
        XCTAssertEqual(recorder.lastEventBody?["name"] as? String, NSString.fromPLYEvent(.appStarted))
        XCTAssertNil(recorder.lastEventBody?["properties"])
        recorder.stopObserving()
    }

    func testEventTriggeredCarriesPropertiesWhenPresent() {
        let recorder = RecordingBridge()
        recorder.startObserving()

        recorder.eventTriggered(.planSelected, properties: ["plan_id": "PLAN1"])

        XCTAssertEqual(recorder.lastEventBody?["name"] as? String, NSString.fromPLYEvent(.planSelected))
        let properties = recorder.lastEventBody?["properties"] as? NSDictionary
        XCTAssertEqual(properties?["plan_id"] as? String, "PLAN1")
        recorder.stopObserving()
    }

    func testEventTriggeredIsNoopWhenNotObserving() {
        let recorder = RecordingBridge()
        recorder.startObserving()
        recorder.stopObserving()

        recorder.eventTriggered(.appStarted, properties: nil)

        XCTAssertNil(recorder.lastEventName)
    }

    // MARK: - requestId omission, the display/preload paths (PurchaselyRN+
    // Presentations.swift:423,497,523,536,547,561) — the static
    // emitPresentationDismissed above is the preload-completion dismiss
    // path; these are the six other event bodies the same fix touched.
    //
    // A missing placementId/presentationId/isDefault makes
    // presentationBuilder(...) return nil without reaching the SDK, so the
    // "no placementId or screenId provided" error path runs synchronously
    // and needs no live SDK — that is what every test below drives.
    //
    // Two bodies are NOT covered here and cannot be without a live SDK:
    // the "missing presentation" onFetchCompletion branch (:547, reached
    // only when presentationBuilder succeeds but the SDK's own fetch then
    // returns a nil presentation) and the success onFetchCompletion branch
    // (:561, reached only with a real presentation from the SDK). Both
    // require presentationBuilder to return a non-nil builder, which means
    // a real `Purchasely.presentation.placement(...)` call into the
    // started SDK — there is no seam here to fake that without one.

    func testPreloadPresentationLoadedEventOmitsRequestIdWhenNil() {
        // Covers PurchaselyRN+Presentations.swift:423 (preloadPresentation's
        // onFetchCompletion, the "loaded" event on the preload path).
        let recorder = RecordingBridge()
        recorder.startObserving()
        let done = expectation(description: "preloadPresentation resolved")

        recorder.preloadPresentation(nil, payload: nil, resolve: { _ in done.fulfill() }, reject: { _, _, _ in
            XCTFail("reject should not be called")
        })

        wait(for: [done], timeout: 2.0)
        XCTAssertEqual(recorder.recordedEvents.map(\.name), ["PURCHASELY_PRESENTATION_LOADED"])
        XCTAssertNil(recorder.recordedEvents.first?.body?["requestId"], "a nil requestId must be an absent key, not \"\"")
        XCTAssertNotNil(recorder.recordedEvents.first?.body?["error"])
        recorder.stopObserving()
    }

    func testDisplayPresentationLoadedPresentedAndDismissedEventsOmitRequestIdWhenNil() {
        // Covers PurchaselyRN+Presentations.swift:523 (onFetchCompletion's
        // "loaded" event), :536 (the same closure's synthesized "presented"
        // event for the error branch) and :497 (emitDismissed, called right
        // after with that same error) — all three fire from this one call,
        // in that order.
        let recorder = RecordingBridge()
        recorder.startObserving()
        let done = expectation(description: "displayPresentation resolved")

        recorder.displayPresentation(nil, payload: nil, transition: nil, resolve: { _ in done.fulfill() }, reject: { _, _, _ in
            XCTFail("reject should not be called")
        })

        wait(for: [done], timeout: 2.0)
        XCTAssertEqual(recorder.recordedEvents.map(\.name), [
            "PURCHASELY_PRESENTATION_LOADED",
            "PURCHASELY_PRESENTATION_PRESENTED",
            "PURCHASELY_PRESENTATION_DISMISSED",
        ])
        for event in recorder.recordedEvents {
            XCTAssertNil(event.body?["requestId"], "\(event.name) must omit requestId, not send \"\"")
        }
        recorder.stopObserving()
    }

    // MARK: - closePresentation: proves the two-block lock shape does not deadlock

    func testClosePresentationTakesTheLockTwiceWithoutDeadlocking() {
        // No SDK presentation is registered under this requestId, so this
        // drives the `else` branch — which still acquires the lock twice,
        // once to look up and once to remove. If an executor hoisted
        // lock()/defer to the closure, this times out.
        let bridge = PurchaselyRN()
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
