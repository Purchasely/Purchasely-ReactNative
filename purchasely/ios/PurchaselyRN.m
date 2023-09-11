//
//  PurchaselyRN.m
//  Purchasely-ReactNative
//
//  Created by Jean-François GRANG on 15/11/2020.
//

#import <React/RCTBridgeModule.h>

#import <React/RCTLog.h>
#import <Purchasely/Purchasely-Swift.h>
#import "PurchaselyRN.h"
#import "Purchasely_Hybrid.h"
#import "UIColor+PLYHelper.h"

@implementation PurchaselyRN

RCT_EXPORT_MODULE(Purchasely);

- (instancetype)init {
	self = [super init];

    self.presentationsLoaded = [NSMutableArray new];
    self.shouldReopenPaywall = NO;

	[Purchasely setAppTechnology:PLYAppTechnologyReactNative];
	return self;
}

- (NSDictionary *)constantsToExport {
	return @{
		@"logLevelDebug": @(LogLevelDebug),
		@"logLevelInfo": @(LogLevelInfo),
		@"logLevelWarn": @(LogLevelWarn),
		@"logLevelError": @(LogLevelError),
		@"productResultPurchased": @(PLYProductViewControllerResultPurchased),
		@"productResultCancelled": @(PLYProductViewControllerResultCancelled),
		@"productResultRestored": @(PLYProductViewControllerResultRestored),
		@"sourceAppStore": @(PLYSubscriptionSourceAppleAppStore),
		@"sourcePlayStore": @(PLYSubscriptionSourceGooglePlayStore),
		@"sourceHuaweiAppGallery": @(PLYSubscriptionSourceHuaweiAppGallery),
		@"sourceAmazonAppstore": @(PLYSubscriptionSourceAmazonAppstore),
		@"firebaseAppInstanceId": @(PLYAttributeFirebaseAppInstanceId),
		@"airshipChannelId": @(PLYAttributeAirshipChannelId),
        @"airshipUserId": @(PLYAttributeAirshipUserId),
        @"batchInstallationId": @(PLYAttributeBatchInstallationId),
        @"adjustId": @(PLYAttributeAdjustId),
        @"appsflyerId": @(PLYAttributeAppsflyerId),
        @"onesignalPlayerId": @(PLYAttributeOneSignalPlayerId),
        @"mixpanelDistinctId": @(PLYAttributeMixpanelDistinctId),
        @"clevertapId": @(PLYAttributeClevertapId),
        @"sendinblueUserEmail": @(PLYAttributeSendinblueUserEmail),
        @"iterableUserId": @(PLYAttributeIterableUserId),
        @"iterableUserEmail": @(PLYAttributeIterableUserEmail),
        @"atInternetIdClient": @(PLYAttributeAtInternetIdClient),
        @"amplitudeUserId": @(PLYAttributeAmplitudeUserId),
        @"amplitudeDeviceId": @(PLYAttributeAmplitudeDeviceId),
        @"mparticleUserId": @(PLYAttributeMParticleUserId),
        @"customerIoUserId": @(PLYAttributeCustomerioUserId),
        @"customerIoUserEmail": @(PLYAttributeCustomerioUserEmail),
        @"branchUserDeveloperIdentity": @(PLYAttributeBranchUserDeveloperIdentity),
        @"moengageUniqueId": @(PLYAttributeMoengageUniqueId),
		@"consumable": @(PLYPlanTypeConsumable),
		@"nonConsumable": @(PLYPlanTypeNonConsumable),
		@"autoRenewingSubscription": @(PLYPlanTypeAutoRenewingSubscription),
		@"nonRenewingSubscription": @(PLYPlanTypeNonRenewingSubscription),
		@"unknown": @(PLYPlanTypeUnknown),
        @"runningModeTransactionOnly": @(PLYRunningModeTransactionOnly),
        @"runningModeObserver": @(PLYRunningModeObserver),
        @"runningModePaywallObserver": @(PLYRunningModePaywallObserver),
        @"runningModeFull": @(PLYRunningModeFull),
        @"presentationTypeNormal": @(PLYPresentationTypeNormal),
        @"presentationTypeFallback": @(PLYPresentationTypeFallback),
        @"presentationTypeDeactivated": @(PLYPresentationTypeDeactivated),
        @"presentationTypeClient": @(PLYPresentationTypeClient)
	};
}

