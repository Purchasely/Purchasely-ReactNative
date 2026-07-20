//
//  PLYPlan+Hybrid.m
//  reactTutorialApp
//
//  Created by Jean-François GRANG on 27/12/2020.
//

#import "PLYPlan+Hybrid.h"

NSString *PLYBillingPlanTypeToRNString(enum PLYBillingPlanType type) {
    switch (type) {
        case PLYBillingPlanTypeUpFront: return @"upFront";
        case PLYBillingPlanTypeMonthly: return @"monthly";
        case PLYBillingPlanTypeUnspecified:
        default: return @"unspecified";
    }
}

enum PLYBillingPlanType PLYBillingPlanTypeFromRNString(NSString * _Nullable value) {
    if ([value isEqualToString:@"upFront"]) return PLYBillingPlanTypeUpFront;
    if ([value isEqualToString:@"monthly"]) return PLYBillingPlanTypeMonthly;
    return PLYBillingPlanTypeUnspecified;
}

@implementation PLYPlan (Hybrid)

- (void)isEligibleForIntroductoryOffer:(void (^)(BOOL))completion {
    [self isUserEligibleForIntroductoryOfferWithCompletion:completion];
}

- (NSDictionary *)asDictionary {
	NSMutableDictionary<NSString *, NSObject *> *dict = [NSMutableDictionary new];

	[dict setObject:self.vendorId forKey:@"vendorId"];
	// [RN-W-07] Always emit hasIntroductoryPrice as a real boolean — the TS
	// `PurchaselyPlan.hasIntroductoryPrice` type is required (non-optional).
	// It used to be removed from the dict for free-trial plans, leaving the
	// field `undefined` at runtime instead of `false`/`true`.
	[dict setObject:@(self.hasIntroductoryPrice) forKey:@"hasIntroductoryPrice"];
	[dict setObject:@([self type]) forKey:@"type"];

	if (self.hasIntroductoryPrice && [[self introAmount] intValue] == 0) {
		[dict setObject:@(YES) forKey:@"hasFreeTrial"];
	}

	if (self.name != nil) {
		[dict setObject:self.name forKey:@"name"];
	}

    if (self.appleProductId != nil) {
        [dict setObject:self.appleProductId forKey:@"productId"];
    }
    
	NSString *price = [self localizedFullPriceWithLanguage:nil];
	if (price != nil) {
		[dict setObject:price forKey:@"price"];
	}

	NSDecimalNumber *amount = [self amount];
	if (amount != nil) {
		[dict setObject:amount forKey:@"amount"];
	}

    NSString *localizedAmount = [self localizedPriceWithLanguage:nil];
    if (localizedAmount != nil) {
        [dict setObject:localizedAmount forKey:@"localizedAmount"];
    }
    
	NSDecimalNumber *introAmount = [self introAmount];
	if (introAmount != nil) {
		[dict setObject:introAmount forKey:@"introAmount"];
	}

	NSString *currencyCode = [self currencyCode];
	if (currencyCode != nil) {
		[dict setObject:currencyCode forKey:@"currencyCode"];
	}

	NSString *currencySymbol = [self currencySymbol];
	if (currencySymbol != nil) {
		[dict setObject:currencySymbol forKey:@"currencySymbol"];
	}

	NSString *period = [self localizedPeriodWithLanguage:nil];
	if (period != nil) {
		[dict setObject:period forKey:@"period"];
	}

	NSString *introPrice = [self localizedFullIntroductoryPriceWithLanguage:nil];
	if (introPrice != nil) {
		[dict setObject:introPrice forKey:@"introPrice"];
	}

	NSString *introDuration = [self localizedIntroductoryDurationWithLanguage:nil];
	if (introDuration != nil) {
		[dict setObject:introDuration forKey:@"introDuration"];
	}

	NSString *introPeriod = [self localizedIntroductoryPeriodWithLanguage:nil];
	if (introPeriod != nil) {
		[dict setObject:introPeriod forKey:@"introPeriod"];
	}

	// Apple-only (iOS 26.4+) multi-period commitment installments. Empty on
	// other stores / non-committed plans, in which case the key is omitted.
	if (self.commitmentInfo.count > 0) {
		NSMutableArray<NSDictionary *> *commitments = [NSMutableArray new];
		for (PLYCommitmentInfo *info in self.commitmentInfo) {
			[commitments addObject:@{
				@"billingPlanType": PLYBillingPlanTypeToRNString(info.billingPlanType),
				@"billingPrice": info.billingPrice,
				@"billingPeriod": info.billingPeriod,
				@"totalPrice": info.totalPrice,
				@"totalPeriod": info.totalPeriod,
				@"totalDuration": @(info.totalDuration),
			}];
		}
		[dict setObject:commitments forKey:@"commitmentInfo"];
	}

	return dict;
}

@end
