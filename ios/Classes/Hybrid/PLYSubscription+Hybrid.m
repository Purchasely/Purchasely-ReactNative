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
	[dict setObject:[NSNumber numberWithInt:self.subscriptionSource] forKey:@"subscriptionSource"];

	if (self.nextRenewalDate != nil) {
		[dict setObject:@(self.nextRenewalDate.timeIntervalSince1970) forKey:@"nextRenewalDate"];
	}

	if (self.cancelledDate != nil) {
		[dict setObject:@(self.cancelledDate.timeIntervalSince1970) forKey:@"cancelledDate"];
	}

	return dict;
}

@end