- (NSDictionary<NSString *, NSObject *> *) resultDictionaryForActionInterceptor:(PLYPresentationAction) action
                                                                     parameters: (PLYPresentationActionParameters * _Nullable) params
                                                              presentationInfos: (PLYPresentationInfo * _Nullable) infos {
	NSMutableDictionary<NSString *, NSObject *> *actionInterceptorResult = [NSMutableDictionary new];

    NSString* actionString;

    switch (action) {
        case PLYPresentationActionLogin:
            actionString = @"login";
            break;
        case PLYPresentationActionPurchase:
            actionString = @"purchase";
            break;
        case PLYPresentationActionClose:
            actionString = @"close";
            break;
        case PLYPresentationActionRestore:
            actionString = @"restore";
            break;
        case PLYPresentationActionNavigate:
            actionString = @"navigate";
            break;
        case PLYPresentationActionPromoCode:
            actionString = @"promo_code";
            break;
        case PLYPresentationActionOpenPresentation:
            actionString = @"open_presentation";
            break;
    }

	[actionInterceptorResult setObject:actionString forKey:@"action"];

    if (infos != nil) {
        NSMutableDictionary<NSString *, NSObject *> *infosResult = [NSMutableDictionary new];
        if (infos.contentId != nil) {
            [infosResult setObject:infos.contentId forKey:@"contentId"];
        }
        if (infos.presentationId != nil) {
            [infosResult setObject:infos.presentationId forKey:@"presentationId"];
        }

        if (infos.placementId != nil) {
            [infosResult setObject:infos.placementId forKey:@"placementId"];
        }

        if (infos.abTestId != nil) {
            [infosResult setObject:infos.abTestId forKey:@"abTestId"];
        }

        if (infos.abTestVariantId != nil) {
            [infosResult setObject:infos.abTestVariantId forKey:@"abTestVariantId"];
        }

        [actionInterceptorResult setObject:infosResult forKey:@"info"];
    }
    if (params != nil) {
        NSMutableDictionary<NSString *, NSObject *> *paramsResult = [NSMutableDictionary new];
        if (params.url != nil) {
            [paramsResult setObject:params.url.absoluteString forKey:@"url"];
        }
        if (params.plan != nil) {
            [paramsResult setObject:[params.plan asDictionary] forKey:@"plan"];
        }
        if (params.title != nil) {
            [paramsResult setObject:params.title forKey:@"title"];
        }
        if (params.presentation != nil) {
            [paramsResult setObject:params.presentation forKey:@"presentation"];
        }

        [actionInterceptorResult setObject:paramsResult forKey:@"parameters"];
    }

	return actionInterceptorResult;
}

- (NSDictionary<NSString *, NSObject *> *) resultDictionaryForPresentationController:(PLYProductViewControllerResult)result plan:(PLYPlan * _Nullable)plan {
    NSMutableDictionary<NSString *, NSObject *> *productViewResult = [NSMutableDictionary new];
    int resultString;

    switch (result) {
        case PLYProductViewControllerResultPurchased:
            resultString = PLYProductViewControllerResultPurchased;
            break;
        case PLYProductViewControllerResultRestored:
            resultString = PLYProductViewControllerResultRestored;
            break;
        case PLYProductViewControllerResultCancelled:
            resultString = PLYProductViewControllerResultCancelled;
            break;
    }

    [productViewResult setObject:[NSNumber numberWithInt:resultString] forKey:@"result"];

    if (plan != nil) {
        [productViewResult setObject:[plan asDictionary] forKey:@"plan"];
    }

    if (result == PLYProductViewControllerResultPurchased || PLYProductViewControllerResultRestored) {
        [self hidePresentation];
        self.shouldReopenPaywall = NO;
    }
    return productViewResult;
}

