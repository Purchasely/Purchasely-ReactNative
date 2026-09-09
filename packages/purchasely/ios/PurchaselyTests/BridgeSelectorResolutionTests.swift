//
//  BridgeSelectorResolutionTests.swift
//  The second half of Task 14's gate. BridgeExportContractTests locks the JS
//  names and their bare selectors as TEXT; this file proves each of those
//  selectors actually resolves on the Swift PurchaselyRN class, which is what
//  a client app's runtime dispatch depends on. Separate from
//  BridgeExportContractTests because this one needs RCTParseMethodSignature
//  (React-Core-umbrella.h:77, via RCTModuleMethod.h); the JS-name half of the
//  gate needs nothing but the pod.
//

import XCTest
import React
@testable import react_native_purchasely

/// Asserts every selector the shim declares actually exists on the Swift class.
final class BridgeSelectorResolutionTests: XCTestCase {

    func testEveryExportedSelectorResolvesOnTheClass() {
        let entries = BridgeExportContractTests.exportedEntries()
        // Gate against the vacuous-pass failure mode: an empty array would
        // make the loop below iterate zero times and PASS while checking
        // nothing. 63 is the frozen JS export count (BridgeExportContractTests).
        XCTAssertEqual(entries.count, 63, "exportedEntries() must return all 63 exports, or every assertion below is skipped silently")
        for entry in entries {
            var arguments: NSArray?
            guard let selector = RCTParseMethodSignature(entry.objcName, &arguments) else {
                XCTFail("RCTParseMethodSignature could not parse '\(entry.objcName)' for JS name '\(entry.jsName)'")
                continue
            }
            XCTAssertTrue(
                PurchaselyRN.instancesRespond(to: NSSelectorFromString(selector)),
                """
                The shim exports JS name '\(entry.jsName)' with selector \
                '\(selector)', which PurchaselyRN does not implement. Copy the \
                selector from that method's @objc(...) annotation.
                """
            )
        }
    }
}
