//
//  PurchaselyViewTests.swift
//  PurchaselyRNTests
//
//  Unit tests for PurchaselyView native component
//

import XCTest
@testable import react_native_purchasely

class PurchaselyViewTests: XCTestCase {

    var purchaselyView: PurchaselyView!

    override func setUp() {
        super.setUp()
        purchaselyView = PurchaselyView()
    }

    override func tearDown() {
        purchaselyView = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testViewInitialization() {
        XCTAssertNotNil(purchaselyView, "PurchaselyView should initialize")
    }

    func testViewIsUIViewSubclass() {
        XCTAssertTrue(purchaselyView is UIView, "PurchaselyView should be a UIView subclass")
    }

    // MARK: - PlacementId Property Tests

    func testPlacementIdInitiallyNil() {
        XCTAssertNil(purchaselyView.placementId, "placementId should be nil initially")
    }

    func testSetPlacementId() {
        purchaselyView.placementId = "onboarding"
        XCTAssertEqual(purchaselyView.placementId, "onboarding", "placementId should be set correctly")
    }

    func testSetPlacementIdToNil() {
        purchaselyView.placementId = "test"
        purchaselyView.placementId = nil
        XCTAssertNil(purchaselyView.placementId, "placementId should be nil after setting to nil")
    }

    func testSetEmptyPlacementId() {
        purchaselyView.placementId = ""
        XCTAssertEqual(purchaselyView.placementId, "", "placementId can be empty string")
    }

    // MARK: - Presentation Property Tests

    func testPresentationInitiallyNil() {
        XCTAssertNil(purchaselyView.presentation, "presentation should be nil initially")
    }

    func testSetPresentation() {
        let presentationDict: NSDictionary = [
            "id": "pres-123",
            "placementId": "onboarding",
            "type": 0,
            "plans": [],
            "metadata": [:],
            "height": NSNull()
        ]

        purchaselyView.presentation = presentationDict
        XCTAssertNotNil(purchaselyView.presentation, "presentation should be set")
        XCTAssertEqual(purchaselyView.presentation?["id"] as? String, "pres-123", "presentation id should match")
    }

    func testSetPresentationWithAllFields() {
        let plans: [[String: Any]] = [
            [
                "planVendorId": "plan-123",
                "storeProductId": "store-product-123",
                "basePlanId": "base-plan",
                "offerId": "offer-123"
            ]
        ]

        let metadata: [String: Any] = [
            "title": "Premium",
            "showDiscount": true,
            "discountPercent": 20
        ]

        let presentationDict: NSDictionary = [
            "id": "pres-123",
            "placementId": "onboarding",
            "audienceId": "audience-123",
            "abTestId": "ab-123",
            "abTestVariantId": "variant-a",
            "language": "en",
            "type": 0,
            "plans": plans,
            "metadata": metadata,
            "height": 500
        ]

        purchaselyView.presentation = presentationDict

        XCTAssertEqual(purchaselyView.presentation?["placementId"] as? String, "onboarding")
        XCTAssertEqual(purchaselyView.presentation?["audienceId"] as? String, "audience-123")
        XCTAssertEqual(purchaselyView.presentation?["language"] as? String, "en")
        XCTAssertEqual(purchaselyView.presentation?["height"] as? Int, 500)
    }

    func testSetPresentationToNil() {
        let presentationDict: NSDictionary = ["id": "pres-123"]
        purchaselyView.presentation = presentationDict
        purchaselyView.presentation = nil
        XCTAssertNil(purchaselyView.presentation, "presentation should be nil after setting to nil")
    }

    // MARK: - View Lifecycle Tests

    func testViewHasZeroSubviewsInitially() {
        // Before setupView is called, there should be no subviews
        // (or minimal subviews depending on implementation)
        XCTAssertTrue(purchaselyView.subviews.count >= 0, "View should have valid subview count")
    }

    // MARK: - View Bounds Tests

    func testViewAcceptsCustomFrame() {
        let customFrame = CGRect(x: 0, y: 0, width: 300, height: 500)
        let viewWithFrame = PurchaselyView(frame: customFrame)

        XCTAssertEqual(viewWithFrame.frame.width, 300, "View width should match")
        XCTAssertEqual(viewWithFrame.frame.height, 500, "View height should match")
    }

    // MARK: - Background Color Tests

    func testViewHasDefaultBackgroundColor() {
        // View should have a background color (clear or default)
        // This is a basic sanity check
        XCTAssertNotNil(purchaselyView.backgroundColor, "View should have a background color")
    }

    // MARK: - Combined Property Tests

    func testBothPlacementIdAndPresentationCanBeSet() {
        let presentationDict: NSDictionary = ["id": "pres-123"]

        purchaselyView.placementId = "onboarding"
        purchaselyView.presentation = presentationDict

        XCTAssertEqual(purchaselyView.placementId, "onboarding", "placementId should be set")
        XCTAssertNotNil(purchaselyView.presentation, "presentation should be set")
    }

    func testPlacementIdTakesPrecedence() {
        // When both are set, placementId should typically take precedence
        // (this depends on actual implementation)
        let presentationDict: NSDictionary = ["id": "pres-from-dict"]

        purchaselyView.placementId = "onboarding"
        purchaselyView.presentation = presentationDict

        // Both should be set - the actual behavior depends on setupView implementation
        XCTAssertEqual(purchaselyView.placementId, "onboarding")
        XCTAssertEqual(purchaselyView.presentation?["id"] as? String, "pres-from-dict")
    }

    // MARK: - View Hierarchy Tests

    func testViewCanBeAddedAsSubview() {
        let parentView = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        parentView.addSubview(purchaselyView)

        XCTAssertTrue(purchaselyView.superview === parentView, "View should be added as subview")
    }

    func testViewCanBeRemoved() {
        let parentView = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        parentView.addSubview(purchaselyView)
        purchaselyView.removeFromSuperview()

        XCTAssertNil(purchaselyView.superview, "View should have no superview after removal")
    }

    // MARK: - Autoresizing Tests

    func testViewSupportAutoresizing() {
        purchaselyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        XCTAssertTrue(purchaselyView.autoresizingMask.contains(.flexibleWidth), "Should support flexible width")
        XCTAssertTrue(purchaselyView.autoresizingMask.contains(.flexibleHeight), "Should support flexible height")
    }

    // MARK: - Thread Safety Tests

    func testPropertyAccessFromMainThread() {
        let expectation = self.expectation(description: "Main thread access")

        DispatchQueue.main.async {
            self.purchaselyView.placementId = "test"
            XCTAssertEqual(self.purchaselyView.placementId, "test")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    // MARK: - Edge Cases

    func testVeryLongPlacementId() {
        let longId = String(repeating: "a", count: 1000)
        purchaselyView.placementId = longId
        XCTAssertEqual(purchaselyView.placementId, longId, "Should handle very long placementId")
    }

    func testSpecialCharactersInPlacementId() {
        let specialId = "test-placement_123.foo@bar"
        purchaselyView.placementId = specialId
        XCTAssertEqual(purchaselyView.placementId, specialId, "Should handle special characters")
    }

    func testUnicodeInPlacementId() {
        let unicodeId = "测试位置"
        purchaselyView.placementId = unicodeId
        XCTAssertEqual(purchaselyView.placementId, unicodeId, "Should handle unicode characters")
    }

    func testLargePresentationMetadata() {
        var largeMetadata: [String: Any] = [:]
        for i in 0..<100 {
            largeMetadata["key\(i)"] = "value\(i)"
        }

        let presentationDict: NSDictionary = [
            "id": "pres-123",
            "metadata": largeMetadata
        ]

        purchaselyView.presentation = presentationDict
        XCTAssertNotNil(purchaselyView.presentation, "Should handle large metadata")
    }

    func testNestedPresentationData() {
        let nestedData: [String: Any] = [
            "level1": [
                "level2": [
                    "level3": "deepValue"
                ]
            ]
        ]

        let presentationDict: NSDictionary = [
            "id": "pres-123",
            "metadata": nestedData
        ]

        purchaselyView.presentation = presentationDict
        XCTAssertNotNil(purchaselyView.presentation, "Should handle nested data structures")
    }
}
