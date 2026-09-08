//
//  PLYProduct+Bridge.swift
//  Serializes a PLYProduct for the React Native bridge.
//  Ported from PLYProduct+Hybrid.m. The key set, the per-key absence policy and
//  the value types are a client contract — see SerializationContractTests and
//  types.ts.
//
//  `asDictionary()` is a METHOD, matching how the Objective-C category imported
//  into Swift, so the contract tests read the same before and after the port.
//
//  `@objc public` on `asDictionary()` is PERMANENT, not a phase-1 scaffold.
//  PurchaselyRN.m (not yet ported — Task 14) still calls it today through the
//  compiler-generated `react_native_purchasely-Swift.h`, which the compiler
//  DOES check. But `PLYSubscription+Hybrid.m` (permanent per amendment A2)
//  reaches it through its own hand-written `@interface PLYProduct
//  (BridgeSerialization)` forward declaration — an Objective-C message send
//  that is RUNTIME dispatch, never checked against this method at compile or
//  link time. Task 14 removes PurchaselyRN.m's own binding but must NOT drop
//  `@objc` here: SerializationContractTests'
//  testPlanAndProductRespondToAsDictionarySelector is the only thing left
//  that would catch it.
//

import Foundation
import Purchasely

@objc public extension PLYProduct {

    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        dict["vendorId"] = vendorId

        // plans is a NON-optional array (Constraint 6): always emit the key,
        // even as [] — PLYProduct+Hybrid.m:18-23 always sets it.
        dict["plans"] = plans.map { $0.asDictionary() }

        if let name {
            dict["name"] = name
        }

        return dict
    }
}
