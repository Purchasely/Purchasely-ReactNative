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
    _controller?.willMove(toParent: nil)
    _controller?.removeFromParent()
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
    let controller = Purchasely.presentationController(
      for: placementId,
      loaded: nil,
      completion: { [weak self] result, plan in
        guard let self = self else { return }
        let resultDict: NSDictionary
        if let plan = plan {
          resultDict = ["result": result.rawValue, "plan": plan.asDictionary()]
        } else {
          resultDict = ["result": result.rawValue, "plan": NSNull()]
        }
        DispatchQueue.main.async {
          self.onPresentationClosedPromise?(resultDict)
        }
      }
    )
    return controller
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
