//
//  PurchaselyRN+Attributes.swift
//  The 21 attribute methods and the legal-basis mapper.
//
//  Ported from PurchaselyRN.m:701-935 (Task 10 of the Swift bridge migration
//  plan). Transliteration only — see the plan's Global Constraints before
//  touching anything here.
//

import Foundation
import Purchasely

extension PurchaselyBridge {

    // MARK: - legal basis

    /// Ported from `-legalBasisFromString:` (PurchaselyRN.m:701-707).
    /// Takes a STRING, not an ordinal, and returns
    /// `PLYDataProcessingLegalBasis` — `PLYLegalBasis` does not exist
    /// (.swiftinterface: `enum PLYDataProcessingLegalBasis`, cases
    /// `.optional`/`.essential`). Upper-cases the input, matches
    /// "ESSENTIAL", and falls back to `.optional` for nil, a non-string and
    /// anything unknown. enums.ts:87-90 sends 'ESSENTIAL' and 'OPTIONAL'.
    static func legalBasis(from value: String?) -> PLYDataProcessingLegalBasis {
        value?.uppercased() == "ESSENTIAL" ? .essential : .optional
    }

    // MARK: - built-in attribute

    // Constraint 4: `attribute` is a C primitive (NSInteger) today, so it
    // stays a primitive Int. `value` is an object-typed (`NSString *
    // _Nonnull`) parameter, so it is Optional here regardless of the ObjC
    // annotation (Global Constraint 4) — the ObjC body (PurchaselyRN.m:709-711)
    // has no nil guard and forwards `value` straight to the SDK, so a nil
    // here is coalesced to "" rather than trapping, same shape as `userId` in
    // `userLogin` (Lifecycle).
    // `Purchasely.setAttribute(_:value:)` takes the Swift
    // `Purchasely.PLYAttribute` enum (.swiftinterface:1366), not an ordinal,
    // so an out-of-range value is guarded the same way as
    // `setLogLevel`/`setThemeMode` in the Lifecycle extension: never
    // force-unwrap `PLYAttribute(rawValue:)`.
    @objc(setAttribute:value:)
    func setAttribute(_ attribute: Int, value: String?) {
        guard let attr = Purchasely.PLYAttribute(rawValue: attribute) else {
            PLYRNLogWarn("Unknown built-in attribute \(attribute), not set")
            return
        }
        Purchasely.setAttribute(attr, value: value ?? "")
    }

    // MARK: - setUserAttributeWith*

