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

static NSMutableArray<PLYPresentation *> *_presentationsLoaded;
static RCTPromiseResolveBlock _purchaseResolve;
static UIViewController *_sharedViewController;

+ (UIViewController *)sharedViewController {
    if (!_sharedViewController) {
        _sharedViewController = [UIViewController new];
    }
    return _sharedViewController;
}

+ (void)setSharedViewController:(UIViewController *)viewController {
    _sharedViewController = viewController;
}

+ (NSMutableArray<PLYPresentation *> *)presentationsLoaded {
    return _presentationsLoaded;
}

+ (void)setPresentationsLoaded:(NSMutableArray<PLYPresentation *> *)presentationsLoaded {
    _presentationsLoaded = presentationsLoaded;
}

+ (RCTPromiseResolveBlock)purchaseResolve {
    return _purchaseResolve;
}

+ (void)setPurchaseResolve:(RCTPromiseResolveBlock)purchaseResolve {
    _purchaseResolve = [purchaseResolve copy];
}

- (instancetype)init {
	self = [super init];

    PurchaselyRN.presentationsLoaded = [NSMutableArray new];
    self.shouldReopenPaywall = NO;
    self.shouldEmit = NO;

	[Purchasely setAppTechnology:PLYAppTechnologyReactNative];
	return self;
}

- (NSDictionary *)constantsToExport {
	return @{
    @"logLevelDebug": @(PLYLogLevelDebug),
		@"logLevelInfo": @(PLYLogLevelInfo),
    @"logLevelWarn": @(PLYLogLevelWarn),
		@"logLevelError": @(PLYLogLevelError),
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
        @"moEngageUniqueId": @(PLYAttributeMoengageUniqueId),
        @"batchCustomUserId": @(PLYAttributeBatchCustomUserId),
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
        @"presentationTypeClient": @(PLYPresentationTypeClient),
        @"themeLight": @(PLYThemeModeLight),
        @"themeDark": @(PLYThemeModeDark),
        @"themeSystem": @(PLYThemeModeSystem),
    @"userAttributeSourcePurchasely": @(PLYUserAttributeSourcePurchasely),
    @"userAttributeSourceClient": @(PLYUserAttributeSourceClient),
    @"userAttributeString": @(PLYUserAttributeTypeString),
    @"userAttributeBoolean": @(PLYUserAttributeTypeBool),
    @"userAttributeInt": @(PLYUserAttributeTypeInt),
    @"userAttributeFloat": @(PLYUserAttributeTypeDouble),
    @"userAttributeDate": @(PLYUserAttributeTypeDate),
    @"userAttributeStringArray": @(PLYUserAttributeTypeStringArray),
    @"userAttributeIntArray": @(PLYUserAttributeTypeIntArray),
    @"userAttributeFloatArray": @(PLYUserAttributeTypeDoubleArray),
    @"userAttributeBooleanArray": @(PLYUserAttributeTypeBoolArray)
	};
}

