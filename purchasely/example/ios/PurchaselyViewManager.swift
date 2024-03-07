//
//  NativeViewManager.swift
//  example
//
//  Created by Chouaib Mounaime on 05/03/2024.
//

import Foundation

@objc (PurchaselyViewManager)
class PurchaselyViewManager: RCTViewManager {
 
  override static func requiresMainQueueSetup() -> Bool {
    return true
  }
 
  override func view() -> UIView! {
    return PurchaselyView()
  }
}
