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
        // PurchaselyRN.m:1441 returns YES. Asserted as a literal, not against
        // the Objective-C class, because a wrong value in BOTH would pass.
        XCTAssertTrue(PurchaselyBridge.requiresMainQueueSetup())
    }

    func testSequentialLockedBlocksDoNotDeadlock() {
        // Constraint 7 in one assertion: two sequential withState calls are the
        // shape closePresentation uses (PurchaselyRN.m:1799 and :1817). If an
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

    func testImplementsOnlyTheFiveArgumentUserAttributeSetOverload() {
        // PLYUserAttributeDelegate declares two onUserAttributeSet overloads
        // (.swiftinterface, protocol PLYUserAttributeDelegate). The
        // Objective-C module implements only the 5-argument one
        // (PurchaselyRN.m:1351-1355), which carries processingLegalBasis into
        // the USER_ATTRIBUTE_SET_LISTENER body (:1367). Implementing the
        // 4-argument overload instead would silently drop
        // processingLegalBasis from that event, so pin both: responds to the
        // 5-arg selector, does not respond to the 4-arg one.
        let bridge = PurchaselyBridge()
        let fiveArg = NSSelectorFromString("onUserAttributeSetWithKey:type:value:source:processingLegalBasis:")
        let fourArg = NSSelectorFromString("onUserAttributeSetWithKey:type:value:source:")
        XCTAssertTrue(bridge.responds(to: fiveArg))
        XCTAssertFalse(bridge.responds(to: fourArg))
    }

    func testPurchaseResultOrdinalCoversEveryCase() {
        // PLYPurchaseResult has four cases (.swiftinterface, enum
        // PLYPurchaseResult): .purchased .cancelled .restored .none.
        // `.none` maps to nil, not to cancelled, so the constants gate
        // (which falls back with `?? 1`) cannot catch a regression here —
        // this test pins the ordinals directly.
        XCTAssertEqual(PurchaselyBridge.purchaseResultOrdinal(.purchased), 0)
        XCTAssertEqual(PurchaselyBridge.purchaseResultOrdinal(.cancelled), 1)
        XCTAssertEqual(PurchaselyBridge.purchaseResultOrdinal(.restored), 2)
        XCTAssertNil(PurchaselyBridge.purchaseResultOrdinal(.none))
    }

    func testRejectWithNilErrorProducesCodeZeroAndNoMessage() {
        // PurchaselyRN.m:1448 messages a nil error and gets code "0" with a nil
        // message. Swift must not force-unwrap or return early here.
        var code: String?
        var message: String?
        PurchaselyBridge.reject({ c, m, _ in code = c; message = m }, with: nil)
        XCTAssertEqual(code, "0")
        XCTAssertNil(message)
    }
}
