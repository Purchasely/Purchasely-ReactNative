//
//  PLYPresentationPlan+Hybrid.m
//  react-native-purchasely
//
//  Created by Florian Huet on 29/09/2023.
//

#import "PLYPresentationPlan+Hybrid.h"
#import "PLYPlan+Hybrid.h"
#import <Foundation/Foundation.h>

@implementation PLYPresentationPlan (Hybrid)

- (NSDictionary *)asDictionary {
    NSMutableDictionary<NSString *, NSObject *> *dict = [NSMutableDictionary new];
    
    if (self.offerId) {
        [dict setObject:self.offerId forKey:@"offerId"];
    }

    if (self.offerVendorId) {
        [dict setObject:self.offerVendorId forKey:@"offerVendorId"];
    }
    
    if (self.storeProductId) {
        [dict setObject:self.storeProductId forKey:@"storeProductId"];
    }
    
    if (self.planVendorId) {
        [dict setObject:self.planVendorId forKey:@"planVendorId"];
    }

    // `default` is an ObjC keyword; the v6 SDK exposes the property as
    // `default_` (getter `default`), so dot-syntax must use `default_`.
    [dict setObject:@(self.default_) forKey:@"default"];

    // Backend-resolved `commitment_billing_type`. Always emitted (never nil —
    // the native enum defaults to `.unspecified` when the key is absent from
    // the paywall JSON) so JS can tell a monthly-billing commitment plan from
    // a plain one without inspecting `PLYPlan.commitmentInfo`.
    [dict setObject:PLYBillingPlanTypeToRNString(self.billingPlanType)
             forKey:@"billingPlanType"];

    return dict;
}

@end
