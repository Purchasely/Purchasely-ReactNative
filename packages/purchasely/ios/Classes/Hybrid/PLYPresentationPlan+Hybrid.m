//
//  PLYPresentationPlan+Hybrid.m
//  react-native-purchasely
//
//  Created by Florian Huet on 29/09/2023.
//

#import "PLYPresentationPlan+Hybrid.h"
#import <Foundation/Foundation.h>

@implementation PLYPresentationPlan (Hybrid)

- (NSDictionary *)asDictionary {
    NSMutableDictionary<NSString *, NSObject *> *dict = [NSMutableDictionary new];
    
    if (self.offerId) {
        [dict setObject:self.offerId forKey:@"offerId"];
    }
    
    if (self.storeProductId) {
        [dict setObject:self.storeProductId forKey:@"storeProductId"];
    }
    
    if (self.planVendorId) {
        [dict setObject:self.planVendorId forKey:@"planVendorId"];
    }
    
    return dict;
}

@end