static NSString * PLYWebCheckoutProviderToString(PLYWebCheckoutProvider provider) {
    switch (provider) {
        case PLYWebCheckoutProviderStripe:
            return @"stripe";
        case PLYWebCheckoutProviderOther:
            return @"other";
        default:
            return @"unknown";
    }
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
    case PLYPresentationActionCloseAll:
      actionString = @"close_all";
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
    case PLYPresentationActionOpenPlacement:
      actionString = @"open_placement";
      break;
    case PLYPresentationActionWebCheckout:
      actionString = @"web_checkout";
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

        if (params.clientReferenceId != nil) {
            [paramsResult setObject:params.clientReferenceId forKey:@"clientReferenceId"];
        }

        if (params.url != nil) {
            [paramsResult setObject:params.url.absoluteString forKey:@"url"];
        }

        if (params.title != nil) {
            [paramsResult setObject:params.title forKey:@"title"];
        }

        if (params.plan != nil) {
            [paramsResult setObject:[params.plan asDictionary] forKey:@"plan"];
        }

        if (params.promoOffer != nil) {
            NSMutableDictionary<NSString *, NSObject *> *promoOffer = [NSMutableDictionary new];
            if (params.promoOffer.vendorId != nil) {
                [promoOffer setObject:params.promoOffer.vendorId forKey:@"vendorId"];
            }
            if (params.promoOffer.storeOfferId != nil) {
                [promoOffer setObject:params.promoOffer.storeOfferId forKey:@"storeOfferId"];
            }
            [paramsResult setObject:promoOffer forKey:@"offer"];
        }

        if (params.presentation != nil) {
            [paramsResult setObject:params.presentation forKey:@"presentation"];
        }

        if (params.placement != nil) {
            [paramsResult setObject:params.placement forKey:@"placement"];
        }

        if (params.queryParameterKey != nil) {
            [paramsResult setObject:params.queryParameterKey forKey:@"queryParameterKey"];
        }

        NSString *webCheckoutProviderString = PLYWebCheckoutProviderToString(params.webCheckoutProvider);
        [paramsResult setObject:webCheckoutProviderString forKey:@"webCheckoutProvider"];

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
            NSMutableArray *plans = [NSMutableArray new];

            for (PLYPresentationPlan *plan in presentation.plans) {
                [plans addObject:plan.asDictionary];
            }
            [presentationResult setObject:plans forKey:@"plans"];
        }

        if (presentation.metadata != nil) {

            NSDictionary<NSString *,id> *rawMetadata = [presentation.metadata getRawMetadata];
            NSMutableDictionary<NSString *,id> *resultDict = [NSMutableDictionary dictionary];

            dispatch_group_t group = dispatch_group_create();
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

            for (NSString *key in rawMetadata)  {
                id value = rawMetadata[key];

                if ([value isKindOfClass: [NSString class]]) {
                    dispatch_group_enter(group); // Enter the dispatch group before making the async call
                    [presentation.metadata getStringWith:key completion:^(NSString * _Nullable result) {
                        [resultDict setObject:result forKey:key];
                        dispatch_group_leave(group); // Leave the dispatch group after the async call is completed
                    }];
                } else {
                    [resultDict setObject:value forKey:key];
                }
            }

            dispatch_group_notify(group, queue, ^{
                // Code to execute after all async calls are completed
                [presentationResult setObject:resultDict forKey:@"metadata"];
                dispatch_semaphore_signal(semaphore);
            });

            // Wait until all async calls are completed
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
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
      
        [presentationResult setObject:[NSNumber numberWithInt:presentation.height] forKey:@"height"];

    }

    return presentationResult;
}

RCT_EXPORT_METHOD(start:(NSString * _Nonnull)apiKey
                  stores:(NSArray * _Nullable)stores
                  storeKit1:(BOOL)storeKit1
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
               storekitSettings: storeKit1 ? [StorekitSettings storeKit1] : [StorekitSettings storeKit2]
                       logLevel:logLevel
                    initialized:^(BOOL initialized, NSError * _Nullable error) {
        if (error != nil) {
            [self reject: reject with: error];
        } else {
            resolve(@(initialized));
        }
    }];

  
    [Purchasely setEventDelegate: self];

    [Purchasely setUserAttributeDelegate: self];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purchasePerformed) name:@"ply_purchasedSubscription" object:nil];
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
        if (error != nil) {
            [self reject: reject with: error];
        } else {
            resolve(@(initialized));
        }
    }];

    [Purchasely setEventDelegate: self];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purchasePerformed) name:@"ply_purchasedSubscription" object:nil];
}

RCT_EXPORT_METHOD(isEligibleForIntroOffer:(NSString * _Nonnull)planVendorId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [Purchasely planWith:planVendorId
                     success:^(PLYPlan * _Nonnull plan) {
            [plan isEligibleForIntroductoryOffer:^(BOOL isEligible) {
                resolve(@(isEligible));
            }];
        } failure:^(NSError * _Nullable error) {
            [self reject: reject with: error];
        }];
    });
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
  [Purchasely userLogout:YES];
}

RCT_REMAP_METHOD(isAnonymous,
                 isAnonymous:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    return resolve(@([Purchasely isAnonymous]));
}

RCT_EXPORT_METHOD(setThemeMode:(NSInteger)mode) {
    [Purchasely setThemeMode: mode];
}

