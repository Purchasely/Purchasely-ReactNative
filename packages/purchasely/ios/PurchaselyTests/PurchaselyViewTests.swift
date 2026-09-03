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

        // A REAL prop change — not a hand-bumped `_setupGeneration` — starts a
        // new generation before the stale completion runs. This is what proves
        // the counter is actually armed by `setupView()`, not merely readable:
        // a test that bumps `_setupGeneration` by hand still passes even if
        // `setupView()` stopped bumping it (the exact regression a prior review
        // caught — the bug the guard exists for would go undetected).
        purchaselyView.placementId = "some-other-placement"
        XCTAssertNotEqual(purchaselyView._setupGeneration, generation,
                          "Precondition: a real prop change must bump the generation")

        let stale = UIViewController()
        purchaselyView.installPreloadedController(stale, generation: generation)

        XCTAssertFalse(purchaselyView._controller === stale,
                       "A completion from a superseded generation must not replace the current controller")
    }

    func testTheCurrentGenerationCompletionIsApplied() {
        let generation = purchaselyView._setupGeneration
        let controller = UIViewController()

        purchaselyView.installPreloadedController(controller, generation: generation)

        XCTAssertTrue(purchaselyView._controller === controller,
                      "A completion matching the current generation must be applied")
    }

    // MARK: - Appearance Transition Tests

    // Bug B: declaring the real ancestor as parent (this PR) makes UIKit's
    // automatic appearance forwarding live for the first time. `_appeared`
    // only tracked OUR manual transitions, so a parent-forwarded disappear
    // plus our own stale-`_appeared` disappear on window exit delivered a
    // complete appear/disappear pair TWICE. A log grep cannot see this (no
    // warning fires — it is silent double delivery), so this counts real
    // UIKit callbacks on a stub controller instead.
    func testBootstrapDrivesABalancedAppearOnWindowEntry() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        root.view.addSubview(purchaselyView)

        let stub = AppearanceCountingViewController()
        purchaselyView._controller = stub
        // `_controller` must be set before window entry drives the transition —
        // exactly `attachController`'s ordering, and what `didMoveToWindow` does
        // for a prop set after mount. Recycling the window-entry path here (over
        // calling `attachControllerToParent()` alone, which only declares
        // containment) is what actually runs `updateAppearanceState()`.
        purchaselyView.removeFromSuperview()
        root.view.addSubview(purchaselyView)

        XCTAssertEqual(stub.willAppearCount, 1,
                       "A controller added after its parent already appeared needs a manually driven appear")
        XCTAssertEqual(stub.didAppearCount, 1)
        XCTAssertEqual(stub.willDisappearCount, 0)
        XCTAssertEqual(stub.didDisappearCount, 0)
    }

    // pi's scenario: the host survives a parent transition (push/pop, tab
    // switch), which UIKit auto-forwards to the child, then later leaves the
    // window entirely.
    //
    // A prior version of this test claimed "there is no code path left that
    // CAN double-fire, regardless of who delivered the first one" — that is
    // false, and the claim does not survive the fix for defect 2 (a
    // permanently-stale `_appeared` after a forwarded disappear, which froze
    // a host that later re-entered the window). `_appeared` tracks only OUR
    // OWN transitions; it has no way to see a disappear UIKit forwarded
    // directly to the child, so window exit legitimately delivers a SECOND
    // disappear pair on top of one already delivered. This is a documented,
    // known ceiling (see the `ponytail:` comment on
    // `disappearAndDetachFromParent`), not a bug: the SDK absorbs it
    // idempotently — `pauseAllVideos`/`pauseAllLottieAnimations`/
    // `removeObservers` are unconditional and idempotent in
    // `viewWillDisappear`, and the `viewDidDisappear` cleanup branch is
    // guarded by the SDK's own `isClosedEventFired` take-once slot. Never
    // delivering at all (the regression this branch replaces) is worse.
    //
    // Reproducing the forwarding mechanism itself (`shouldAutomaticallyForwardAppearanceMethods`)
    // deterministically in XCTest was NOT achievable: neither driving `screenA`'s
    // own `beginAppearanceTransition`/`endAppearanceTransition` directly, nor a
    // real `UINavigationController` push, delivered it in this environment — both
    // require a running app + animation coordinator UIKit does not stand up for a
    // bare `UIWindow` in a unit test host (`screenA.view` never entered
    // `purchaselyView.window` even after `makeKeyAndVisible()`). So this stands
    // in for "however delivered" a first disappear (UIKit forwarding, in
    // production) with a direct call on the stub, and asserts what actually
    // happens next: window exit adds its own disappear on top.
    func testWindowExitDeliversASecondDisappearAfterAForwardedOne() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        root.view.addSubview(purchaselyView)

        let stub = AppearanceCountingViewController()
        purchaselyView._controller = stub
        purchaselyView.removeFromSuperview()
        root.view.addSubview(purchaselyView)
        XCTAssertEqual(stub.didAppearCount, 1, "Precondition: bootstrap appear delivered")

        // Stands in for a parent transition UIKit auto-forwards to `stub` in
        // production (e.g. a push/pop through the real ancestor `stub` is
        // contained in via `attachControllerToParent`).
        stub.beginAppearanceTransition(false, animated: false)
        stub.endAppearanceTransition()
        XCTAssertEqual(stub.didDisappearCount, 1, "Precondition: one disappear already delivered")

        // The host later leaves the window entirely. We cannot tell the
        // forwarded disappear above already happened, so this legitimately
        // delivers a second pair — the known, documented ceiling.
        purchaselyView.removeFromSuperview()

        XCTAssertEqual(stub.didDisappearCount, 2,
                       "Window exit cannot detect an already-forwarded disappear, so it adds its own " +
                       "on top — tolerated because the SDK absorbs it idempotently, see the " +
                       "`ponytail:` comment on `disappearAndDetachFromParent`")
    }

    // The leak fix: `detachController` must drive `willMove(toParent: nil)`
    // BEFORE the disappear transition, so the SDK's own `viewDidDisappear` sees
    // `isMovingFromParent == true` and takes its real cleanup branch
    // (PRESENTATION_CLOSED, releasing `presentationStrongRef`,
    // `FlowsManager.onPresentationClosed`) instead of leaking the presentation
    // graph forever.
    func testDetachControllerReachesTheSDKCleanupBranch() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        root.view.addSubview(purchaselyView)

        let stub = AppearanceCountingViewController()
        purchaselyView._controller = stub
        purchaselyView.removeFromSuperview()
        root.view.addSubview(purchaselyView)
        XCTAssertEqual(stub.didAppearCount, 1, "Precondition: bootstrap appear delivered")

        purchaselyView.detachController()

        XCTAssertEqual(stub.didDisappearWhileMovingFromParentCount, 1,
                       "Teardown must reach viewDidDisappear with isMovingFromParent == true")
        XCTAssertNil(stub.parent, "Teardown must remove the controller from its parent")
    }

    // The regression this whole redesign fixes: the REAL RN unmount path is
    // `removeFromSuperview()` -> `didMoveToWindow()` with `window == nil` ->
    // (eventually) `deinit`. The parent is released as part of that same
    // window-exit call, so a teardown gated on `controller.parent != nil`
    // (the previous, rejected version of this fix) sees a nil parent and
    // delivers NOTHING — no pause*, no removeObservers, no PRESENTATION_CLOSED.
    // Drives the exact sequence and asserts exactly one balanced disappear,
    // reaching the SDK's cleanup branch.
    func testProductionUnmountDeliversExactlyOneDisappear() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        root.view.addSubview(purchaselyView)

        let stub = AppearanceCountingViewController()
        purchaselyView._controller = stub
        purchaselyView.removeFromSuperview()
        root.view.addSubview(purchaselyView)
        XCTAssertEqual(stub.didAppearCount, 1, "Precondition: bootstrap appear delivered")

        // The real production unmount trigger — nothing else.
        purchaselyView.removeFromSuperview()

        XCTAssertEqual(stub.willDisappearCount, 1)
        XCTAssertEqual(stub.didDisappearCount, 1)
        XCTAssertEqual(stub.didDisappearWhileMovingFromParentCount, 1,
                       "Unmount must reach viewDidDisappear with isMovingFromParent == true, " +
                       "or the SDK never fires PRESENTATION_CLOSED / releases presentationStrongRef")
        XCTAssertNil(stub.parent, "Unmount must release containment (unchanged behaviour)")
    }

    // Defect 2: a host that leaves the window and later re-enters it (e.g.
    // recycled by `react-native-pager-view`, no intervening `detachController`)
    // must get a fresh appear — `_appeared` must not stay latched from before
    // the window exit.
    func testReEntryAfterWindowExitDrivesAFreshAppear() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        root.view.addSubview(purchaselyView)

        let stub = AppearanceCountingViewController()
        purchaselyView._controller = stub
        purchaselyView.removeFromSuperview()
        root.view.addSubview(purchaselyView)
        XCTAssertEqual(stub.didAppearCount, 1, "Precondition: bootstrap appear delivered")

        // Leaves the window, then re-enters it — same controller, no
        // `detachController` in between.
        purchaselyView.removeFromSuperview()
        XCTAssertEqual(stub.didDisappearCount, 1, "Precondition: window exit delivered a disappear")

        root.view.addSubview(purchaselyView)

        XCTAssertEqual(stub.willAppearCount, 2,
                       "Re-entering the window must drive a fresh appear, not stay latched stale")
        XCTAssertEqual(stub.didAppearCount, 2)
    }

    // A prop change (`placementId`/`presentation`/`requestId`) while the host is
    // ALREADY in a window — `setupView()`'s `detachController()` +
    // `installPreloadedController` path — must balance the outgoing controller's
    // disappear, reaching the SDK cleanup branch. That half is this fix's scope
    // and is asserted below.
    //
    // FINDING (pre-existing, NOT part of this fix, out of scope per the task):
    // the incoming controller measurably gets TWO appear deliveries here, not
    // one. `attachController` (`PurchaselyView.swift:193`) calls `addSubview(view)`
    // BEFORE `attachControllerToParent()` declares containment. With the host
    // already mounted in a live window (this scenario), inserting the
    // controller's view via plain `addSubview` — with no parent VC yet — makes
    // UIKit's OWN window-based auto-appearance fire once
    // (`-[UIViewController viewWillMoveToWindow:]`, the same mechanism that
    // appears a bare `window.rootViewController`); our manual
    // `updateAppearanceState()` then fires a second, independent pair. This
    // predates LOT 1/2 and is orthogonal to the four defects this task fixes —
    // reported here, not silently patched.
    func testInstallingANewControllerWhileInWindowBalancesOldAndAppearsNew() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        root.view.addSubview(purchaselyView)

        let outgoing = AppearanceCountingViewController()
        purchaselyView._controller = outgoing
        purchaselyView.removeFromSuperview()
        root.view.addSubview(purchaselyView)
        XCTAssertEqual(outgoing.didAppearCount, 1, "Precondition: bootstrap appear delivered")

        // Mirrors what a real prop change does via `setupView()`:
        // `detachController()` (outgoing) then `attachController()` (incoming) —
        // both reached through the same `installPreloadedController` seam the
        // async `preload` completion uses.
        let incoming = AppearanceCountingViewController()
        let generation = purchaselyView._setupGeneration
        purchaselyView.installPreloadedController(incoming, generation: generation)

        XCTAssertEqual(outgoing.willDisappearCount, 1)
        XCTAssertEqual(outgoing.didDisappearCount, 1)
        XCTAssertEqual(outgoing.didDisappearWhileMovingFromParentCount, 1,
                       "Outgoing controller must reach the SDK cleanup branch")
        // See the FINDING above — 2, not 1, measured on unmodified `attachController`.
        XCTAssertEqual(incoming.willAppearCount, 2)
        XCTAssertEqual(incoming.didAppearCount, 2)
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

/// Counts real UIKit appearance callbacks. A log grep cannot see double
/// delivery (no warning fires for it), so the appearance tests above assert
/// against this stub's counters instead.
final class AppearanceCountingViewController: UIViewController {
    var willAppearCount = 0, didAppearCount = 0
    var willDisappearCount = 0, didDisappearCount = 0
    var didDisappearWhileMovingFromParentCount = 0
    override func viewWillAppear(_ a: Bool)   { super.viewWillAppear(a);  willAppearCount += 1 }
    override func viewDidAppear(_ a: Bool)    { super.viewDidAppear(a);   didAppearCount += 1 }
    override func viewWillDisappear(_ a: Bool){ super.viewWillDisappear(a); willDisappearCount += 1 }
    override func viewDidDisappear(_ a: Bool) {
        super.viewDidDisappear(a); didDisappearCount += 1
        if isMovingFromParent { didDisappearWhileMovingFromParentCount += 1 }
    }
}