- (NSDictionary<NSString *, NSObject *> *) resultDictionaryForFetchPresentation:(PLYPresentation * _Nullable) presentation {
    NSMutableDictionary<NSString *, NSObject *> *presentationResult = [NSMutableDictionary new];

    // TODO: fill all parameters.
    if (presentation != nil) {

        if (presentation.id != nil) {
            [presentationResult setObject:presentation.id forKey:@"id"];
        }

        if (presentation.placementId != nil) {
            [presentationResult setObject:presentation.placementId forKey:@"placementId"];
        }

        if (presentation.audienceId != nil) {
            [presentationResult setObject:presentation.audienceId forKey:@"audienceId"];
        }

        if (presentation.abTestId != nil) {
            [presentationResult setObject:presentation.abTestId forKey:@"abTestId"];
        }

        if (presentation.abTestVariantId != nil) {
            [presentationResult setObject:presentation.abTestVariantId forKey:@"abTestVariantId"];
        }

        if (presentation.language != nil) {
            [presentationResult setObject:presentation.language forKey:@"language"];
        }

        if (presentation.plans != nil) {
            [presentationResult setObject:presentation.plans forKey:@"plans"];
        }

        int resultString;

        switch (presentation.type) {
            case PLYPresentationTypeNormal:
                resultString = PLYPresentationTypeNormal;
                break;
            case PLYPresentationTypeClient:
                resultString = PLYPresentationTypeClient;
                break;
            case PLYPresentationTypeFallback:
                resultString = PLYPresentationTypeFallback;
                break;
            case PLYPresentationTypeDeactivated:
                resultString = PLYPresentationTypeDeactivated;
                break;
        }

        [presentationResult setObject:[NSNumber numberWithInt:resultString] forKey:@"type"];

    }

    return presentationResult;
}


RCT_EXPORT_METHOD(startWithAPIKey:(NSString * _Nonnull)apiKey
				  stores:(NSArray * _Nullable)stores
				  userId:(NSString * _Nullable)userId
				  logLevel:(NSInteger)logLevel
                  runningMode:(NSInteger)runningMode
                  purchaselySdkVersion:(NSString * _Nullable)purchaselySdkVersion
				  initialized:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject) {

    [Purchasely setSdkBridgeVersion:purchaselySdkVersion];

    [Purchasely startWithAPIKey:apiKey
                      appUserId:userId
                    runningMode:runningMode
      paywallActionsInterceptor:nil
               storekitSettings:[StorekitSettings storeKit2]
                       logLevel:logLevel
                    initialized:^(BOOL initialized, NSError * _Nullable error) {
        resolve(@(initialized));
    }];

    [Purchasely setEventDelegate:self];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purchasePerformed) name:@"ply_purchasedSubscription" object:nil];
}

RCT_EXPORT_METHOD(setLogLevel:(NSInteger)logLevel) {
	[Purchasely setLogLevel:logLevel];
}

RCT_EXPORT_METHOD(userLogin:(NSString * _Nonnull)userId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	[Purchasely userLoginWith:userId shouldRefresh:^(BOOL shouldRefresh) {
		resolve(@(shouldRefresh));
	}];
}

RCT_EXPORT_METHOD(isDeeplinkHandled:(NSString * _Nullable) deeplink
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    if (deeplink == nil) {
        NSString *domain = @"";
        NSString *desc = NSLocalizedString(@"Deeplink must not be null", @"");
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc };
        NSError *error = [NSError errorWithDomain:domain code:-1 userInfo:userInfo];

        [self reject: reject with: error];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        resolve(@([Purchasely isDeeplinkHandledWithDeeplink:[NSURL URLWithString:deeplink]]));
    });
}

RCT_EXPORT_METHOD(userLogout) {
	[Purchasely userLogout];
}

RCT_REMAP_METHOD(isAnonymous,
                 isAnonymous:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    return resolve(@([Purchasely isAnonymous]));
}

RCT_EXPORT_METHOD(setAttribute:(NSInteger)attribute value:(NSString * _Nonnull)value) {
	[Purchasely setAttribute:attribute value:value];
}

