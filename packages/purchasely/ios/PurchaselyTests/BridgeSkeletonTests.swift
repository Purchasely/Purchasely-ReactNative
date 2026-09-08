//
//  BridgeSkeletonTests.swift
//  Locks the Swift bridge class skeleton against the Objective-C module it
//  will replace. PurchaselyBridge carries no export macro yet (Task 8), so
//  this reaches it only through @testable import.
//

import XCTest
@testable import react_native_purchasely

final class BridgeSkeletonTests: XCTestCase {

    func testConstantsMatchTheObjectiveCModuleExactly() {
        // The Swift class must produce the same 60 keys and the same values as
        // the module it replaces. Comparing the two directly is stronger than
        // comparing either to a literal list.
        let objc = PurchaselyRN().constantsToExport() as? [String: NSNumber] ?? [:]
        let swift = PurchaselyBridge().constantsToExport() as? [String: NSNumber] ?? [:]
        XCTAssertEqual(swift, objc)
    }

    func testSupportedEventsMatchTheObjectiveCModuleExactly() {
        let objc = PurchaselyRN().supportedEvents() as? [String] ?? []
        let swift = PurchaselyBridge().supportedEvents() as? [String] ?? []
        XCTAssertEqual(swift, objc)
    }

    func testRequiresMainQueueSetupIsTrue() {
        // PurchaselyRN.m:1447 returns YES. Asserted as a literal, not against
        // the Objective-C class, because a wrong value in BOTH would pass.
        XCTAssertTrue(PurchaselyBridge.requiresMainQueueSetup())
    }

    func testSequentialLockedBlocksDoNotDeadlock() {
        // Constraint 7 in one assertion: two sequential withState calls are the
        // shape closePresentation uses (PurchaselyRN.m:1807 and :1826). If an
        // executor hoists lock()/defer to the enclosing closure, the second
        // acquisition deadlocks and this test times out rather than failing
        // fast — the timeout IS the signal.
        //
        // The real reentrancy proof lives in Task 12's closePresentation test;
        // this one only guards the helper.
        PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds.insert("a") }
        PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds.insert("b") }
        XCTAssertEqual(PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds },
                       Set(["a", "b"]))
        PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds.removeAll() }
    }

    func testRejectWithNilErrorProducesCodeZeroAndNoMessage() {
        // PurchaselyRN.m:1455 messages a nil error and gets code "0" with a nil
        // message. Swift must not force-unwrap or return early here.
        var code: String?
        var message: String?
        PurchaselyBridge.reject({ c, m, _ in code = c; message = m }, with: nil)
        XCTAssertEqual(code, "0")
        XCTAssertNil(message)
    }
}
