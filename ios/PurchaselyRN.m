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
		@"productResultRestored": @(PLYProductViewControllerResultRestored)
	};
}

RCT_EXPORT_METHOD(startWithAPIKey:(NSString * _Nonnull)apiKey stores:(NSArray * _Nullable)stores appUserId:(NSString * _Nullable)appUserId logLevel:(NSInteger)logLevel) {
	[Purchasely startWithAPIKey:apiKey appUserId:appUserId eventDelegate:self uiDelegate:nil logLevel:logLevel];
}

RCT_EXPORT_METHOD(setLogLevel:(NSInteger)logLevel) {
	[Purchasely setLogLevel:logLevel];
}

RCT_EXPORT_METHOD(userLogin:(NSString * _Nullable)userId) {
	[Purchasely userLoginWith: userId];
}

RCT_EXPORT_METHOD(userLogout) {
	[Purchasely userLogout];
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
			resolve(productViewResult);

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
	return @[@"APP_INSTALLED", @"APP_UPDATED", @"APP_STARTED", @"DEEPLINK_OPENED", @"PRESENTATION_VIEWED", @"LOGIN_TAPPED", @"PURCHASE_FROM_STORE_TAPPED", @"PURCHASE_TAPPED", @"PURCHASE_CANCELLED", @"IN_APP_PURCHASING", @"IN_APP_PURCHASED", @"IN_APP_RENEWED", @"RECEIPT_CREATED", @"RECEIPT_VALIDATED", @"RECEIPT_FAILED", @"RESTORE_STARTED", @"IN_APP_RESTORED", @"RESTORE_SUCCEEDED", @"RESTORE_FAILED", @"IN_APP_DEFERRED", @"IN_APP_PURCHASE_FAILED", @"LINK_OPENED", @"SUBSCRIPTIONS_LIST_VIEWED", @"SUBSCRIPTION_DETAILS_VIEWED", @"SUBSCRIPTION_CANCEL_TAPPED", @"SUBSCRIPTION_PLAN_TAPPED", @"CANCELLATION_REASON_PUBLISHED"];
}

- (void)eventTriggered:(enum PLYEvent)event properties:(NSDictionary<NSString *,id> * _Nullable)properties {
	[self sendEventWithName: [NSString fromPLYEvent:event] body: properties];
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
