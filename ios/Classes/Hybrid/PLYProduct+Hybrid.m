//
//  PLYProduct+Hybrid.m
//  reactTutorialApp
//
//  Created by Jean-François GRANG on 27/12/2020.
//

#import "PLYProduct+Hybrid.h"
#import "PLYPlan+Hybrid.h"

@implementation PLYProduct (Hybrid)

- (NSDictionary *)asDictionary {
  NSMutableDictionary<NSString *, NSObject *> *dict = [NSMutableDictionary new];

  [dict setObject:self.vendorId forKey:@"vendorId"];

  NSMutableArray *plansArray = [NSMutableArray new];
  for (PLYPlan *plan in self.plans) {
    [plansArray addObject:plan.asDictionary];
  }

  [dict setObject:plansArray forKey:@"plans"];

  if (self.name != nil) {
    [dict setObject:self.name forKey:@"name"];
  }

  return dict;
}

@end
