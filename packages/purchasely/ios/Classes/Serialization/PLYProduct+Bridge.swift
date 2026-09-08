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
//  `@objc public` is temporary: PLYSubscription+Hybrid.m still calls this
//  during phase 1, and a framework-layout target's generated header carries
//  only public declarations. Task 14 reduces it to `internal`.
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
