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

#pragma mark - forward declarations

// v6 renames the global default-presentation handler from
// `setDefaultPresentationResultHandler:` (block: result, plan) to
// `setDefaultPresentationDismissHandler:` (block: PLYPresentationOutcome).
// The CocoaPods release we currently build against may predate that rename, so
// we forward-declare the new selector here and guard the call site with
// `respondsToSelector:`. Once the native SDK ships the rename, the handler
// activates automatically — no further bridge change required.
@interface Purchasely (PLYDefaultDismissHandler)
+ (void)setDefaultPresentationDismissHandler:(void (^)(PLYPresentationOutcome *outcome))handler;
@end

#pragma mark - event names

static NSString *const kPresentationEventLoaded = @"PURCHASELY_PRESENTATION_LOADED";
static NSString *const kPresentationEventPresented = @"PURCHASELY_PRESENTATION_PRESENTED";
static NSString *const kPresentationEventCloseRequested = @"PURCHASELY_PRESENTATION_CLOSE_REQUESTED";
static NSString *const kPresentationEventDismissed = @"PURCHASELY_PRESENTATION_DISMISSED";
static NSString *const kPresentationEventDefaultDismissed = @"PURCHASELY_DEFAULT_PRESENTATION_DISMISSED";
static NSString *const kPresentationEventActionIntercepted = @"PURCHASELY_ACTION_INTERCEPTED";

#pragma mark - internal state (shared across presentation methods)

/// requestId → captured PLYPresentation (so we can replay it in events).
static NSMutableDictionary<NSString *, id<PLYPresentation>> *kPresentationsByRequest;
/// callbackId → completion block to call once JS replies with an InterceptResult.
static NSMutableDictionary<NSString *, void (^)(NSString *)> *kInterceptorCallbacks;
/// kind → BOOL : tracks which interceptor kinds JS has registered.
static NSMutableSet<NSString *> *kInterceptorKinds;
/// Serialises every access to the three mutable collections above. RN bridge
/// methods run on a background queue while the interceptor block / completions
/// run on the main queue; `NSMutable*` is not thread-safe, so all reads and
/// writes are guarded by `@synchronized(kPresentationStateLock)`.
static NSObject *kPresentationStateLock;

/// Mirrors the Android bridge's `INTERCEPTOR_TIMEOUT_MS = 30_000L`. If JS never
/// replies via `completeActionInterceptor:` (RN bridge reloaded, the JS event
/// listener torn down, or the handler threw before completing), the stored
/// callback is fired with `notHandled` after this delay so the native SDK's
/// `completion` block is always invoked and the action is never frozen for the
/// lifetime of the process.
static const int64_t kInterceptorTimeoutSeconds = 30;

static void ensurePresentationState(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kPresentationsByRequest = [NSMutableDictionary new];
        kInterceptorCallbacks = [NSMutableDictionary new];
        kInterceptorKinds = [NSMutableSet new];
        kPresentationStateLock = [NSObject new];
    });
}

#pragma mark - helpers

/// Map a `PLYPresentationAction` to its string kind.
/// Mirrors the kind names emitted by the Android bridge.
static NSString *stringFromPresentationAction(PLYPresentationAction action) {
    switch (action) {
        case PLYPresentationActionLogin:           return @"login";
        case PLYPresentationActionPurchase:        return @"purchase";
        case PLYPresentationActionClose:           return @"close";
        case PLYPresentationActionCloseAll:        return @"closeAll";
        case PLYPresentationActionRestore:         return @"restore";
        case PLYPresentationActionNavigate:        return @"navigate";
        case PLYPresentationActionPromoCode:       return @"promoCode";
        case PLYPresentationActionOpenPresentation:return @"openPresentation";
        case PLYPresentationActionOpenPlacement:   return @"openPlacement";
        case PLYPresentationActionWebCheckout:     return @"webCheckout";
    }
    return @"unknown";
}

static BOOL presentationActionFromString(NSString *kind, PLYPresentationAction *action) {
    if ([kind isEqualToString:@"login"]) { *action = PLYPresentationActionLogin; return YES; }
    if ([kind isEqualToString:@"purchase"]) { *action = PLYPresentationActionPurchase; return YES; }
    if ([kind isEqualToString:@"close"]) { *action = PLYPresentationActionClose; return YES; }
    if ([kind isEqualToString:@"closeAll"]) { *action = PLYPresentationActionCloseAll; return YES; }
    if ([kind isEqualToString:@"restore"]) { *action = PLYPresentationActionRestore; return YES; }
    if ([kind isEqualToString:@"navigate"]) { *action = PLYPresentationActionNavigate; return YES; }
    if ([kind isEqualToString:@"promoCode"]) { *action = PLYPresentationActionPromoCode; return YES; }
    if ([kind isEqualToString:@"openPresentation"]) { *action = PLYPresentationActionOpenPresentation; return YES; }
    if ([kind isEqualToString:@"openPlacement"]) { *action = PLYPresentationActionOpenPlacement; return YES; }
    if ([kind isEqualToString:@"webCheckout"]) { *action = PLYPresentationActionWebCheckout; return YES; }
    return NO;
}

