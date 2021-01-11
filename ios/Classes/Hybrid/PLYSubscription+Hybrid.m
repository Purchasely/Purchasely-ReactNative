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
    case PLYSubscriptionSourceAppStore:
      [dict setObject:@"APPSTORE" forKey:@"subscriptionSource"];
      break;
    case PLYSubscriptionSourcePlayStore:
      [dict setObject:@"PLAYSTORE" forKey:@"subscriptionSource"];
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
