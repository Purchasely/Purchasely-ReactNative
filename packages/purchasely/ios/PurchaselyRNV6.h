//
//  PurchaselyRNV6.h
//  Purchasely-ReactNative
//
//  Created on 2026-05-28.
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>

#import "PurchaselyRN.h"

NS_ASSUME_NONNULL_BEGIN

/// v6 bridge category — adds the cross-platform contract methods on top of
/// the existing `Purchasely` native module. The legacy methods stay on the
/// main `PurchaselyRN.m` so backwards-compatible JS code keeps working.
///
/// Contract: reports/v6-presentation-comparison-v3-claude/BRIDGE-CONTRACT.md
@interface PurchaselyRN (V6)

@end

NS_ASSUME_NONNULL_END
