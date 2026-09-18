//
//  BridgeSkeletonTests.swift
//  Locks the Swift bridge class skeleton. Before Task 14 this compared the
//  Swift PurchaselyBridge against the Objective-C PurchaselyRN it would
//  replace; after the swap both names are the same class, so those two
//  comparisons are replaced with assertions against the literal lists
//  BridgeExportContractTests already locks.
//

import XCTest
@testable import react_native_purchasely

final class BridgeSkeletonTests: XCTestCase {

    func testConstantsKeepAllSixtyKeys() {
        let constants = PurchaselyRN().constantsToExport() as? [String: Any] ?? [:]
        XCTAssertEqual(Set(constants.keys), BridgeExportContractTests.expectedConstantKeys)
    }

    func testSupportedEventsKeepTheirOrder() {
        XCTAssertEqual(PurchaselyRN().supportedEvents() as? [String] ?? [],
                       BridgeExportContractTests.expectedEvents)
    }

    func testRequiresMainQueueSetupIsTrue() {
        // PurchaselyRN.m:1441 returns YES. Asserted as a literal, not against
        // the Objective-C class, because a wrong value in BOTH would pass.
        XCTAssertTrue(PurchaselyRN.requiresMainQueueSetup())
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
        PurchaselyRN.withState { PurchaselyRN.interceptorKinds.insert("a") }
        PurchaselyRN.withState { PurchaselyRN.interceptorKinds.insert("b") }
        XCTAssertEqual(PurchaselyRN.withState { PurchaselyRN.interceptorKinds },
                       Set(["a", "b"]))
        PurchaselyRN.withState { PurchaselyRN.interceptorKinds.removeAll() }
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
        let bridge = PurchaselyRN()
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
        XCTAssertEqual(PurchaselyRN.purchaseResultOrdinal(.purchased), 0)
        XCTAssertEqual(PurchaselyRN.purchaseResultOrdinal(.cancelled), 1)
        XCTAssertEqual(PurchaselyRN.purchaseResultOrdinal(.restored), 2)
        XCTAssertNil(PurchaselyRN.purchaseResultOrdinal(.none))
    }

    func testRejectWithNilErrorProducesCodeZeroAndNoMessage() {
        // PurchaselyRN.m:1448 messages a nil error and gets code "0" with a nil
        // message. Swift must not force-unwrap or return early here.
        var code: String?
        var message: String?
        PurchaselyRN.reject({ c, m, _ in code = c; message = m }, with: nil)
        XCTAssertEqual(code, "0")
        XCTAssertNil(message)
    }
}
