//
//  UIColor+PLYHex.swift
//  Ported from UIColor+PLYHelper.m. Parses the colour forms a paywall's
//  backend JSON carries.
//
//  `@objc public` was temporary, UNLIKE PLYPlan+Bridge.swift and
//  PLYProduct+Bridge.swift, whose `@objc` is permanent because
//  PLYSubscription+Hybrid.m (permanent per amendment A2) reaches them through
//  a hand-written forward declaration. Nothing under Hybrid/ calls
//  `ply_fromHex`, and PurchaselyRN+Presentations.swift's call is Swift-to-
//  Swift since Task 14 — reduced to `internal`.
//

import UIKit

extension UIColor {

    /// Returns nil for any string it cannot parse. Never traps: the input is
    /// backend data, not a local constant.
    static func ply_fromHex(_ hex: String?) -> UIColor? {
        guard var string = hex?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else { return nil }

        let nsString = string as NSString
        if nsString.length > 0, nsString.character(at: 0) == 0x23 {
            string = nsString.substring(from: 1)
        }
        // UIColor+PLYHelper.m accepts RRGGBB and RRGGBBAA only. It does NOT
        // accept the 3-digit short form — do not add it here, that would be a
        // behaviour change dressed up as a port.
        //
        let length = (string as NSString).length
        guard length == 6 || length == 8 else { return nil }

        // Match UIColor+PLYHelper.m, which ignored scanHexInt's return value.
        // Length-valid malformed input remains accepted with whatever numeric
        // prefix NSScanner managed to parse (or zero if it parsed nothing).
        var code: UInt32 = 0
        Scanner(string: string).scanHexInt32(&code)
        func channel(_ shift: UInt32) -> CGFloat {
            CGFloat((code >> shift) & 0xff) / 0xff
        }

        if length == 6 {
            return UIColor(red: channel(16), green: channel(8), blue: channel(0), alpha: 1.0)
        }
        return UIColor(red: channel(24), green: channel(16), blue: channel(8), alpha: channel(0))
    }
}
