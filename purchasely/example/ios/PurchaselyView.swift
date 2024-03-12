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
  
  @objc var onCompletionCallback: RCTPromiseResolveBlock?
  
  @objc var placementId: String? {
    didSet {
      print("### placementId was properly set")
      setupView()
    }
  }
  
  @objc var presentation: String? {
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
    _controller = getPresentationController(presentation: presentation, placementId: placementId)
    let view = _controller?.view ?? UIView()
    addSubview(view)
    
    let statusBarHeight = UIApplication.shared.windows.first?.windowScene?.statusBarManager?.statusBarFrame.height
    
    view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        view.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
        view.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        view.heightAnchor.constraint(equalTo: safeAreaLayoutGuide.heightAnchor, constant: statusBarHeight != nil ? -statusBarHeight! : 0),
        view.widthAnchor.constraint(equalTo: safeAreaLayoutGuide.widthAnchor),
        view.trailingAnchor.constraint(equalTo: trailingAnchor),
        view.leadingAnchor.constraint(equalTo: leadingAnchor)
    ])
  }
  
  private func getPresentationController(presentation: String?,
                                         placementId: String?) -> UIViewController? {
      
        guard let presentationId = presentation,
              //let presentationId = presentation.id,
              //let presentationPlacementId = presentation.placementId,
              let loadedPresentations = PurchaselyRN.presentationsLoaded as? [PLYPresentation],
              let presentationLoaded = loadedPresentations.filter({ $0.id == presentationId}).first,
              //let presentationLoaded = loadedPresentations.filter({ $0.id == presentationId && $0.placementId == presentationPlacementId }).first,
              let presentationLoadedController = presentationLoaded.controller else {
          print("### Didn't find presentation with id \(String(describing: presentation))")
            return self.createNativeViewController(placementId: placementId)
        }
    print("### Found presentation with id \(String(describing: presentation))")
        return presentationLoadedController
  }
  
  private func createNativeViewController(placementId: String?) -> UIViewController? {
    if let placementId = placementId {
      let controller = Purchasely.presentationController(
        for: placementId,
        loaded: nil,
        completion: { result, plan in

          if let plan = plan {
            self.onCompletionCallback?(["result": result.rawValue,
                                        "plan": plan.asDictionary()])
          } else {
            self.onCompletionCallback?(["result": result.rawValue])
          }
        }
      )
      return controller
    }
    return nil
  }
}