#pragma mark - Legal basis mapper

- (PLYDataProcessingLegalBasis)legalBasisFromString:(NSString * _Nullable)basis {
    if (![basis isKindOfClass:NSString.class]) { return PLYDataProcessingLegalBasisOptional; }
    NSString *b = basis.uppercaseString;
    if ([b isEqualToString:@"ESSENTIAL"]) { return PLYDataProcessingLegalBasisEssential; }
    // default/fallback
    return PLYDataProcessingLegalBasisOptional;
}

RCT_EXPORT_METHOD(setAttribute:(NSInteger)attribute value:(NSString * _Nonnull)value) {
	[Purchasely setAttribute:attribute value:value];
}

RCT_EXPORT_METHOD(setUserAttributeWithString:(NSString * _Nonnull)key
                  value:(NSString * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis) {
    [Purchasely setUserAttributeWithStringValue:value
                                         forKey:key
                         processingLegalBasis:[self legalBasisFromString:legalBasis]];
}

RCT_EXPORT_METHOD(setUserAttributeWithBoolean:(NSString * _Nonnull)key
                  value:(BOOL)value
                  legalBasis:(NSString * _Nullable)legalBasis) {
    [Purchasely setUserAttributeWithBoolValue:value
                                       forKey:key
                       processingLegalBasis:[self legalBasisFromString:legalBasis]];
}

RCT_EXPORT_METHOD(setUserAttributeWithNumber:(NSString * _Nonnull)key
                  value:(double)value
                  legalBasis:(NSString * _Nullable)legalBasis) {
    PLYDataProcessingLegalBasis lb = [self legalBasisFromString:legalBasis];
    if (!fmod(value, 1.0)) {
        [Purchasely setUserAttributeWithIntValue:(NSInteger)value
                                          forKey:key
                          processingLegalBasis:lb];
    } else {
        [Purchasely setUserAttributeWithDoubleValue:value
                                             forKey:key
                             processingLegalBasis:lb];
    }
}

RCT_EXPORT_METHOD(setUserAttributeWithDate:(NSString * _Nonnull)key
                  value:(NSString * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis) {
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    NSDate *date = [dateFormatter dateFromString:value];

    if (date != nil) {
        [Purchasely setUserAttributeWithDateValue:date
                                           forKey:key
                           processingLegalBasis:[self legalBasisFromString:legalBasis]];
    } else {
        NSLog(@"[Purchasely] Cannot save date attribute %@: invalid ISO-8601 string %@", key, value);
    }
}

// String Array
RCT_EXPORT_METHOD(setUserAttributeWithStringArray:(NSString * _Nonnull)key
                  value:(NSArray<NSString *> * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis) {
    [Purchasely setUserAttributeWithStringArray:value
                                         forKey:key
                         processingLegalBasis:[self legalBasisFromString:legalBasis]];
}

// Boolean Array
RCT_EXPORT_METHOD(setUserAttributeWithBooleanArray:(NSString * _Nonnull)key
                  value:(NSArray<NSNumber *> * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis) {
    // Normalize to pure BOOL array to avoid NSDecimalNumber surprises from JS
    NSMutableArray<NSNumber *> *bools = [NSMutableArray arrayWithCapacity:value.count];
    for (NSNumber *n in value) { [bools addObject:@(n.boolValue)]; }

    [Purchasely setUserAttributeWithBoolArray:bools
                                       forKey:key
                       processingLegalBasis:[self legalBasisFromString:legalBasis]];
}

// Number Array
RCT_EXPORT_METHOD(setUserAttributeWithNumberArray:(NSString * _Nonnull)key
                  value:(NSArray<NSNumber *> * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis) {
    PLYDataProcessingLegalBasis lb = [self legalBasisFromString:legalBasis];

    NSMutableArray<NSNumber *> *intArray = [NSMutableArray new];
    NSMutableArray<NSNumber *> *doubleArray = [NSMutableArray new];

    for (NSNumber *numberValue in value) {
        double number = numberValue.doubleValue;
        if (!fmod(number, 1.0)) {         // integer
            [intArray addObject:@(numberValue.integerValue)];
        } else {                          // double
            [doubleArray addObject:@(number)];
        }
    }

    if (intArray.count > 0) {
        [Purchasely setUserAttributeWithIntArray:intArray
                                          forKey:key
                          processingLegalBasis:lb];
    }
    if (doubleArray.count > 0) {
        [Purchasely setUserAttributeWithDoubleArray:doubleArray
                                            forKey:key
                            processingLegalBasis:lb];
    }
}

RCT_EXPORT_METHOD(incrementUserAttribute:(NSString * _Nonnull)key
                  value:(NSNumber * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis) {
    [Purchasely incrementUserAttributeWithKey:key
                                        value:value.intValue
                        processingLegalBasis:[self legalBasisFromString:legalBasis]];
}

RCT_EXPORT_METHOD(decrementUserAttribute:(NSString * _Nonnull)key
                  value:(NSNumber * _Nonnull)value
                  legalBasis:(NSString * _Nullable)legalBasis) {
    [Purchasely decrementUserAttributeWithKey:key
                                        value:value.intValue
                        processingLegalBasis:[self legalBasisFromString:legalBasis]];
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

RCT_EXPORT_METHOD(clearBuiltInAttributes) {
    [Purchasely clearBuiltInAttributes];
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
                [Purchasely showController:self.presentedPresentationViewController type:PLYUIControllerTypeProductPage from:nil];
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

RCT_EXPORT_METHOD(signPromotionalOffer:(NSString * )storeProductId
                  storeOfferId:(NSString * )storeOfferId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 12.2, *)) {
            [Purchasely signPromotionalOfferWithStoreProductId:storeProductId storeOfferId:storeOfferId success:^(PLYOfferSignature * _Nonnull signature) {
                NSDictionary* result = signature.asDictionary;
                resolve(result);
            } failure:^(NSError * _Nullable error) {
                [self reject: reject with: error];
            }];
        } else {
            [self reject: reject with: nil];
        }
    });
}

RCT_EXPORT_METHOD(fetchPresentation:(NSString * _Nullable)placementId
                  presentationId: (NSString * _Nullable) presentationId
                  contentId:(NSString * _Nullable)contentId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{

        [PurchaselyRN setSharedViewController:nil];
        for (PLYPresentation *presentation in PurchaselyRN.presentationsLoaded) {
            if ([presentation.id isEqualToString:presentationId]) {
                [PurchaselyRN.presentationsLoaded removeObject:presentation];
            }
        }

        if (placementId != nil) {
            [Purchasely fetchPresentationFor:placementId contentId: contentId fetchCompletion:^(PLYPresentation * _Nullable presentation, NSError * _Nullable error)
             {
                if (error != nil) {
                    [self reject: reject with: error];
                } else if (presentation != nil) {
                    [PurchaselyRN.presentationsLoaded addObject:presentation];
                    resolve([self resultDictionaryForFetchPresentation:presentation]);
                }
            } completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
                if (PurchaselyRN.purchaseResolve != nil){
                    PurchaselyRN.purchaseResolve([self resultDictionaryForPresentationController:result plan:plan]);
                }
            } loadedCompletion:nil];
        } else {
            [Purchasely fetchPresentationWith:presentationId contentId: contentId fetchCompletion:^(PLYPresentation * _Nullable presentation, NSError * _Nullable error) {
                if (error != nil) {
                    [self reject: reject with: error];
                } else if (presentation != nil) {
                    [PurchaselyRN.presentationsLoaded addObject:presentation];
                    resolve([self resultDictionaryForFetchPresentation:presentation]);
                }
            } completion:^(enum PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
                if (PurchaselyRN.purchaseResolve != nil) {
                    PurchaselyRN.purchaseResolve([self resultDictionaryForPresentationController:result plan:plan]);
                }
            } loadedCompletion:nil];
        }
    });
}

- (PLYPresentation *) findPresentationLoadedFor:(NSString * _Nullable)presentationId
                                    placementId:(NSString * _Nullable)placementId {
    for (PLYPresentation *presentationLoaded in PurchaselyRN.presentationsLoaded) {
        if ([presentationLoaded.id isEqualToString: presentationId] && [presentationLoaded.placementId isEqualToString: placementId]) {
            return presentationLoaded;
        }
    }
    return nil;
}

- (NSInteger) findIndexPresentationLoadedFor:(NSString * _Nullable)presentationId
                                 placementId:(NSString * _Nullable)placementId {
    NSInteger index = 0;
    for (PLYPresentation *presentationLoaded in PurchaselyRN.presentationsLoaded) {
        if ([presentationLoaded.id isEqualToString: presentationId] && [presentationLoaded.placementId isEqualToString: placementId]) {
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

    PurchaselyRN.purchaseResolve = resolve;

    dispatch_async(dispatch_get_main_queue(), ^{

        PLYPresentation *presentationLoaded = [self findPresentationLoadedFor:(NSString *)[presentationDictionary objectForKey:@"id"] placementId:(NSString *)[presentationDictionary objectForKey:@"placementId"]];

        if (presentationLoaded == nil) {
            reject(@"presentation_failure", [NSString stringWithFormat:@"No presentation found for this placement %@", [presentationDictionary objectForKey:@"placementId"]], nil);
            return;
        }

        if (presentationLoaded.controller == nil) {
            reject(@"presentation_failure", [NSString stringWithFormat:@"No Purchasely presentation attached to this placement %@", [presentationDictionary objectForKey:@"placementId"]], nil);
            return;
        }

        [PurchaselyRN.presentationsLoaded removeObjectAtIndex:[self findIndexPresentationLoadedFor:(NSString *)[presentationDictionary objectForKey:@"id"] placementId:(NSString *)[presentationDictionary objectForKey:@"placementId"]]];

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
                  // if presentationLoaded flowId is not nil then display
                  if (presentationLoaded.isFlow) {
                    [presentationLoaded displayFrom:nil];
                  } else {
                    [Purchasely showController:presentationLoaded.controller type: PLYUIControllerTypeProductPage from:nil];
                  }
                });
            } else {
                self.presentedPresentationViewController = presentationLoaded.controller;
                if (presentationLoaded.isFlow) {
                  [presentationLoaded displayFrom:nil];
                } else {
                  [Purchasely showController:presentationLoaded.controller type: PLYUIControllerTypeProductPage from:nil];
                }
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

    PLYPresentation *presentationLoaded = [self findPresentationLoadedFor:(NSString *)[presentationDictionary objectForKey:@"id"] placementId:(NSString *)[presentationDictionary objectForKey:@"placementId"]];
    [Purchasely clientPresentationOpenedWith:presentationLoaded];
}

RCT_EXPORT_METHOD(clientPresentationClosed:(NSDictionary<NSString *, id> * _Nullable) presentationDictionary)
{
    if (presentationDictionary == nil) {
        NSLog(@"Presentation cannot be null");
        return;
    }
    PLYPresentation *presentationLoaded = [self findPresentationLoadedFor:(NSString *)[presentationDictionary objectForKey:@"id"] placementId:(NSString *)[presentationDictionary objectForKey:@"placementId"]];
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
                    [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage from:nil];
                });
            } else {
                self.presentedPresentationViewController = ctrl;
                [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage from:nil];
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
                    [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage from:nil];
                });
            } else {
                self.presentedPresentationViewController = ctrl;
                [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage from:nil];
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
                    [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage from:nil];
                });
            } else {
                self.presentedPresentationViewController = ctrl;
                [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage from:nil];
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
                    [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage from:nil];
                });
            } else {
                self.presentedPresentationViewController = ctrl;
                [Purchasely showController:ctrl type: PLYUIControllerTypeProductPage from:nil];
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
		[Purchasely showController:navCtrl type: PLYUIControllerTypeSubscriptionList from:nil];
	});
}

