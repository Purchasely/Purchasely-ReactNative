//
//  PLYPresentationPlan+Bridge.swift
//  Serializes a PLYPresentationPlan for the React Native bridge.
//  Ported from PLYPresentationPlan+Hybrid.m. The key set, the per-key
//  absence policy and the value types are a client contract — see
//  SerializationContractTests and types.ts.
//
//  `asDictionary()` is a METHOD, matching how the Objective-C category
//  imported into Swift, so the contract tests read the same before and
//  after the port.
//
//  `@objc public` was temporary scaffolding for Objective-C callers that no
//  longer exist as of Task 14 — reduced to `internal`.
//

import Foundation
import Purchasely

extension PLYPresentationPlan {

    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        if let offerId {
            dict["offerId"] = offerId
        }

        if let offerVendorId {
            dict["offerVendorId"] = offerVendorId
        }

        if let storeProductId {
            dict["storeProductId"] = storeProductId
        }

        if let planVendorId {
            dict["planVendorId"] = planVendorId
        }

        // `default` is a Swift Bool on the interface, not an enum — the plan
        // text calling for `.rawValue` here disagrees with
        // arm64-apple-ios-simulator.swiftinterface (Global Constraint 0: the
        // interface wins). Matches PLYPresentationPlan+Hybrid.m's
        // `@(self.default_)`, a boxed BOOL.
        dict["default"] = self.`default`

        return dict
    }
}
