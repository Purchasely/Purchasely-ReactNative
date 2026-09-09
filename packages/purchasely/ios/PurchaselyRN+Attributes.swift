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
    // stays a primitive Int. `Purchasely.setAttribute(_:value:)` takes the
    // Swift `Purchasely.PLYAttribute` enum (.swiftinterface:1366), not an
    // ordinal, so an out-of-range value is guarded the same way as
    // `setLogLevel`/`setThemeMode` in the Lifecycle extension: never
    // force-unwrap `PLYAttribute(rawValue:)`.
    @objc(setAttribute:value:)
    func setAttribute(_ attribute: Int, value: String) {
        guard let attr = Purchasely.PLYAttribute(rawValue: attribute) else {
            PLYRNLogWarn("Unknown built-in attribute \(attribute), not set")
            return
        }
        Purchasely.setAttribute(attr, value: value)
    }

    // MARK: - setUserAttributeWith*

    @objc(setUserAttributeWithString:value:legalBasis:)
    func setUserAttributeWithString(_ key: String, value: String, legalBasis: String?) {
        Purchasely.setUserAttribute(withStringValue: value, forKey: key, processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    @objc(setUserAttributeWithBoolean:value:legalBasis:)
    func setUserAttributeWithBoolean(_ key: String, value: Bool, legalBasis: String?) {
        Purchasely.setUserAttribute(withBoolValue: value, forKey: key, processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    // Constraint: PurchaselyRN.m:729-742's fmod(value, 1.0) == 0 check is
    // replaced by `Int(exactly:)`, per the plan's verified trap for this
    // exact range — `Int(exactly:)` returns nil for a fractional, NaN,
    // infinite or out-of-range value, which is what fmod's behaviour plus
    // the 1e300 fix amounts to, without a separate `.rounded()` step that
    // would turn 2.5 into 3.
    @objc(setUserAttributeWithNumber:value:legalBasis:)
    func setUserAttributeWithNumber(_ key: String, value: Double, legalBasis: String?) {
        let lb = Self.legalBasis(from: legalBasis)
        if let asInt = Int(exactly: value) {
            Purchasely.setUserAttribute(withIntValue: asInt, forKey: key, processingLegalBasis: lb)
        } else {
            Purchasely.setUserAttribute(withDoubleValue: value, forKey: key, processingLegalBasis: lb)
        }
    }

    @objc(setUserAttributeWithInt:value:legalBasis:)
    func setUserAttributeWithInt(_ key: String, value: Int, legalBasis: String?) {
        Purchasely.setUserAttribute(withIntValue: value, forKey: key, processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    @objc(setUserAttributeWithDouble:value:legalBasis:)
    func setUserAttributeWithDouble(_ key: String, value: Double, legalBasis: String?) {
        Purchasely.setUserAttribute(withDoubleValue: value, forKey: key, processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    @objc(setUserAttributeWithDate:value:legalBasis:)
    func setUserAttributeWithDate(_ key: String, value: String, legalBasis: String?) {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

        guard let date = dateFormatter.date(from: value) else {
            PLYRNLogWarn("[Purchasely] Cannot save date attribute \(key): invalid ISO-8601 string \(value)")
            return
        }
        Purchasely.setUserAttribute(withDateValue: date, forKey: key, processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    // Constraint 4: the JS array crosses as `NSArray * _Nonnull` in the ObjC
    // annotation, but is Optional here regardless. A non-string element is
    // dropped via `compactMap`, same shape as `revokeDataProcessingConsent`.
    @objc(setUserAttributeWithStringArray:value:legalBasis:)
    func setUserAttributeWithStringArray(_ key: String, value: [Any]?, legalBasis: String?) {
        let strings = (value ?? []).compactMap { $0 as? String }
        Purchasely.setUserAttribute(withStringArray: strings, forKey: key, processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    // PurchaselyRN.m:787-797: normalizes every element to a pure BOOL to
    // avoid NSDecimalNumber surprises from JS.
    @objc(setUserAttributeWithBooleanArray:value:legalBasis:)
    func setUserAttributeWithBooleanArray(_ key: String, value: [Any]?, legalBasis: String?) {
        let bools = (value ?? []).compactMap { ($0 as? NSNumber)?.boolValue }
        Purchasely.setUserAttribute(withBoolArray: bools, forKey: key, processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    // PurchaselyRN.m:800-827: splits into an int array and a double array by
    // the same fractional test as setUserAttributeWithNumber, and calls each
    // SDK setter only when its array is non-empty.
    @objc(setUserAttributeWithNumberArray:value:legalBasis:)
    func setUserAttributeWithNumberArray(_ key: String, value: [Any]?, legalBasis: String?) {
        let lb = Self.legalBasis(from: legalBasis)
        var intArray: [Int] = []
        var doubleArray: [Double] = []
        for element in value ?? [] {
            guard let number = element as? NSNumber else { continue }
            let double = number.doubleValue
            if let asInt = Int(exactly: double) {
                intArray.append(asInt)
            } else {
                doubleArray.append(double)
            }
        }
        if !intArray.isEmpty {
            Purchasely.setUserAttribute(withIntArray: intArray, forKey: key, processingLegalBasis: lb)
        }
        if !doubleArray.isEmpty {
            Purchasely.setUserAttribute(withDoubleArray: doubleArray, forKey: key, processingLegalBasis: lb)
        }
    }

    @objc(setUserAttributeWithIntArray:value:legalBasis:)
    func setUserAttributeWithIntArray(_ key: String, value: [Any]?, legalBasis: String?) {
        let ints = (value ?? []).compactMap { ($0 as? NSNumber)?.intValue }
        Purchasely.setUserAttribute(withIntArray: ints, forKey: key, processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    @objc(setUserAttributeWithDoubleArray:value:legalBasis:)
    func setUserAttributeWithDoubleArray(_ key: String, value: [Any]?, legalBasis: String?) {
        let doubles = (value ?? []).compactMap { ($0 as? NSNumber)?.doubleValue }
        Purchasely.setUserAttribute(withDoubleArray: doubles, forKey: key, processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    // MARK: - increment / decrement

    // PurchaselyRN.m:847-861 reads `value.intValue`, which is 32-bit in
    // Objective-C. Swift's `NSNumber.intValue` is native-width `Int`, so
    // `Int(number.int32Value)` reproduces the truncation.
    @objc(incrementUserAttribute:value:legalBasis:)
    func incrementUserAttribute(_ key: String, value: NSNumber, legalBasis: String?) {
        Purchasely.incrementUserAttribute(withKey: key, value: Int(value.int32Value), processingLegalBasis: Self.legalBasis(from: legalBasis))
    }

    @objc(decrementUserAttribute:value:legalBasis:)
    func decrementUserAttribute(_ key: String, value: NSNumber, legalBasis: String?) {
        Purchasely.decrementUserAttribute(withKey: key, value: Int(value.int32Value), processingLegalBasis: Self.legalBasis(from: legalBasis))
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

    @objc(userAttribute:resolve:reject:)
    func userAttribute(_ key: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            resolve(Self.rnValue(for: Purchasely.getUserAttribute(for: key)))
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

    @objc(clearUserAttribute:)
    func clearUserAttribute(_ key: String) {
        Purchasely.clearUserAttribute(forKey: key)
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

    @objc(getBuiltInAttribute:resolve:reject:)
    func getBuiltInAttribute(_ key: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            resolve(Self.rnValue(for: Purchasely.getBuiltInAttribute(with: key)))
        }
    }
}