RCT_EXPORT_METHOD(purchaseWithPlanVendorId:(NSString * _Nonnull)planVendorId
                  offerId:(NSString * _Nullable)offerId
				  contentId:(NSString * _Nullable)contentId
				  resolve:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{

		[Purchasely planWith:planVendorId
					 success:^(PLYPlan * _Nonnull plan) {

            if (@available(iOS 12.2, macOS 12.0, tvOS 15.0, watchOS 8.0, *)) {

                NSString *storeOfferId = nil;
                for (PLYPromoOffer *promoOffer in plan.promoOffers) {
                    if ([promoOffer.vendorId isEqualToString:offerId]) {
                        storeOfferId = promoOffer.storeOfferId;
                        break;
                    }
                }

                if (storeOfferId) {
                    [Purchasely purchaseWithPromotionalOfferWithPlan:plan
                                                           contentId:contentId
                                                        storeOfferId:storeOfferId
                                                             success:^{
                        resolve(plan.asDictionary);
                    } failure:^(NSError * _Nonnull error) {
                        [self reject: reject with: error];
                    }];
                } else {
                    [Purchasely purchaseWithPlan:plan
                                       contentId:contentId
                                         success:^{
                        resolve(plan.asDictionary);
                    } failure:^(NSError * _Nonnull error) {
                        [self reject: reject with: error];
                    }];
                }
            } else {
                [Purchasely purchaseWithPlan:plan
                                   contentId:contentId
                                     success:^{
                    resolve(plan.asDictionary);
                } failure:^(NSError * _Nonnull error) {
                    [self reject: reject with: error];
                }];
            }

		} failure:^(NSError * _Nullable error) {
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

RCT_EXPORT_METHOD(synchronize:(RCTPromiseResolveBlock)resolve
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

RCT_EXPORT_METHOD(userSubscriptions:(BOOL) invalidate
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [Purchasely userSubscriptions:invalidate
                              success:^(NSArray<PLYSubscription *> * _Nullable subscriptions) {
            NSMutableArray *result = [NSMutableArray new];
            for (PLYSubscription *subscription in subscriptions) {
                [result addObject:subscription.asDictionary];
            }
            resolve(result);
        } failure:^(NSError * _Nonnull error) {
            [self reject: reject with: error];
        }];
  });
}


RCT_EXPORT_METHOD(userSubscriptionsHistory:(RCTPromiseResolveBlock)resolve
				  reject:(RCTPromiseRejectBlock)reject)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[Purchasely userSubscriptionsHistory:false
                              success:^(NSArray<PLYSubscription *> * _Nullable subscriptions) {
            NSMutableArray *result = [NSMutableArray new];
            for (PLYSubscription *subscription in subscriptions) {
                [result addObject:subscription.asDictionary];
            }
            resolve(result);
        } failure:^(NSError * _Nonnull error) {
            [self reject: reject with: error];
        }];
	});
}

