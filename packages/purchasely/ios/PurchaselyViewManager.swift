//
//  NativeViewManager.swift
//  example
//
//  Created by Chouaib Mounaime on 05/03/2024.
//

import Foundation
#if SWIFT_PACKAGE
import React
#endif

// public: under SwiftPM the ObjC registration lives in another target, and a
// Release (WMO, no -enable-testing) build does not export internal symbols.
@objc (PurchaselyViewManager)
public class PurchaselyViewManager: RCTViewManager {

  // MUST stay false. Fabric instantiates this manager's view on the main
  // thread; returning true would force any `NativeModules.PurchaselyView`
  // resolution to `dispatch_sync` onto that same main queue, deadlocking if it
  // happens while the view is mid-creation. Returning false lets each thread
  // resolve its own instance without a cross-thread hop. `view()` is still
  // called on the main queue by UIManager regardless, and init does no UIKit
  // work.
  public override static func requiresMainQueueSetup() -> Bool {
    return false
  }

  public override func view() -> UIView! {
    return PurchaselyView()
  }
}