/// String representation of `PLYWebCheckoutProvider` for the JS payload.
static NSString *stringFromWebCheckoutProvider(PLYWebCheckoutProvider provider) {
    switch (provider) {
        case PLYWebCheckoutProviderStripe: return @"stripe";
        case PLYWebCheckoutProviderOther:  return @"other";
        default:                           return @"unknown";
    }
}

/// Convert a `PLYPresentation` to the cross-platform map.
/// On iOS we map `presentation.id` to `screenId` and keep `id` as alias (P1.1).
static NSDictionary *presentationToMap(id<PLYPresentation> presentation) {
    if (presentation == nil) {
        return nil;
    }
    NSMutableDictionary *map = [NSMutableDictionary new];
    if (presentation.id != nil) {
        map[@"screenId"] = presentation.id;
        map[@"id"] = presentation.id;
    }
    if (presentation.placementId != nil) {
        map[@"placementId"] = presentation.placementId;
    }
    if (presentation.audienceId != nil) {
        map[@"audienceId"] = presentation.audienceId;
    }
    if (presentation.abTestId != nil) {
        map[@"abTestId"] = presentation.abTestId;
    }
    if (presentation.abTestVariantId != nil) {
        map[@"abTestVariantId"] = presentation.abTestVariantId;
    }
    if (presentation.language != nil) {
        map[@"language"] = presentation.language;
    }
    map[@"type"] = @(presentation.type);
    map[@"height"] = @(presentation.height);
    if (presentation.plans != nil) {
        NSMutableArray *plans = [NSMutableArray new];
        for (PLYPresentationPlan *plan in presentation.plans) {
            [plans addObject:plan.asDictionary];
        }
        map[@"plans"] = plans;
    }
    if (presentation.metadata != nil) {
        map[@"metadata"] = [presentation.metadata getRawMetadata];
    }
    return map;
}

/// Wrap an `NSError` into the `PresentationError` shape.
static NSDictionary *presentationErrorToMap(NSError *error) {
    if (error == nil) {
        return nil;
    }
    NSMutableDictionary *map = [NSMutableDictionary new];
    map[@"code"] = @(error.code);
    map[@"domain"] = error.domain ?: @"";
    map[@"message"] = error.localizedDescription ?: @"Unknown error";
    return map;
}

/// Convert a `PLYPurchaseResult` to the ordinal that JS expects for
/// `PRESENTATION_DISMISSED.purchaseResult`. We keep the legacy ordinals here
/// because the TS helper `purchaseResultFromOrdinal` translates them to the
/// contract strings. `none` carries no purchase outcome, so it maps to nil.
static NSNumber *purchaseResultOrdinal(PLYPurchaseResult result) {
    switch (result) {
        case PLYPurchaseResultPurchased: return @(0);
        case PLYPurchaseResultCancelled: return @(1);
        case PLYPurchaseResultRestored:  return @(2);
        case PLYPurchaseResultNone:      return nil;
    }
    return nil;
}

/// Convert a `PLYCloseReason` to the cross-platform wire string consumed by the
/// TS `CloseReason` union (`button` / `backSystem` / `programmatic`). `none`
/// carries no reason, so it maps to nil. iOS interactive dismiss (swipe-down /
/// nav pop) maps to `backSystem` for parity with Android's system back.
static NSString *closeReasonToRNString(PLYCloseReason reason) {
    switch (reason) {
        case PLYCloseReasonButton:             return @"button";
        case PLYCloseReasonInteractiveDismiss: return @"backSystem";
        case PLYCloseReasonProgrammatic:       return @"programmatic";
        case PLYCloseReasonNone:               return nil;
    }
    return nil;
}

/// Build a `PLYPresentationBuilder` from the cross-platform builder payload.
/// `placementId` wins over `screenId`, which wins over the default presentation
/// (mirrors the JS `PresentationBuilder` resolution order). Returns nil when no
/// target was provided.
static PLYPresentationBuilder *presentationBuilderFor(NSString *placementId,
                                                      NSString *presentationId,
                                                      NSString *contentId,
                                                      BOOL isDefault) {
    PLYPresentationBuilder *builder = nil;
    if (placementId != nil) {
        builder = [PLYPresentationBuilder forPlacementId:placementId];
    } else if (presentationId != nil) {
        // P1.1: `screenId` → `forScreenId:` on iOS.
        builder = [PLYPresentationBuilder forScreenId:presentationId];
    } else if (isDefault) {
        builder = [[PLYPresentationBuilder alloc] init];
    }
    if (builder != nil && contentId != nil) {
        [builder contentId:contentId];
    }
    return builder;
}