RCT_EXPORT_METHOD(setUserAttributeWithString:(NSString * _Nonnull)key value:(NSString * _Nonnull)value) {
    [Purchasely setUserAttributeWithStringValue:value forKey:key];
}

RCT_EXPORT_METHOD(setUserAttributeWithBoolean:(NSString * _Nonnull)key value:(BOOL)value) {
    [Purchasely setUserAttributeWithBoolValue:value forKey:key];
}

RCT_EXPORT_METHOD(setUserAttributeWithNumber:(NSString * _Nonnull)key value:(double)value) {
    if (!fmod(value, 1.0)) {
        [Purchasely setUserAttributeWithIntValue:value forKey:key];
    } else {
        [Purchasely setUserAttributeWithDoubleValue:value forKey:key];
    }
}

RCT_EXPORT_METHOD(setUserAttributeWithDate:(NSString * _Nonnull)key value:(NSString * _Nonnull)value) {
    NSDateFormatter * dateFormatter = [NSDateFormatter new];
    dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    NSDate *date = [dateFormatter dateFromString:value];
    if (date != nil) {
        [Purchasely setUserAttributeWithDateValue:date forKey:key];
    } else {
        NSLog(@"[Purchasely] Cannot save date attribute %@", key);
    }
}

RCT_REMAP_METHOD(userAttribute,
                 userAttribute:(NSString * _Nonnull)key
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject){
    dispatch_async(dispatch_get_main_queue(), ^{

        id _Nullable result = [self getUserAttributeValueForRN:[Purchasely getUserAttributeFor:key]];
        resolve(result);
    });
}

RCT_EXPORT_METHOD(userAttributes:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{

        NSDictionary<NSString *, id> * _Nonnull attributes = [Purchasely userAttributes];
        NSMutableDictionary *attributesDict = [NSMutableDictionary new];
        for (NSString *key in attributes) {
            id value = attributes[key];
            [attributesDict setValue:[self getUserAttributeValueForRN:value] forKey:key];
        }
        resolve(attributesDict);
    });
}

- (id _Nullable) getUserAttributeValueForRN:(id _Nullable) value {
    if ([value isKindOfClass:[NSDate class]]) {
        NSDateFormatter * dateFormatter = [NSDateFormatter new];
        dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        NSString *dateStr = [dateFormatter stringFromDate:value];
        return dateStr;
    }

    return value;
}

RCT_EXPORT_METHOD(clearUserAttribute:(NSString * _Nonnull)key) {
    [Purchasely clearUserAttributeForKey:key];
}

RCT_EXPORT_METHOD(clearUserAttributes) {
    [Purchasely clearUserAttributes];
}


RCT_EXPORT_METHOD(setLanguage:(NSString * _Nonnull) language) {
    NSLocale *locale = [NSLocale localeWithLocaleIdentifier:language];
    [Purchasely setLanguageFrom:locale];
}

RCT_EXPORT_METHOD(showPresentation) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.presentedPresentationViewController && self.shouldReopenPaywall) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                self.shouldReopenPaywall = NO;
                [Purchasely showController:self.presentedPresentationViewController type:PLYUIControllerTypeProductPage];
            });
        }
    });
}

RCT_EXPORT_METHOD(hidePresentation) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.presentedPresentationViewController != nil) {
            UIViewController *presentingViewController = self.presentedPresentationViewController;
            while (presentingViewController.presentingViewController) {
                presentingViewController = presentingViewController.presentingViewController;
            }
            self.shouldReopenPaywall = YES;
            [presentingViewController dismissViewControllerAnimated:true completion:nil];
        }
    });
}

RCT_EXPORT_METHOD(closePresentation) {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.presentedPresentationViewController = nil;
        [Purchasely closeDisplayedPresentation];
    });
}

RCT_EXPORT_METHOD(userDidConsumeSubscriptionContent) {
    [Purchasely userDidConsumeSubscriptionContent];
}

