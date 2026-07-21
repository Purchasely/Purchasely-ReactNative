//
//  PLYTransitionFactory.swift
//  react-native-purchasely
//
//  Created for v6 Flutter-parity: exposes width + pixel-height transitions to
//  the Objective-C bridge (PurchaselyRN.m).
//

import Foundation
import Purchasely

/// `PLYTransition`'s Objective-C-visible convenience initializer only exposes
/// a legacy 0…1 `heightPercentage` — not the typed pixel/percentage
/// `PLYDimension` the Swift-only designated initializer
/// (`init(type:height:width:heightPercentage:backgroundColors:dismissible:)`)
/// takes. `PLYDimension` itself (a Swift enum with associated values) has no
/// Objective-C-visible factory at all, so `PurchaselyRN.m` cannot construct
/// one directly. This `@objc` shim is the only way for that bridge to reach
/// pixel-height and any-width transitions — mirrors the Flutter iOS plugin's
/// `parseDimension`/`parseTransition`
/// (SwiftPurchaselyFlutterPlugin.swift).
@objc public class PLYTransitionFactory: NSObject {

    /// - Parameters:
    ///   - type: transition kind, already resolved by the caller (shared
    ///     `PLYTransitionType` enum, bridged fully to Objective-C).
    ///   - widthType / widthValue: `"pixel"` or `"percentage"` + raw value.
    ///     `nil` (or an unrecognized widthType, or a nil value) means "hug".
    ///   - heightType / heightValue: same shape as width, for height.
    ///   - heightPercentage: legacy 0…1 fallback, forwarded unchanged so the
    ///     back-compat `height_percentage` wire field keeps working.
    ///   - backgroundColors / dismissible: forwarded unchanged.
    @objc public static func make(type: PLYTransitionType,
                                   widthType: String?,
                                   widthValue: NSNumber?,
                                   heightType: String?,
                                   heightValue: NSNumber?,
                                   heightPercentage: NSNumber?,
                                   backgroundColors: PLYColors?,
                                   dismissible: Bool) -> PLYTransition {
        return PLYTransition(type: type,
                              height: dimension(type: heightType, value: heightValue),
                              width: dimension(type: widthType, value: widthValue),
                              heightPercentage: heightPercentage,
                              backgroundColors: backgroundColors,
                              dismissible: dismissible)
    }

    private static func dimension(type: String?, value: NSNumber?) -> PLYDimension? {
        guard let value = value else { return nil }
        switch type {
        case "pixel": return .value(Int(value.intValue))
        case "percentage": return .percentage(value.floatValue)
        default: return nil
        }
    }
}
