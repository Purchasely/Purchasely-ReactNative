//
//  react-native-purchasely-Bridging-Header.h
//  Bridge header for Purchasely SDK
//
//  Created by Kevin Herembourg on 14/03/2024.
//

#ifndef react_native_purchasely_Bridging_Header_h
#define react_native_purchasely_Bridging_Header_h

#import "React/RCTBridgeModule.h"
#import "React/RCTEventEmitter.h"
#import "React/RCTViewManager.h"
#import "React/RCTComponent.h"

/// Non-variadic wrapper around RCTLogWarn, for the Swift side. Defined in
/// PurchaselyRN.m. RCTLogWarn itself is a variadic macro Swift cannot see.
FOUNDATION_EXPORT void PLYRNLogWarn(NSString *message);

#endif /* react_native_purchasely_Bridging_Header_h */