RCT_EXPORT_METHOD(setDynamicOffering:(NSString *)reference
                  planVendorId:(NSString *)planVendorId
                  offerId:(nullable NSString *)offerId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
      [Purchasely setDynamicOfferingWithReference:reference planVendorId:planVendorId offerVendorId:offerId completion:^(BOOL result) {
        resolve(@(result));
      }];
    });
}

RCT_EXPORT_METHOD(getDynamicOfferings:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [Purchasely getDynamicOfferingsWithCompletion:^(NSArray<PLYOffering *> * _Nonnull offerings) {
            NSMutableArray *result = [NSMutableArray new];
            
            for (PLYOffering *offering in offerings) {
                NSMutableDictionary *map = [NSMutableDictionary new];
                map[@"reference"] = offering.reference;
                map[@"planVendorId"] = offering.planId;
                if (offering.offerId != nil) {
                    map[@"offerVendorId"] = offering.offerId;
                }
                [result addObject:map];
            }
            resolve(result);
        }];
    });
}

RCT_EXPORT_METHOD(removeDynamicOffering:(NSString *)reference)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [Purchasely removeDynamicOfferingWithReference:reference];
    });
}

RCT_EXPORT_METHOD(clearDynamicOfferings)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [Purchasely clearDynamicOfferings];
    });
}

