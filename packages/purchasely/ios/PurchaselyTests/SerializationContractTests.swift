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

    /// Exact key sets, read off PLYPlan+Hybrid.m: the 9 unconditional keys
    /// (planAlwaysPresent), plus name/productId on the populated fixture
    /// (the ten StoreKit-resolved keys and commitmentInfo stay absent even
    /// when "populated" — no SKProduct is loaded in a unit test, Amendment
    /// A3). A port that ADDS a key must fail this, not just widen silently.
    func testPlanPopulatedKeySetIsExact() throws {
        let dict = try SerializationFixtures.plan(populated: true).asDictionary()
        let expected = Self.planAlwaysPresent.union(["name", "productId"])
        XCTAssertEqual(Set(dict.keys), expected)
    }

    func testPlanSparseKeySetIsExact() throws {
        let dict = try SerializationFixtures.plan(populated: false).asDictionary()
        XCTAssertEqual(Set(dict.keys), Self.planAlwaysPresent)
    }

    /// [Hole 3] PLYPlan+Hybrid.m:10-23's two billing-plan-type mappers are
    /// Task 2's named deliverable and had zero coverage. Pure functions over
    /// an enum, pinned in both directions for every case plus the fallback.
    /// Cases read off the SDK interface (Global Constraint 0):
    /// `awk '/enum PLYBillingPlanType/,/^}/' "$SI"` → .unspecified .upFront .monthly.
    func testBillingPlanTypeToRNStringForEveryCase() {
        XCTAssertEqual(PLYBillingPlanTypeToRNString(.upFront), "upFront")
        XCTAssertEqual(PLYBillingPlanTypeToRNString(.monthly), "monthly")
        XCTAssertEqual(PLYBillingPlanTypeToRNString(.unspecified), "unspecified")
    }

    func testBillingPlanTypeFromRNStringForEveryCaseAndFallback() {
        XCTAssertEqual(PLYBillingPlanTypeFromRNString("upFront"), .upFront)
        XCTAssertEqual(PLYBillingPlanTypeFromRNString("monthly"), .monthly)
        XCTAssertEqual(PLYBillingPlanTypeFromRNString("unspecified"), .unspecified)
        // Unknown / nil input falls back to .unspecified (PLYPlan+Hybrid.h:17).
        XCTAssertEqual(PLYBillingPlanTypeFromRNString("garbage"), .unspecified)
        XCTAssertEqual(PLYBillingPlanTypeFromRNString(nil), .unspecified)
    }

    /// [Hole 4] The five coalesced offer* defaults (PLYPlan+Hybrid.m:52-56):
    /// @(NO), @"", @0, @"", @"" — the VALUE is the contract here (Global
    /// Constraint 6's coalesced-to-a-value policy), not just presence.
    func testPlanOfferDefaultsHaveTheExactCoalescedValues() throws {
        let dict = try SerializationFixtures.plan(populated: true).asDictionary()
        XCTAssertEqual(dict["hasOfferPrice"] as? Bool, false)
        XCTAssertEqual(dict["offerPrice"] as? String, "")
        XCTAssertEqual(dict["offerAmount"] as? Int, 0)
        XCTAssertEqual(dict["offerDuration"] as? String, "")
        XCTAssertEqual(dict["offerPeriod"] as? String, "")
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

    /// [Hole 1, CRITICAL] PLYProduct+Hybrid.m:18-23 maps each nested plan
    /// through `plan.asDictionary`, not the raw PLYPlan object. A port that
    /// writes `dict["plans"] = product.plans` stays green on the sparse
    /// fixture's count==0 check above but drops every field in JS (Global
    /// Constraint 5's silent-drop hazard, one level down). Pin the populated
    /// fixture's one plan as a real dictionary with a real vendorId.
    func testProductPlansAreSerializedAsDictionariesNotRawPLYPlanObjects() throws {
        let dict = try SerializationFixtures.product(populated: true).asDictionary()
        guard let plans = dict["plans"] as? [[String: Any]] else {
            return XCTFail("'plans' must bridge as [[String: Any]], got \(type(of: dict["plans"]))")
        }
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?["vendorId"] as? String, "PLAN_MONTHLY")
    }

    /// [Hole 2] Exact key sets, read off PLYProduct+Hybrid.m: vendorId and
    /// plans unconditional, name guarded by `if (self.name != nil)`.
    func testProductPopulatedKeySetIsExact() throws {
        let dict = try SerializationFixtures.product(populated: true).asDictionary()
        XCTAssertEqual(Set(dict.keys), Self.productAlwaysPresent.union(Self.productNullable))
    }

    func testProductSparseKeySetIsExact() throws {
        let dict = try SerializationFixtures.product(populated: false).asDictionary()
        XCTAssertEqual(Set(dict.keys), Self.productAlwaysPresent)
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

    /// [Hole 2] Exact key set: all six keys are unconditional (Step 1's
    /// dead-code-guard finding), so there is only one set for this type.
    func testOfferSignatureKeySetIsExact() throws {
        let dict = try SerializationFixtures.offerSignature().asDictionary()
        XCTAssertEqual(Set(dict.keys), Self.offerSignatureAlwaysPresent)
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

    /// [Hole 2] Exact key sets, read off PLYPresentationPlan+Hybrid.m: default
    /// and planVendorId unconditional (planVendorId's guard is dead code —
    /// see the comment above), offerId/offerVendorId/storeProductId guarded.
    func testPresentationPlanPopulatedKeySetIsExact() throws {
        let dict = try SerializationFixtures.presentationPlan(populated: true).asDictionary()
        let expected = Self.presentationPlanAlwaysPresent.union(Self.presentationPlanNullable)
        XCTAssertEqual(Set(dict.keys), expected)
    }

    func testPresentationPlanSparseKeySetIsExact() throws {
        let dict = try SerializationFixtures.presentationPlan(populated: false).asDictionary()
        XCTAssertEqual(Set(dict.keys), Self.presentationPlanAlwaysPresent)
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
