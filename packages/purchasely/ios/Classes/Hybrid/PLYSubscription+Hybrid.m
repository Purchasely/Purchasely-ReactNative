//
//  PLYSubscription+Hybrid.m
//  reactTutorialApp
//
//  Created by Jean-François GRANG on 27/12/2020.
//

#import "PLYSubscription+Hybrid.h"
#import "Purchasely_Hybrid.h"

@implementation PLYSubscription (Hybrid)

- (NSDictionary *)asDictionary {
	NSMutableDictionary<NSString *, NSObject *> *dict = [NSMutableDictionary new];

	[dict setObject:self.plan.asDictionary forKey:@"plan"];
    [dict setObject:self.product.asDictionary forKey:@"product"];
	[dict setObject:[NSNumber numberWithInt:self.subscriptionSource] forKey:@"subscriptionSource"];

    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    
	if (self.nextRenewalDate != nil) {
		[dict setObject:[dateFormat stringFromDate:self.nextRenewalDate] forKey:@"nextRenewalDate"];
	}

	if (self.cancelledDate != nil) {
		[dict setObject:[dateFormat stringFromDate:self.cancelledDate] forKey:@"cancelledDate"];
	}

	return dict;
}

@end