- (NSSet<PLYDataProcessingPurpose *> *)mapPurposesFromStrings:(NSArray<NSString *> *)strings {
  NSMutableSet<PLYDataProcessingPurpose *> *result = [NSMutableSet set];
  
  if ([strings containsObject:@"all-non-essentials"]) {
      [result addObject:PLYDataProcessingPurpose.allNonEssentials];
      return result;
  }
  
  for (NSString *purpose in strings) {
    NSString *p = purpose.lowercaseString;
    if ([p isEqualToString:@"analytics"]) {
      [result addObject:PLYDataProcessingPurpose.analytics];
    } else if ([p isEqualToString:@"identified-analytics"]) {
      [result addObject:PLYDataProcessingPurpose.identifiedAnalytics];
    } else if ([p isEqualToString:@"campaigns"]) {
      [result addObject:PLYDataProcessingPurpose.campaigns];
    } else if ([p isEqualToString:@"personalization"]) {
      [result addObject:PLYDataProcessingPurpose.personalization];
    } else if ([p isEqualToString:@"third-party-integration"]) {
      [result addObject:PLYDataProcessingPurpose.thirdPartyIntegrations];
    } else if ([p isEqualToString:@"all-non-essentials"]) {
      [result addObject:PLYDataProcessingPurpose.allNonEssentials];
    }
  }
  
  return result;
}

