#import <Foundation/Foundation.h>
#import "React/RCTBridgeModule.h"
#import "React/RCTViewManager.h"

// SwiftPM compiles Objective-C and Swift sources in separate targets.
// This category links against the Swift PurchaselyViewManager class, which is
// public under SWIFT_PACKAGE so that Release builds export its symbol.
@interface RCT_EXTERN_REMAP_MODULE(PurchaselyView, PurchaselyViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(placementId, NSString)
RCT_EXPORT_VIEW_PROPERTY(presentation, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(requestId, NSString)
RCT_EXPORT_VIEW_PROPERTY(viewId, NSString)

@end
