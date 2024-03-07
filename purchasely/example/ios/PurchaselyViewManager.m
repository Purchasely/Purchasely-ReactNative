//
//  NativeViewManager.m
//  example
//
//  Created by Chouaib Mounaime on 05/03/2024.
//

#import <Foundation/Foundation.h>
#import "React/RCTBridgeModule.h"
#import "React/RCTViewManager.h"

@interface RCT_EXTERN_MODULE(PurchaselyViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(placementId, NSString)
RCT_EXPORT_VIEW_PROPERTY(completionCallback, RCTBubblingEventBlock)

@end