RCT_REMAP_METHOD(getAnonymousUserId,
				 getAnonymousUserId:(RCTPromiseResolveBlock)resolve
				 reject:(RCTPromiseRejectBlock)reject)
{
	return resolve([Purchasely anonymousUserId]);
}

RCT_EXPORT_METHOD(readyToOpenDeeplink:(BOOL)ready) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [Purchasely readyToOpenDeeplink: ready];
    });
}

RCT_EXPORT_METHOD(setDefaultPresentationResultHandler:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[Purchasely setDefaultPresentationResultHandler:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
			resolve([self resultDictionaryForPresentationController:result plan:plan]);
		}];
	});
}

RCT_EXPORT_METHOD(setPaywallActionInterceptor:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [Purchasely setPaywallActionsInterceptor:^(enum PLYPresentationAction action, PLYPresentationActionParameters * _Nullable parameters, PLYPresentationInfo * _Nullable infos, void (^ _Nonnull onProcessActionHandler)(BOOL)) {
            self.onProcessActionHandler = onProcessActionHandler;
            self.paywallAction = action;
            resolve([self resultDictionaryForActionInterceptor:action parameters:parameters presentationInfos:infos]);
        }];
    });
}

RCT_EXPORT_METHOD(onProcessAction:(BOOL)processAction) {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.onProcessActionHandler(processAction);
    });
}

RCT_EXPORT_METHOD(fetchPresentation:(NSString * _Nullable)placementId
                  presentationId: (NSString * _Nullable) presentationId
                  contentId:(NSString * _Nullable)contentId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (placementId != nil) {
            [Purchasely fetchPresentationFor:placementId contentId: contentId fetchCompletion:^(PLYPresentation * _Nullable presentation, NSError * _Nullable error) {
                if (error != nil) {
                    [self reject: reject with: error];
                } else if (presentation != nil) {
                    [self.presentationsLoaded addObject:presentation];
                    resolve([self resultDictionaryForFetchPresentation:presentation]);
                }
            } completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
                if (self.purchaseResolve != nil){
                    self.purchaseResolve([self resultDictionaryForPresentationController:result plan:plan]);
                }
            }];
        } else {
            [Purchasely fetchPresentationWith:presentationId contentId: contentId fetchCompletion:^(PLYPresentation * _Nullable presentation, NSError * _Nullable error) {
                if (error != nil) {
                    [self reject: reject with: error];
                } else if (presentation != nil) {
                    [self.presentationsLoaded addObject:presentation];
                    resolve([self resultDictionaryForFetchPresentation:presentation]);
                }
            } completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
                if (self.purchaseResolve != nil) {
                    self.purchaseResolve([self resultDictionaryForPresentationController:result plan:plan]);
                }
            }];
        }
    });
}

- (PLYPresentation *) findPresentationLoadedFor:(NSString * _Nullable) presentationId {
    for (PLYPresentation *presentationLoaded in self.presentationsLoaded) {
        if ([presentationLoaded.id isEqualToString: presentationId]) {
            return presentationLoaded;
        }
    }
    return nil;
}

- (NSInteger) findIndexPresentationLoadedFor:(NSString * _Nullable) presentationId {
    NSInteger index = 0;
    for (PLYPresentation *presentationLoaded in self.presentationsLoaded) {
        if ([presentationLoaded.id isEqualToString: presentationId]) {
            return index;
        }
        index++;
    }
    return -1;
}

