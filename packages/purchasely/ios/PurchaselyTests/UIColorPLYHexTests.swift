//
//  UIColorPLYHexTests.swift
//  Locks the hex-colour parser across the Objective-C → Swift port
//  (UIColor+PLYHelper.m → UIColor+PLYHex.swift). Not appended to
//  SerializationContractTests.swift: that file is a frozen gate outside
//  this task's Files list.
//

import XCTest
@testable import react_native_purchasely

final class UIColorPLYHexTests: XCTestCase {

    // MARK: - UIColor hex parsing

    func testHexParserAcceptsTheFormsTheBackendSends() {
        // Values and expectations read off UIColor+PLYHelper.m. A paywall's
        // JSON carries colours in these forms.
        // UIColor+PLYHelper.m accepts RRGGBB and RRGGBBAA, with or without a
        // leading '#', after trimming whitespace. Nothing else.
        func rgba(_ hex: String) -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
            guard let color = UIColor.ply_fromHex(hex) else { return nil }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (r, g, b, a)
        }

        for form in ["#FF0000", "FF0000", "  #FF0000  "] {
            // `guard let (a, b) = optionalTuple` does not compile; the pattern
            // needs `case let ...?`.
            guard case let (r, g, b, a)? = rgba(form) else {
                return XCTFail("'\(form)' must parse")
            }
            XCTAssertEqual(r, 1.0, accuracy: 0.01, form)
            XCTAssertEqual(g, 0.0, accuracy: 0.01, form)
            XCTAssertEqual(b, 0.0, accuracy: 0.01, form)
            XCTAssertEqual(a, 1.0, accuracy: 0.01, form)
        }

        // RRGGBBAA: the alpha byte is last.
        guard case let (_, _, _, alpha)? = rgba("#00000080") else {
            return XCTFail("8-digit form must parse")
        }
        XCTAssertEqual(alpha, 0.5, accuracy: 0.01)

        // #00000080's r/g/b are all zero, so it alone would pass even with
        // the red and blue shifts transposed. This fixture has three
        // distinct non-zero channels plus full alpha, so it catches that.
        guard case let (r8, g8, b8, a8)? = rgba("#112233FF") else {
            return XCTFail("8-digit form with distinct channels must parse")
        }
        XCTAssertEqual(r8, CGFloat(0x11) / 0xff, accuracy: 0.01)
        XCTAssertEqual(g8, CGFloat(0x22) / 0xff, accuracy: 0.01)
        XCTAssertEqual(b8, CGFloat(0x33) / 0xff, accuracy: 0.01)
        XCTAssertEqual(a8, 1.0, accuracy: 0.01)
    }

    func testHexParserRejectsGarbageInsteadOfTrapping() {
        // The Swift parameter is String?, so nil compiles and returns nil.
        XCTAssertNil(UIColor.ply_fromHex(nil))
        XCTAssertNil(UIColor.ply_fromHex(""))
        XCTAssertNil(UIColor.ply_fromHex("   "))
        XCTAssertNil(UIColor.ply_fromHex("#12"))       // too short
        XCTAssertNil(UIColor.ply_fromHex("#1234567"))  // wrong length
    }

    func testLegacyScannerSemanticsForLengthValidMalformedColours() {
        func rgba(_ hex: String) -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
            guard let color = UIColor.ply_fromHex(hex) else { return nil }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (r, g, b, a)
        }

        // NSScanner's scanHexInt result was ignored by UIColor+PLYHelper.m.
        // A malformed suffix therefore preserves the valid prefix it scanned.
        guard case let (r, g, b, a)? = rgba("FF00ZZ") else {
            return XCTFail("length-valid malformed input must retain legacy scanner output")
        }
        XCTAssertEqual(r, CGFloat(0x00) / 0xff, accuracy: 0.01)
        XCTAssertEqual(g, CGFloat(0xff) / 0xff, accuracy: 0.01)
        XCTAssertEqual(b, CGFloat(0x00) / 0xff, accuracy: 0.01)
        XCTAssertEqual(a, 1, accuracy: 0.01)

        guard case let (blackR, blackG, blackB, blackA)? = rgba("#GGGGGG") else {
            return XCTFail("an unscannable but length-valid value must produce legacy black")
        }
        XCTAssertEqual(blackR, 0, accuracy: 0.01)
        XCTAssertEqual(blackG, 0, accuracy: 0.01)
        XCTAssertEqual(blackB, 0, accuracy: 0.01)
        XCTAssertEqual(blackA, 1, accuracy: 0.01)

        // NSString length counted UTF-16 code units. A variation selector
        // combines with the preceding digit as one Swift Character, but still
        // contributes a code unit to NSScanner's length check.
        guard case let (emojiR, emojiG, emojiB, emojiA)? = rgba("#1\u{FE0F}2345") else {
            return XCTFail("a six-code-unit colour with a leading # must retain legacy length behavior")
        }
        XCTAssertEqual(emojiR, 0, accuracy: 0.01)
        XCTAssertEqual(emojiG, 0, accuracy: 0.01)
        XCTAssertEqual(emojiB, CGFloat(1) / 0xff, accuracy: 0.01)
        XCTAssertEqual(emojiA, 1, accuracy: 0.01)
    }
}
