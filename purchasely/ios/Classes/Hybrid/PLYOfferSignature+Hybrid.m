//
//  PLYOfferSignature+Hybrid.m
//  react-native-purchasely
//
//  Created by Florian Huet on 29/09/2023.
//

#import "PLYOfferSignature+Hybrid.h"
#import <Foundation/Foundation.h>

@implementation PLYOfferSignature (Hybrid)

- (NSDictionary *)asDictionary {
    NSMutableDictionary<NSString *, NSObject *> *dict = [NSMutableDictionary new];

    [dict setObject:self.planVendorId forKey:@"planVendorId"];
    [dict setObject:self.identifier forKey:@"identifier"];
    [dict setObject:self.signature forKey:@"signature"];
    [dict setObject:self.keyIdentifier forKey:@"keyIdentifier"];
    
    NSString *nonceString = [self.nonce UUIDString];
    NSObject *nonce = (NSObject *)nonceString;
    if (nonce != nil) {
        [dict setObject:nonce forKey:@"nonce"];
    }
    
    NSNumber *timestamp = [NSNumber numberWithDouble:self.timestamp];
    if (timestamp != nil) {
        [dict setObject:timestamp forKey:@"timestamp"];
    }

    return dict;
}

@end
