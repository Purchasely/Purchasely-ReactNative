//
//  RCTConvert_PurchaselyRN.m
//  reactTutorialApp
//
//  Created by Jean-François GRANG on 15/11/2020.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTConvert.h>
//#import <Purchasely/Purchasely-Swift.h>
@import Purchasely;

@implementation RCTConvert (PurchaselyRN)

RCT_ENUM_CONVERTER(LogLevel, (@{ @"logLevelDebug": @(LogLevelDebug),
                                 @"logLevelInfo": @(LogLevelInfo),
                                 @"logLevelWarn": @(LogLevelWarn),
                                 @"logLevelError": @(LogLevelError)}),
                   LogLevelError, integerValue)

RCT_ENUM_CONVERTER(PLYProductViewControllerResult, (@{ @"productResultPurchased": @(PLYProductViewControllerResultPurchased),
                                                       @"productResultCancelled": @(PLYProductViewControllerResultCancelled),
                                                       @"productResultRestored": @(PLYProductViewControllerResultRestored)}),
                   PLYProductViewControllerResultPurchased, integerValue)

RCT_ENUM_CONVERTER(PLYAttribute, (@{@"amplitudeSessionId": @(PLYAttributeAmplitudeSessionId),
                                    @"amplitudeUserId": @(PLYAttributeAmplitudeUserId),
                                    @"amplitudeDeviceId": @(PLYAttributeAmplitudeDeviceId),
									@"firebaseAppInstanceId": @(PLYAttributeFirebaseAppInstanceId),
									@"airshipChannelId": @(PLYAttributeAirshipChannelId),
                                    @"batchInstallationId": @(PLYAttributeBatchInstallationId),
                                    @"adjustId": @(PLYAttributeAdjustId),
                                    @"appsflyerId": @(PLYAttributeAppsflyerId),
                                    @"onesignalPlayerId": @(PLYAttributeOneSignalPlayerId),
									@"mixpanelDistinctId": @(PLYAttributeMixpanelDistinctId),
        							@"clevertapId": @(PLYAttributeClevertapId),
									@"sendinblueUserEmail": @(PLYAttributeSendinblueUserEmail),
                                    @"iterableUserEmail": @(PLYAttributeIterableUserEmail),
        							@"iterableUserId": @(PLYAttributeIterableUserId),
        							@"atInternetIdClient": @(PLYAttributeAtInternetIdClient),
                                    @"mparticleUserId": @(PLYAttributeMParticleUserId),
                                    @"branchUserDeveloperIdentity": @(PLYAttributeBranchUserDeveloperIdentity),
                                    @"customerIoUserEmail": @(PLYAttributeCustomerioUserEmail),
                                    @"customerIoUserId": @(PLYAttributeCustomerioUserId)}),
				   PLYAttributeAmplitudeSessionId, integerValue)

RCT_ENUM_CONVERTER(PLYSubscriptionSource, (@{ @"sourceAppStore": @(PLYSubscriptionSourceAppleAppStore),
											  @"sourcePlayStore": @(PLYSubscriptionSourceGooglePlayStore),
											  @"sourceHuaweiAppGallery": @(PLYSubscriptionSourceHuaweiAppGallery),
											  @"sourceAmazonAppstore": @(PLYSubscriptionSourceAmazonAppstore),
											  @"sourceNone": @(PLYSubscriptionSourceNone)
										   }),
				   PLYSubscriptionSourceNone, integerValue)

RCT_ENUM_CONVERTER(PLYPlanType, (@{ @"consumable": @(PLYPlanTypeConsumable),
									@"nonConsumable": @(PLYPlanTypeNonConsumable),
									@"autoRenewingSubscription": @(PLYPlanTypeAutoRenewingSubscription),
									@"nonRenewingSubscription": @(PLYPlanTypeNonRenewingSubscription),
									@"unknown": @(PLYPlanTypeUnknown)}),
				   PLYSubscriptionSourceNone, integerValue)
@end