/// JS-facing running-mode ordinals. v6 removed `TransactionOnly` and
/// `PaywallObserver` from the native `PLYRunningMode`, so we keep a stable
/// cross-platform protocol here (same ordinals as Android `PurchaselyModule`)
/// and map them to the nearest native mode at start.
typedef NS_ENUM(NSInteger, PLYRNRunningMode) {
    PLYRNRunningModeTransactionOnly = 0,
    PLYRNRunningModeObserver = 1,
    PLYRNRunningModePaywallObserver = 3,
    PLYRNRunningModeFull = 4,
};

/// Map a JS running-mode ordinal to a native `PLYRunningMode`. transactionOnly/
/// full → Full, observer/paywallObserver → Observer. Any unknown/unset value
/// falls back to **Observer** — the v6 default (matches the JS/Dart default and
/// Flutter's `?? .observer`); only `full` opts into Purchasely owning the flow.
static PLYRunningMode runningModeFromOrdinal(NSInteger ordinal) {
    switch (ordinal) {
        case PLYRNRunningModeTransactionOnly:
        case PLYRNRunningModeFull:
            return PLYRunningModeFull;
        case PLYRNRunningModeObserver:
        case PLYRNRunningModePaywallObserver:
        default:
            return PLYRunningModeObserver;
    }
}

@implementation PurchaselyRN

RCT_EXPORT_MODULE(Purchasely);

static NSMutableArray<id<PLYPresentation>> *_presentationsLoaded;
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

+ (NSMutableArray<id<PLYPresentation>> *)presentationsLoaded {
    return _presentationsLoaded;
}