RCT_EXPORT_METHOD(presentPresentation:(NSDictionary<NSString *, id> * _Nullable) presentationDictionary
                  isFullscreen: (BOOL) isFullscreen
                  loadingBackgroundColor: (NSString * _Nullable)backgroundColorCode
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    if (presentationDictionary == nil) {
        [self reject:reject with:[NSError errorWithDomain:@"io.purchasely" code:1 userInfo:@{@"Error reason": @"Presentation cannot be null"}]];
        return;
    }

    self.purchaseResolve = resolve;

    dispatch_async(dispatch_get_main_queue(), ^{

        PLYPresentation *presentationLoaded = [self findPresentationLoadedFor:(NSString *)[presentationDictionary objectForKey:@"id"]];

        if (presentationLoaded == nil || presentationLoaded.controller == nil) {
            [self reject:reject with:[NSError errorWithDomain:@"io.purchasely" code:2 userInfo:@{@"Error reason": @"Presentation not loaded"}]];
            return;
        }

        [self.presentationsLoaded removeObjectAtIndex:[self findIndexPresentationLoadedFor:(NSString *)[presentationDictionary objectForKey:@"id"]]];

        if (presentationLoaded.controller != nil) {
            if (backgroundColorCode != nil) {
                UIColor *backColor = [UIColor ply_fromHex:backgroundColorCode];
                if (backColor != nil) {
                    [presentationLoaded.controller.view setBackgroundColor:backColor];
                }
            }

            if (isFullscreen) {
                presentationLoaded.controller.modalPresentationStyle = UIModalPresentationFullScreen;
            }

            self.shouldReopenPaywall = NO;

            if (self.presentedPresentationViewController != nil) {
                [Purchasely closeDisplayedPresentation];
                self.presentedPresentationViewController = presentationLoaded.controller;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [Purchasely showController:presentationLoaded.controller type: PLYUIControllerTypeProductPage];
                });
            } else {
                self.presentedPresentationViewController = presentationLoaded.controller;
                [Purchasely showController:presentationLoaded.controller type: PLYUIControllerTypeProductPage];
            }
        }
    });
}

RCT_EXPORT_METHOD(clientPresentationDisplayed:(NSDictionary<NSString *, id> * _Nullable) presentationDictionary)
{
    if (presentationDictionary == nil) {
        NSLog(@"Presentation cannot be null");
        return;
    }

    PLYPresentation *presentationLoaded = [self findPresentationLoadedFor:(NSString *)[presentationDictionary objectForKey:@"id"]];
    [Purchasely clientPresentationOpenedWith:presentationLoaded];
}

RCT_EXPORT_METHOD(clientPresentationClosed:(NSDictionary<NSString *, id> * _Nullable) presentationDictionary)
{
    if (presentationDictionary == nil) {
        NSLog(@"Presentation cannot be null");
        return;
    }
    PLYPresentation *presentationLoaded = [self findPresentationLoadedFor:(NSString *)[presentationDictionary objectForKey:@"id"]];
    [Purchasely clientPresentationClosedWith:presentationLoaded];
}

RCT_EXPORT_METHOD(presentPresentationWithIdentifier:(NSString * _Nullable)presentationVendorId
				  contentId:(NSString * _Nullable)contentId
				  isFullscreen: (BOOL) isFullscreen
				  loadingBackgroundColor: (NSString * _Nullable)backgroundColorCode
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *ctrl = [Purchasely presentationControllerWith:presentationVendorId
															  contentId:contentId
                                                                 loaded:nil
															 completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
			resolve([self resultDictionaryForPresentationController:result plan:plan]);
		}];

        if (ctrl != nil) {
			if (backgroundColorCode != nil) {
				UIColor *backColor = [UIColor ply_fromHex:backgroundColorCode];
				if (backColor != nil) {
					[ctrl.view setBackgroundColor:backColor];
				}
			}

            self.shouldReopenPaywall = NO;
            ctrl.modalPresentationStyle = isFullscreen ? UIModalPresentationFullScreen : ctrl.modalPresentationStyle;

            if (self.presentedPresentationViewController != nil) {
                [Purchasely closeDisplayedPresentation];
                self.presentedPresentationViewController = ctrl;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage];
                });
            } else {
                self.presentedPresentationViewController = ctrl;
                [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage];
            }
        }
	});
}

