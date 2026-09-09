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
        XCTAssertEqual(PurchaselyRN.legalBasis(from: "ESSENTIAL"), .essential)
    }

    func testLegalBasisFromStringEssentialLowercaseStillMatches() {
        // PurchaselyRN.m:701-707 upper-cases the input before comparing.
        XCTAssertEqual(PurchaselyRN.legalBasis(from: "essential"), .essential)
    }

    func testLegalBasisFromStringOptional() {
        XCTAssertEqual(PurchaselyRN.legalBasis(from: "OPTIONAL"), .optional)
    }

    func testLegalBasisFromStringUnknownFallsBackToOptional() {
        XCTAssertEqual(PurchaselyRN.legalBasis(from: "nonsense"), .optional)
    }

    func testLegalBasisFromStringNilFallsBackToOptional() {
        XCTAssertEqual(PurchaselyRN.legalBasis(from: nil), .optional)
    }

    // MARK: - rnValue(for:)

    func testRnValueFormatsADateAsIso8601() {
        // PurchaselyRN.m:889-899: NSDate -> "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'" in GMT.
        let date = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(PurchaselyRN.rnValue(for: date) as? String, "1970-01-01T00:00:00.000Z")
    }

    func testRnValuePassesThroughNonDateValuesUnchanged() {
        XCTAssertEqual(PurchaselyRN.rnValue(for: "hello") as? String, "hello")
        XCTAssertEqual(PurchaselyRN.rnValue(for: 42) as? Int, 42)
    }

    func testRnValuePassesThroughNil() {
        XCTAssertNil(PurchaselyRN.rnValue(for: nil))
    }

    // MARK: - wholeNumberAttributeValue(_:) — the Int(exactly:) split

    func testWholeNumberAttributeValueIntegerReturnsInt() {
        XCTAssertEqual(PurchaselyRN.wholeNumberAttributeValue(42.0), 42)
    }

    func testWholeNumberAttributeValueFractionalReturnsNil() {
        // The boundary that makes this trap matter: 2.5 must take the
        // double path, not round to 3 (that was the first-draft bug this
        // trap replaces, per PurchaselyRN.m:729-742's fmod check).
        XCTAssertNil(PurchaselyRN.wholeNumberAttributeValue(2.5))
    }

    func testWholeNumberAttributeValueOutOfRangeReturnsNil() {
        // PurchaselyRN.m's fmod-based check has no fractional remainder for
        // a value this large, but it does not fit in Int — the "1e300 fix"
        // the plan attributes to Int(exactly:).
        XCTAssertNil(PurchaselyRN.wholeNumberAttributeValue(1e300))
    }

    func testWholeNumberAttributeValueNaNReturnsNil() {
        XCTAssertNil(PurchaselyRN.wholeNumberAttributeValue(Double.nan))
    }

    // MARK: - truncatedToInt32(_:) — the 32-bit NSNumber.intValue trap

    func testTruncatedToInt32PassesThroughAnInRangeValue() {
        XCTAssertEqual(PurchaselyRN.truncatedToInt32(NSNumber(value: 42)), 42)
    }

    func testTruncatedToInt32WrapsAtTheInt32Boundary() {
        // The boundary that makes this trap matter: Int32.max + 1 wraps to
        // Int32.min, reproducing Objective-C's 32-bit `NSNumber.intValue`
        // truncation (PurchaselyRN.m:847-861) instead of Swift's
        // native-width `Int`.
        let overflowing = NSNumber(value: Int64(Int32.max) + 1)
        XCTAssertEqual(PurchaselyRN.truncatedToInt32(overflowing), Int(Int32.min))
    }

    func testTruncatedToInt32OfNilNumberIsZero() {
        // Objective-C: an `.intValue` message sent to a nil `NSNumber *`
        // returns 0 (message-to-nil yields a zeroed scalar).
        XCTAssertEqual(PurchaselyRN.truncatedToInt32(nil), 0)
    }

    // MARK: - the RULING: array element handling (group a — coerce, group b — bail)

    // (a) setUserAttributeWithBooleanArray coerces: a non-NSNumber element
    // becomes `false`, and every element is kept — never dropped.
    func testCoercedBoolArrayCoercesANonNumericElementToFalse() {
        let mixed: [Any] = [true, "not a bool", false]
        XCTAssertEqual(PurchaselyRN.coercedBoolArray(mixed), [true, false, false])
    }

    // (a) setUserAttributeWithNumberArray coerces: a non-NSNumber element
    // becomes 0 (which lands in the int bucket), and every element is kept.
    func testSplitNumberArrayCoercesANonNumericElementToZero() {
        let mixed: [Any] = [1, "not a number", 2.5]
        let split = PurchaselyRN.splitNumberArray(mixed)
        XCTAssertEqual(split.ints, [1, 0])
        XCTAssertEqual(split.doubles, [2.5])
    }

    // (b) setUserAttributeWithStringArray rejects the WHOLE array if any
    // element is not exactly a String — it must not silently drop the bad
    // element and set a partial array.
    func testExactStringArrayBailsOutOnAnyNonStringElement() {
        let mixed: [Any] = ["a", 42, "b"]
        XCTAssertNil(PurchaselyRN.exactStringArray(mixed, forKey: "k"))
    }

    func testExactStringArrayReturnsEveryElementWhenAllAreStrings() {
        XCTAssertEqual(PurchaselyRN.exactStringArray(["a", "b"], forKey: "k"), ["a", "b"])
    }

    // (b) setUserAttributeWithIntArray rejects the WHOLE array if any element
    // is not an integral NSNumber — a fractional NSNumber (e.g. 2.7) fails
    // the same way a non-numeric element does, matching the empirically
    // verified `NSArray as? [Int]` bridging behaviour.
    func testExactIntArrayBailsOutOnAFractionalElement() {
        let mixed: [Any] = [1, 2.7, 3]
        XCTAssertNil(PurchaselyRN.exactIntArray(mixed, forKey: "k"))
    }

    func testExactIntArrayBailsOutOnANonNumericElement() {
        let mixed: [Any] = [1, "not a number"]
        XCTAssertNil(PurchaselyRN.exactIntArray(mixed, forKey: "k"))
    }

    func testExactIntArrayReturnsEveryElementWhenAllAreIntegral() {
        XCTAssertEqual(PurchaselyRN.exactIntArray([1, 2, 3], forKey: "k"), [1, 2, 3])
    }

    // (b) setUserAttributeWithDoubleArray rejects the WHOLE array if any
    // element is not an NSNumber at all — unlike Int, a fractional NSNumber
    // is fine here (verified: `NSArray as? [Double]` accepts any NSNumber).
    func testExactDoubleArrayBailsOutOnANonNumericElement() {
        let mixed: [Any] = [1.5, "not a number"]
        XCTAssertNil(PurchaselyRN.exactDoubleArray(mixed, forKey: "k"))
    }

    func testExactDoubleArrayReturnsEveryElementWhenAllAreNumeric() {
        XCTAssertEqual(PurchaselyRN.exactDoubleArray([1, 2.5], forKey: "k"), [1.0, 2.5])
    }
}
