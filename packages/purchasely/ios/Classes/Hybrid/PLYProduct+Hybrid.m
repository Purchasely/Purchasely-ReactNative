//
//  PLYProduct+Hybrid.m
//  reactTutorialApp
//
//  Created by Jean-François GRANG on 27/12/2020.
//

#import "PLYProduct+Hybrid.h"
// Compiler-generated Swift interface header for *this* pod, needed here for
// `PLYPlan.asDictionary()` (PLYPlan+Bridge.swift). Copied verbatim from
// PurchaselyRN.m:24-28 — see that file for why the #if is needed.
#if __has_include(<react_native_purchasely/react_native_purchasely-Swift.h>)
#import <react_native_purchasely/react_native_purchasely-Swift.h>
#else
#import "react_native_purchasely-Swift.h"
#endif

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
