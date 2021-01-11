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

  if (self.name != nil) {
    [dict setObject:self.name forKey:@"name"];
  }

  NSString *price = [self localizedFullPriceWithLanguage:nil];
  if (price != nil) {
    [dict setObject:price forKey:@"price"];
  }

  NSString *amount = [self localizedPriceWithLanguage:nil];
  if (amount != nil) {
    [dict setObject:amount forKey:@"amount"];
  }

  NSString *period = [self localizedPeriodWithLanguage:nil];
  if (period != nil) {
    [dict setObject:period forKey:@"period"];
  }

  NSString *introPrice = [self localizedFullIntroductoryPriceWithLanguage:nil];
  if (introPrice != nil) {
    [dict setObject:introPrice forKey:@"introPrice"];
  }

  NSString *introAmount = [self localizedIntroductoryPriceWithLanguage:nil];
  if (introAmount != nil) {
    [dict setObject:introAmount forKey:@"introAmount"];
  }

  NSString *introDuration = [self localizedIntroductoryDurationWithLanguage:nil];
  if (introDuration != nil) {
    [dict setObject:introDuration forKey:@"introDuration"];
  }
  
  return dict;
}

@end
