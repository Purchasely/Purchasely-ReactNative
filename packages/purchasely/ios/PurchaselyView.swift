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
  // `_controller`, `_setupGeneration`, `attachControllerToParent`,
  // `nearestViewController`, `detachController` and `installPreloadedController`
  // are `internal` purely as XCTest seams.
  var _controller: UIViewController?
  // We drove the controller through an "appeared" transition; one per window entry.
  private var _appeared = false
  // Bumped by every `setupView()`, so a slow preload completion can tell it has
  // been superseded. See `installPreloadedController`.
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

  /// Id the JS component listens on for the dismiss event.
  ///
  /// Deliberately NOT wired to `setupView()`: RN applies props in any order, so
  /// re-running setup here would double-preload. The `onDismissed` closures read
  /// it lazily at dismiss time instead, so late application still routes right.
  @objc var viewId: String?

  override init(frame: CGRect) {
    super.init(frame: frame)
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  // Frame-based, not Auto Layout: the host view is Yoga-managed.
  override func layoutSubviews() {
    super.layoutSubviews()
    if let view = _view, view.frame != bounds {
      view.frame = bounds
    }
  }

  // UIKit does not forward appearance to a child added after its parent already
  // appeared, which is always the case for an inline view in a running RN app —
  // so we drive the transition ourselves around window entry and exit.
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      attachControllerToParent()
    }
    updateAppearanceState()
    if window == nil {
      // A window exit may be transient (a pager recycling this row), so keep the
      // disappear PLAIN — no `willMove(toParent: nil)`. That call sends the SDK
      // into its dismissal branch, which fires PRESENTATION_CLOSED and
      // `onDismissed` into client JS for a paywall that is still mounted.
      // Guarded on `_appeared` only: a controller that never got containment
      // still needs its disappear.
      //
      // ponytail: if UIKit already forwarded a disappear via a parent transition
      // we cannot tell, so this delivers a second one. The SDK's
      // `viewWillDisappear` work is idempotent, so it is tolerated.
      if let controller = _controller, _appeared {
        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()
        _appeared = false
      }
      // Released so the next window entry re-resolves the ancestor — RN may
      // remount this view under a different screen.
      detachControllerFromParent()
    }
  }

  // Drives the bootstrap appear only. Disappears are driven by `didMoveToWindow`
  // (window exit) and `detachController` (teardown).
  private func updateAppearanceState() {
    guard let controller = _controller else { return }
    let inWindow = (window != nil)
    if inWindow && !_appeared {
      _appeared = true
      controller.beginAppearanceTransition(true, animated: false)
      controller.endAppearanceTransition()
      // The iOS SDK emits PRESENTATION_VIEWED only through its full-screen flow,
      // so the embedded path surfaces it here (Android's SDK does it natively).
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

  /// Installs a controller: frame-based layout, containment deferred to window
  /// entry, and a balanced appearance transition. Mirrors Flutter's `NativeView`.
  private func attachController(_ controller: UIViewController) {
    _controller = controller
    let view = controller.view ?? UIView()
    _view = view

    view.frame = bounds
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(view)

    // No-op unless we are already in a window; otherwise `didMoveToWindow` does it.
    attachControllerToParent()

    updateAppearanceState()
  }

  /// Declares the controller a child of our REAL nearest ancestor controller.
  ///
  /// UIKit raises `UIViewControllerHierarchyInconsistency` when the parent named
  /// through `addChild` is not the actual ancestor. Naming the app's root
  /// controller crashed any inline paywall inside an `RNSScreen` or a pager.
  ///
  /// Deferred to window entry because RN applies props — and so runs
  /// `setupView` — before inserting the view, when the responder chain still
  /// ends at the root. Android waits on `isAttachedToWindow` for the same reason.
  func attachControllerToParent() {
    guard let controller = _controller, controller.parent == nil, window != nil else { return }
    // No root-controller fallback: naming a non-ancestor is the crash above. A
    // host with no ancestor controller gets no containment and renders anyway.
    guard let parent = nearestViewController() else { return }
    parent.addChild(controller)
    controller.didMove(toParent: parent)
  }

  private func detachControllerFromParent() {
    guard let controller = _controller, controller.parent != nil else { return }
    controller.willMove(toParent: nil)
    controller.removeFromParent()
  }

  /// Walks the responder chain: `UIView.next` is the superview, or the owning
  /// controller when the view is a controller's root view.
  func nearestViewController() -> UIViewController? {
    var responder: UIResponder? = next
    while let current = responder {
      if let controller = current as? UIViewController { return controller }
      responder = current.next
    }
    return nil
  }

  /// Teardown: a prop change or preload swap replacing this controller, or
  /// `deinit`. The disappear is PLAIN — `willMove(toParent: nil)` comes after the
  /// transition, so the SDK does NOT take its dismissal branch.
  ///
  /// That is a trade-off, not an oversight. Driving `willMove` first would nil
  /// the SDK's `presentationStrongRef` (no leak) but also emit
  /// PRESENTATION_CLOSED and `onDismissed` — spurious for a banner that is being
  /// reconfigured, and a visible step change in every integrator's analytics.
  ///
  /// ponytail: so we keep `main`'s leak of one retained presentation per
  /// in-window swap. The real fix is an SDK-side silent release; until then,
  /// remounting the view (`key=`) instead of swapping `placementId` avoids it.
  func detachController() {
    if let controller = _controller, controller.parent != nil {
      controller.beginAppearanceTransition(false, animated: false)
      _view?.removeFromSuperview()
      controller.endAppearanceTransition()
      detachControllerFromParent()
    } else if let controller = _controller, _appeared {
      controller.beginAppearanceTransition(false, animated: false)
      controller.endAppearanceTransition()
      _view?.removeFromSuperview()
    } else {
      _view?.removeFromSuperview()
    }
    _appeared = false
    _view = nil
    _controller = nil
  }

  private func getPresentationController(presentation: PurchaselyPresentation?,
                                         placementId: String?) -> UIViewController? {
      // A `requestId` means JS already preloaded this presentation: reuse it.
      // Its dismissal is already routed by `preloadPresentation:`.
      if let requestId = self.requestId,
         let loaded = PurchaselyRN.loadedPresentation(forRequestId: requestId),
         let controller = loaded.controller {
          return controller
      }

      // Needed to recreate the controller later when only `presentation` is set.
      let effectivePlacementId = placementId ?? presentation?.placementId

      // The `presentation` prop carries no `requestId`, so match the loaded
      // presentation by screen/placement identity — claimed atomically so two
      // views cannot share one instance.
      if let presentation = presentation,
         let presentationPlacementId = presentation.placementId,
         let matched = PurchaselyRN.takeLoadedPresentation(matchingScreenId: presentation.id,
                                                            placementId: presentationPlacementId),
         let controller = matched.controller {
          // Re-route the dismissal to the id JS actually listens on. `onDismissed`
          // is one slot, so this replaces the earlier wiring. `viewId` is read
          // lazily because RN may still apply it after this runs.
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

    // Preload is async, so return nil now and install the controller in the
    // completion. The generation captured here is what makes a stale completion
    // detectable — see `installPreloadedController`.
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
        // ponytail: a superseded preload is dropped, not released — the SDK has no
        // release for a presentation that was never displayed.
        self?.installPreloadedController(controller, generation: generation)
      }
    }
    return nil
  }

  /// Installs a preloaded controller unless a newer `setupView()` has superseded
  /// it — otherwise a slow preload would replace the paywall the props now name.
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
    // A view that unmounts without ever dismissing would otherwise leak its
    // `kPresentationsByRequest` entry. Parity with Android's `onDropViewInstance`.
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