RCT_EXPORT_METHOD(presentPresentationForPlacement:(NSString * _Nullable)placementVendorId
                  contentId:(NSString * _Nullable)contentId
                  isFullscreen: (BOOL) isFullscreen
				  loadingBackgroundColor: (NSString * _Nullable)backgroundColorCode
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *ctrl = [Purchasely presentationControllerFor:placementVendorId
                                                             contentId:contentId
                                                                loaded:nil
                                                            completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
            resolve([self resultDictionaryForPresentationController:result plan:plan]);
        }];

        if (ctrl != nil) {
			if (backgroundColorCode != nil) {
				UIColor *backColor = [UIColor ply_fromHex:backgroundColorCode];
				if (backColor != nil) {
					[ctrl.view setBackgroundColor:backColor];
				}
			}

            self.shouldReopenPaywall = NO;
            ctrl.modalPresentationStyle = isFullscreen ? UIModalPresentationFullScreen : ctrl.modalPresentationStyle;

            if (self.presentedPresentationViewController != nil) {
                [Purchasely closeDisplayedPresentation];
                self.presentedPresentationViewController = ctrl;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage];
                });
            } else {
                self.presentedPresentationViewController = ctrl;
                [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage];
            }
        }
    });
}

RCT_EXPORT_METHOD(presentPlanWithIdentifier:(NSString * _Nonnull)planVendorId
				  presentationVendorId:(NSString * _Nullable)presentationVendorId
				  contentId:(NSString * _Nullable)contentId
				  isFullscreen: (BOOL) isFullscreen
				  loadingBackgroundColor: (NSString * _Nullable)backgroundColorCode
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *ctrl = [Purchasely planControllerFor:planVendorId
														  with:presentationVendorId
													 contentId:contentId
                                                        loaded:nil
													completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
			resolve([self resultDictionaryForPresentationController:result plan:plan]);
		}];

        if (ctrl != nil) {
			if (backgroundColorCode != nil) {
				UIColor *backColor = [UIColor ply_fromHex:backgroundColorCode];
				if (backColor != nil) {
					[ctrl.view setBackgroundColor:backColor];
				}
			}

            ctrl.modalPresentationStyle = isFullscreen ? UIModalPresentationFullScreen : ctrl.modalPresentationStyle;

            if (self.presentedPresentationViewController != nil) {
                [Purchasely closeDisplayedPresentation];
                self.presentedPresentationViewController = ctrl;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage];
                });
            } else {
                self.presentedPresentationViewController = ctrl;
                [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage];
            }
        }
	});
}

RCT_EXPORT_METHOD(presentProductWithIdentifier:(NSString * _Nonnull)productVendorId
				  presentationVendorId:(NSString * _Nullable)presentationVendorId
				  contentId:(NSString * _Nullable)contentId
				  isFullscreen: (BOOL)isFullscreen
                  loadingBackgroundColor: (NSString * _Nullable)backgroundColorCode
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *ctrl = [Purchasely productControllerFor:productVendorId
															 with:presentationVendorId
														contentId:contentId
                                                           loaded:nil
													   completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
			resolve([self resultDictionaryForPresentationController:result plan:plan]);
		}];

        if (ctrl != nil) {
			if (backgroundColorCode != nil) {
				UIColor *backColor = [UIColor ply_fromHex:backgroundColorCode];
				if (backColor != nil) {
					[ctrl.view setBackgroundColor:backColor];
				}
			}

            if (self.presentedPresentationViewController != nil) {
                [Purchasely closeDisplayedPresentation];
                self.presentedPresentationViewController = ctrl;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage];
                });
            } else {
                self.presentedPresentationViewController = ctrl;
                [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage];
            }
        }
	});
}

RCT_EXPORT_METHOD(presentSubscriptions)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *ctrl = [Purchasely subscriptionsController];
		UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:ctrl];

#if TARGET_OS_TV
		[navCtrl setNavigationBarHidden:YES];
#else
		ctrl.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone target:navCtrl action:@selector(close)];
#endif
		[Purchasely showController:navCtrl type: PLYUIControllerTypeSubscriptionList];
	});
}

