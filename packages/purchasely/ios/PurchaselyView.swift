//
//  NativeView.swift
//  example
//
//  Created by Chouaib Mounaime on 05/03/2024.
//

import Foundation
import Purchasely

class PurchaselyView: UIView {

  private var _view: UIView?
  // `internal` so the XCTest bundle can install a stub controller and assert
  // the containment `attachControllerToParent` declares.
  var _controller: UIViewController?
  // Tracks whether we have already driven the embedded controller through an
  // "appeared" appearance transition, so we fire it exactly once per window entry.
  private var _appeared = false
  // Identifies the `setupView` generation a preload completion belongs to, so a
  // slow completion cannot replace the paywall a newer generation installed.
  // `internal` so the XCTest bundle can drive `installPreloadedController` directly.
  var _setupGeneration = 0

  @objc var placementId: String? {
    didSet {
      setupView()
    }
  }

  @objc var presentation: NSDictionary? {
    didSet {
      setupView()
    }
  }

  /// Bridge `requestId` of a presentation the JS layer already preloaded via
  /// `request.preload()`. When set, the view reuses that loaded presentation's
  /// controller instead of loading a new one (mirrors Android / Flutter).
  @objc var requestId: String? {
    didSet {
      setupView()
    }
  }

  /// Id the JS `PLYPresentationView` component listens on for the dismiss
  /// event routed through `PURCHASELY_PRESENTATION_DISMISSED` — the bridge
  /// `requestId` when reusing a preloaded presentation (identical to
  /// `requestId` above in that case), or a component-generated id for the
  /// `presentation` prop and fresh `placementId` paths, which have no bridge
  /// `requestId` of their own.
  ///
  /// Plain stored property — NOT wired to `setupView()`. RN applies props in
  /// an unspecified order, so `viewId` may land after `placementId`/
  /// `presentation`, which already triggered `setupView()`/preload. Re-running
  /// `setupView()` here would double-preload (and double-fire
  /// `PRESENTATION_VIEWED`). Instead, the `onDismissed` closures wired in
  /// `createNativeViewController` and `getPresentationController` read
  /// `self?.viewId` lazily at dismiss time, so whatever value RN eventually
  /// settles on is the one used for routing, regardless of application order.
  @objc var viewId: String?

