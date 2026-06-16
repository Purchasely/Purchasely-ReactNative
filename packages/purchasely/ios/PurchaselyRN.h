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

/// Look up a presentation that was preloaded through `preloadPresentation:` by
/// its bridge `requestId`. Used by the embedded `PLYPresentationView` to reuse a
/// presentation the JS layer already preloaded (instead of loading it again).
+ (nullable id<PLYPresentation>)loadedPresentationForRequestId:(nonnull NSString *)requestId;

@end
