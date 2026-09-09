//
//  BridgeProductsTests.swift
//  Unit tests for PurchaselyRN+Products.swift (Task 11). Only the two
//  methods with mapping logic observable without a live SDK are covered
//  here — the promo-offer lookup inside `purchaseWithPlanVendorId` and the
//  dictionary shape `getDynamicOfferings` builds. Every other exported
//  method in this file is a single (possibly branching-on-availability) SDK
//  call, exercised by E2E instead, per the shared task shape.
//

import XCTest
@testable import react_native_purchasely
import Purchasely

final class BridgeProductsTests: XCTestCase {

    // MARK: - storeOfferId(forOfferId:in:)

    /// `PLYPlan` has no public no-arg initializer (Global Constraint 0's
    /// verified-symbol note) so, as in the Task 1/2 fixtures, a plan carrying
    /// promo offers is built by decoding JSON through its own `CodingKeys`.
    private func decodedPlan(promoOffersJSON: String) throws -> PLYPlan {
        let json = """
        {
          "vendor_id": "PLAN_MONTHLY",
          "public_id": "plan_abc",
          "id": "1",
          "distribution_type": "renewing_subscription",
          "name": "Monthly",
          "store_product_id": "com.example.monthly",
          "is_visible": true,
          "promo_offers": \(promoOffersJSON)
        }
        """
        return try JSONDecoder().decode(PLYPlan.self, from: Data(json.utf8))
    }

    private func promoOfferJSON(vendorId: String, storeOfferId: String) -> String {
        """
        {"vendor_id": "\(vendorId)", "store_offer_id": "\(storeOfferId)", "public_id": "promo_\(vendorId)"}
        """
    }

    func testStoreOfferIdReturnsTheMatchingPromoOffersStoreOfferId() throws {
        // PurchaselyRN.m:1001-1009: iterate promoOffers, return the
        // storeOfferId of the one whose vendorId matches offerId.
        let plan = try decodedPlan(promoOffersJSON: "[\(promoOfferJSON(vendorId: "OFFER_A", storeOfferId: "sk_a")), \(promoOfferJSON(vendorId: "OFFER_B", storeOfferId: "sk_b"))]")

        XCTAssertEqual(PurchaselyBridge.storeOfferId(forOfferId: "OFFER_B", in: plan), "sk_b")
    }

    func testStoreOfferIdReturnsNilWhenNoPromoOfferMatches() throws {
        let plan = try decodedPlan(promoOffersJSON: "[\(promoOfferJSON(vendorId: "OFFER_A", storeOfferId: "sk_a"))]")

        XCTAssertNil(PurchaselyBridge.storeOfferId(forOfferId: "NO_SUCH_OFFER", in: plan))
    }

    func testStoreOfferIdReturnsNilWhenThePlanHasNoPromoOffers() throws {
        let plan = try decodedPlan(promoOffersJSON: "[]")

        XCTAssertNil(PurchaselyBridge.storeOfferId(forOfferId: "OFFER_A", in: plan))
    }

    // MARK: - offeringDictionary(_:)

    func testOfferingDictionaryIncludesOfferVendorIdWhenPresent() {
        // PurchaselyRN.m:1189-1209.
        let offering = PLYOffering(reference: "ref-1", planId: "plan-1", offerId: "offer-1", billingPlanType: .monthly)

        let dict = PurchaselyBridge.offeringDictionary(offering)

        XCTAssertEqual(dict["reference"] as? String, "ref-1")
        XCTAssertEqual(dict["planVendorId"] as? String, "plan-1")
        XCTAssertEqual(dict["offerVendorId"] as? String, "offer-1")
        // Fix 6: assert the literal wire string (PLYPlan+Bridge.swift's
        // `rnString(fromBillingPlanType:)`, `.monthly` -> "monthly"), not the
        // same mapper call the implementation uses — that comparison can
        // never catch a wrong wire string, only a mapper that disagrees with
        // itself.
        XCTAssertEqual(dict["billingPlanType"] as? String, "monthly")
    }

    func testOfferingDictionaryOmitsOfferVendorIdWhenNil() {
        // Constraint 6: omitted when nil, not emitted as NSNull.
        let offering = PLYOffering(reference: "ref-2", planId: "plan-2", offerId: nil, billingPlanType: .unspecified)

        let dict = PurchaselyBridge.offeringDictionary(offering)

        XCTAssertNil(dict["offerVendorId"])
        XCTAssertEqual(dict.keys.contains("offerVendorId"), false)
    }
}
