//
//  NativeViewManager.m
//  example
//
//  Created by Chouaib Mounaime on 05/03/2024.
//

#import <Foundation/Foundation.h>
#import "React/RCTBridgeModule.h"
#import "React/RCTViewManager.h"

@interface RCT_EXTERN_REMAP_MODULE(PurchaselyView, PurchaselyViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(placementId, NSString)
RCT_EXPORT_VIEW_PROPERTY(presentation, NSDictionary)

RCT_EXTERN_METHOD(onPresentationClosed:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject);

@end

