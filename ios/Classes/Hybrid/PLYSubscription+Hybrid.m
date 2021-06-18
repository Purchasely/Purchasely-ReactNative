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

	switch (self.subscriptionSource) {
		case PLYSubscriptionSourceAppleAppStore:
			[dict setObject:@"sourceAppStore" forKey:@"subscriptionSource"];
			break;
		case PLYSubscriptionSourceGooglePlayStore:
			[dict setObject:@"sourcePlayStore" forKey:@"subscriptionSource"];
			break;
		case PLYSubscriptionSourceAmazonAppstore:
			[dict setObject:@"sourceAmazonAppstore" forKey:@"subscriptionSource"];
			break;
		case PLYSubscriptionSourceHuaweiAppGallery:
			[dict setObject:@"sourceHuaweiAppGallery" forKey:@"subscriptionSource"];
			break;
		case PLYSubscriptionSourceNone:
			break;
	}

	if (self.nextRenewalDate != nil) {
		[dict setObject:@(self.nextRenewalDate.timeIntervalSince1970) forKey:@"nextRenewalDate"];
	}

	if (self.cancelledDate != nil) {
		[dict setObject:@(self.cancelledDate.timeIntervalSince1970) forKey:@"cancelledDate"];
	}

	return dict;
}

@end
