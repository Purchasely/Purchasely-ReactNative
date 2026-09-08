//
//  UIColor+PLYHex.swift
//  Ported from UIColor+PLYHelper.m. Parses the colour forms a paywall's
//  backend JSON carries. `@objc public` is temporary — see PLYPlan+Bridge.swift.
//

import UIKit

@objc public extension UIColor {

    /// Returns nil for any string it cannot parse. Never traps: the input is
    /// backend data, not a local constant.
    @objc(ply_fromHex:)
    static func ply_fromHex(_ hex: String?) -> UIColor? {
        guard var string = hex?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else { return nil }

        if string.hasPrefix("#") {
            string.removeFirst()
        }
        // UIColor+PLYHelper.m accepts RRGGBB and RRGGBBAA only. It does NOT
        // accept the 3-digit short form — do not add it here, that would be a
        // behaviour change dressed up as a port.
        guard string.count == 6 || string.count == 8,
              let code = UInt32(string, radix: 16) else { return nil }

        // The Objective-C version used NSScanner and ignored its result, so a
        // string such as "GGGGGG" scanned to 0 and produced opaque black.
        // UInt32(_:radix:) returns nil instead, which is strictly better and
        // the reason testHexParserRejectsGarbageInsteadOfTrapping exists.
        func channel(_ shift: UInt32) -> CGFloat {
            CGFloat((code >> shift) & 0xff) / 0xff
        }

        if string.count == 6 {
            return UIColor(red: channel(16), green: channel(8), blue: channel(0), alpha: 1.0)
        }
        return UIColor(red: channel(24), green: channel(16), blue: channel(8), alpha: channel(0))
    }
}