RCT_EXPORT_METHOD(purchaseWithPlanVendorId:(NSString * _Nonnull)planVendorId
				  contentId:(NSString * _Nullable)contentId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[Purchasely planWith:planVendorId
					 success:^(PLYPlan * _Nonnull plan) {
			[Purchasely purchaseWithPlan:plan
							   contentId:contentId
								 success:^{
				resolve(plan.asDictionary);
			}
								 failure:^(NSError * _Nonnull error) {
				[self reject: reject with: error];
			}];
		}
					 failure:^(NSError * _Nullable error) {
			[self reject: reject with: error];
		}];
	});
}

RCT_REMAP_METHOD(restoreAllProducts,
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [Purchasely restoreAllProductsWithSuccess:^{
            resolve([NSNumber numberWithBool:true]);
        }
                                          failure:^(NSError * _Nonnull error) {
            [self reject: reject with: error];
        }];
    });
}

RCT_REMAP_METHOD(silentRestoreAllProducts,
                 silentRestoreWithResolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [Purchasely synchronizeWithSuccess:^{
            resolve([NSNumber numberWithBool:true]);
        } failure:^(NSError * _Nonnull error) {
            [self reject: reject with: error];
        }];
    });
}

RCT_EXPORT_METHOD(allProducts:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[Purchasely allProductsWithSuccess:^(NSArray<PLYProduct *> * _Nonnull products) {
			NSMutableArray *productsArray = [NSMutableArray new];

			for (PLYProduct *product in products) {
				if (product != nil) {
					[productsArray addObject: product.asDictionary];
				}
			}

			resolve(productsArray);
		} failure:^(NSError * _Nullable error) {
			[self reject: reject with: error];
		}];
	});
}

RCT_REMAP_METHOD(productWithIdentifier,
				 productWithIdentifier:(NSString * _Nonnull)productVendorId
				 resolve:(RCTPromiseResolveBlock)resolve
				 reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[Purchasely productWith:productVendorId
						success:^(PLYProduct * _Nonnull product) {
			NSDictionary* productDict = product.asDictionary;
			resolve(productDict);
		}
						failure:^(NSError * _Nullable error) {
			[self reject: reject with: error];
		}];
	});
}

RCT_EXPORT_METHOD(planWithIdentifier:(NSString * _Nonnull)planVendorId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[Purchasely planWith:planVendorId
					 success:^(PLYPlan * _Nonnull plan) {
			NSDictionary* planDict = plan.asDictionary;
			resolve(planDict);
		}
					 failure:^(NSError * _Nullable error) {
			[self reject: reject with: error];
		}];
	});
}

RCT_EXPORT_METHOD(userSubscriptions:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[Purchasely userSubscriptionsWithSuccess:^(NSArray<PLYSubscription *> * _Nullable subscriptions) {
			NSMutableArray *result = [NSMutableArray new];
			for (PLYSubscription *subscription in subscriptions) {
				[result addObject:subscription.asDictionary];
			}
			resolve(result);
		}
										 failure:^(NSError * _Nonnull error) {
			[self reject: reject with: error];
		}];
	});
}


// ****************************************************************************
#pragma mark - Events

- (NSArray<NSString *> *)supportedEvents {
	return @[@"PURCHASELY_EVENTS", @"PURCHASE_LISTENER"];
}

- (void)eventTriggered:(enum PLYEvent)event properties:(NSDictionary<NSString *, id> * _Nullable)properties {
	if (properties != nil) {
		NSDictionary<NSString *, id> *body = @{@"name": [NSString fromPLYEvent:event], @"properties": properties};
		[self sendEventWithName: @"PURCHASELY_EVENTS" body: body];
	} else {
		NSDictionary<NSString *, id> *body = @{@"name": [NSString fromPLYEvent:event]};
		[self sendEventWithName:@"PURCHASELY_EVENTS" body:body];
	}
}

- (void)purchasePerformed {
	[self sendEventWithName: @"PURCHASE_LISTENER" body: nil];
}

+ (BOOL)requiresMainQueueSetup {
	return YES;
}

// ****************************************************************************
#pragma mark - Error

- (void)reject:(RCTPromiseRejectBlock)reject with:(NSError *)error {
	reject([NSString stringWithFormat: @"%ld", (long)error.code], [error localizedDescription], error);
}

@end
