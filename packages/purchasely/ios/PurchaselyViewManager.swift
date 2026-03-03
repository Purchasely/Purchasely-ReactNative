//
//  NativeViewManager.swift
//  example
//
//  Created by Chouaib Mounaime on 05/03/2024.
//

import Foundation

@objc (PurchaselyViewManager)
class PurchaselyViewManager: RCTViewManager {
  
  private var purchaselyView: PurchaselyView?
  private var resolve: RCTPromiseResolveBlock?
 
  override static func requiresMainQueueSetup() -> Bool {
    return true
  }
 
  override func view() -> UIView! {
    self.purchaselyView = PurchaselyView()
    self.purchaselyView?.onPresentationClosedPromise = resolve
    return self.purchaselyView!
  }
  
  @objc func onPresentationClosed(_ resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    self.resolve = resolve
    // Forward resolve to the current view — view() is called before this useEffect fires,
    // so we must update onPresentationClosedPromise after the fact.
    self.purchaselyView?.onPresentationClosedPromise = resolve
  }
}
