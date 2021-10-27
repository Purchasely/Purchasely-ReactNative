//
//  PurchaselyRN.h
//  Purchasely-ReactNative
//
//  Created by Jean-François GRANG on 15/11/2020.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface PurchaselyRN: RCTEventEmitter <RCTBridgeModule, PLYEventDelegate>

@property (nonatomic, retain) UIViewController* presentedPresentationViewController;

@property void (^loginClosedHandler)(BOOL loggedIn);
@property void (^authorizePurchaseHandler)(BOOL authorizePurchase);

@end
