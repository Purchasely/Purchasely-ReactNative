//
//  PLYOfferSignature+Bridge.swift
//  Serializes a PLYOfferSignature for the React Native bridge.
//  Ported from PLYOfferSignature+Hybrid.m. The key set, the per-key absence
//  policy and the value types are a client contract — see
//  SerializationContractTests and types.ts.
//
//  `asDictionary()` is a METHOD, matching how the Objective-C category
//  imported into Swift, so the contract tests read the same before and
//  after the port.
//
//  `@objc public` is temporary: Task 14 reduces it to `internal`.
//

import Foundation
import Purchasely

@objc public extension PLYOfferSignature {

    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        dict["planVendorId"] = planVendorId
        dict["identifier"] = identifier
        dict["signature"] = signature
        dict["keyIdentifier"] = keyIdentifier

        // nonce (Foundation.UUID) and timestamp (Double) are non-optional on
        // PLYOfferSignature — the Objective-C guards were dead code on a
        // never-nil value (Constraint 6). Both keys are unconditional.
        dict["nonce"] = nonce.uuidString
        dict["timestamp"] = timestamp

        return dict
    }
}