RCT_EXPORT_METHOD(revokeDataProcessingConsent:(NSArray<NSString *> * _Nonnull)purposes) {
    NSSet<PLYDataProcessingPurpose *> *mapped = [self mapPurposesFromStrings:purposes];
  
    if (mapped.count > 0) {
        [Purchasely revokeDataProcessingConsentFor:mapped];
    } else {
        NSLog(@"[Purchasely] revokeDataProcessingConsent called with no valid purposes: %@", purposes);
    }
}

RCT_EXPORT_METHOD(setDebugMode:(BOOL)enabled) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [Purchasely setDebugModeWithEnabled: enabled];
    });
}

// ****************************************************************************
#pragma mark - Events

- (NSArray<NSString *> *)supportedEvents {
  return @[@"PURCHASELY_EVENTS", @"PURCHASE_LISTENER", @"USER_ATTRIBUTE_SET_LISTENER", @"USER_ATTRIBUTE_REMOVED_LISTENER"];
}

- (void)startObserving
{
  self.shouldEmit = YES;
}

- (void)stopObserving
{
  self.shouldEmit = NO;
}

- (void)eventTriggered:(enum PLYEvent)event properties:(NSDictionary<NSString *, id> * _Nullable)properties {
    if (!self.shouldEmit) return;

	if (properties != nil) {
		NSDictionary<NSString *, id> *body = @{@"name": [NSString fromPLYEvent:event], @"properties": properties};
		[self sendEventWithName: @"PURCHASELY_EVENTS" body: body];
	} else {
		NSDictionary<NSString *, id> *body = @{@"name": [NSString fromPLYEvent:event]};
		[self sendEventWithName:@"PURCHASELY_EVENTS" body:body];
	}
}

- (void)onUserAttributeSetWithKey:(NSString * _Nonnull)key
                             type:(enum PLYUserAttributeType)type
                            value:(id _Nullable)value
                           source:(enum PLYUserAttributeSource)source
             processingLegalBasis:(enum PLYDataProcessingLegalBasis) processingLegalBasis{
    if (!self.shouldEmit) return;

    NSMutableDictionary<NSString *, id> *body = [NSMutableDictionary dictionary];
    body[@"key"] = key;
    body[@"type"] = @(type);

    if (value != nil) {
      body[@"value"] = [self getUserAttributeValueForRN:[Purchasely getUserAttributeFor:key]];
    }

    body[@"source"] = @(source);
    body[@"processingLegalBasis"] = @(processingLegalBasis);

    [self sendEventWithName:@"USER_ATTRIBUTE_SET_LISTENER" body:body];
}

- (void)onUserAttributeRemovedWithKey:(NSString * _Nonnull)key
                               source:(enum PLYUserAttributeSource)source {
    if (!self.shouldEmit) return;

    NSDictionary<NSString *, id> *body = @{
        @"key": key,
        @"source": @(source)
    };

    [self sendEventWithName:@"USER_ATTRIBUTE_REMOVED_LISTENER" body:body];
}


- (void)purchasePerformed {
  if (!self.shouldEmit) return;
  [self sendEventWithName: @"PURCHASE_LISTENER" body: @{}];
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


