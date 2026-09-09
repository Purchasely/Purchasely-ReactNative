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

extension PurchaselyRN {

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

    // ORCHESTRATOR RULING (array element handling): the Objective-C treated
    // the five array setters two different ways and this file must keep
    // both, not flatten them into one `compactMap` that silently sets a
    // PARTIAL array — user attributes drive audience targeting, so a
    // partial array shows a client the wrong paywall.
    //
    // Group (b) below — StringArray, IntArray, DoubleArray — forwarded
    // `value` VERBATIM to a Swift-typed SDK setter (`[String]`/`[Int]`/
    // `[Double]`). Objective-C generics are erased so the compiler never
    // checked element type; the ACTUAL conversion happened in the
    // Objective-C↔Swift array-bridging thunk, and that thunk is all-or-
    // nothing. Verified empirically (`NSArray as? [Int]` / `[Double]` /
    // `[String]`, Foundation, outside the SDK):
    //   - [String]: any non-String element fails the WHOLE bridge.
    //   - [Int]: any element that is not an NSNumber, OR an NSNumber with a
    //     fractional part (e.g. 2.7), fails the WHOLE bridge.
    //   - [Double]: any non-NSNumber element fails the WHOLE bridge; a
    //     fractional NSNumber is fine.
    // So the Objective-C's OBSERVABLE outcome for these three is: the
    // attribute is NOT set at all. This file reproduces that outcome
    // WITHOUT reproducing the bridge's trap — deliberately shipping a crash
    // is not acceptable. `exactStringArray`/`exactIntArray`/
    // `exactDoubleArray` below return nil (bail, NSLog, do not set) instead
    // of force-casting. Do NOT "simplify" these back to a `compactMap` that
    // drops the bad element and sets a partial array — that changes the
    // observable outcome from "attribute not set" to "attribute set wrong".

    /// (b) `setUserAttributeWithStringArray`, PurchaselyRN.m:778-784: the
    /// verbatim-forward case. Returns nil, having NSLog'd the offending
    /// index, the moment an element is not exactly a `String`.
    static func exactStringArray(_ value: [Any]?, forKey key: String) -> [String]? {
        var result: [String] = []
        for (index, element) in (value ?? []).enumerated() {
            guard let string = element as? String else {
                NSLog("[Purchasely] setUserAttributeWithStringArray: attribute \"%@\" not set, element at index %ld is not a string", key, index)
                return nil
            }
            result.append(string)
        }
        return result
    }

    @objc(setUserAttributeWithStringArray:value:legalBasis:)
    func setUserAttributeWithStringArray(_ key: String?, value: [Any]?, legalBasis: String?) {
        guard let strings = Self.exactStringArray(value, forKey: key ?? "") else { return }
        Purchasely.setUserAttribute(withStringArray: strings, forKey: key ?? "", processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    /// (a) `setUserAttributeWithBooleanArray`, PurchaselyRN.m:787-797: the
    /// coercing case. The Objective-C LOOPED and sent `-boolValue` to every
    /// element, so a non-NSNumber element message-sent `.boolValue` and
    /// became `false` rather than dropping out — reproduced here with
    /// `?? false` instead of a message-send-to-nil.
    static func coercedBoolArray(_ value: [Any]?) -> [Bool] {
        (value ?? []).map { ($0 as? NSNumber)?.boolValue ?? false }
    }

    @objc(setUserAttributeWithBooleanArray:value:legalBasis:)
    func setUserAttributeWithBooleanArray(_ key: String?, value: [Any]?, legalBasis: String?) {
        let bools = Self.coercedBoolArray(value)
        Purchasely.setUserAttribute(withBoolArray: bools, forKey: key ?? "", processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    /// (a) `setUserAttributeWithNumberArray`, PurchaselyRN.m:800-827: the
    /// other coercing case. Every element is coerced through
    /// `-doubleValue` (a non-NSNumber element becomes 0) and kept, then
    /// split into an int array and a double array by the same fractional
    /// test as `setUserAttributeWithNumber`; each SDK setter fires only
    /// when its array is non-empty, exactly as the Objective-C did.
    static func splitNumberArray(_ value: [Any]?) -> (ints: [Int], doubles: [Double]) {
        var intArray: [Int] = []
        var doubleArray: [Double] = []
        for element in value ?? [] {
            let double = (element as? NSNumber)?.doubleValue ?? 0
            if let asInt = Self.wholeNumberAttributeValue(double) {
                intArray.append(asInt)
            } else {
                doubleArray.append(double)
            }
        }
        return (intArray, doubleArray)
    }

    @objc(setUserAttributeWithNumberArray:value:legalBasis:)
    func setUserAttributeWithNumberArray(_ key: String?, value: [Any]?, legalBasis: String?) {
        let lb = Self.legalBasis(from: legalBasis)
        let split = Self.splitNumberArray(value)
        if !split.ints.isEmpty {
            Purchasely.setUserAttribute(withIntArray: split.ints, forKey: key ?? "", processingLegalBasis: lb)
        }
        if !split.doubles.isEmpty {
            Purchasely.setUserAttribute(withDoubleArray: split.doubles, forKey: key ?? "", processingLegalBasis: lb)
        }
    }

    /// (b) `setUserAttributeWithIntArray`, PurchaselyRN.m:830-836: the
    /// verbatim-forward case. A fractional NSNumber (e.g. 2.7) fails the
    /// same way a non-numeric element does — verified empirically, see the
    /// group comment above — so both bail out here too.
    static func exactIntArray(_ value: [Any]?, forKey key: String) -> [Int]? {
        var result: [Int] = []
        for (index, element) in (value ?? []).enumerated() {
            guard let number = element as? NSNumber, let asInt = Self.wholeNumberAttributeValue(number.doubleValue) else {
                NSLog("[Purchasely] setUserAttributeWithIntArray: attribute \"%@\" not set, element at index %ld is not an integer", key, index)
                return nil
            }
            result.append(asInt)
        }
        return result
    }

    @objc(setUserAttributeWithIntArray:value:legalBasis:)
    func setUserAttributeWithIntArray(_ key: String?, value: [Any]?, legalBasis: String?) {
        guard let ints = Self.exactIntArray(value, forKey: key ?? "") else { return }
        Purchasely.setUserAttribute(withIntArray: ints, forKey: key ?? "", processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    /// (b) `setUserAttributeWithDoubleArray`, PurchaselyRN.m:839-845: the
    /// verbatim-forward case. Unlike Int, a fractional NSNumber is fine
    /// here — only a non-NSNumber element bails out (verified empirically,
    /// see the group comment above).
    static func exactDoubleArray(_ value: [Any]?, forKey key: String) -> [Double]? {
        var result: [Double] = []
        for (index, element) in (value ?? []).enumerated() {
            guard let number = element as? NSNumber else {
                NSLog("[Purchasely] setUserAttributeWithDoubleArray: attribute \"%@\" not set, element at index %ld is not a number", key, index)
                return nil
            }
            result.append(number.doubleValue)
        }
        return result
    }

    @objc(setUserAttributeWithDoubleArray:value:legalBasis:)
    func setUserAttributeWithDoubleArray(_ key: String?, value: [Any]?, legalBasis: String?) {
        guard let doubles = Self.exactDoubleArray(value, forKey: key ?? "") else { return }
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