    // Constraint 4: `key` and `value` are both object-typed (`NSString *
    // _Nonnull`), so both are Optional here. PurchaselyRN.m:713-718 has no
    // nil guard and forwards both straight to the SDK, so both coalesce to
    // "" rather than trapping.
    @objc(setUserAttributeWithString:value:legalBasis:)
    func setUserAttributeWithString(_ key: String?, value: String?, legalBasis: String?) {
        Purchasely.setUserAttribute(withStringValue: value ?? "", forKey: key ?? "", processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    @objc(setUserAttributeWithBoolean:value:legalBasis:)
    func setUserAttributeWithBoolean(_ key: String?, value: Bool, legalBasis: String?) {
        Purchasely.setUserAttribute(withBoolValue: value, forKey: key ?? "", processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    /// Ported from PurchaselyRN.m:729-742's `fmod(value, 1.0) == 0` check.
    /// Returns the integer path's value when `value` has no fractional part
    /// and fits in `Int`; a fractional, NaN, infinite or out-of-range value
    /// returns nil, which is what the fmod check plus the 1e300 fix amounts
    /// to, without a separate `.rounded()` step that would turn 2.5 into 3.
    /// A pure function with no SDK dependency, so it is unit-tested directly.
    static func wholeNumberAttributeValue(_ value: Double) -> Int? {
        Int(exactly: value)
    }

    @objc(setUserAttributeWithNumber:value:legalBasis:)
    func setUserAttributeWithNumber(_ key: String?, value: Double, legalBasis: String?) {
        let lb = Self.legalBasis(from: legalBasis)
        if let asInt = Self.wholeNumberAttributeValue(value) {
            Purchasely.setUserAttribute(withIntValue: asInt, forKey: key ?? "", processingLegalBasis: lb)
        } else {
            Purchasely.setUserAttribute(withDoubleValue: value, forKey: key ?? "", processingLegalBasis: lb)
        }
    }

    @objc(setUserAttributeWithInt:value:legalBasis:)
    func setUserAttributeWithInt(_ key: String?, value: Int, legalBasis: String?) {
        Purchasely.setUserAttribute(withIntValue: value, forKey: key ?? "", processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    @objc(setUserAttributeWithDouble:value:legalBasis:)
    func setUserAttributeWithDouble(_ key: String?, value: Double, legalBasis: String?) {
        Purchasely.setUserAttribute(withDoubleValue: value, forKey: key ?? "", processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    // Constraint 4: `key` and `value` are both Optional. `value` feeds
    // `dateFormatter.date(from:)`, which already returns nil for anything
    // that doesn't parse — coalescing a nil `value` to "" lands in that same
    // failure branch rather than adding a second guard, and the warning
    // below is logged with NSLog, matching PurchaselyRN.m:773 exactly (that
    // site is NOT RCTLogWarn/PLYRNLogWarn in the Objective-C original).
    @objc(setUserAttributeWithDate:value:legalBasis:)
    func setUserAttributeWithDate(_ key: String?, value: String?, legalBasis: String?) {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

        guard let date = dateFormatter.date(from: value ?? "") else {
            NSLog("[Purchasely] Cannot save date attribute %@: invalid ISO-8601 string %@", key ?? "", value ?? "")
            return
        }
        Purchasely.setUserAttribute(withDateValue: date, forKey: key ?? "", processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    // Constraint 4: the JS array crosses as `NSArray * _Nonnull` in the ObjC
    // annotation, but is Optional here regardless, same as `key`.
    //
    // Finding 10 — verified, not matched exactly; see the file-level note
    // above `setUserAttributeWithIntArray` for why. Kept as `compactMap`
    // (drop), the pre-existing reviewed baseline.
    @objc(setUserAttributeWithStringArray:value:legalBasis:)
    func setUserAttributeWithStringArray(_ key: String?, value: [Any]?, legalBasis: String?) {
        let strings = (value ?? []).compactMap { $0 as? String }
        Purchasely.setUserAttribute(withStringArray: strings, forKey: key ?? "", processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    // PurchaselyRN.m:787-797: normalizes every element to a pure BOOL to
    // avoid NSDecimalNumber surprises from JS.
    @objc(setUserAttributeWithBooleanArray:value:legalBasis:)
    func setUserAttributeWithBooleanArray(_ key: String?, value: [Any]?, legalBasis: String?) {
        let bools = (value ?? []).compactMap { ($0 as? NSNumber)?.boolValue }
        Purchasely.setUserAttribute(withBoolArray: bools, forKey: key ?? "", processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    // PurchaselyRN.m:800-827: splits into an int array and a double array by
    // the same fractional test as setUserAttributeWithNumber, and calls each
    // SDK setter only when its array is non-empty.
    @objc(setUserAttributeWithNumberArray:value:legalBasis:)
    func setUserAttributeWithNumberArray(_ key: String?, value: [Any]?, legalBasis: String?) {
        let lb = Self.legalBasis(from: legalBasis)
        var intArray: [Int] = []
        var doubleArray: [Double] = []
        for element in value ?? [] {
            guard let number = element as? NSNumber else { continue }
            let double = number.doubleValue
            if let asInt = Self.wholeNumberAttributeValue(double) {
                intArray.append(asInt)
            } else {
                doubleArray.append(double)
            }
        }
        if !intArray.isEmpty {
            Purchasely.setUserAttribute(withIntArray: intArray, forKey: key ?? "", processingLegalBasis: lb)
        }
        if !doubleArray.isEmpty {
            Purchasely.setUserAttribute(withDoubleArray: doubleArray, forKey: key ?? "", processingLegalBasis: lb)
        }
    }

    // Finding 10 (IntArray/DoubleArray/StringArray, all three): PurchaselyRN.m
    // has NO per-element loop for these three — it forwards `value` verbatim
    // to the matching `+setUserAttributeWith*Array:forKey:...`, whose Swift
    // signature takes a typed array (`[Int]`/`[Double]`/`[String]`).
    // Objective-C generics are erased, so the compiler does not check element
    // type; the ACTUAL conversion happens in the Objective-C↔Swift
    // array-bridging thunk. Verified empirically (`NSArray as? [Int]`/
    // `[String]`, Foundation, outside the SDK):
    //   - a non-conforming element (e.g. a string in an int array) -> the
    //     WHOLE bridge fails (`nil`), which force-casting (`as!`) would turn
    //     into a trap;
    //   - critically, a FRACTIONAL NSNumber (e.g. 2.7) in an int/double-typed
    //     bridge to `[Int]` ALSO fails the same way — the bridge requires an
    //     exact per-element type match, not a coercible one.
    // So the verbatim-forward's real failure mode is: the entire array is
    // rejected by ANY element that isn't already exactly the target type —
    // not "drop the bad one" and not "truncate the bad one". Reproducing
    // that exactly would mean trapping the whole call on a single fractional
    // number sent from JS (where numbers have no int/double distinction),
    // which no other setter in this file does and which the orchestrator
    // has not asked for. `compactMap` (drop per-element) is kept as the
    // pre-existing, already-reviewed behaviour instead of introducing a new
    // whole-array trap — this is reported, not silently decided; see
    // `deviations`.
    @objc(setUserAttributeWithIntArray:value:legalBasis:)
    func setUserAttributeWithIntArray(_ key: String?, value: [Any]?, legalBasis: String?) {
        let ints = (value ?? []).compactMap { ($0 as? NSNumber)?.intValue }
        Purchasely.setUserAttribute(withIntArray: ints, forKey: key ?? "", processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    @objc(setUserAttributeWithDoubleArray:value:legalBasis:)
    func setUserAttributeWithDoubleArray(_ key: String?, value: [Any]?, legalBasis: String?) {
        let doubles = (value ?? []).compactMap { ($0 as? NSNumber)?.doubleValue }
        Purchasely.setUserAttribute(withDoubleArray: doubles, forKey: key ?? "", processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    // MARK: - increment / decrement

    /// Ported from PurchaselyRN.m:847-861's `value.intValue`, which in
    /// Objective-C is 32-bit. Swift's `NSNumber.intValue` is native-width
    /// `Int`, so this reproduces the truncation explicitly via
    /// `int32Value`. A nil `value` message-sent `.intValue` in Objective-C
    /// returns 0 (message-to-nil yields a zeroed scalar), preserved here
    /// rather than inventing a new guard. A pure function with no SDK
    /// dependency, so it is unit-tested directly.
    static func truncatedToInt32(_ value: NSNumber?) -> Int {
        Int(value?.int32Value ?? 0)
    }

    // Constraint 4: `key` and `value` are both object-typed, so both are
    // Optional.
    @objc(incrementUserAttribute:value:legalBasis:)
    func incrementUserAttribute(_ key: String?, value: NSNumber?, legalBasis: String?) {
        Purchasely.incrementUserAttribute(withKey: key ?? "", value: Self.truncatedToInt32(value), processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    @objc(decrementUserAttribute:value:legalBasis:)
    func decrementUserAttribute(_ key: String?, value: NSNumber?, legalBasis: String?) {
        Purchasely.decrementUserAttribute(withKey: key ?? "", value: Self.truncatedToInt32(value), processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    // MARK: - reading attributes

    /// Ported from `-getUserAttributeValueForRN:` (PurchaselyRN.m:889-899).
    /// An `NSDate` value is formatted to the same ISO-8601 shape the setters
    /// accept; everything else, nil included, passes through unchanged.
    static func rnValue(for value: Any?) -> Any? {
        guard let date = value as? Date else { return value }
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return dateFormatter.string(from: date)
    }

    // Constraint 4: `key` is Optional.
    @objc(userAttribute:resolve:reject:)
    func userAttribute(_ key: String?, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            resolve(Self.rnValue(for: Purchasely.getUserAttribute(for: key ?? "")))
        }
    }

    @objc(userAttributes:reject:)
    func userAttributes(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            var attributesDict: [String: Any] = [:]
            for (key, value) in Purchasely.userAttributes {
                attributesDict[key] = Self.rnValue(for: value)
            }
            resolve(attributesDict)
        }
    }

    // MARK: - clearing attributes

    // Constraint 4: `key` is Optional.
    @objc(clearUserAttribute:)
    func clearUserAttribute(_ key: String?) {
        Purchasely.clearUserAttribute(forKey: key ?? "")
    }

    @objc(clearUserAttributes)
    func clearUserAttributes() {
        Purchasely.clearUserAttributes()
    }

    @objc(clearBuiltInAttributes)
    func clearBuiltInAttributes() {
        Purchasely.clearBuiltInAttributes()
    }

    // MARK: - built-in attributes (read)

    // [PAR-07] Reuses `rnValue(for:)` (same value shaping as
    // userAttributes/userAttribute) for consistency.
    @objc(getBuiltInAttributes:reject:)
    func getBuiltInAttributes(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            var attributesDict: [String: Any] = [:]
            for (key, value) in Purchasely.getBuiltInAttributes() {
                attributesDict[key] = Self.rnValue(for: value)
            }
            resolve(attributesDict)
        }
    }

    // Constraint 4: `key` is Optional.
    @objc(getBuiltInAttribute:resolve:reject:)
    func getBuiltInAttribute(_ key: String?, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            resolve(Self.rnValue(for: Purchasely.getBuiltInAttribute(with: key ?? "")))
        }
    }
}
