//
//  SerializationContractTests.swift
//  Locks the bridge's serialization contract across the Objective-C → Swift
//  port. Written against the Objective-C categories, kept green unchanged by
//  the Swift extensions that replace them. Do not relax an assertion to make a
//  port pass: types.ts documents this behaviour to clients.
//

import XCTest
import Purchasely
@testable import react_native_purchasely

final class SerializationContractTests: XCTestCase {

    // MARK: - PLYPlan
    //
    // Filled from PLYPlan+Hybrid.m, read directly (grep -nE 'forKey:|if \(').

    /// Emitted on every plan, populated or sparse. The five `offer*` keys are
    /// deliberate safe defaults: the SDK's PLYTagHelper is `private` and takes
    /// an internal type, so no bridge can compute a real promotional-offer
    /// price — in Objective-C or in Swift. Do not "fix" them during the port.
    /// See the comment at PLYPlan+Hybrid.m:22-30.
    private static let planAlwaysPresent: Set<String> = [
        "vendorId", "hasIntroductoryPrice", "type", "hasFreeTrial",
        "hasOfferPrice", "offerPrice", "offerAmount", "offerDuration",
        "offerPeriod",
    ]

    /// Present on the populated fixture, ABSENT on the sparse one — not
    /// NSNull, not an empty string.
    private static let planNullable: Set<String> = [
        "name", "productId", "price", "amount", "localizedAmount",
        "introAmount", "currencyCode", "currencySymbol", "period",
        "introPrice", "introDuration", "introPeriod", "commitmentInfo",
    ]

    /// Keys whose value must bridge as an NSNumber. Global Constraint 5: a
    /// Swift enum written without `.rawValue` becomes an opaque box the RN
    /// bridge drops, and the key arrives `undefined`.
    private static let planNumericKeys: Set<String> = [
        "type", "hasIntroductoryPrice", "hasFreeTrial", "hasOfferPrice",
        "offerAmount",
    ]

    func testPlanAlwaysPresentKeysSurviveBothFixtures() throws {
        for populated in [true, false] {
            let dict = try SerializationFixtures.plan(populated: populated).asDictionary()
            for key in Self.planAlwaysPresent {
                XCTAssertNotNil(dict[key], "plan(populated: \(populated)) lost '\(key)'")
            }
        }
    }

    func testPlanNullableKeysArePresentWhenPopulated() throws {
        let dict = try SerializationFixtures.plan(populated: true).asDictionary()
        // Only assert the keys the populated fixture actually sets. A key here
        // that the fixture does not set belongs in the sparse assertion only —
        // widen the fixture rather than weakening this test.
        //
        // No SKProduct is loaded in a unit test, so price/amount/introAmount/
        // currencyCode/currencySymbol/period/introPrice/introDuration/
        // introPeriod stay absent even on the "populated" fixture — the plan
        // anticipated this by only asserting name/productId here.
        for key in ["name", "productId"] {
            XCTAssertNotNil(dict[key], "a populated plan must emit '\(key)'")
        }
    }

    func testPlanNullableKeysAreAbsentWhenSparse() throws {
        let dict = try SerializationFixtures.plan(populated: false).asDictionary()
        for key in Self.planNullable {
            XCTAssertNil(
                dict[key],
                """
                '\(key)' must be ABSENT on a sparse plan — not NSNull and not \
                an empty string. types.ts documents the omission and the JS \
                layer reads `undefined`.
                """
            )
        }
    }

    func testPlanNumericKeysBridgeAsNumbers() throws {
        let dict = try SerializationFixtures.plan(populated: true).asDictionary()
        for key in Self.planNumericKeys {
            XCTAssertTrue(
                dict[key] is NSNumber,
                "plan['\(key)'] is \(type(of: dict[key])), expected NSNumber — write .rawValue"
            )
        }
    }

    func testPlanCommitmentInfoIsOmittedWhenEmptyNotEmittedAsAnEmptyArray() throws {
        // PLYPlan+Hybrid.m:120 guards on `count > 0`, not on nil. An `if let`
        // in the Swift port would emit [] and the JS layer would stop reading
        // the key as absent.
        let dict = try SerializationFixtures.plan(populated: false).asDictionary()
        XCTAssertNil(dict["commitmentInfo"])
    }

    // MARK: - PLYProduct
    //
    // Filled from PLYProduct+Hybrid.m: vendorId and plans are unconditional;
    // name is guarded by `if (self.name != nil)`.

    private static let productAlwaysPresent: Set<String> = ["vendorId", "plans"]
    private static let productNullable: Set<String> = ["name"]

    func testProductAlwaysPresentKeysSurviveBothFixtures() throws {
        for populated in [true, false] {
            let dict = try SerializationFixtures.product(populated: populated).asDictionary()
            for key in Self.productAlwaysPresent {
                XCTAssertNotNil(dict[key], "product(populated: \(populated)) lost '\(key)'")
            }
        }
    }

    func testProductNullableKeysArePresentWhenPopulated() throws {
        let dict = try SerializationFixtures.product(populated: true).asDictionary()
        for key in Self.productNullable {
            XCTAssertNotNil(dict[key], "a populated product must emit '\(key)'")
        }
    }

