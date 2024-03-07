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
  
  @objc var completionCallback: (() -> Void)?
  
  @objc var placementId: String? {
      didSet {
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
    createNativeView(presentationId: nil, placementId: placementId)
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
  
  func createNativeView(presentationId: String?, placementId: String?) {
         if let presentationId = presentationId {
             _controller = Purchasely.presentationController(
                 with: presentationId,
                 loaded: { _,_,_  in
                   print("Loaded")
                 },
                 completion: { _,_ in
                   self.completionCallback?()
                 }
             )
         }
         else if let placementId = placementId {
             _controller = Purchasely.presentationController(
                 for: placementId,
                 loaded: { _,_,_  in
                   print("Loaded")
                 },
                 completion: { _,_ in
                   self.completionCallback?()
                 }
             )
         }
     }
 
 }