  override init(frame: CGRect) {
    super.init(frame: frame)
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  // Keep the embedded controller's view pinned to our bounds as Yoga resizes us.
  // Frame-based layout (matching the Flutter `NativeView` container) — NOT Auto
  // Layout against this Yoga-managed host view.
  override func layoutSubviews() {
    super.layoutSubviews()
    if let view = _view, view.frame != bounds {
      view.frame = bounds
    }
  }

  // The embedded paywall becomes visible only when this host view enters a
  // window. The RN app has been running for a while before an inline view
  // mounts, so UIKit will NOT auto-forward the appearance lifecycle to a child
  // controller added after the parent already appeared. We therefore drive a
  // balanced appearance transition here so the controller receives
  // viewWillAppear/viewDidAppear (its normal lifecycle), and we surface the
  // "viewed" signal to JS at the same point (see `updateAppearanceState`).
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      attachControllerToParent()
    }
    updateAppearanceState()
    if window == nil {
      // Balanced by `attachControllerToParent` on the next window entry, which
      // re-resolves the ancestor: RN may re-mount this view under another screen.
      detachControllerFromParent()
    }
  }

  // Ownership rule: UIKit owns appearance whenever a parent transition
  // delivers it. We drive exactly two things ourselves — the bootstrap
  // appear (below) and teardown (`detachController`). Declaring the real
  // ancestor as parent (this PR) makes UIKit's automatic appearance
  // forwarding live for the first time, so a manually-driven disappear here
  // would double up with whatever UIKit already forwarded to the child on a
  // parent transition (push/pop, tab switch, etc.) — see
  // `testNoDoubleDisappearAfterAnExternallyDeliveredDisappear`.
  //
  // ponytail: a host that leaves the window while still MOUNTED, with no
  // parent transition (no push, no pop), gets no disappear — the SDK keeps
  // the paywall "visible" until teardown, so a hidden banner's video keeps
  // playing. UIKit delivers nothing in that case and there is no API to ask
  // the parent. Fix by tracking the parent's own transitions if it ever
  // shows up in the field.
  private func updateAppearanceState() {
    guard let controller = _controller else { return }
    let inWindow = (window != nil)
    if inWindow && !_appeared {
      _appeared = true
      controller.beginAppearanceTransition(true, animated: false)
      controller.endAppearanceTransition()
      // The embedded paywall is now on screen. The iOS SDK only emits
      // PRESENTATION_VIEWED through its own full-screen display flow, so surface
      // it here for the embedded path (parity with Android, whose SDK fires it
      // for embedded views too).
      PurchaselyRN.emitEmbeddedPresentationViewed(
        forRequestId: requestId,
        placementId: placementId ?? (presentation?["placementId"] as? String))
    }
  }

  private func setupView() {
    _setupGeneration += 1

    // Clean up previous controller/view before setting up new ones.
    detachController()

    if let controller = getPresentationController(
      presentation: presentation != nil ? PurchaselyPresentation(from: presentation!) : nil,
      placementId: placementId) {
      attachController(controller)
    }
  }

  /// Install a preloaded controller into this view using the frame-based,
  /// child-VC-containment pattern proven in the Flutter `NativeView`:
  ///   • frame + autoresizingMask (resynced in `layoutSubviews`) — no Auto Layout
  ///     constraints against the Yoga host view;
  ///   • proper `addChild` / `didMove(toParent:)` containment, DEFERRED to window
  ///     entry (see `attachControllerToParent`);
  ///   • a BALANCED appearance transition driven from `updateAppearanceState`
  ///     (begin+end) on window entry — the old code called
  ///     `beginAppearanceTransition` without an `endAppearanceTransition`, so
  ///     `viewDidAppear` (and thus the SDK's `onPresented`/PRESENTATION_VIEWED)
  ///     never fired.
  private func attachController(_ controller: UIViewController) {
    _controller = controller
    let view = controller.view ?? UIView()
    _view = view

    view.frame = bounds
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(view)

    // Containment happens here only when we are ALREADY in a window (a prop set
    // after mount, or the async `preload` completion); otherwise
    // `didMoveToWindow` declares it on window entry.
    attachControllerToParent()

    updateAppearanceState()
  }

  /// Declares the embedded controller a child of the view hierarchy's real
  /// nearest ancestor controller.
  ///
  /// UIKit requires the parent declared through `addChild` to match the actual
  /// ancestor of the child's view, and raises
  /// `UIViewControllerHierarchyInconsistency` otherwise. The previous code always
  /// used the app's ROOT controller, which crashed as soon as the inline view sat
  /// inside a `RNSScreen` or a pager's `UIHostingController`.
  ///
  /// It is deferred to window entry on purpose: RN applies the props (and so runs
  /// `setupView`) BEFORE inserting the view into its real hierarchy, when the
  /// responder chain still ends at the root controller. This mirrors Android's
  /// `isAttachedToWindow` wait in `PurchaselyViewManager.createFragment`.
  func attachControllerToParent() {
    guard let controller = _controller, controller.parent == nil, window != nil else { return }
    // No fallback to the app's root controller. A host mounted outside any
    // controller-owned hierarchy has no valid parent to declare: the root
    // controller's view is not our ancestor, so naming it would rebuild the very
    // inconsistency this fix removes (and in a multi-scene app it could even name
    // another window's root). Such a host simply gets no containment — the
    // paywall still renders as a plain subview, and the appearance transition is
    // driven from `updateAppearanceState`.
    guard let parent = nearestViewController() else { return }
    parent.addChild(controller)
    controller.didMove(toParent: parent)
  }

  private func detachControllerFromParent() {
    guard let controller = _controller, controller.parent != nil else { return }
    controller.willMove(toParent: nil)
    controller.removeFromParent()
  }

  /// Nearest ancestor controller of this view, walking the responder chain
  /// (`UIView.next` is the superview, or the owning controller for a controller's
  /// root view). `internal` so the XCTest bundle can exercise it directly.
  func nearestViewController() -> UIViewController? {
    var responder: UIResponder? = next
    while let current = responder {
      if let controller = current as? UIViewController { return controller }
      responder = current.next
    }
    return nil
  }

  // Apple's documented child-removal order, so the SDK's own `viewDidDisappear`
  // sees `isMovingFromParent == true` and takes its real cleanup branch
  // (PRESENTATION_CLOSED, `presentationStrongRef = nil`,
  // `FlowsManager.onPresentationClosed`) instead of the "not a dismissal" one.
  // `willMove(toParent: nil)` FIRST is the whole point — it must run before the
  // disappear transition, not after.
  // `internal` so the XCTest bundle can drive teardown directly and assert the
  // SDK's cleanup branch is reached (same seam precedent as `attachControllerToParent`).
  func detachController() {
    if let controller = _controller, controller.parent != nil {
      controller.willMove(toParent: nil)
      controller.beginAppearanceTransition(false, animated: false)
      _view?.removeFromSuperview()
      controller.endAppearanceTransition()
      controller.removeFromParent()
    } else {
      _view?.removeFromSuperview()
    }
    _appeared = false
    _view = nil
    _controller = nil
  }

  private func getPresentationController(presentation: PurchaselyPresentation?,
                                         placementId: String?) -> UIViewController? {
      // v6 / iso Flutter: when a `requestId` is provided, reuse the presentation
      // the JS layer already preloaded (`request.preload()`) instead of loading a
      // new one. Mirrors Android's `PurchaselyModule.loadedPresentation(requestId)`.
      // Its dismissal is already routed by `preloadPresentation:`'s own wiring,
      // keyed by this same requestId — nothing left to wire here.
      if let requestId = self.requestId,
         let loaded = PurchaselyRN.loadedPresentation(forRequestId: requestId),
         let controller = loaded.controller {
          return controller
      }

      // Capture effective placement id before guard bindings are lost in the else branch.
      // When only the `presentation` prop is set (placementId prop is nil), we still need
      // the placement id to recreate the view controller on subsequent visits.
      let effectivePlacementId = placementId ?? presentation?.placementId

      // The `presentation` prop carries no bridge `requestId` (it's the raw
      // screen data JS resolved from a `preload()`), so the matching loaded
      // presentation is resolved by screen/placement identity instead — atomically
      // claimed (single-use) so a second view can't reuse the same instance.
      if let presentation = presentation,
         let presentationPlacementId = presentation.placementId,
         let matched = PurchaselyRN.takeLoadedPresentation(matchingScreenId: presentation.id,
                                                            placementId: presentationPlacementId),
         let controller = matched.controller {
          // Re-route this presentation's dismissal to the id the JS component
          // is actually listening on (it doesn't know the internal requestId
          // `preloadPresentation:` wired earlier) — `onDismissed` is a single
          // settable slot, so this replaces that wiring rather than stacking.
          // `viewId` is read lazily at dismiss time (not captured now) since RN
          // may still apply it after this method runs.
          matched.onDismissed = { [weak self] outcome in
              guard let routingId = self?.viewId else { return }
              PurchaselyRN.emitPresentationDismissed(forId: routingId, outcome: outcome)
          }
          return controller
      }

      return createNativeViewController(placementId: effectivePlacementId)
  }

  private func createNativeViewController(placementId: String?) -> UIViewController? {
    guard let placementId = placementId else { return nil }

    // v6: `Purchasely.presentationController(for:loaded:completion:)` was removed.
    // Build a presentation request, preload it, then install the controller once
    // the SDK hands it back. Preload is asynchronous, so we return nil here and
    // swap the real view in via `attachController` on completion.
    // `viewId` is read lazily at dismiss time (not captured now) since RN may
    // still apply it after this method runs.
    let generation = _setupGeneration

    let request = PLYPresentationBuilder
      .from(placementId: placementId)
      .onDismissed { [weak self] outcome in
        guard let routingId = self?.viewId else { return }
        PurchaselyRN.emitPresentationDismissed(forId: routingId, outcome: outcome)
      }
      .build()

    request.preload { [weak self] presentation, _ in
      DispatchQueue.main.async {
        guard let controller = presentation?.controller else { return }
        // ponytail: a superseded preload is dropped, not closed — the SDK exposes no
        // release for a presentation that was never displayed, and close() routes
        // through real UIKit dismiss/pop primitives. Revisit if the SDK adds one.
        self?.installPreloadedController(controller, generation: generation)
      }
    }
    return nil
  }

  /// Installs a controller handed back by an async `preload` completion, but
  /// only if no newer `setupView()` call (a prop change while the preload was
  /// in flight) has already superseded this one. `internal` so the XCTest
  /// bundle can exercise the guard without a real SDK preload.
  func installPreloadedController(_ controller: UIViewController, generation: Int) {
    guard _setupGeneration == generation else { return }
    detachController()
    attachController(controller)
  }

  /// Map a v6 `PLYPurchaseResult` to the `ProductResult` ordinal JS expects.
  /// Kept in sync with the legacy `productResult*` ordinals exported by PurchaselyRN.
  func productResultOrdinal(_ result: PLYPurchaseResult) -> Int {
    switch result {
    case .purchased: return 0
    case .cancelled: return 1
    case .restored:  return 2
    case .none:      return 1
    @unknown default: return 1
    }
  }

  deinit {
    detachController()
    // Hardening (parity with Android's `onDropViewInstance` →
    // `evictPresentationRequest`): a view that unmounts without ever
    // dismissing (e.g. the host navigates away) would otherwise leak the
    // `requestId` entry this view consumed in `kPresentationsByRequest`
    // forever — only `emitPresentationDismissed(forId:outcome:)` purged it
    // before. No-op if `requestId` was never set or was already purged by a
    // normal dismiss.
    if let requestId = requestId {
      PurchaselyRN.evictPresentationRequest(requestId)
    }
  }
}

private struct PurchaselyPresentation {
    let id: String
    let placementId: String?
    let audienceId: String?
    let abTestId: String?
    let abTestVariantId: String?
    let language: String?

  init(from data: NSDictionary) {
    self.id = data["id"] as? String ?? "--id-error--"
    self.placementId = data["placementId"] as? String
    self.audienceId = data["audienceId"] as? String
    self.abTestId = data["abTestId"] as? String
    self.abTestVariantId = data["abTestVariantId"] as? String
    self.language = data["language"] as? String
  }
}
