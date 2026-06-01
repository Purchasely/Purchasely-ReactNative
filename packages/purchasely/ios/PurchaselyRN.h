//
//  PurchaselyRN.h
//  Purchasely-ReactNative
//
//  Created by Jean-François GRANG on 15/11/2020.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
@import Purchasely;

@interface PurchaselyRN: RCTEventEmitter <RCTBridgeModule, PLYEventDelegate>

@property (nonatomic, retain) UIViewController* presentedPresentationViewController;

@property (class, nonatomic, copy) RCTPromiseResolveBlock purchaseResolve;

@property (class, nonatomic, strong) NSMutableArray<id<PLYPresentation>> *presentationsLoaded;

@property (nonatomic, assign) Boolean shouldReopenPaywall;

@property (nonatomic, assign) Boolean shouldEmit;

@end
