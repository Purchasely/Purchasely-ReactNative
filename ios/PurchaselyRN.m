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

@implementation PurchaselyRN

RCT_EXPORT_MODULE(Purchasely);

- (instancetype)init {
	self = [super init];

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
		@"amplitudeSessionId": @(PLYAttributeAmplitudeSessionId),
		@"firebaseAppInstanceId": @(PLYAttributeFirebaseAppInstanceId),
		@"airshipChannelId": @(PLYAttributeAirshipChannelId),
        @"batchInstallationId": @(PLYAttributeBatchInstallationId),
        @"adjustId": @(PLYAttributeAdjustId),
        @"appsflyerId": @(PLYAttributeAppsflyerId),
        @"onesignalPlayerId": @(PLYAttributeOneSignalPlayerId),
        @"mixpanelDistinctId": @(PLYAttributeMixpanelDistinctId),
        @"clevertapId": @(PLYAttributeClevertapId),
		@"consumable": @(PLYPlanTypeConsumable),
		@"nonConsumable": @(PLYPlanTypeNonConsumable),
		@"autoRenewingSubscription": @(PLYPlanTypeAutoRenewingSubscription),
		@"nonRenewingSubscription": @(PLYPlanTypeNonRenewingSubscription),
		@"unknown": @(PLYPlanTypeUnknown),
        @"runningModeTransactionOnly": @(PLYRunningModeTransactionOnly),
        @"runningModeObserver": @(PLYRunningModeObserver),
        @"runningModePaywallOnly": @(PLYRunningModePaywallOnly),
        @"runningModePaywallObserver": @(PLYRunningModePaywallObserver),
        @"runningModeFull": @(PLYRunningModeFull)
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
    return productViewResult;
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
    
    [Purchasely startWithAPIKey:apiKey appUserId:userId runningMode:runningMode eventDelegate:self uiDelegate:nil paywallActionsInterceptor:nil logLevel:logLevel initialized:^(BOOL initialized, NSError * _Nullable error) {
        resolve(@(initialized));
    }];

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

RCT_EXPORT_METHOD(userLogout) {
	[Purchasely userLogout];
}

RCT_EXPORT_METHOD(setAttribute:(NSInteger)attribute value:(NSString * _Nonnull)value) {
	[Purchasely setAttribute:attribute value:value];
}

RCT_EXPORT_METHOD(setLanguage:(NSString * _Nonnull) language) {
    NSLocale *locale = [NSLocale localeWithLocaleIdentifier:language];
    [Purchasely setLanguageFrom:locale];
}

RCT_EXPORT_METHOD(closePaywall) {
    if (self.presentedPresentationViewController != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.presentedPresentationViewController dismissViewControllerAnimated:true completion:^{
                self.presentedPresentationViewController = nil;
            }];
        });
    }
}

RCT_REMAP_METHOD(getAnonymousUserId,
				 getAnonymousUserId:(RCTPromiseResolveBlock)resolve
				 reject:(RCTPromiseRejectBlock)reject)
{
	return resolve([Purchasely anonymousUserId]);
}

RCT_EXPORT_METHOD(isReadyToPurchase:(BOOL)ready) {
	[Purchasely isReadyToPurchase: ready];
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
            resolve([self resultDictionaryForActionInterceptor:action parameters:parameters presentationInfos:infos]);
        }];
    });
}

RCT_EXPORT_METHOD(onProcessAction:(BOOL)processAction) {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.onProcessActionHandler(processAction);
    });
}

RCT_EXPORT_METHOD(presentPresentationWithIdentifier:(NSString * _Nullable)presentationVendorId
				  contentId:(NSString * _Nullable)contentId
				  isFullscreen: (BOOL) isFullscreen
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
            UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:ctrl];
            [navCtrl.navigationBar setTranslucent:YES];
            [navCtrl.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
            [navCtrl.navigationBar setShadowImage: [UIImage new]];
            [navCtrl.navigationBar setTintColor: [UIColor whiteColor]];

            self.presentedPresentationViewController = navCtrl;

            if (isFullscreen) {
                navCtrl.modalPresentationStyle = UIModalPresentationFullScreen;
            }
            [Purchasely showController:navCtrl type: PLYUIControllerTypeProductPage];
        }
	});
}

RCT_EXPORT_METHOD(presentPresentationForPlacement:(NSString * _Nullable)placementVendorId
                  contentId:(NSString * _Nullable)contentId
                  isFullscreen: (BOOL) isFullscreen
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
            UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:ctrl];
            [navCtrl.navigationBar setTranslucent:YES];
            [navCtrl.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
            [navCtrl.navigationBar setShadowImage: [UIImage new]];
            [navCtrl.navigationBar setTintColor: [UIColor whiteColor]];

            self.presentedPresentationViewController = navCtrl;

            if (isFullscreen) {
                navCtrl.modalPresentationStyle = UIModalPresentationFullScreen;
            }
            [Purchasely showController:navCtrl type: PLYUIControllerTypeProductPage];
        }
    });
}

RCT_EXPORT_METHOD(presentPlanWithIdentifier:(NSString * _Nonnull)planVendorId
				  presentationVendorId:(NSString * _Nullable)presentationVendorId
				  contentId:(NSString * _Nullable)contentId
				  isFullscreen: (BOOL) isFullscreen
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
            UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:ctrl];
            [navCtrl.navigationBar setTranslucent:YES];
            [navCtrl.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
            [navCtrl.navigationBar setShadowImage: [UIImage new]];
            [navCtrl.navigationBar setTintColor: [UIColor whiteColor]];
            
            self.presentedPresentationViewController = navCtrl;
            
            if (isFullscreen) {
                navCtrl.modalPresentationStyle = UIModalPresentationFullScreen;
            }
            
            [Purchasely showController:navCtrl type: PLYUIControllerTypeProductPage];
        }
	});
}

RCT_EXPORT_METHOD(presentProductWithIdentifier:(NSString * _Nonnull)productVendorId
				  presentationVendorId:(NSString * _Nullable)presentationVendorId
				  contentId:(NSString * _Nullable)contentId
				  isFullscreen: (BOOL) isFullscreen
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
            UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:ctrl];
            [navCtrl.navigationBar setTranslucent:YES];
            [navCtrl.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
            [navCtrl.navigationBar setShadowImage: [UIImage new]];
            [navCtrl.navigationBar setTintColor: [UIColor whiteColor]];

            self.presentedPresentationViewController = navCtrl;

            if (isFullscreen) {
                navCtrl.modalPresentationStyle = UIModalPresentationFullScreen;
            }

            [Purchasely showController:navCtrl type: PLYUIControllerTypeProductPage];
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
        [Purchasely silentRestoreAllProductsWithSuccess:^{
            resolve([NSNumber numberWithBool:true]);
        }
                                                failure:^(NSError * _Nonnull error) {
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
