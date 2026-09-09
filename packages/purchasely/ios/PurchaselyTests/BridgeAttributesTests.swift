//
//  BridgeAttributesTests.swift
//  Unit tests for PurchaselyRN+Attributes.swift (Task 10). Only the two
//  methods with behaviour observable without a live SDK are covered here —
//  the legal-basis mapper and the date-shaping read helper. Every setter/
//  getter that is a single (possibly branching) SDK call is exercised by
//  E2E instead, per the shared task shape.
//

import XCTest
@testable import react_native_purchasely
import Purchasely

final class BridgeAttributesTests: XCTestCase {

    // MARK: - legalBasis(from:)

    func testLegalBasisFromStringEssentialUppercase() {
        XCTAssertEqual(PurchaselyBridge.legalBasis(from: "ESSENTIAL"), .essential)
    }

    func testLegalBasisFromStringEssentialLowercaseStillMatches() {
        // PurchaselyRN.m:701-707 upper-cases the input before comparing.
        XCTAssertEqual(PurchaselyBridge.legalBasis(from: "essential"), .essential)
    }

    func testLegalBasisFromStringOptional() {
        XCTAssertEqual(PurchaselyBridge.legalBasis(from: "OPTIONAL"), .optional)
    }

    func testLegalBasisFromStringUnknownFallsBackToOptional() {
        XCTAssertEqual(PurchaselyBridge.legalBasis(from: "nonsense"), .optional)
    }

    func testLegalBasisFromStringNilFallsBackToOptional() {
        XCTAssertEqual(PurchaselyBridge.legalBasis(from: nil), .optional)
    }

    // MARK: - rnValue(for:)

    func testRnValueFormatsADateAsIso8601() {
        // PurchaselyRN.m:889-899: NSDate -> "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'" in GMT.
        let date = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(PurchaselyBridge.rnValue(for: date) as? String, "1970-01-01T00:00:00.000Z")
    }

    func testRnValuePassesThroughNonDateValuesUnchanged() {
        XCTAssertEqual(PurchaselyBridge.rnValue(for: "hello") as? String, "hello")
        XCTAssertEqual(PurchaselyBridge.rnValue(for: 42) as? Int, 42)
    }

    func testRnValuePassesThroughNil() {
        XCTAssertNil(PurchaselyBridge.rnValue(for: nil))
    }
}
