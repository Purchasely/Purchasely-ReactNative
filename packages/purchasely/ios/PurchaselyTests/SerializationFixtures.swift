//
//  SerializationFixtures.swift
//  Decoded model instances for the serialization contract tests.
//
//  The SDK's model types have no public no-argument initializer, only
//  `init(from decoder:)`. So a fixture is JSON. The wire keys are each type's
//  `enum CodingKeys` in /Users/kevin/Purchasely/iOS/Sources/Purchasely/.
//
//  Each type gets TWO fixtures: `populated`, with every optional field set,
//  and `sparse`, with only the required fields. The pair is what proves the
//  per-field absence policy, which is the one thing Swift silently changes.
//
//  PLYSubscription is NOT included here. Its `init(from:)` resolves `.product`
//  via the SDK-internal `ProductRepository.shared.getProduct(containingPlan:)`
//  (PLYSubscription.swift:98, ProductRepository.swift:132), which is empty in
//  a unit test process and has no public seam to populate. Decoding always
//  throws `PLYSubscriptionError.couldntFindProduct`, regardless of JSON. See
//  SerializationContractTests.swift for the observed failure and the report.
//

import Foundation
import Purchasely

enum SerializationFixtures {

    static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // MARK: - PLYPlan
    // CodingKeys: vendor_id, public_id, id, distribution_type, level, name,
    //             store_product_id, is_visible, promo_offers

    static let planPopulatedJSON = """
    {
      "vendor_id": "PLAN_MONTHLY",
      "public_id": "plan_abc",
      "id": "1",
      "distribution_type": "renewing_subscription",
      "name": "Monthly",
      "store_product_id": "com.example.monthly",
      "is_visible": true
    }
    """

    /// Only what the decoder requires. Every optional stays absent, which is
    /// what makes the omission assertions meaningful.
    static let planSparseJSON = """
    { "vendor_id": "PLAN_MONTHLY", "id": "1" }
    """

    static func plan(populated: Bool) throws -> PLYPlan {
        try decode(PLYPlan.self, populated ? planPopulatedJSON : planSparseJSON)
    }

    // MARK: - PLYProduct
    // CodingKeys: id, public_id, vendor_id, name, plans, icon
    // `plans` decodes via `decodeSafelyArray`, which returns `[]` on a
    // missing key rather than throwing (KeyedDecodingContainer+Extension.swift:63-66).

    static let productPopulatedJSON = """
    {
      "id": "prod_1",
      "public_id": "product_abc",
      "vendor_id": "PRODUCT_MONTHLY",
      "name": "Monthly Product",
      "plans": [\(planPopulatedJSON)]
    }
    """

    static let productSparseJSON = """
    { "id": "prod_1", "vendor_id": "PRODUCT_MONTHLY" }
    """

    static func product(populated: Bool) throws -> PLYProduct {
        try decode(PLYProduct.self, populated ? productPopulatedJSON : productSparseJSON)
    }

    // MARK: - PLYOfferSignature
    // CodingKeys: key_identifier, plan_vendor_id, offer_identifier,
    //             offer_signature, offer_nonce, offer_timestamp
    // All six fields are decoded with `decode` (required), not
    // `decodeIfPresent` (PLYOfferSignature.swift:21-26) — there is no
    // nullable key. `nonce`/`timestamp` are non-optional at the property
    // level too, matching Step 1's "dead code guard" finding.

    static let offerSignatureJSON = """
    {
      "plan_vendor_id": "PLAN_MONTHLY",
      "key_identifier": "key_1",
      "offer_identifier": "offer_1",
      "offer_signature": "sig_1",
      "offer_nonce": "9d5e2e6a-9b0a-4e1a-8b0a-2e6a9d5e2e6a",
      "offer_timestamp": 1700000000.0
    }
    """

    /// PLYOfferSignature has no optional key (Step 1), so there is no
    /// meaningfully "sparse" variant distinct from the populated one — every
    /// required key must be present for decoding to succeed at all.
    static func offerSignature() throws -> PLYOfferSignature {
        try decode(PLYOfferSignature.self, offerSignatureJSON)
    }

    // MARK: - PLYPresentationPlan
    // CodingKeys: plan_vendor_id, store_product_id, offer_id, offer_vendor_id,
    //             default, commitment_billing_type
    // `plan_vendor_id` is decoded with `decode` (required, PLYPresentationPlan.swift:25)
    // even though the property type is `String?` — so, unlike the plan's
    // draft table, `planVendorId` CANNOT be omitted from the sparse fixture.
    // `storeProductId`, `offerId`, `offerVendorId` are `decodeIfPresent`
    // (optional) and are the true absent-on-sparse set.

    static let presentationPlanPopulatedJSON = """
    {
      "plan_vendor_id": "PLAN_MONTHLY",
      "store_product_id": "com.example.monthly",
      "offer_id": "offer_1",
      "offer_vendor_id": "OFFER_1",
      "default": true
    }
    """

    static let presentationPlanSparseJSON = """
    { "plan_vendor_id": "PLAN_MONTHLY" }
    """

    static func presentationPlan(populated: Bool) throws -> PLYPresentationPlan {
        try decode(PLYPresentationPlan.self, populated ? presentationPlanPopulatedJSON : presentationPlanSparseJSON)
    }
}
