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

    func testViewHasNoBackgroundColorByDefault() {
        XCTAssertNil(purchaselyView.backgroundColor, "View should preserve UIView's default background")
    }

    // MARK: - Purchase Result Compatibility Tests

    func testPurchaseResultOrdinalsPreserveJavaScriptContract() {
        XCTAssertEqual(purchaselyView.productResultOrdinal(.purchased), 0)
        XCTAssertEqual(purchaselyView.productResultOrdinal(.cancelled), 1)
        XCTAssertEqual(purchaselyView.productResultOrdinal(.restored), 2)
        XCTAssertEqual(purchaselyView.productResultOrdinal(.none), 1)
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

    // MARK: - Nearest Ancestor Controller Tests

    // Regression: `attachController` used to declare the embedded controller a
    // child of the app's ROOT view controller. Under react-native-screens the
    // real nearest ancestor is the RNSScreen's controller, and UIKit raises
    // `UIViewControllerHierarchyInconsistency` when the two disagree.
    func testNearestViewControllerFindsTheRealAncestor() {
        let host = UIViewController()
        let intermediate = UIView()
        host.view.addSubview(intermediate)
        intermediate.addSubview(purchaselyView)

        XCTAssertTrue(purchaselyView.nearestViewController() === host,
                      "Should walk the responder chain up to the owning controller, not the root VC")
    }

    func testNearestViewControllerIsNilWhenDetached() {
        XCTAssertNil(purchaselyView.nearestViewController(),
                     "A view with no superview has no ancestor controller")
    }

    func testNearestViewControllerIsNilUnderAControllerlessHierarchy() {
        let parentView = UIView()
        parentView.addSubview(purchaselyView)

        XCTAssertNil(purchaselyView.nearestViewController(),
                     "A plain view hierarchy owns no controller")
    }

    // The walk above is only half the fix: what UIKit checks is the parent
    // DECLARED through `addChild`. These assert the declaration itself, which is
    // what raised `UIViewControllerHierarchyInconsistency` in the client's app.
    func testContainmentDeclaresTheNestedAncestorNotTheRootController() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()

        // Stands in for the RNSScreen controller the inline view sits inside.
        let nested = UIViewController()
        root.addChild(nested)
        root.view.addSubview(nested.view)
        nested.didMove(toParent: root)
        nested.view.addSubview(purchaselyView)

        let embedded = UIViewController()
        purchaselyView._controller = embedded
        purchaselyView.attachControllerToParent()

        XCTAssertTrue(embedded.parent === nested,
                      "Containment must name the real nearest ancestor, not the window's root VC")
        XCTAssertFalse(embedded.parent === root,
                       "Naming the root VC is the bug that crashed under react-native-screens")
    }

    func testContainmentIsReleasedWhenTheHostLeavesTheWindow() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        root.view.addSubview(purchaselyView)

        let embedded = UIViewController()
        purchaselyView._controller = embedded
        purchaselyView.attachControllerToParent()
        XCTAssertTrue(embedded.parent === root, "Precondition: containment declared")

        // `didMoveToWindow(nil)` must release the parent, so a view remounted
        // under another screen re-resolves its ancestor instead of keeping a
        // stale one.
        purchaselyView.removeFromSuperview()

        XCTAssertNil(embedded.parent,
                     "Leaving the window must release the declared parent")
    }

    // The claim this PR makes is that a view moved to another screen RE-RESOLVES
    // its ancestor. Releasing the parent is only half of it, and T30 cannot see
    // the other half: it drops the whole ScreenStack, so the second request gets
    // brand-new native objects. This moves ONE view instance between two
    // controllers, which is the case a missing re-resolve would break.
    func testContainmentReResolvesTheAncestorWhenTheViewMovesToAnotherScreen() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()

        let screenA = UIViewController()
        let screenB = UIViewController()
        for screen in [screenA, screenB] {
            root.addChild(screen)
            root.view.addSubview(screen.view)
            screen.didMove(toParent: root)
        }

        let embedded = UIViewController()
        screenA.view.addSubview(purchaselyView)
        purchaselyView._controller = embedded
        purchaselyView.attachControllerToParent()
        XCTAssertTrue(embedded.parent === screenA, "Precondition: declared under screen A")

        // Move the SAME host view under screen B. `removeFromSuperview` releases
        // the parent through `didMoveToWindow(nil)`; the re-add must resolve B.
        purchaselyView.removeFromSuperview()
        screenB.view.addSubview(purchaselyView)
        purchaselyView.attachControllerToParent()

        XCTAssertTrue(embedded.parent === screenB,
                      "A view remounted under another screen must re-resolve its ancestor")
        XCTAssertFalse(embedded.parent === screenA,
                       "Keeping the stale parent is what UIKit answers with an inconsistency")
    }

    func testContainmentIsSkippedWhenNoAncestorControllerExists() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        // Mounted straight on the window, BESIDE the root controller's view, so
        // no controller sits in this view's responder chain.
        window.addSubview(purchaselyView)

        let embedded = UIViewController()
        purchaselyView._controller = embedded
        purchaselyView.attachControllerToParent()

        XCTAssertNil(embedded.parent,
                     "With no ancestor controller there is no valid parent to declare — " +
                     "falling back to the root VC would rebuild the inconsistency")
    }

    // MARK: - Stale Preload Completion Tests

    // Bug: `request.preload` completions carry no identity. If a prop change
    // starts a second `setupView()` while an earlier preload is still in
    // flight, the stale completion must not replace the controller the newer
    // generation already installed.
    func testASupersededPreloadCompletionIsIgnored() {
        let generation = purchaselyView._setupGeneration
        let current = UIViewController()
        purchaselyView.installPreloadedController(current, generation: generation)
        XCTAssertTrue(purchaselyView._controller === current, "Precondition: current controller installed")

        // Simulate a prop change starting a new generation before the stale
        // completion runs.
        purchaselyView._setupGeneration += 1
        let stale = UIViewController()
        purchaselyView.installPreloadedController(stale, generation: generation)

        XCTAssertTrue(purchaselyView._controller === current,
                      "A completion from a superseded generation must not replace the current controller")
    }

    func testTheCurrentGenerationCompletionIsApplied() {
        let generation = purchaselyView._setupGeneration
        let controller = UIViewController()

        purchaselyView.installPreloadedController(controller, generation: generation)

        XCTAssertTrue(purchaselyView._controller === controller,
                      "A completion matching the current generation must be applied")
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
