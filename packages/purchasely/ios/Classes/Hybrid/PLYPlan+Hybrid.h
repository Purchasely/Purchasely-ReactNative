//
//  PLYPlan+Hybrid.h
//  reactTutorialApp
//
//  Created by Jean-François GRANG on 27/12/2020.
//

#import <Foundation/Foundation.h>
#import <Purchasely/Purchasely-Swift.h>
//@import Purchasely;

NS_ASSUME_NONNULL_BEGIN

/// Wire value for `PLYBillingPlanType` shared with JS ('unspecified' / 'upFront' / 'monthly').
FOUNDATION_EXPORT NSString *PLYBillingPlanTypeToRNString(enum PLYBillingPlanType type);
/// Inverse of `PLYBillingPlanTypeToRNString`; unknown / nil maps to `PLYBillingPlanTypeUnspecified`.
FOUNDATION_EXPORT enum PLYBillingPlanType PLYBillingPlanTypeFromRNString(NSString * _Nullable value);

@interface PLYPlan (Hybrid)

- (NSDictionary *)asDictionary;
- (void)isEligibleForIntroductoryOffer:(void (^)(BOOL))completion;

@end

NS_ASSUME_NONNULL_END
