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
        XCTAssertNil(UIColor.ply_fromHex("#1234567"))  // 7 digits
        // Behaviour change: the Objective-C version ignored the scanner
        // result and returned opaque black here. See the Task 4 commit.
        XCTAssertNil(UIColor.ply_fromHex("#GGGGGG"))   // 6 chars, not hex

        // UInt32(_:radix:) accepts a leading sign, which the Objective-C
        // NSScanner-based parser did not. The Objective-C version did NOT
        // reject "+12345" either — it fed the sign-stripped scan result
        // through regardless and produced opaque black. Rejecting it here
        // is the Swift version deliberately being STRICTER than the
        // Objective-C one, not matching it.
        //
        // This divergence IS client-reachable, for "+12345" and for every
        // other malformed input this parser now rejects. The sole caller is
        // `plyTransitionFromMap` (PurchaselyRN.m:334-335), which reads
        // `map["backgroundColors"]["light"/"dark"]` out of the `transition`
        // dictionary a JS caller passes to `displayPresentation` /
        // `preloadPresentation` — not backend paywall JSON. The Objective-C
        // NSScanner-based parser returned a colour (often opaque black) for
        // malformed input such as "FF00ZZ", "0xFFFF" or "FF 000", where
        // `UInt32(_:radix:)` returns nil; the guard here exists to make that
        // divergence UNIFORM and predictable across all such input, not to
        // hide it.
        XCTAssertNil(UIColor.ply_fromHex("+12345"))
    }
}
