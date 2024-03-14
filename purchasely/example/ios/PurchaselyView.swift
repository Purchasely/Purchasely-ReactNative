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
  
  @objc var onCompletionCallback: RCTBubblingEventBlock?
  
  @objc var placementId: String? {
    didSet {
      print("### placementId was properly set")
      setupView()
    }
  }
  
  @objc var presentation: NSDictionary? {
    didSet {
      print("### presentation was properly set")
      setupView()
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
 
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  private func setupView() {
    _controller = getPresentationController(presentation: presentation != nil ? PurchaselyPresentation(from: presentation!) : nil,
                                            placementId: placementId)
    let view = _controller?.view ?? UIView()
    self.addSubview(view)
    
    let statusBarHeight = UIApplication.shared.windows.first?.windowScene?.statusBarManager?.statusBarFrame.height
    
    view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor),
      view.heightAnchor.constraint(equalTo: safeAreaLayoutGuide.heightAnchor, constant: statusBarHeight != nil ? -statusBarHeight! : 0),
      view.widthAnchor.constraint(equalTo: safeAreaLayoutGuide.widthAnchor),
      view.trailingAnchor.constraint(equalTo: self.trailingAnchor),
      view.leadingAnchor.constraint(equalTo: self.leadingAnchor)
    ])
    
    if fetched {
      _controller?.beginAppearanceTransition(true, animated: true)
    }
  }
  
  private func getPresentationController(presentation: PurchaselyPresentation?,
                                         placementId: String?) -> UIViewController? {
      
        guard let presentation = presentation,
              let presentationPlacementId = presentation.placementId,
              let loadedPresentations = PurchaselyRN.presentationsLoaded as? [PLYPresentation],
              let presentationLoaded = loadedPresentations.filter({ $0.id == presentation.id && $0.placementId == presentationPlacementId }).first,
              let presentationLoadedController = presentationLoaded.controller else {
          print("### Didn't find presentation with id \(String(describing: presentation))")
          self.fetched = false
            return self.createNativeViewController(placementId: placementId)
        }
    print("### Found presentation with id \(String(describing: presentation))")
    
    self.fetched = true
    PurchaselyRN.purchaseResolve = { result in
      self.onCompletionCallback?(result as? [AnyHashable : Any])
    }
    return presentationLoadedController
  }
  
  private func createNativeViewController(placementId: String?) -> UIViewController? {
    if let placementId = placementId {
      let controller = Purchasely.presentationController(
        for: placementId,
        loaded: nil,
        completion: { result, plan in

          if let plan = plan {
            let result: [AnyHashable : Any]? = [
              "result": result.rawValue,
              "plan": plan.asDictionary()
            ]
            
            self.onCompletionCallback?(result)
          } else {
            
            let result: [AnyHashable : Any]? = [
              "result": result.rawValue
            ]
            
            self.onCompletionCallback?(result)
          }
        }
      )
      return controller
    }
    return nil
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
