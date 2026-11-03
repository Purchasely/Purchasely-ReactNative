#import <Foundation/Foundation.h>
#import "React/RCTBridgeModule.h"
#import "React/RCTViewManager.h"

// SwiftPM compiles Objective-C and Swift sources in separate targets.
// Keeping the extern-module registration here lets this target depend on the
// Swift PurchaselyViewManager implementation, which prevents Release builds
// from dead-stripping the Swift class.
@interface RCT_EXTERN_REMAP_MODULE(PurchaselyView, PurchaselyViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(placementId, NSString)
RCT_EXPORT_VIEW_PROPERTY(presentation, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(requestId, NSString)
RCT_EXPORT_VIEW_PROPERTY(viewId, NSString)

@end
