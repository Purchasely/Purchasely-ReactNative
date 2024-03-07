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
  
  @objc var completionCallback: (() -> Void)? = {
    
  }
  
  @objc var placementId: String? {
    didSet {
      setupView()
    }
  }
  
  @objc var presentation: PLYPresentation? {
    didSet {
      setupView()
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    Purchasely.setEventDelegate(self)
  }
 
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  private func setupView() {
    _controller = getPresentationController(presentation: presentation, placementId: placementId)
    let view = _controller?.view ?? UIView()
    addSubview(view)
    
    view.translatesAutoresizingMaskIntoConstraints = false
    view.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    view.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
    view.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    view.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    view.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
    view.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
  }
  
  private func getPresentationController(presentation: PLYPresentation?,
                                         placementId: String?) -> UIViewController? {
      
        guard let presentation = presentation,
              let presentationId = presentation.id,
              let presentationPlacementId = presentation.placementId,
              let loadedPresentations = PurchaselyRN.getPresentationsLoaded() as? [PLYPresentation],
              let presentationLoaded = loadedPresentations.filter({ $0.id == presentationId && $0.placementId == presentationPlacementId }).first,
              let presentationLoadedController = presentationLoaded.controller else {
            print("Didn't find presentation with id \(presentation?.id)")
            return self.createNativeViewController(placementId: placementId)
        }
        print("Found presentation with id \(presentation.id)")
        return presentationLoadedController
  }
  
  private func createNativeViewController(placementId: String?) -> UIViewController? {
    if let placementId = placementId {
      let controller = Purchasely.presentationController(
        for: placementId,
        loaded: nil,
        completion: { result, plan in
          //TODO: CALLBACK
        }
      )
      return controller
    }
    return nil
  }
}

extension PurchaselyView: PLYEventDelegate {
  func eventTriggered(_ event: PLYEvent, properties: [String : Any]?) {
    if event == .presentationClosed {
      DispatchQueue.main.async {
        //self._controller?.view.removeFromSuperview()
        //self.completionCallback?()
      }
    }
  }
}
