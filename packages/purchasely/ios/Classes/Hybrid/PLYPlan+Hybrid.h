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

@interface PLYPlan (Hybrid)

- (NSDictionary *)asDictionary;
- (void)isEligibleForIntroductoryOffer:(void (^)(BOOL))completion;

@end

NS_ASSUME_NONNULL_END