    func testProductNullableKeysAreAbsentWhenSparse() throws {
        let dict = try SerializationFixtures.product(populated: false).asDictionary()
        for key in Self.productNullable {
            XCTAssertNil(dict[key], "'\(key)' must be ABSENT on a sparse product")
        }
    }

    func testProductPlansIsAnEmptyArrayNotAbsentWhenNoPlans() throws {
        // PLYProduct+Hybrid.m:18-23 always sets "plans", even to an empty
        // array — unlike PLYPlan's commitmentInfo, this key is never omitted.
        let dict = try SerializationFixtures.product(populated: false).asDictionary()
        guard let plans = dict["plans"] as? [Any] else {
            return XCTFail("'plans' must bridge as an array, got \(type(of: dict["plans"]))")
        }
        XCTAssertEqual(plans.count, 0)
    }

    // MARK: - PLYOfferSignature
    //
    // Filled from PLYOfferSignature+Hybrid.m. Step 1 found both guards
    // (`nonce`/`timestamp`) are dead code: the underlying properties are
    // non-optional (UUID, Double), so both keys are always present. There is
    // no nullable key on this type at all.

    private static let offerSignatureAlwaysPresent: Set<String> = [
        "planVendorId", "identifier", "signature", "keyIdentifier", "nonce", "timestamp",
    ]

    private static let offerSignatureNumericKeys: Set<String> = ["timestamp"]

    func testOfferSignatureAlwaysPresentKeys() throws {
        let dict = try SerializationFixtures.offerSignature().asDictionary()
        for key in Self.offerSignatureAlwaysPresent {
            XCTAssertNotNil(dict[key], "offerSignature lost '\(key)'")
        }
    }

    func testOfferSignatureNumericKeysBridgeAsNumbers() throws {
        let dict = try SerializationFixtures.offerSignature().asDictionary()
        for key in Self.offerSignatureNumericKeys {
            XCTAssertTrue(
                dict[key] is NSNumber,
                "offerSignature['\(key)'] is \(type(of: dict[key])), expected NSNumber"
            )
        }
    }

    // MARK: - PLYPresentationPlan
    //
    // Filled from PLYPresentationPlan+Hybrid.m. `default` is unconditional
    // (`@(self.default_)`). offerId/offerVendorId/storeProductId are each
    // guarded by `if (self.X)`.
    //
    // planVendorId is NOT in the nullable set here, unlike the plan's draft
    // table: PLYPresentationPlan.swift:25 decodes `plan_vendor_id` with
    // `decode` (required), not `decodeIfPresent`, so it is always present in
    // any JSON that decodes at all, and the Hybrid.m guard around it
    // (`if (self.planVendorId)`) is dead code — like the offer-signature
    // guards Step 1 found. Reported as a discrepancy from the plan text; the
    // interface (and the source) wins.

    private static let presentationPlanAlwaysPresent: Set<String> = ["default", "planVendorId"]
    private static let presentationPlanNullable: Set<String> = ["offerId", "offerVendorId", "storeProductId"]
    private static let presentationPlanNumericKeys: Set<String> = ["default"]

    func testPresentationPlanAlwaysPresentKeysSurviveBothFixtures() throws {
        for populated in [true, false] {
            let dict = try SerializationFixtures.presentationPlan(populated: populated).asDictionary()
            for key in Self.presentationPlanAlwaysPresent {
                XCTAssertNotNil(dict[key], "presentationPlan(populated: \(populated)) lost '\(key)'")
            }
        }
    }

    func testPresentationPlanNullableKeysArePresentWhenPopulated() throws {
        let dict = try SerializationFixtures.presentationPlan(populated: true).asDictionary()
        for key in Self.presentationPlanNullable {
            XCTAssertNotNil(dict[key], "a populated presentationPlan must emit '\(key)'")
        }
    }

    func testPresentationPlanNullableKeysAreAbsentWhenSparse() throws {
        let dict = try SerializationFixtures.presentationPlan(populated: false).asDictionary()
        for key in Self.presentationPlanNullable {
            XCTAssertNil(dict[key], "'\(key)' must be ABSENT on a sparse presentationPlan")
        }
    }

    func testPresentationPlanNumericKeysBridgeAsNumbers() throws {
        let dict = try SerializationFixtures.presentationPlan(populated: true).asDictionary()
        for key in Self.presentationPlanNumericKeys {
            XCTAssertTrue(
                dict[key] is NSNumber,
                "presentationPlan['\(key)'] is \(type(of: dict[key])), expected NSNumber"
            )
        }
    }

    // MARK: - PLYSubscription
    //
    // NOT COVERED. `PLYSubscription.init(from:)` (PLYSubscription.swift:92-153)
    // resolves `.product` via `ProductRepository.shared.getProduct(containingPlan:)`
    // (ProductRepository.swift:132-140), which reads `internal var allProducts`
    // — nil in this test process, with no public seam to populate it from
    // outside the Purchasely module. Decoding throws
    // `PLYSubscriptionError.couldntFindProduct` for every JSON payload,
    // populated or sparse. See this task's report for the observed failure
    // text and the consequence for Task 3.
}
