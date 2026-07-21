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

	// [RN-W-07] Same always-a-boolean treatment as hasIntroductoryPrice above —
	// `self.hasFreeTrial` (PLYPlan.swift) already computes exactly
	// `hasIntroductoryPrice && introAmount == 0` natively; the TS `hasFreeTrial`
	// type is required, so it must never come back `undefined`.
	[dict setObject:@(self.hasFreeTrial) forKey:@"hasFreeTrial"];

	// basePlanId is a Google Play concept (base-plan / offer hierarchy); the
	// App Store has no equivalent on PLYPlan, so the key is omitted (JS types
	// it as optional, and Android is the only source of a real value).

	// Promotional-offer price fields (hasOfferPrice/offerPrice/offerAmount/
	// offerDuration/offerPeriod): iOS `PLYPlan` has no public accessor for a
	// promotional offer's localized price/duration/period — only the
	// introductory-offer accessors above exist (`localizedFullIntroductoryPrice`
	// etc.). The equivalent computation lives in the SDK's internal
	// `PLYTagHelper.computeOfferPriceTag`/`computeOfferAmountTag`/etc.
	// (Sources/Purchasely/common/Model/UI/PLYTagHelper.swift), which is
	// `private` and takes an internal `ProductType` — unreachable from this
	// Objective-C bridge. Emit safe defaults so the RN keys are always present.
	[dict setObject:@(NO) forKey:@"hasOfferPrice"];
	[dict setObject:@"" forKey:@"offerPrice"];
	[dict setObject:@0 forKey:@"offerAmount"];
	[dict setObject:@"" forKey:@"offerDuration"];
	[dict setObject:@"" forKey:@"offerPeriod"];

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
