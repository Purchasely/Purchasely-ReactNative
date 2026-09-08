//
//  PLYSubscription+Hybrid.m
//  reactTutorialApp
//
//  Created by Jean-François GRANG on 27/12/2020.
//

#import "PLYSubscription+Hybrid.h"
#import "Purchasely_Hybrid.h"

// PLYPlan+Hybrid.{h,m} is gone — `asDictionary` now lives in
// PLYPlan+Bridge.swift as an `@objc public` extension method. Objective-C
// only needs the declaration to compile this call; the Swift extension
// supplies the body at link time. Do NOT import the pod's generated
// react_native_purchasely-Swift.h here: it is compiled with
// -import-underlying-module, so importing it from a header inside the
// umbrella is a cycle, and a .m-only import would differ between the
// static-library and use_frameworks! layouts (CI builds both).
@interface PLYPlan (BridgeSerialization)
- (NSDictionary *)asDictionary;
@end

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

	// Apple-only (iOS 26.4+) progress through a multi-period commitment.
	// nil on other stores / non-committed subscriptions → key omitted.
	if (self.commitmentProgress != nil) {
		PLYCommitmentProgress *progress = self.commitmentProgress;
		[dict setObject:@{
			@"billingPeriodNumber": @(progress.billingPeriodNumber),
			@"totalBillingPeriods": @(progress.totalBillingPeriods),
			@"commitmentExpiresDate": [dateFormat stringFromDate:progress.commitmentExpiresDate],
			@"commitmentPrice": progress.commitmentPrice,
		} forKey:@"commitmentProgress"];
	}

	return dict;
}

@end
