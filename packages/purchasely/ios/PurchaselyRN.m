//
//  PurchaselyRN.m
//  The Objective-C export shim for the Swift bridge module.
//
//  React Native discovers a legacy module through class methods named
//  __rct_export__*, which only these macros can generate; Swift cannot emit
//  them. So this file is not optional, and it is the whole reason
//  BridgeExportContractTests exists: every line below is parsed as TEXT at
//  registration, not linked. A selector here that disagrees with its Swift
//  @objc(...) annotation compiles fine and fails at run time in a client app
//  with "method not found".
//
//  RULE FOR EVERY LINE: copy the selector from the Swift method's explicit
//  @objc(...) annotation, verbatim. Do not retype it.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTLog.h>

// RCTLogWarn is a variadic macro (RCTLog.h:37) over a variadic C function, and
// Swift imports neither. This is the one piece of logic the shim keeps.
void PLYRNLogWarn(NSString *message) {
    RCTLogWarn(@"%@", message);
}

// The JS name is `Purchasely` on the class `PurchaselyRN`, so this must be the
// REMAP form. The plain RCT_EXTERN_MODULE would export it as `PurchaselyRN`
// and break every JS call. BridgeExportContractTests asserts the name.
@interface RCT_EXTERN_REMAP_MODULE(Purchasely, PurchaselyRN, RCTEventEmitter)

