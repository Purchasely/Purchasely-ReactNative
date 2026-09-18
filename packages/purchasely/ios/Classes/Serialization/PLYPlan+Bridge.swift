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
//  `@objc public` on `asDictionary()` is PERMANENT, not a phase-1 scaffold.
//  Since Task 14, PurchaselyRN.m no longer calls it — the shim's only
//  consumer is `PLYSubscription+Hybrid.m` (permanent per amendment A2),
//  which reaches it through its own hand-written `@interface PLYPlan
//  (BridgeSerialization)` forward declaration — an Objective-C message send
//  that is RUNTIME dispatch, never checked against this method at compile or
//  link time. Dropping `@objc` here compiles and links fine and crashes only
//  the first time a real `userSubscriptions` call reaches it;
//  SerializationContractTests' testPlanAndProductRespondToAsDictionarySelector
//  is the only thing left that would catch it. (PLYProduct+Hybrid.m, the
//  other stale caller this comment used to name, was deleted in Task 3.)
//

import Foundation
import Purchasely

extension PLYPlan {

    @objc public func asDictionary() -> [String: Any] {
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

        // `period` is the accessor name, but PLYPlan also has a real `period`
        // property with a different value (Global Constraint 0 shadow trap:
        // verified via awk '/class PLYPlan :/,/^}/' against the .swiftinterface
        // extension block). A local named `period` here would silently ship
        // the wrong string if a later edit hoists this write out of the
        // if-let, so the local is named localizedPeriodValue instead.
        if let localizedPeriodValue = localizedPeriod(language: nil) {
            dict["period"] = localizedPeriodValue
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

    /// Replaces the C function `PLYBillingPlanTypeToRNString`. Since Task 14
    /// this is called only from Swift (`PurchaselyRN+Products.swift`), by its
    /// Swift name, so it no longer needs `@objc`.
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
