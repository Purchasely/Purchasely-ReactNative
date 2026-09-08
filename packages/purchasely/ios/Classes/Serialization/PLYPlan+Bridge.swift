//
//  PLYPlan+Bridge.swift
//  Serializes a PLYPlan for the React Native bridge.
//  Ported from PLYPlan+Hybrid.m. The key set, the per-key absence policy and
//  the value types are a client contract — see SerializationContractTests and
//  types.ts.
//
//  `asDictionary()` is a METHOD, matching how the Objective-C category imported
//  into Swift, so the contract tests read the same before and after the port.
//
//  `@objc public` is temporary: PurchaselyRN.m and PLYProduct+Hybrid.m still
//  call this during phase 1, and a framework-layout target's generated header
//  carries only public declarations. Task 14 reduces it to `internal`.
//

import Foundation
import Purchasely

@objc public extension PLYPlan {

    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        dict["vendorId"] = vendorId
        // [RN-W-07] Always emit hasIntroductoryPrice/hasFreeTrial as real
        // booleans — the TS types are required (non-optional).
        dict["hasIntroductoryPrice"] = hasIntroductoryPrice
        dict["type"] = type.rawValue
        dict["hasFreeTrial"] = hasFreeTrial

        // basePlanId is a Google Play concept; App Store has no equivalent on
        // PLYPlan, so the key is omitted.

        // Promotional-offer price fields: iOS PLYPlan has no public accessor
        // for a promotional offer's localized price/duration/period — only
        // the introductory-offer accessors below exist. Emit safe defaults
        // so the RN keys are always present, per PLYPlan+Hybrid.m.
        dict["hasOfferPrice"] = false
        dict["offerPrice"] = ""
        dict["offerAmount"] = 0
        dict["offerDuration"] = ""
        dict["offerPeriod"] = ""

        if let name {
            dict["name"] = name
        }

        if let appleProductId {
            dict["productId"] = appleProductId
        }

        if let price = localizedFullPrice(language: nil) {
            dict["price"] = price
        }

        if let amount {
            dict["amount"] = amount
        }

        if let localizedAmount = localizedPrice(language: nil) {
            dict["localizedAmount"] = localizedAmount
        }

        if let introAmount {
            dict["introAmount"] = introAmount
        }

        if let currencyCode {
            dict["currencyCode"] = currencyCode
        }

        if let currencySymbol {
            dict["currencySymbol"] = currencySymbol
        }

        if let period = localizedPeriod(language: nil) {
            dict["period"] = period
        }

        if let introPrice = localizedFullIntroductoryPrice(language: nil) {
            dict["introPrice"] = introPrice
        }

        if let introDuration = localizedIntroductoryDuration(language: nil) {
            dict["introDuration"] = introDuration
        }

        if let introPeriod = localizedIntroductoryPeriod(language: nil) {
            dict["introPeriod"] = introPeriod
        }

        // Apple-only (iOS 26.4+) multi-period commitment installments. Empty
        // on other stores / non-committed plans — key omitted (Constraint 6:
        // `count > 0` on a non-optional array, not `if let`).
        if !commitmentInfo.isEmpty {
            dict["commitmentInfo"] = commitmentInfo.map { info -> [String: Any] in
                [
                    "billingPlanType": PLYPlan.rnString(fromBillingPlanType: info.billingPlanType),
                    "billingPrice": info.billingPrice,
                    "billingPeriod": info.billingPeriod,
                    "totalPrice": info.totalPrice,
                    "totalPeriod": info.totalPeriod,
                    "totalDuration": info.totalDuration,
                ]
            }
        }

        return dict
    }

    // MARK: - billing plan type wire values

    /// Replaces the C function `PLYBillingPlanTypeToRNString`. A free Swift
    /// function cannot be `@objc`, so this is a static member and
    /// `PurchaselyRN.m` calls `[PLYPlan rnStringFromBillingPlanType:x]`.
    @objc(rnStringFromBillingPlanType:)
    static func rnString(fromBillingPlanType type: PLYBillingPlanType) -> String {
        switch type {
        case .upFront: return "upFront"
        case .monthly: return "monthly"
        case .unspecified: return "unspecified"
        @unknown default: return "unspecified"
        }
    }

    /// Replaces `PLYBillingPlanTypeFromRNString`. Unknown and nil map to
    /// `.unspecified`, as the C function did.
    @objc(billingPlanTypeFromRNString:)
    static func billingPlanType(fromRNString value: String?) -> PLYBillingPlanType {
        switch value {
        case "upFront": return .upFront
        case "monthly": return .monthly
        default: return .unspecified
        }
    }
}

// MARK: - free-function aliases (SerializationContractTests contract)
//
// SerializationContractTests.swift is a frozen gate (Task 1) and calls these
// two mappers as top-level Swift functions with the ORIGINAL C-function
// names, not as PLYPlan static members. A free Swift function cannot be
// `@objc`, so it cannot serve PurchaselyRN.m directly — hence the `@objc`
// static members above for the Objective-C call sites, and these thin
// free-function aliases for the Swift-only gate test contract. Both paths
// share the same logic; there is exactly one implementation.

func PLYBillingPlanTypeToRNString(_ type: PLYBillingPlanType) -> String {
    PLYPlan.rnString(fromBillingPlanType: type)
}

func PLYBillingPlanTypeFromRNString(_ value: String?) -> PLYBillingPlanType {
    PLYPlan.billingPlanType(fromRNString: value)
}
