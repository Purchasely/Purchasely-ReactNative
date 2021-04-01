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

- (NSDictionary *)constantsToExport {
	return @{
		@"logLevelDebug": @(LogLevelDebug),
		@"logLevelInfo": @(LogLevelInfo),
		@"logLevelWarn": @(LogLevelWarn),
		@"logLevelError": @(LogLevelError),
		@"productResultPurchased": @(PLYProductViewControllerResultPurchased),
		@"productResultCancelled": @(PLYProductViewControllerResultCancelled),
		@"productResultRestored": @(PLYProductViewControllerResultRestored),
		@"amplitudeSessionId": @(PLYAttributeAmplitudeSessionId),
		@"firebaseAppInstanceId": @(PLYAttributeFirebaseAppInstanceId),
		@"airshipChannelId": @(PLYAttributeAirshipChannelId)
	};
}

- (NSDictionary<NSString *, NSObject *> *) resultDictionaryForPresentationController:(PLYProductViewControllerResult)result plan:(PLYPlan * _Nullable)plan {
	NSMutableDictionary<NSString *, NSObject *> *productViewResult = [NSMutableDictionary new];
	NSString *resultString;

	switch (result) {
		case PLYProductViewControllerResultPurchased:
			resultString = @"productResultPurchased";
			break;
		case PLYProductViewControllerResultRestored:
			resultString = @"productResultRestored";
			break;
		case PLYProductViewControllerResultCancelled:
			resultString = @"productResultCancelled";
			break;
	}

	[productViewResult setObject:resultString forKey:@"result"];

	if (plan != nil) {
		[productViewResult setObject:[plan asDictionary] forKey:@"plan"];
	}
	return productViewResult;
}

RCT_EXPORT_METHOD(startWithAPIKey:(NSString * _Nonnull)apiKey stores:(NSArray * _Nullable)stores userId:(NSString * _Nullable)userId logLevel:(NSInteger)logLevel observerMode:(BOOL)observerMode) {
	[Purchasely startWithAPIKey:apiKey appUserId:userId observerMode:observerMode eventDelegate:self uiDelegate:nil confirmPurchaseHandler:nil logLevel:logLevel];
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

RCT_EXPORT_METHOD(presentPresentationWithIdentifier:(NSString * _Nullable)presentationVendorId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *ctrl = [Purchasely presentationControllerWith:presentationVendorId completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
			resolve([self resultDictionaryForPresentationController:result plan:plan]);
		}];
		[Purchasely showController:ctrl type: PLYUIControllerTypeProductPage];
	});
}

RCT_EXPORT_METHOD(presentPlanWithIdentifier:(NSString * _Nonnull)planVendorId
				  presentationVendorId:(NSString * _Nullable)presentationVendorId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *ctrl = [Purchasely planControllerFor:planVendorId with:presentationVendorId completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
			resolve([self resultDictionaryForPresentationController:result plan:plan]);
		}];
		[Purchasely showController:ctrl type: PLYUIControllerTypeProductPage];
	});
}

RCT_EXPORT_METHOD(presentProductWithIdentifier:(NSString * _Nonnull)productVendorId
				  presentationVendorId:(NSString * _Nullable)presentationVendorId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *ctrl = [Purchasely productControllerFor:productVendorId with:presentationVendorId completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
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

		ctrl.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone target:navCtrl action:@selector(close)];
		[Purchasely showController:navCtrl type: PLYUIControllerTypeSubscriptionList];
	});
}

RCT_EXPORT_METHOD(purchaseWithPlanVendorId:(NSString * _Nonnull)planVendorId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[Purchasely planWith:planVendorId
					 success:^(PLYPlan * _Nonnull plan) {
			[Purchasely purchaseWithPlan:plan
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
	return @[@"APP_CONFIGURED", @"APP_INSTALLED", @"APP_STARTED", @"APP_UPDATED", @"CANCELLATION_REASON_PUBLISHED", @"DEEPLINK_OPENED", @"IN_APP_DEFERRED", @"IN_APP_PURCHASE_FAILED", @"IN_APP_PURCHASED", @"IN_APP_PURCHASING", @"IN_APP_RENEWED", @"IN_APP_RESTORED", @"LINK_OPENED", @"LOGIN_TAPPED", @"PLAN_SELECTED", @"PRESENTATION_OPENED", @"PRESENTATION_SELECTED", @"PRESENTATION_VIEWED", @"PURCHASE_CANCELLED", @"PURCHASE_CANCELLED_BY_APP", @"PURCHASE_FROM_STORE_TAPPED", @"PURCHASE_TAPPED", @"RECEIPT_CREATED", @"RECEIPT_FAILED", @"RECEIPT_VALIDATED", @"RESTORE_FAILED", @"RESTORE_STARTED", @"RESTORE_SUCCEEDED", @"STORE_PRODUCT_FETCH_FAILED", @"SUBSCRIPTION_CANCEL_TAPPED", @"SUBSCRIPTION_DETAILS_VIEWED", @"SUBSCRIPTION_PLAN_TAPPED", @"SUBSCRIPTIONS_LIST_VIEWED", @"PURCHASE_LISTENER"];
}

- (void)eventTriggered:(enum PLYEvent)event properties:(NSDictionary<NSString *,id> * _Nullable)properties {
	[self sendEventWithName: [NSString fromPLYEvent:event] body: properties];
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