RCT_EXTERN_METHOD(start:(NSString * _Nonnull)apiKey
                  stores:(NSArray * _Nullable)stores
                  storeKit1:(BOOL)storeKit1
                  userId:(NSString * _Nullable)userId
                  logLevel:(NSInteger)logLevel
                  runningMode:(NSInteger)runningMode
                  purchaselySdkVersion:(NSString * _Nullable)purchaselySdkVersion
                  startOptions:(NSDictionary * _Nullable)startOptions
                  initialized:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(isEligibleForIntroOffer:(NSString * _Nonnull)planVendorId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(setLogLevel:(NSInteger)logLevel)

RCT_EXTERN_METHOD(userLogin:(NSString * _Nonnull)userId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(handleDeeplink:(NSString * _Nullable) deeplink
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(userLogout:(BOOL)clearUserAttributes)

RCT_EXTERN_METHOD(isAnonymous:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(setThemeMode:(NSInteger)mode)

RCT_EXTERN_METHOD(setAttribute:(NSInteger)attribute value:(NSString * _Nonnull)value)

RCT_EXTERN_METHOD(setUserAttributeWithString:(NSString * _Nonnull)key
                  value:(NSString * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis)

RCT_EXTERN_METHOD(setUserAttributeWithBoolean:(NSString * _Nonnull)key
                  value:(BOOL)value
                  legalBasis:(NSString * _Nullable)legalBasis)

RCT_EXTERN_METHOD(setUserAttributeWithNumber:(NSString * _Nonnull)key
                  value:(double)value
                  legalBasis:(NSString * _Nullable)legalBasis)

RCT_EXTERN_METHOD(setUserAttributeWithInt:(NSString * _Nonnull)key
                  value:(NSInteger)value
                  legalBasis:(NSString * _Nullable)legalBasis)

RCT_EXTERN_METHOD(setUserAttributeWithDouble:(NSString * _Nonnull)key
                  value:(double)value
                  legalBasis:(NSString * _Nullable)legalBasis)

RCT_EXTERN_METHOD(setUserAttributeWithDate:(NSString * _Nonnull)key
                  value:(NSString * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis)

RCT_EXTERN_METHOD(setUserAttributeWithStringArray:(NSString * _Nonnull)key
                  value:(NSArray<NSString *> * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis)

RCT_EXTERN_METHOD(setUserAttributeWithBooleanArray:(NSString * _Nonnull)key
                  value:(NSArray<NSNumber *> * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis)

RCT_EXTERN_METHOD(setUserAttributeWithNumberArray:(NSString * _Nonnull)key
                  value:(NSArray<NSNumber *> * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis)

RCT_EXTERN_METHOD(setUserAttributeWithIntArray:(NSString * _Nonnull)key
                  value:(NSArray<NSNumber *> * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis)

RCT_EXTERN_METHOD(setUserAttributeWithDoubleArray:(NSString * _Nonnull)key
                  value:(NSArray<NSNumber *> * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis)

RCT_EXTERN_METHOD(incrementUserAttribute:(NSString * _Nonnull)key
                  value:(NSNumber * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis)

RCT_EXTERN_METHOD(decrementUserAttribute:(NSString * _Nonnull)key
                  value:(NSNumber * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis)

RCT_EXTERN_METHOD(userAttribute:(NSString * _Nonnull)key
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(userAttributes:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(clearUserAttribute:(NSString * _Nonnull)key)

RCT_EXTERN_METHOD(clearUserAttributes)

RCT_EXTERN_METHOD(clearBuiltInAttributes)

RCT_EXTERN_METHOD(getBuiltInAttributes:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getBuiltInAttribute:(NSString * _Nonnull)key
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(setLanguage:(NSString * _Nonnull) language)

RCT_EXTERN_METHOD(userDidConsumeSubscriptionContent)

RCT_EXTERN_METHOD(getAnonymousUserId:(RCTPromiseResolveBlock)resolve
				 reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(readyToOpenDeeplink:(BOOL)ready)

RCT_EXTERN_METHOD(allowDeeplink:(BOOL)allow)

RCT_EXTERN_METHOD(allowCampaigns:(BOOL)allow)

RCT_EXTERN_METHOD(signPromotionalOffer:(NSString * )storeProductId
                  storeOfferId:(NSString * )storeOfferId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(purchaseWithPlanVendorId:(NSString * _Nonnull)planVendorId
                  offerId:(NSString * _Nullable)offerId
				  contentId:(NSString * _Nullable)contentId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(restoreAllProducts:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(silentRestoreAllProducts:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(synchronize:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(allProducts:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(productWithIdentifier:(NSString * _Nonnull)productVendorId
				 resolve:(RCTPromiseResolveBlock)resolve
				 reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(planWithIdentifier:(NSString * _Nonnull)planVendorId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(userSubscriptions:(BOOL) invalidate
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(userSubscriptionsHistory:(BOOL)invalidateCache
                  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(setDynamicOffering:(NSString *)reference
                  planVendorId:(NSString *)planVendorId
                  offerId:(nullable NSString *)offerId
                  billingPlanType:(nullable NSString *)billingPlanType
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getDynamicOfferings:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(removeDynamicOffering:(NSString *)reference)

RCT_EXTERN_METHOD(clearDynamicOfferings)

RCT_EXTERN_METHOD(revokeDataProcessingConsent:(NSArray<NSString *> * _Nonnull)purposes)

RCT_EXTERN_METHOD(setDebugMode:(BOOL)enabled)

RCT_EXTERN_METHOD(closeAllScreens)

RCT_EXTERN_METHOD(preloadPresentation:(NSString *)requestId
                  payload:(NSDictionary *)payload
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(displayPresentation:(NSString *)requestId
                  payload:(NSDictionary *)payload
                  transition:(NSDictionary *)transition
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(setDefaultPresentationDismissHandler)

RCT_EXTERN_METHOD(removeDefaultPresentationDismissHandler)

RCT_EXTERN_METHOD(closePresentation:(NSString *)requestId)

RCT_EXTERN_METHOD(goBackToPreviousScreen:(NSString *)requestId)

RCT_EXTERN_METHOD(clientPresentationDisplayed:(NSDictionary<NSString *, id> * _Nullable)presentationMap)

RCT_EXTERN_METHOD(clientPresentationClosed:(NSDictionary<NSString *, id> * _Nullable)presentationMap)

RCT_EXTERN_METHOD(registerActionInterceptor:(NSString *)kind)

RCT_EXTERN_METHOD(unregisterActionInterceptor:(NSString *)kind)

RCT_EXTERN_METHOD(completeActionInterceptor:(NSString *)callbackId result:(NSString *)result)

@end
