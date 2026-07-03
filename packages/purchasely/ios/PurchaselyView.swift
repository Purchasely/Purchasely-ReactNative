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
  private var _controller: UIViewController?
  // Tracks whether we have already driven the embedded controller through an
  // "appeared" appearance transition, so we fire it exactly once per window entry.
  private var _appeared = false

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

  var onPresentationClosedPromise: RCTPromiseResolveBlock?

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
    updateAppearanceState()
  }

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
    } else if !inWindow && _appeared {
      _appeared = false
      controller.beginAppearanceTransition(false, animated: false)
      controller.endAppearanceTransition()
    }
  }

  private func setupView() {
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
  ///   • proper `addChild` / `didMove(toParent:)` containment;
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

    if let rootVC = PurchaselyView.findRootViewController() {
      rootVC.addChild(controller)
      controller.didMove(toParent: rootVC)
    }

    // If we are already in a window (prop set after mount), drive the appearance
    // transition now; otherwise `didMoveToWindow` will drive it on window entry.
    updateAppearanceState()
  }

  private func detachController() {
    if let controller = _controller {
      // Balance any appearance transition we drove so UIKit does not leave the
      // controller in an "appeared" limbo before it is torn down.
      if _appeared {
        _appeared = false
        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()
      }
      if controller.parent != nil {
        controller.willMove(toParent: nil)
        controller.removeFromParent()
      }
    }
    _appeared = false
    _view?.removeFromSuperview()
    _view = nil
    _controller = nil
  }

  /// Locates the host view controller, preferring the active scene's key window
  /// (iOS 13+ multi-scene apps) and falling back to the app delegate's window.
  /// Mirrors the Flutter `NativeView.findRootViewController()`.
  private static func findRootViewController() -> UIViewController? {
    if let windowScene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
       let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
      return rootVC
    }
    return UIApplication.shared.delegate?.window??.rootViewController
  }

  private func getPresentationController(presentation: PurchaselyPresentation?,
                                         placementId: String?) -> UIViewController? {
      // v6 / iso Flutter: when a `requestId` is provided, reuse the presentation
      // the JS layer already preloaded (`request.preload()`) instead of loading a
      // new one. Mirrors Android's `PurchaselyModule.loadedPresentation(requestId)`.
      if let requestId = self.requestId,
         let loaded = PurchaselyRN.loadedPresentation(forRequestId: requestId),
         let controller = loaded.controller {
          PurchaselyRN.purchaseResolve = { [weak self] result in
              self?.onPresentationClosedPromise?(result)
          }
          return controller
      }

      // Capture effective placement id before guard bindings are lost in the else branch.
      // When only the `presentation` prop is set (placementId prop is nil), we still need
      // the placement id to recreate the view controller on subsequent visits.
      let effectivePlacementId = placementId ?? presentation?.placementId

      guard let presentation = presentation,
              let presentationPlacementId = presentation.placementId,
              let loadedPresentations = PurchaselyRN.presentationsLoaded as? [PLYPresentation],
              let presentationLoaded = loadedPresentations.filter({ $0.id == presentation.id && $0.placementId == presentationPlacementId }).first,
              let presentationLoadedController = presentationLoaded.controller else {
          return self.createNativeViewController(placementId: effectivePlacementId)
        }
    return prefetchPresentationViewController(presentation: presentation,
                                              presentationLoadedController: presentationLoadedController)
  }

  private func prefetchPresentationViewController(presentation: PurchaselyPresentation,
                                                  presentationLoadedController: PLYPresentationViewController) -> UIViewController? {
    self.removeLoadedPresentation(presentation: presentation)

    PurchaselyRN.purchaseResolve = { [weak self] result in
      self?.onPresentationClosedPromise?(result)
    }
    return presentationLoadedController
  }

  private func removeLoadedPresentation(presentation: PurchaselyPresentation) {
    var presentationsLoaded = (PurchaselyRN.presentationsLoaded as? [PLYPresentation]) ?? []
    if let indexToRemove = presentationsLoaded.firstIndex(where: { $0.id == presentation.id }) {
        presentationsLoaded.remove(at: indexToRemove)
    }
    PurchaselyRN.presentationsLoaded = NSMutableArray(array: presentationsLoaded)
  }

  private func createNativeViewController(placementId: String?) -> UIViewController? {
    guard let placementId = placementId else { return nil }

    // v6: `Purchasely.presentationController(for:loaded:completion:)` was removed.
    // Build a presentation request, preload it, then install the controller once
    // the SDK hands it back. Preload is asynchronous, so we return nil here and
    // swap the real view in via `attachController` on completion.
    let request = PLYPresentationBuilder
      .from(placementId: placementId)
      .onDismissed { [weak self] outcome in
        guard let self = self else { return }
        let resultDict: NSDictionary
        if let plan = outcome.plan {
          resultDict = ["result": self.productResultOrdinal(outcome.purchaseResult), "plan": plan.asDictionary()]
        } else {
          resultDict = ["result": self.productResultOrdinal(outcome.purchaseResult), "plan": NSNull()]
        }
        DispatchQueue.main.async {
          self.onPresentationClosedPromise?(resultDict)
        }
      }
      .build()

    request.preload { [weak self] presentation, _ in
      DispatchQueue.main.async {
        guard let self = self, let controller = presentation?.controller else { return }
        self.detachController()
        self.attachController(controller)
      }
    }
    return nil
  }

  /// Map a v6 `PLYPurchaseResult` to the `ProductResult` ordinal JS expects.
  /// Kept in sync with the `productResult*` constants exported by PurchaselyRN
  /// (which are backed by `PLYProductViewControllerResult`, not `PLYPurchaseResult`).
  private func productResultOrdinal(_ result: PLYPurchaseResult) -> Int {
    switch result {
    case .purchased: return PLYProductViewControllerResult.purchased.rawValue
    case .cancelled: return PLYProductViewControllerResult.cancelled.rawValue
    case .restored:  return PLYProductViewControllerResult.restored.rawValue
    case .none:      return PLYProductViewControllerResult.cancelled.rawValue
    @unknown default: return PLYProductViewControllerResult.cancelled.rawValue
    }
  }

  deinit {
    detachController()
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