+ (void)setPresentationsLoaded:(NSMutableArray<id<PLYPresentation>> *)presentationsLoaded {
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
        @"runningModeTransactionOnly": @(PLYRNRunningModeTransactionOnly),
        @"runningModeObserver": @(PLYRNRunningModeObserver),
        @"runningModePaywallObserver": @(PLYRNRunningModePaywallObserver),
        @"runningModeFull": @(PLYRNRunningModeFull),
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

RCT_EXPORT_METHOD(start:(NSString * _Nonnull)apiKey
                  stores:(NSArray * _Nullable)stores
                  storeKit1:(BOOL)storeKit1
                  userId:(NSString * _Nullable)userId
                  logLevel:(NSInteger)logLevel
                  runningMode:(NSInteger)runningMode
                  purchaselySdkVersion:(NSString * _Nullable)purchaselySdkVersion
                  initialized:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {

    PurchaselyBuilder *builder = [[[[[[[Purchasely apiKey:apiKey]
        appUserId:userId]
        runningMode:runningModeFromOrdinal(runningMode)]
        storekitSettings: storeKit1 ? [StorekitSettings storeKit1] : [StorekitSettings storeKit2]]
        logLevel:(PLYLogLevel)logLevel]
        appTechnology:PLYAppTechnologyReactNative]
        sdkBridgeVersion:purchaselySdkVersion];

    [builder startWithInitialized:^(NSError * _Nullable error) {
        if (error != nil) {
            [self reject: reject with: error];
        } else {
            resolve(@(YES));
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

    PurchaselyBuilder *builder = [[[[[[[Purchasely apiKey:apiKey]
        appUserId:userId]
        runningMode:runningModeFromOrdinal(runningMode)]
        storekitSettings:[StorekitSettings storeKit2]]
        logLevel:(PLYLogLevel)logLevel]
        appTechnology:PLYAppTechnologyReactNative]
        sdkBridgeVersion:purchaselySdkVersion];

    [builder startWithInitialized:^(NSError * _Nullable error) {
        if (error != nil) {
            [self reject: reject with: error];
        } else {
            resolve(@(YES));
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

RCT_EXPORT_METHOD(handleDeeplink:(NSString * _Nullable) deeplink
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
        resolve(@([Purchasely handleDeeplink:[NSURL URLWithString:deeplink]]));
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
        [Purchasely allowDeeplink: ready];
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

- (id<PLYPresentation>) findPresentationLoadedFor:(NSString * _Nullable)presentationId
                                      placementId:(NSString * _Nullable)placementId {
    for (id<PLYPresentation> presentationLoaded in PurchaselyRN.presentationsLoaded) {
        if ([presentationLoaded.id isEqualToString: presentationId] && [presentationLoaded.placementId isEqualToString: placementId]) {
            return presentationLoaded;
        }
    }
    return nil;
}

RCT_EXPORT_METHOD(clientPresentationDisplayed:(NSDictionary<NSString *, id> * _Nullable) presentationDictionary)
{
    if (presentationDictionary == nil) {
        NSLog(@"Presentation cannot be null");
        return;
    }

    id<PLYPresentation> presentationLoaded = [self findPresentationLoadedFor:(NSString *)[presentationDictionary objectForKey:@"id"] placementId:(NSString *)[presentationDictionary objectForKey:@"placementId"]];
    [Purchasely clientPresentationOpenedWith:presentationLoaded];
}

RCT_EXPORT_METHOD(clientPresentationClosed:(NSDictionary<NSString *, id> * _Nullable) presentationDictionary)
{
    if (presentationDictionary == nil) {
        NSLog(@"Presentation cannot be null");
        return;
    }
    id<PLYPresentation> presentationLoaded = [self findPresentationLoadedFor:(NSString *)[presentationDictionary objectForKey:@"id"] placementId:(NSString *)[presentationDictionary objectForKey:@"placementId"]];
    [Purchasely clientPresentationClosedWith:presentationLoaded];
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
      [Purchasely setDynamicOfferingWithReference:reference planVendorId:planVendorId offerVendorId:offerId billingPlanType:PLYBillingPlanTypeUnspecified completion:^(BOOL result) {
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
  return @[
    @"PURCHASELY_EVENTS",
    @"PURCHASE_LISTENER",
    @"USER_ATTRIBUTE_SET_LISTENER",
    @"USER_ATTRIBUTE_REMOVED_LISTENER",
    // cross-platform bridge events. Names mirror the Android bridge so the
    // same JS layer drives both platforms. See the presentation section below.
    @"PURCHASELY_PRESENTATION_LOADED",
    @"PURCHASELY_PRESENTATION_PRESENTED",
    @"PURCHASELY_PRESENTATION_CLOSE_REQUESTED",
    @"PURCHASELY_PRESENTATION_DISMISSED",
    @"PURCHASELY_DEFAULT_PRESENTATION_DISMISSED",
    @"PURCHASELY_ACTION_INTERCEPTED",
  ];
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

// ****************************************************************************
#pragma mark - cross-platform bridge
//
//  cross-platform bridge implementation.
//  Implements the contract documented in:
//    the cross-platform bridge contract
//
//  Mapping notes (iOS-specific workarounds — see contract P0.2 / P0.4 / P1.1):
//    - The native iOS SDK delivers a `PLYPresentationOutcome` via the builder's
//      `onDismissed` handler. The bridge maps it to the 5-field cross-platform
//      outcome (presentation, purchaseResult, plan, closeReason, error):
//        * `presentation` is captured from the loaded `PLYPresentation`.
//        * `closeReason` maps `PLYCloseReason` → `button`/`backSystem`/
//          `programmatic` (interactiveDismiss → `backSystem`); `none` → nil.
//        * `error` is propagated from the outcome / fetch completion handler.
//    - `screenId` maps to `presentation.id` until iOS exposes a dedicated
//      `screenId` property.
//    - `onPresented(presentation?, error?)` is synthesized after preload/display.
//    - The Promise returned by `display()` resolves at DISMISS (not at trigger),
//      matching the Android contract.

#pragma mark - emitter access

/// Wrapper around `sendEventWithName:body:` that ensures the bridge is observing.
/// If `shouldEmit` is NO the SDK is not active yet — drop the event silently.
- (void)emitPresentationEvent:(NSString *)eventName body:(NSDictionary *)body {
    if (!self.shouldEmit) {
        return;
    }
    [self sendEventWithName:eventName body:body ?: @{}];
}

#pragma mark - builder payload parsing

/// Extract a `PLYPresentation` lookup spec from the builder payload sent by JS.
/// Returns the values resolved into the corresponding strings.
- (void)extractPresentationTargets:(NSDictionary *)payload
                       toPlacement:(NSString * __autoreleasing *)placementId
                    toPresentation:(NSString * __autoreleasing *)presentationId
                       toContentId:(NSString * __autoreleasing *)contentId
                       toIsDefault:(BOOL *)isDefault {
    if (payload[@"placementId"] != [NSNull null]) {
        *placementId = payload[@"placementId"];
    }
    // JS sends `screenId` as `presentationId` (cf. presentation.ts toNativePayload).
    if (payload[@"presentationId"] != [NSNull null]) {
        *presentationId = payload[@"presentationId"];
    }
    if (payload[@"contentId"] != [NSNull null]) {
        *contentId = payload[@"contentId"];
    }
    // `PresentationBuilder.default()` sends `isDefault: true` with no placement /
    // screen — route it to the SDK's default presentation (cf. legacy
    // `fetchPresentation` which falls back to `fetchPresentationWith:nil`).
    id isDefaultValue = payload[@"isDefault"];
    if ([isDefaultValue isKindOfClass:[NSNumber class]]) {
        *isDefault = [isDefaultValue boolValue];
    }
}

#pragma mark - preloadPresentation

RCT_EXPORT_METHOD(preloadPresentation:(NSString *)requestId
                  payload:(NSDictionary *)payload
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    ensurePresentationState();

    NSString *placementId = nil;
    NSString *presentationId = nil;
    NSString *contentId = nil;
    BOOL isDefault = NO;
    [self extractPresentationTargets:payload
                          toPlacement:&placementId
                       toPresentation:&presentationId
                          toContentId:&contentId
                          toIsDefault:&isDefault];

    __weak PurchaselyRN *weakSelf = self;
    void (^onFetchCompletion)(id<PLYPresentation> _Nullable, NSError * _Nullable) =
    ^(id<PLYPresentation> _Nullable presentation, NSError * _Nullable error) {
        PurchaselyRN *strongSelf = weakSelf;
        if (!strongSelf) { return; }

        NSMutableDictionary *event = [NSMutableDictionary new];
        event[@"requestId"] = requestId;
        if (presentation != nil) {
            event[@"presentation"] = presentationToMap(presentation);
            [PurchaselyRN.presentationsLoaded addObject:presentation];
            @synchronized (kPresentationStateLock) {
                kPresentationsByRequest[requestId] = presentation;
            }
        }
        if (error != nil) {
            event[@"error"] = presentationErrorToMap(error);
        }
        [strongSelf emitPresentationEvent:kPresentationEventLoaded body:event];
    };

    dispatch_async(dispatch_get_main_queue(), ^{
        PLYPresentationBuilder *builder = presentationBuilderFor(placementId, presentationId, contentId, isDefault);
        if (builder == nil) {
            NSError *error = [NSError errorWithDomain:@"io.purchasely.presentation"
                                                 code:400
                                             userInfo:@{NSLocalizedDescriptionKey: @"No placementId or screenId provided"}];
            onFetchCompletion(nil, error);
            resolve(@(YES));
            return;
        }
        id<PLYPresentationRequest> request = [builder build];
        [request preloadWithCompletion:onFetchCompletion];
        resolve(@(YES));
    });
}

#pragma mark - displayPresentation

RCT_EXPORT_METHOD(displayPresentation:(NSString *)requestId
                  payload:(NSDictionary *)payload
                  transition:(NSDictionary *)transition
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    ensurePresentationState();

    NSString *placementId = nil;
    NSString *presentationId = nil;
    NSString *contentId = nil;
    BOOL isDefault = NO;
    [self extractPresentationTargets:payload
                          toPlacement:&placementId
                       toPresentation:&presentationId
                          toContentId:&contentId
                          toIsDefault:&isDefault];

    __weak PurchaselyRN *weakSelf = self;

    // Captured for the close-flow: lets the dismissal handler send the
    // dismissed event with the right outcome.
    __block id<PLYPresentation> capturedPresentation = nil;
    __block PLYPurchaseResult capturedResult = PLYPurchaseResultCancelled;
    __block PLYPlan *capturedPlan = nil;
    __block BOOL hasPurchaseOutcome = NO;
    __block PLYCloseReason capturedCloseReason = PLYCloseReasonNone;

    void (^emitDismissed)(NSError * _Nullable) = ^(NSError * _Nullable error) {
        PurchaselyRN *strongSelf = weakSelf;
        if (!strongSelf) { return; }
        NSMutableDictionary *body = [NSMutableDictionary new];
        body[@"requestId"] = requestId;
        if (capturedPresentation != nil) {
            body[@"presentation"] = presentationToMap(capturedPresentation);
        }
        if (hasPurchaseOutcome) {
            NSNumber *ordinal = purchaseResultOrdinal(capturedResult);
            if (ordinal != nil) {
                body[@"purchaseResult"] = ordinal;
            }
            if (capturedPlan != nil) {
                body[@"plan"] = [capturedPlan asDictionary];
            }
        }
        if (error != nil) {
            body[@"error"] = presentationErrorToMap(error);
        } else {
            // Exclusion rule: only surface closeReason when there is no error.
            NSString *closeReason = closeReasonToRNString(capturedCloseReason);
            if (closeReason != nil) {
                body[@"closeReason"] = closeReason;
            }
        }
        [strongSelf emitPresentationEvent:kPresentationEventDismissed body:body];
        @synchronized (kPresentationStateLock) {
            [kPresentationsByRequest removeObjectForKey:requestId];
        }
    };

    void (^onFetchCompletion)(id<PLYPresentation> _Nullable, NSError * _Nullable) =
    ^(id<PLYPresentation> _Nullable presentation, NSError * _Nullable error) {
        PurchaselyRN *strongSelf = weakSelf;
        if (!strongSelf) { return; }

        // Emit `onLoaded` (mirrors Android contract — preload+display share the
        // same lifecycle on the JS side).
        NSMutableDictionary *loaded = [NSMutableDictionary new];
        loaded[@"requestId"] = requestId;
        if (presentation != nil) {
            loaded[@"presentation"] = presentationToMap(presentation);
        }
        if (error != nil) {
            loaded[@"error"] = presentationErrorToMap(error);
        }
        [strongSelf emitPresentationEvent:kPresentationEventLoaded body:loaded];

        if (error != nil) {
            // P0.4: synthesize an onPresented(null, error) since the native
            // pipeline failed before the controller was shown.
            NSMutableDictionary *presented = [NSMutableDictionary new];
            presented[@"requestId"] = requestId;
            presented[@"error"] = presentationErrorToMap(error);
            [strongSelf emitPresentationEvent:kPresentationEventPresented body:presented];

            emitDismissed(error);
            return;
        }

        if (presentation == nil) {
            NSError *missing = [NSError errorWithDomain:@"io.purchasely.presentation"
                                                   code:404
                                               userInfo:@{NSLocalizedDescriptionKey: @"Presentation not found"}];
            NSMutableDictionary *presented = [NSMutableDictionary new];
            presented[@"requestId"] = requestId;
            presented[@"error"] = presentationErrorToMap(missing);
            [strongSelf emitPresentationEvent:kPresentationEventPresented body:presented];

            emitDismissed(missing);
            return;
        }

        capturedPresentation = presentation;
        @synchronized (kPresentationStateLock) {
            kPresentationsByRequest[requestId] = presentation;
        }

        // Emit onPresented (no native callback for it yet — we fire after the
        // controller becomes available).
        NSMutableDictionary *presented = [NSMutableDictionary new];
        presented[@"requestId"] = requestId;
        presented[@"presentation"] = presentationToMap(presentation);
        [strongSelf emitPresentationEvent:kPresentationEventPresented body:presented];

        UIViewController *controller = presentation.controller;
        if (controller == nil) {
            NSError *err = [NSError errorWithDomain:@"io.purchasely.presentation"
                                               code:500
                                           userInfo:@{NSLocalizedDescriptionKey: @"Presentation has no controller"}];
            emitDismissed(err);
            return;
        }

        // Apply the transition `dismissible` flag if provided.
        if ([transition isKindOfClass:[NSDictionary class]]) {
            id dismissible = transition[@"dismissible"];
            if ([dismissible isKindOfClass:[NSNumber class]]) {
                controller.modalInPresentation = ![dismissible boolValue];
            }
        }

        strongSelf.presentedPresentationViewController = controller;
        [Purchasely showController:controller type:PLYUIControllerTypeProductPage from:nil];
    };

    // v6: the dismiss outcome (purchaseResult, plan, closeReason, error) is
    // delivered through the builder's `onDismissed` handler instead of the
    // legacy `PLYProductViewControllerCompletionBlock`.
    void (^onDismissed)(PLYPresentationOutcome *) = ^(PLYPresentationOutcome *outcome) {
        capturedResult = outcome.purchaseResult;
        capturedPlan = outcome.plan;
        hasPurchaseOutcome = YES;
        capturedCloseReason = outcome.closeReason;
        if (outcome.presentation != nil) {
            capturedPresentation = outcome.presentation;
        }
        emitDismissed(outcome.error);
    };

    dispatch_async(dispatch_get_main_queue(), ^{
        PLYPresentationBuilder *builder = presentationBuilderFor(placementId, presentationId, contentId, isDefault);
        if (builder == nil) {
            NSError *error = [NSError errorWithDomain:@"io.purchasely.presentation"
                                                 code:400
                                             userInfo:@{NSLocalizedDescriptionKey: @"No placementId or screenId provided"}];
            onFetchCompletion(nil, error);
            resolve(@(YES));
            return;
        }
        [builder onDismissed:onDismissed];
        id<PLYPresentationRequest> request = [builder build];
        // Preload to obtain the controller, then show it ourselves so we keep
        // control over the transition flag and `presentedPresentationViewController`
        // tracking (`onFetchCompletion` calls `showController:`).
        [request preloadWithCompletion:onFetchCompletion];
        resolve(@(YES));
    });
}

#pragma mark - setDefaultPresentationDismissHandler

// Global handler for presentations the app did NOT instantiate itself
// (campaigns, deeplinks, Promoted In-App Purchases). v6 renamed the native
// `setDefaultPresentationResultHandler` (block: result, plan) to
// `setDefaultPresentationDismissHandler` (block: PLYPresentationOutcome). The
// rich outcome is forwarded to JS through the dedicated
// DEFAULT_PRESENTATION_DISMISSED event (no requestId — the SDK owns these).
RCT_EXPORT_METHOD(setDefaultPresentationDismissHandler) {
    ensurePresentationState();

    __weak PurchaselyRN *weakSelf = self;
    void (^handler)(PLYPresentationOutcome *) = ^(PLYPresentationOutcome *outcome) {
        PurchaselyRN *strongSelf = weakSelf;
        if (!strongSelf) { return; }

        NSMutableDictionary *body = [NSMutableDictionary new];
        // `presentation` is always populated for this handler so JS can tell
        // which campaign/deeplink screen closed.
        if (outcome.presentation != nil) {
            body[@"presentation"] = presentationToMap(outcome.presentation);
        }
        NSNumber *ordinal = purchaseResultOrdinal(outcome.purchaseResult);
        if (ordinal != nil) {
            body[@"purchaseResult"] = ordinal;
        }
        if (outcome.plan != nil) {
            body[@"plan"] = [outcome.plan asDictionary];
        }
        NSString *closeReason = closeReasonToRNString(outcome.closeReason);
        if (closeReason != nil) {
            body[@"closeReason"] = closeReason;
        }
        if (outcome.error != nil) {
            body[@"error"] = presentationErrorToMap(outcome.error);
        }
        [strongSelf emitPresentationEvent:kPresentationEventDefaultDismissed body:body];
    };

    dispatch_async(dispatch_get_main_queue(), ^{
        // Guard against SDK builds that predate the v6 rename (see the
        // forward-declared category at the top of this file).
        if ([Purchasely respondsToSelector:@selector(setDefaultPresentationDismissHandler:)]) {
            [Purchasely setDefaultPresentationDismissHandler:handler];
        } else {
            RCTLogWarn(@"[Purchasely] setDefaultPresentationDismissHandler is unavailable in this native SDK build; the global default dismiss handler will not fire.");
        }
    });
}

#pragma mark - closePresentation / goBackToPreviousScreen

RCT_EXPORT_METHOD(closePresentation:(NSString *)requestId) {
    ensurePresentationState();
    dispatch_async(dispatch_get_main_queue(), ^{
        // Notify JS so the host app can react before the native dismissal happens.
        [self emitPresentationEvent:kPresentationEventCloseRequested body:@{ @"requestId": requestId ?: @"" }];
        id<PLYPresentation> presentation = nil;
        @synchronized (kPresentationStateLock) {
            presentation = kPresentationsByRequest[requestId];
        }
        self.presentedPresentationViewController = nil;
        // v6: close the specific presentation when we still hold it; otherwise
        // fall back to closing every Purchasely screen (`closeDisplayedPresentation`
        // was removed in the native v6 SDK).
        if (presentation != nil) {
            [presentation close];
        } else {
            [Purchasely closeAllScreens];
        }
        @synchronized (kPresentationStateLock) {
            [kPresentationsByRequest removeObjectForKey:requestId];
        }
    });
}

RCT_EXPORT_METHOD(goBackToPreviousScreen:(NSString *)requestId) {
    // The legacy iOS SDK does not expose a `back()` primitive on the
    // presentation controller. Bridge contract says: noop with a warn.
    RCTLogWarn(@"[Purchasely] goBackToPreviousScreen(%@) is not yet bridged on iOS", requestId);
}

#pragma mark - interceptors

RCT_EXPORT_METHOD(registerActionInterceptor:(NSString *)kind) {
    ensurePresentationState();

    PLYPresentationAction nativeAction;
    if (!presentationActionFromString(kind, &nativeAction)) {
        RCTLogWarn(@"[Purchasely] unknown interceptor kind: %@", kind);
        return;
    }

    @synchronized (kPresentationStateLock) {
        [kInterceptorKinds addObject:kind];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        __weak PurchaselyRN *weakSelf = self;
        [Purchasely interceptAction:nativeAction
                             handler:^(PLYInterceptorInfo * _Nonnull infos,
                                       PLYPresentationActionParameters * _Nullable params,
                                       void (^ _Nonnull completion)(PLYInterceptResult)) {
            PurchaselyRN *strongSelf = weakSelf;
            if (!strongSelf) {
                completion(PLYInterceptResultNotHandled);
                return;
            }

            NSString *callbackId = [[NSUUID UUID] UUIDString];
            @synchronized (kPresentationStateLock) {
                kInterceptorCallbacks[callbackId] = ^(NSString *result) {
                    if ([result isEqualToString:@"success"]) {
                        completion(PLYInterceptResultSuccess);
                    } else if ([result isEqualToString:@"failed"]) {
                        completion(PLYInterceptResultFailed);
                    } else {
                        completion(PLYInterceptResultNotHandled);
                    }
                };
            }

            // Fallback timer mirroring the Android bridge: if JS never calls
            // completeActionInterceptor: for this callbackId, fire the stored
            // callback with `notHandled` so the SDK's `completion` block is always
            // invoked and the action is never frozen. Whoever removes the entry
            // first (this timer or completeActionInterceptor:) wins; the loser
            // reads nil and no-ops, so the SDK completion can never fire twice.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kInterceptorTimeoutSeconds * NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^{
                void (^timedOutCallback)(NSString *) = nil;
                @synchronized (kPresentationStateLock) {
                    timedOutCallback = kInterceptorCallbacks[callbackId];
                    if (timedOutCallback != nil) {
                        [kInterceptorCallbacks removeObjectForKey:callbackId];
                    }
                }
                if (timedOutCallback != nil) {
                    RCTLogWarn(@"[Purchasely] interceptor callback %@ timed out after %llds; falling back to notHandled",
                               callbackId, (long long)kInterceptorTimeoutSeconds);
                    timedOutCallback(@"notHandled");
                }
            });

            NSMutableDictionary *info = [NSMutableDictionary new];
            if (infos.contentId != nil) {
                info[@"contentId"] = infos.contentId;
            }
            if (infos.presentation != nil) {
                info[@"presentation"] = presentationToMap(infos.presentation);
            }

            NSMutableDictionary *payloadOut = [NSMutableDictionary new];
            if (params != nil) {
                switch (nativeAction) {
                    case PLYPresentationActionNavigate: {
                        payloadOut[@"url"] = params.url.absoluteString ?: @"";
                        if (params.title != nil) {
                            payloadOut[@"title"] = params.title;
                        }
                        break;
                    }
                    case PLYPresentationActionPurchase: {
                        if (params.plan != nil) {
                            payloadOut[@"plan"] = [params.plan asDictionary];
                        }
                        if (params.promoOffer != nil) {
                            NSMutableDictionary *offer = [NSMutableDictionary new];
                            if (params.promoOffer.vendorId != nil) {
                                offer[@"vendorId"] = params.promoOffer.vendorId;
                            }
                            if (params.promoOffer.storeOfferId != nil) {
                                offer[@"storeOfferId"] = params.promoOffer.storeOfferId;
                            }
                            payloadOut[@"offer"] = offer;
                        }
                        break;
                    }
                    case PLYPresentationActionClose:
                    case PLYPresentationActionCloseAll: {
                        payloadOut[@"closeReason"] = @"button";
                        break;
                    }
                    case PLYPresentationActionOpenPresentation: {
                        if (params.presentation != nil) {
                            payloadOut[@"presentationId"] = params.presentation;
                        }
                        break;
                    }
                    case PLYPresentationActionOpenPlacement: {
                        if (params.placement != nil) {
                            payloadOut[@"placementId"] = params.placement;
                        }
                        break;
                    }
                    case PLYPresentationActionWebCheckout: {
                        payloadOut[@"url"] = params.url.absoluteString ?: @"";
                        if (params.clientReferenceId != nil) {
                            payloadOut[@"clientReferenceId"] = params.clientReferenceId;
                        }
                        if (params.queryParameterKey != nil) {
                            payloadOut[@"queryParameterKey"] = params.queryParameterKey;
                        }
                        payloadOut[@"webCheckoutProvider"] =
                            stringFromWebCheckoutProvider(params.webCheckoutProvider);
                        break;
                    }
                    default:
                        break;
                }
            }

            NSMutableDictionary *event = [NSMutableDictionary new];
            event[@"requestId"] = @"";
            event[@"callbackId"] = callbackId;
            event[@"kind"] = kind;
            event[@"info"] = info;
            event[@"payload"] = payloadOut;
            [strongSelf emitPresentationEvent:kPresentationEventActionIntercepted body:event];
        }];
    });
}

RCT_EXPORT_METHOD(unregisterActionInterceptor:(NSString *)kind) {
    ensurePresentationState();

    PLYPresentationAction nativeAction;
    if (!presentationActionFromString(kind, &nativeAction)) {
        RCTLogWarn(@"[Purchasely] unknown interceptor kind: %@", kind);
        return;
    }

    @synchronized (kPresentationStateLock) {
        [kInterceptorKinds removeObject:kind];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [Purchasely removeActionInterceptor:nativeAction];
    });
}

RCT_EXPORT_METHOD(completeActionInterceptor:(NSString *)callbackId result:(NSString *)result) {
    ensurePresentationState();
    void (^cb)(NSString *) = nil;
    @synchronized (kPresentationStateLock) {
        cb = kInterceptorCallbacks[callbackId];
        if (cb != nil) {
            [kInterceptorCallbacks removeObjectForKey:callbackId];
        }
    }
    // Invoke outside the lock — the callback re-enters the SDK's action handler.
    if (cb != nil) {
        cb(result);
    }
}

#pragma mark - start options

RCT_EXPORT_METHOD(applyStartOptions:(NSDictionary *)options) {
    if (![options isKindOfClass:[NSDictionary class]]) { return; }
    id allowDeeplink = options[@"allowDeeplink"];
    if ([allowDeeplink isKindOfClass:[NSNumber class]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [Purchasely allowDeeplink:[allowDeeplink boolValue]];
        });
    }
    // `allowCampaigns` is honored on Android via the consent manager; on iOS
    // the equivalent is not exposed publicly yet — JS clients receive the value
    // back through the start payload but iOS does not yet act on it.
    id allowCampaigns = options[@"allowCampaigns"];
    if ([allowCampaigns isKindOfClass:[NSNumber class]] && ![allowCampaigns boolValue]) {
        RCTLogWarn(@"[Purchasely] allowCampaigns(false) is not bridged on iOS yet");
    }
}

@end


