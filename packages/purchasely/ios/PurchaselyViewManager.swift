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

// requiresMainQueueSetup() MUST stay false. Fabric instantiates this manager's
// view on the main thread; returning true would force any
// `NativeModules.PurchaselyView` resolution to `dispatch_sync` onto that same
// main queue, deadlocking if it happens while the view is mid-creation.
// Returning false lets each thread resolve its own instance without a
// cross-thread hop. `view()` is still called on the main queue by UIManager
// regardless, and init does no UIKit work.

#if SWIFT_PACKAGE
// public only under SwiftPM: the ObjC registration lives in another target, and
// a Release (WMO, no -enable-testing) build does not export internal symbols.
// It stays internal for CocoaPods: a public @objc RCTViewManager subclass makes
// the generated react_native_purchasely-Swift.h import
// <react_native_purchasely/react_native_purchasely.h>, which the pod lacks.
@objc (PurchaselyViewManager)
public class PurchaselyViewManager: RCTViewManager {
  public override static func requiresMainQueueSetup() -> Bool {
    return false
  }

  public override func view() -> UIView! {
    return PurchaselyView()
  }
}
#else
@objc (PurchaselyViewManager)
class PurchaselyViewManager: RCTViewManager {
  override static func requiresMainQueueSetup() -> Bool {
    return false
  }

  override func view() -> UIView! {
    return PurchaselyView()
  }
}
#endif
