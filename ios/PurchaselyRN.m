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

RCT_EXPORT_METHOD(setAppUserId:(NSString * _Nullable)appUserId) {
  [Purchasely setAppUserId: appUserId];
}

RCT_EXPORT_METHOD(isReadyToPurchase:(BOOL)ready) {
  [Purchasely isReadyToPurchase: ready];
}

RCT_EXPORT_METHOD(presentProductWithIdentifier:(NSString * _Nonnull)productVendorId
				  with:(NSString * _Nullable)presentationVendorId
				  errorCallback: (RCTResponseSenderBlock)errorCallback
				  successCallback: (RCTResponseSenderBlock)successCallback)
{
  dispatch_async(dispatch_get_main_queue(), ^{
	UIViewController *ctrl = [Purchasely productControllerFor:productVendorId with:presentationVendorId completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
	  if (result == PLYProductViewControllerResultCancelled) {
		errorCallback(@[@"Cancelled", [NSNull null]]);
	  } else {
		successCallback(@[[NSNull null], [NSNull null]]);
	  }
	}];
	[[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:ctrl animated:true completion:nil];
  });
}

RCT_EXPORT_METHOD(presentSubscriptions)
{
  dispatch_async(dispatch_get_main_queue(), ^{
	UIViewController *ctrl = [Purchasely subscriptionsController];
	[[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:ctrl animated:true completion:nil];
  });
}

RCT_EXPORT_METHOD(purchaseWithPlanVendorId:(NSString * _Nonnull)planVendorId
				  errorCallback: (RCTResponseSenderBlock)errorCallback
				  successCallback: (RCTResponseSenderBlock)successCallback)
{
  dispatch_async(dispatch_get_main_queue(), ^{
	[Purchasely planWith:planVendorId
				 success:^(PLYPlan * _Nonnull plan) {
	  [Purchasely purchaseWithPlan:plan
						   success:^{
		successCallback(@[plan.asDictionary]);
	  }
						   failure:^(NSError * _Nonnull error) {
		errorCallback(@[error.localizedDescription]);
	  }];
	}
				 failure:^(NSError * _Nullable error) {
	  errorCallback(@[error.localizedDescription]);
	}];
  });
}

RCT_EXPORT_METHOD(restoreAllProducts: (RCTResponseSenderBlock)errorCallback
				  successCallback: (RCTResponseSenderBlock)successCallback)
{
  dispatch_async(dispatch_get_main_queue(), ^{
	[Purchasely restoreAllProductsWithSuccess:^{
	  successCallback(@[[NSNull null]]);
	}
									  failure:^(NSError * _Nonnull error) {
	  errorCallback(@[error.localizedDescription]);
	}];
  });
}

RCT_EXPORT_METHOD(productWithIdentifier:(NSString * _Nonnull)productVendorId
				  errorCallback: (RCTResponseSenderBlock)errorCallback
				  successCallback: (RCTResponseSenderBlock)successCallback)
{
  dispatch_async(dispatch_get_main_queue(), ^{
	[Purchasely productWith:productVendorId
				 success:^(PLYProduct * _Nonnull product) {
	  NSDictionary* productDict = product.asDictionary;
	  successCallback(@[productDict]);
	}
				 failure:^(NSError * _Nullable error) {
	  errorCallback(@[[error localizedDescription]]);
	}];
  });
}

RCT_EXPORT_METHOD(planWithIdentifier:(NSString * _Nonnull)planVendorId
				  errorCallback: (RCTResponseSenderBlock)errorCallback
				  successCallback: (RCTResponseSenderBlock)successCallback)
{
  dispatch_async(dispatch_get_main_queue(), ^{
	[Purchasely planWith:planVendorId
				 success:^(PLYPlan * _Nonnull plan) {
	  NSDictionary* planDict = plan.asDictionary;
	  successCallback(@[planDict]);
	}
				 failure:^(NSError * _Nullable error) {
	  errorCallback(@[[error localizedDescription]]);
	}];
  });
}

RCT_EXPORT_METHOD(userSubscriptions: (RCTResponseSenderBlock)errorCallback
				  successCallback: (RCTResponseSenderBlock)successCallback)
{
  dispatch_async(dispatch_get_main_queue(), ^{
	[Purchasely userSubscriptionsWithSuccess:^(NSArray<PLYSubscription *> * _Nullable subscriptions) {
	  NSMutableArray *result = [NSMutableArray new];
	  for (PLYSubscription *subscription in subscriptions) {
		[result addObject:subscription.asDictionary];
	  }
	  successCallback(@[result]);
	}
									 failure:^(NSError * _Nonnull error) {
	  errorCallback(@[[error localizedDescription]]);
	}];
  });
}

// ****************************************************************************
#pragma mark - Events

- (NSArray<NSString *> *)supportedEvents {
  return @[@"Purchasely-Events"];
}

- (void)eventTriggered:(enum PLYEvent)event properties:(NSDictionary<NSString *,id> * _Nullable)properties {
  [self sendEventWithName:@"Purchasely-Events" body:@{@"name": [NSString fromPLYEvent: event], @"properties": properties}];
}

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

@end
