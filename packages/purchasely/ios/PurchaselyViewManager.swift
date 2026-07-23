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
 
  // MUST stay false. `PurchaselyView` is exposed both as a view component and
  // as a callable module (`onPresentationClosed`). When the embedded paywall
  // mounts, Fabric instantiates this manager on the main thread while the JS
  // `PLYPresentationView` effect concurrently resolves the same module via
  // `NativeModules.PurchaselyView`. If this returned true, the JS-thread
  // instantiation would `dispatch_sync` onto the main queue — which is itself
  // blocked waiting on the module holder — deadlocking both threads (proven by
  // a process sample: main thread in condition_variable::wait, JS thread in
  // RCTUnsafeExecuteOnMainQueueSync). Returning false lets each thread create
  // its instance without a cross-thread hop. `view()` is still called on the
  // main queue by UIManager regardless, and init does no UIKit work.
  override static func requiresMainQueueSetup() -> Bool {
    return false
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
