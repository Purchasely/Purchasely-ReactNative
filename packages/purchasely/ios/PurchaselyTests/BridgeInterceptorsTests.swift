//
//  BridgeInterceptorsTests.swift
//  Unit tests for PurchaselyRN+Interceptors.swift (Task 13). register/
//  unregister/complete all end in a single SDK call or a dictionary op with
//  no live-SDK dependency, so all three plus the 30-second timeout are
//  covered here without a live SDK.
//

import XCTest
@testable import react_native_purchasely
import Purchasely

final class BridgeInterceptorsTests: XCTestCase {

    override func tearDown() {
        // Fix 5: `testRegisterActionInterceptorWithAKnownKindRecordsIt`
        // drives `registerActionInterceptor`, which installs a REAL SDK
        // interceptor via `Purchasely.interceptAction(...)` on the main
        // queue. Undoing only `interceptorKinds` left that SDK-side
        // registration alive to leak into a later test. Unregister every
        // kind this test run recorded — via the SDK's own
        // `removeActionInterceptor`, on the same queue `registerActionInterceptor`
        // used, which preserves FIFO ordering against that still-pending
        // registration — before clearing the local state.
        let kinds = PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds }
        for kind in kinds {
            if let action = PurchaselyBridge.presentationAction(from: kind) {
                DispatchQueue.main.async {
                    Purchasely.removeActionInterceptor(action)
                }
            }
        }
        PurchaselyBridge.withState {
            PurchaselyBridge.interceptorCallbacks.removeAll()
            PurchaselyBridge.interceptorKinds.removeAll()
        }
        super.tearDown()
    }

    // MARK: - the 30-second timeout, made testable via an injectable delay

    func testAStaleInterceptorCallbackIsCompletedWithNotHandled() {
        let done = expectation(description: "notHandled delivered")
        let bridge = PurchaselyBridge()
        PurchaselyBridge.withState {
            PurchaselyBridge.interceptorCallbacks["cb-1"] = { result in
                XCTAssertEqual(result, "notHandled")
                done.fulfill()
            }
        }
        bridge.scheduleInterceptorTimeout(callbackId: "cb-1", after: 0.05)
        wait(for: [done], timeout: 1.0)
    }

    func testATimedOutCallbackIsRemovedFromTheRegistry() {
        let done = expectation(description: "notHandled delivered")
        let bridge = PurchaselyBridge()
        PurchaselyBridge.withState {
            PurchaselyBridge.interceptorCallbacks["cb-2"] = { _ in done.fulfill() }
        }
        bridge.scheduleInterceptorTimeout(callbackId: "cb-2", after: 0.05)
        wait(for: [done], timeout: 1.0)
        XCTAssertNil(PurchaselyBridge.withState { PurchaselyBridge.interceptorCallbacks["cb-2"] })
    }

    func testATimedOutCallbackThatWasAlreadyCompletedIsNotFiredTwice() {
        // Whoever removes the entry first wins; the loser reads nil and no-ops.
        var fireCount = 0
        let bridge = PurchaselyBridge()
        PurchaselyBridge.withState {
            PurchaselyBridge.interceptorCallbacks["cb-3"] = { _ in fireCount += 1 }
        }
        bridge.scheduleInterceptorTimeout(callbackId: "cb-3", after: 0.05)
        // completeActionInterceptor races the timeout and wins.
        bridge.completeActionInterceptor("cb-3", result: "success")
        XCTAssertEqual(fireCount, 1)

        let noSecondFire = expectation(description: "timeout observed, no second fire")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { noSecondFire.fulfill() }
        wait(for: [noSecondFire], timeout: 1.0)
        XCTAssertEqual(fireCount, 1)
    }

    // MARK: - registerActionInterceptor

    func testRegisterActionInterceptorWithUnknownKindDoesNotRegisterIt() {
        let bridge = PurchaselyBridge()
        bridge.registerActionInterceptor("not-a-real-kind")
        XCTAssertFalse(PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds.contains("not-a-real-kind") })
    }

    func testRegisterActionInterceptorWithNilKindDoesNotCrash() {
        let bridge = PurchaselyBridge()
        bridge.registerActionInterceptor(nil)
        XCTAssertTrue(PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds }.isEmpty)
    }

    func testRegisterActionInterceptorWithAKnownKindRecordsIt() {
        let bridge = PurchaselyBridge()
        bridge.registerActionInterceptor("purchase")
        XCTAssertTrue(PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds.contains("purchase") })
    }

    // MARK: - unregisterActionInterceptor

    func testUnregisterActionInterceptorRemovesAKnownKind() {
        let bridge = PurchaselyBridge()
        PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds.insert("purchase") }
        bridge.unregisterActionInterceptor("purchase")
        XCTAssertFalse(PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds.contains("purchase") })
    }

    func testUnregisterActionInterceptorWithUnknownKindDoesNotCrash() {
        let bridge = PurchaselyBridge()
        bridge.unregisterActionInterceptor("not-a-real-kind")
        // no crash is the assertion
    }

    // MARK: - completeActionInterceptor

    func testCompleteActionInterceptorInvokesAndRemovesTheStoredCallback() {
        let bridge = PurchaselyBridge()
        var received: String?
        PurchaselyBridge.withState {
            PurchaselyBridge.interceptorCallbacks["cb-4"] = { result in received = result }
        }
        bridge.completeActionInterceptor("cb-4", result: "success")
        XCTAssertEqual(received, "success")
        XCTAssertNil(PurchaselyBridge.withState { PurchaselyBridge.interceptorCallbacks["cb-4"] })
    }

    func testCompleteActionInterceptorWithNilResultFallsBackToNotHandled() {
        // Objective-C: `cb(result)` with a nil `result` messages `isEqualToString:`
        // to nil, which returns false for both comparisons and falls to the
        // `notHandled` default. The Swift callback takes a non-optional String
        // (Task 8), so the nil-to-notHandled fallback happens at the call site.
        let bridge = PurchaselyBridge()
        var received: String?
        PurchaselyBridge.withState {
            PurchaselyBridge.interceptorCallbacks["cb-5"] = { result in received = result }
        }
        bridge.completeActionInterceptor("cb-5", result: nil)
        XCTAssertEqual(received, "notHandled")
    }

    func testCompleteActionInterceptorWithUnknownCallbackIdDoesNotCrash() {
        let bridge = PurchaselyBridge()
        bridge.completeActionInterceptor("no-such-callback", result: "success")
        // no crash is the assertion
    }

    func testCompleteActionInterceptorWithNilCallbackIdDoesNotCrash() {
        let bridge = PurchaselyBridge()
        bridge.completeActionInterceptor(nil, result: "success")
        // no crash is the assertion
    }
}
