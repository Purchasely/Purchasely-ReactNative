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
		@"consumable": @(PLYPlanTypeConsumable),
		@"nonConsumable": @(PLYPlanTypeNonConsumable),
		@"autoRenewingSubscription": @(PLYPlanTypeAutoRenewingSubscription),
		@"nonRenewingSubscription": @(PLYPlanTypeNonRenewingSubscription),
		@"unknown": @(PLYPlanTypeUnknown)
	};
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
				  logLevel:(NSInteger)logLevel observerMode:(BOOL)observerMode
				  initialized:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject) {
	[Purchasely startWithAPIKey:apiKey appUserId:userId observerMode:observerMode eventDelegate:self uiDelegate:nil confirmPurchaseHandler:nil logLevel:logLevel initialized:^(BOOL initialized, NSError * _Nullable error) {
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

RCT_EXPORT_METHOD(setLoginTappedHandler:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[Purchasely setLoginTappedHandler:^(UIViewController * _Nonnull ctrl, void (^ _Nonnull closedHandler)(BOOL) ) {
			self.loginClosedHandler = closedHandler;
			resolve(nil);
		}];
	});
}

RCT_EXPORT_METHOD(onUserLoggedIn:(BOOL)userLoggedIn) {
	self.loginClosedHandler(userLoggedIn);
}

RCT_EXPORT_METHOD(setConfirmPurchaseHandler:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[Purchasely setConfirmPurchaseHandler:^(UIViewController * _Nonnull ctrl, void (^ _Nonnull authorizePurchase)(BOOL)) {
			self.authorizePurchaseHandler = authorizePurchase;
			resolve(nil);
		}];
	});
}

RCT_EXPORT_METHOD(processToPayment:(BOOL)processToPayment) {
	self.authorizePurchaseHandler(processToPayment);
}

RCT_EXPORT_METHOD(presentPresentationWithIdentifier:(NSString * _Nullable)presentationVendorId
				  contentId:(NSString * _Nullable)contentId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *ctrl = [Purchasely presentationControllerWith:presentationVendorId
															  contentId:contentId
															 completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
			resolve([self resultDictionaryForPresentationController:result plan:plan]);
		}];

		UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:ctrl];
		[navCtrl.navigationBar setTranslucent:YES];
		[navCtrl.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
		[navCtrl.navigationBar setShadowImage: [UIImage new]];
		[navCtrl.navigationBar setTintColor: [UIColor whiteColor]];

		[Purchasely showController:navCtrl type: PLYUIControllerTypeProductPage];
	});
}

RCT_EXPORT_METHOD(presentPlanWithIdentifier:(NSString * _Nonnull)planVendorId
				  presentationVendorId:(NSString * _Nullable)presentationVendorId
				  contentId:(NSString * _Nullable)contentId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *ctrl = [Purchasely planControllerFor:planVendorId
														  with:presentationVendorId
													 contentId:contentId
													completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
			resolve([self resultDictionaryForPresentationController:result plan:plan]);
		}];
		[Purchasely showController:ctrl type: PLYUIControllerTypeProductPage];
	});
}

RCT_EXPORT_METHOD(presentProductWithIdentifier:(NSString * _Nonnull)productVendorId
				  presentationVendorId:(NSString * _Nullable)presentationVendorId
				  contentId:(NSString * _Nullable)contentId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *ctrl = [Purchasely productControllerFor:productVendorId
															 with:presentationVendorId
														contentId:contentId
													   completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
			resolve([self resultDictionaryForPresentationController:result plan:plan]);
		}];
		[Purchasely showController:ctrl type: PLYUIControllerTypeProductPage];
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
