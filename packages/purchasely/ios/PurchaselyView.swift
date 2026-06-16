//
//  NativeView.swift
//  example
//
//  Created by Chouaib Mounaime on 05/03/2024.
//

import Foundation
import Purchasely

class PurchaselyView: UIView {
  
  private var fetched: Bool = false
  
  private var _view: UIView?
  private var _controller: UIViewController?
  
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
  
  var onPresentationClosedPromise: RCTPromiseResolveBlock?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
 
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  private func setupView() {
    // Clean up previous view/controller before setting up new ones
    _view?.removeFromSuperview()
    _view = nil
    _controller = nil

    _controller = getPresentationController(presentation: presentation != nil ? PurchaselyPresentation(from: presentation!) : nil,
                                            placementId: placementId)
    let view = _controller?.view ?? UIView()
    _view = view
    self.addSubview(view)

    view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: self.topAnchor),
      view.trailingAnchor.constraint(equalTo: self.trailingAnchor),
      view.leadingAnchor.constraint(equalTo: self.leadingAnchor),
      view.bottomAnchor.constraint(equalTo: self.bottomAnchor)
    ])

    if fetched {
      _controller?.beginAppearanceTransition(true, animated: true)
    }
  }
  
  private func getPresentationController(presentation: PurchaselyPresentation?,
                                         placementId: String?) -> UIViewController? {
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
    self.fetched = true

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
    self.fetched = false
    guard let placementId = placementId else { return nil }

    // v6: `Purchasely.presentationController(for:loaded:completion:)` was removed.
    // Build a presentation request, preload it, then install the controller once
    // the SDK hands it back. Preload is asynchronous, so we return nil here and
    // swap the real view in via `installController` on completion.
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
        self.installController(controller)
      }
    }
    return nil
  }

  /// Install a freshly-preloaded controller into this view, replacing any
  /// placeholder added synchronously while the presentation was still loading.
  private func installController(_ controller: UIViewController) {
    _view?.removeFromSuperview()
    _controller = controller
    let view = controller.view ?? UIView()
    _view = view
    self.addSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: self.topAnchor),
      view.trailingAnchor.constraint(equalTo: self.trailingAnchor),
      view.leadingAnchor.constraint(equalTo: self.leadingAnchor),
      view.bottomAnchor.constraint(equalTo: self.bottomAnchor)
    ])
    self.fetched = true
    controller.beginAppearanceTransition(true, animated: true)
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
