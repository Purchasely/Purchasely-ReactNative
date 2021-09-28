//
//  PLYPlan+Hybrid.m
//  reactTutorialApp
//
//  Created by Jean-François GRANG on 27/12/2020.
//

#import "PLYPlan+Hybrid.h"

@implementation PLYPlan (Hybrid)

- (NSDictionary *)asDictionary {
	NSMutableDictionary<NSString *, NSObject *> *dict = [NSMutableDictionary new];

	[dict setObject:self.vendorId forKey:@"vendorId"];
	[dict setObject:@(self.hasIntroductoryPrice) forKey:@"hasIntroductoryPrice"];
	[dict setObject:@([self type]) forKey:@"type"];

	if (self.hasIntroductoryPrice && [[self introAmount] intValue] == 0) {
		[dict setObject:@(YES) forKey:@"hasFreeTrial"];
		[dict removeObjectForKey:@"hasIntroductoryPrice"];
	}

	if (self.name != nil) {
		[dict setObject:self.name forKey:@"name"];
	}

	NSString *price = [self localizedFullPriceWithLanguage:nil];
	if (price != nil) {
		[dict setObject:price forKey:@"price"];
	}

	NSDecimalNumber *amount = [self amount];
	if (amount != nil) {
		[dict setObject:amount forKey:@"amount"];
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

	return dict;
}

@end
