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

    // MARK: - wholeNumberAttributeValue(_:) — the Int(exactly:) split

    func testWholeNumberAttributeValueIntegerReturnsInt() {
        XCTAssertEqual(PurchaselyBridge.wholeNumberAttributeValue(42.0), 42)
    }

    func testWholeNumberAttributeValueFractionalReturnsNil() {
        // The boundary that makes this trap matter: 2.5 must take the
        // double path, not round to 3 (that was the first-draft bug this
        // trap replaces, per PurchaselyRN.m:729-742's fmod check).
        XCTAssertNil(PurchaselyBridge.wholeNumberAttributeValue(2.5))
    }

    func testWholeNumberAttributeValueOutOfRangeReturnsNil() {
        // PurchaselyRN.m's fmod-based check has no fractional remainder for
        // a value this large, but it does not fit in Int — the "1e300 fix"
        // the plan attributes to Int(exactly:).
        XCTAssertNil(PurchaselyBridge.wholeNumberAttributeValue(1e300))
    }

    func testWholeNumberAttributeValueNaNReturnsNil() {
        XCTAssertNil(PurchaselyBridge.wholeNumberAttributeValue(Double.nan))
    }

    // MARK: - truncatedToInt32(_:) — the 32-bit NSNumber.intValue trap

    func testTruncatedToInt32PassesThroughAnInRangeValue() {
        XCTAssertEqual(PurchaselyBridge.truncatedToInt32(NSNumber(value: 42)), 42)
    }

    func testTruncatedToInt32WrapsAtTheInt32Boundary() {
        // The boundary that makes this trap matter: Int32.max + 1 wraps to
        // Int32.min, reproducing Objective-C's 32-bit `NSNumber.intValue`
        // truncation (PurchaselyRN.m:847-861) instead of Swift's
        // native-width `Int`.
        let overflowing = NSNumber(value: Int64(Int32.max) + 1)
        XCTAssertEqual(PurchaselyBridge.truncatedToInt32(overflowing), Int(Int32.min))
    }

    func testTruncatedToInt32OfNilNumberIsZero() {
        // Objective-C: an `.intValue` message sent to a nil `NSNumber *`
        // returns 0 (message-to-nil yields a zeroed scalar).
        XCTAssertEqual(PurchaselyBridge.truncatedToInt32(nil), 0)
    }
}
