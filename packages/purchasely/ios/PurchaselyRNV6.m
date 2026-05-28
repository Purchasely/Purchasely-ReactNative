//
//  PurchaselyRNV6.m
//  Purchasely-ReactNative
//
//  v6 cross-platform bridge implementation.
//  Implements the contract documented in:
//    reports/v6-presentation-comparison-v3-claude/BRIDGE-CONTRACT.md
//
//  Mapping notes (iOS-specific workarounds — see contract P0.2 / P0.4 / P1.1):
//    - The native iOS SDK currently surfaces a `PLYProductViewControllerResult` +
//      `PLYPlan` via the legacy `fetchPresentationFor:contentId:fetchCompletion:`
//      callbacks. The v6 contract requires a 5-field outcome (presentation,
//      purchaseResult, plan, closeReason, error). The bridge synthesizes the
//      missing fields:
//        * `presentation` is captured from the loaded `PLYPresentation`.
//        * `closeReason` is set to `nil` (iOS does not yet expose it).
//        * `error` is propagated from the fetch completion handler.
//    - `screenId` maps to `presentation.id` until iOS exposes a dedicated
//      `screenId` property.
//    - `onPresented(presentation?, error?)` is synthesized after preload/display.
//    - The Promise returned by `display()` resolves at DISMISS (not at trigger),
//      matching the Android contract.
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTLog.h>
#import <Purchasely/Purchasely-Swift.h>

#import "PurchaselyRN.h"
#import "PurchaselyRNV6.h"

#pragma mark - Event names

static NSString *const kV6EventLoaded = @"PURCHASELY_V6_LOADED";
static NSString *const kV6EventPresented = @"PURCHASELY_V6_PRESENTED";
static NSString *const kV6EventCloseRequested = @"PURCHASELY_V6_CLOSE_REQUESTED";
static NSString *const kV6EventDismissed = @"PURCHASELY_V6_DISMISSED";
static NSString *const kV6EventActionIntercepted = @"PURCHASELY_V6_ACTION_INTERCEPTED";

#pragma mark - Internal state (shared across category methods)

/// requestId → captured PLYPresentation (so we can replay it in events).
static NSMutableDictionary<NSString *, PLYPresentation *> *kV6PresentationsByRequest;
/// callbackId → completion block to call once JS replies with an InterceptResult.
static NSMutableDictionary<NSString *, void (^)(NSString *)> *kV6InterceptorCallbacks;
/// kind → BOOL : tracks which interceptor kinds JS has registered. The native
/// interceptor itself is global (`setPaywallActionsInterceptor`) — we only fire
/// the JS event when the action kind matches a registered one.
static NSMutableSet<NSString *> *kV6InterceptorKinds;

static void V6EnsureInternalState(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kV6PresentationsByRequest = [NSMutableDictionary new];
        kV6InterceptorCallbacks = [NSMutableDictionary new];
        kV6InterceptorKinds = [NSMutableSet new];
    });
}

#pragma mark - Helpers

/// Map a `PLYPresentationAction` to its v6 string kind.
/// Mirrors the kind names emitted by the Android bridge.
static NSString *V6StringFromAction(PLYPresentationAction action) {
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

/// String representation of `PLYWebCheckoutProvider` for the JS payload.
static NSString *V6StringFromWebCheckoutProvider(PLYWebCheckoutProvider provider) {
    switch (provider) {
        case PLYWebCheckoutProviderStripe:     return @"stripe";
        case PLYWebCheckoutProviderPaddle:     return @"paddle";
        case PLYWebCheckoutProviderRecurly:    return @"recurly";
        case PLYWebCheckoutProviderChargebee:  return @"chargebee";
        case PLYWebCheckoutProviderPaypal:     return @"paypal";
        case PLYWebCheckoutProviderRevenuecat: return @"revenuecat";
        case PLYWebCheckoutProviderAdapty:     return @"adapty";
        case PLYWebCheckoutProviderQonversion: return @"qonversion";
        case PLYWebCheckoutProviderOther:      return @"other";
        default:                               return @"unknown";
    }
}

/// Convert a `PLYPresentation` to the v6 cross-platform map.
/// On iOS we map `presentation.id` to `screenId` and keep `id` as alias (P1.1).
static NSDictionary *V6PresentationToMap(PLYPresentation *presentation) {
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
    return map;
}

/// Wrap an `NSError` into the v6 `PresentationError` shape.
static NSDictionary *V6ErrorToMap(NSError *error) {
    if (error == nil) {
        return nil;
    }
    NSMutableDictionary *map = [NSMutableDictionary new];
    map[@"code"] = @(error.code);
    map[@"domain"] = error.domain ?: @"";
    map[@"message"] = error.localizedDescription ?: @"Unknown error";
    return map;
}

/// Convert a `PLYProductViewControllerResult` to the v6 ordinal that JS expects
/// for `PRESENTATION_DISMISSED.purchaseResult`. We keep the legacy ordinals
/// here because the TS helper `purchaseResultFromOrdinal` translates them to
/// the contract strings.
static NSNumber *V6PurchaseResultOrdinal(PLYProductViewControllerResult result) {
    switch (result) {
        case PLYProductViewControllerResultPurchased: return @(0);
        case PLYProductViewControllerResultCancelled: return @(1);
        case PLYProductViewControllerResultRestored:  return @(2);
    }
    return nil;
}

#pragma mark - Emitter access

@interface PurchaselyRN ()
- (void)sendEventWithName:(NSString *)name body:(id)body;
@end

@implementation PurchaselyRN (V6)

/// Wrapper around `sendEventWithName:body:` that ensures the bridge is observing.
/// If `shouldEmit` is NO the SDK is not active yet — drop the event silently.
- (void)v6EmitEvent:(NSString *)eventName body:(NSDictionary *)body {
    if (!self.shouldEmit) {
        return;
    }
    [self sendEventWithName:eventName body:body ?: @{}];
}

#pragma mark - Builder payload parsing

/// Extract a `PLYPresentation` lookup spec from the builder payload sent by JS.
/// Returns the values resolved into the corresponding strings.
- (void)v6ExtractTargetsFromPayload:(NSDictionary *)payload
                       toPlacement:(NSString * __autoreleasing *)placementId
                    toPresentation:(NSString * __autoreleasing *)presentationId
                       toContentId:(NSString * __autoreleasing *)contentId {
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
}

#pragma mark - v6Preload

RCT_EXPORT_METHOD(v6Preload:(NSString *)requestId
                  payload:(NSDictionary *)payload
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    V6EnsureInternalState();

    NSString *placementId = nil;
    NSString *presentationId = nil;
    NSString *contentId = nil;
    [self v6ExtractTargetsFromPayload:payload
                          toPlacement:&placementId
                       toPresentation:&presentationId
                          toContentId:&contentId];

    __weak PurchaselyRN *weakSelf = self;
    void (^onFetchCompletion)(PLYPresentation * _Nullable, NSError * _Nullable) =
    ^(PLYPresentation * _Nullable presentation, NSError * _Nullable error) {
        PurchaselyRN *strongSelf = weakSelf;
        if (!strongSelf) { return; }

        NSMutableDictionary *event = [NSMutableDictionary new];
        event[@"requestId"] = requestId;
        if (presentation != nil) {
            event[@"presentation"] = V6PresentationToMap(presentation);
            [PurchaselyRN.presentationsLoaded addObject:presentation];
            kV6PresentationsByRequest[requestId] = presentation;
        }
        if (error != nil) {
            event[@"error"] = V6ErrorToMap(error);
        }
        [strongSelf v6EmitEvent:kV6EventLoaded body:event];
    };

    dispatch_async(dispatch_get_main_queue(), ^{
        if (placementId != nil) {
            [Purchasely fetchPresentationFor:placementId
                                   contentId:contentId
                              fetchCompletion:onFetchCompletion
                                   completion:nil
                            loadedCompletion:nil];
        } else if (presentationId != nil) {
            // P1.1: `screenId` → `fetchPresentationWith:` on iOS.
            [Purchasely fetchPresentationWith:presentationId
                                    contentId:contentId
                             fetchCompletion:onFetchCompletion
                                    completion:nil
                             loadedCompletion:nil];
        } else {
            NSError *error = [NSError errorWithDomain:@"io.purchasely.v6"
                                                 code:400
                                             userInfo:@{NSLocalizedDescriptionKey: @"No placementId or screenId provided"}];
            onFetchCompletion(nil, error);
        }
        resolve(@(YES));
    });
}

#pragma mark - v6Display

RCT_EXPORT_METHOD(v6Display:(NSString *)requestId
                  payload:(NSDictionary *)payload
                  transition:(NSDictionary *)transition
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    V6EnsureInternalState();

    NSString *placementId = nil;
    NSString *presentationId = nil;
    NSString *contentId = nil;
    [self v6ExtractTargetsFromPayload:payload
                          toPlacement:&placementId
                       toPresentation:&presentationId
                          toContentId:&contentId];

    __weak PurchaselyRN *weakSelf = self;

    // Captured for the close-flow: lets the dismissal handler send the
    // dismissed event with the right outcome.
    __block PLYPresentation *capturedPresentation = nil;
    __block PLYProductViewControllerResult capturedResult = PLYProductViewControllerResultCancelled;
    __block PLYPlan *capturedPlan = nil;
    __block BOOL hasPurchaseOutcome = NO;

    void (^emitDismissed)(NSError * _Nullable) = ^(NSError * _Nullable error) {
        PurchaselyRN *strongSelf = weakSelf;
        if (!strongSelf) { return; }
        NSMutableDictionary *body = [NSMutableDictionary new];
        body[@"requestId"] = requestId;
        if (capturedPresentation != nil) {
            body[@"presentation"] = V6PresentationToMap(capturedPresentation);
        }
        if (hasPurchaseOutcome) {
            NSNumber *ordinal = V6PurchaseResultOrdinal(capturedResult);
            if (ordinal != nil) {
                body[@"purchaseResult"] = ordinal;
            }
            if (capturedPlan != nil) {
                body[@"plan"] = [capturedPlan asDictionary];
            }
        }
        if (error != nil) {
            body[@"error"] = V6ErrorToMap(error);
        }
        // closeReason stays absent on iOS until native exposes it (cf. P0.2).
        [strongSelf v6EmitEvent:kV6EventDismissed body:body];
        [kV6PresentationsByRequest removeObjectForKey:requestId];
    };

    void (^onFetchCompletion)(PLYPresentation * _Nullable, NSError * _Nullable) =
    ^(PLYPresentation * _Nullable presentation, NSError * _Nullable error) {
        PurchaselyRN *strongSelf = weakSelf;
        if (!strongSelf) { return; }

        // Emit `onLoaded` (mirrors Android contract — preload+display share the
        // same lifecycle on the JS side).
        NSMutableDictionary *loaded = [NSMutableDictionary new];
        loaded[@"requestId"] = requestId;
        if (presentation != nil) {
            loaded[@"presentation"] = V6PresentationToMap(presentation);
        }
        if (error != nil) {
            loaded[@"error"] = V6ErrorToMap(error);
        }
        [strongSelf v6EmitEvent:kV6EventLoaded body:loaded];

        if (error != nil) {
            // P0.4: synthesize an onPresented(null, error) since the native
            // pipeline failed before the controller was shown.
            NSMutableDictionary *presented = [NSMutableDictionary new];
            presented[@"requestId"] = requestId;
            presented[@"error"] = V6ErrorToMap(error);
            [strongSelf v6EmitEvent:kV6EventPresented body:presented];

            emitDismissed(error);
            return;
        }

        if (presentation == nil) {
            NSError *missing = [NSError errorWithDomain:@"io.purchasely.v6"
                                                   code:404
                                               userInfo:@{NSLocalizedDescriptionKey: @"Presentation not found"}];
            NSMutableDictionary *presented = [NSMutableDictionary new];
            presented[@"requestId"] = requestId;
            presented[@"error"] = V6ErrorToMap(missing);
            [strongSelf v6EmitEvent:kV6EventPresented body:presented];

            emitDismissed(missing);
            return;
        }

        capturedPresentation = presentation;
        kV6PresentationsByRequest[requestId] = presentation;

        // Emit onPresented (no native callback for it yet — we fire after the
        // controller becomes available).
        NSMutableDictionary *presented = [NSMutableDictionary new];
        presented[@"requestId"] = requestId;
        presented[@"presentation"] = V6PresentationToMap(presentation);
        [strongSelf v6EmitEvent:kV6EventPresented body:presented];

        UIViewController *controller = presentation.controller;
        if (controller == nil) {
            NSError *err = [NSError errorWithDomain:@"io.purchasely.v6"
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

    void (^onResultCompletion)(PLYProductViewControllerResult, PLYPlan * _Nullable) =
    ^(PLYProductViewControllerResult result, PLYPlan * _Nullable plan) {
        capturedResult = result;
        capturedPlan = plan;
        hasPurchaseOutcome = YES;
        emitDismissed(nil);
    };

    dispatch_async(dispatch_get_main_queue(), ^{
        if (placementId != nil) {
            [Purchasely fetchPresentationFor:placementId
                                   contentId:contentId
                              fetchCompletion:onFetchCompletion
                                   completion:onResultCompletion
                            loadedCompletion:nil];
        } else if (presentationId != nil) {
            [Purchasely fetchPresentationWith:presentationId
                                    contentId:contentId
                             fetchCompletion:onFetchCompletion
                                    completion:onResultCompletion
                             loadedCompletion:nil];
        } else {
            NSError *error = [NSError errorWithDomain:@"io.purchasely.v6"
                                                 code:400
                                             userInfo:@{NSLocalizedDescriptionKey: @"No placementId or screenId provided"}];
            onFetchCompletion(nil, error);
        }
        resolve(@(YES));
    });
}

#pragma mark - v6Close / v6Back

RCT_EXPORT_METHOD(v6Close:(NSString *)requestId) {
    V6EnsureInternalState();
    dispatch_async(dispatch_get_main_queue(), ^{
        // Notify JS so the host app can react before the native dismissal happens.
        [self v6EmitEvent:kV6EventCloseRequested body:@{ @"requestId": requestId ?: @"" }];
        self.presentedPresentationViewController = nil;
        [Purchasely closeDisplayedPresentation];
        [kV6PresentationsByRequest removeObjectForKey:requestId];
    });
}

RCT_EXPORT_METHOD(v6Back:(NSString *)requestId) {
    // The legacy iOS SDK does not expose a `back()` primitive on the
    // presentation controller. Bridge contract says: noop with a warn.
    RCTLogWarn(@"[v6] v6Back(%@) is not yet bridged on iOS", requestId);
}

#pragma mark - Interceptors

RCT_EXPORT_METHOD(v6RegisterInterceptor:(NSString *)kind) {
    V6EnsureInternalState();
    [kV6InterceptorKinds addObject:kind];

    // The iOS SDK exposes a single global interceptor — we wire it once and
    // dispatch to JS only for the registered kinds. Re-installing the same
    // block on each call is safe (the SDK replaces the previous one).
    dispatch_async(dispatch_get_main_queue(), ^{
        __weak PurchaselyRN *weakSelf = self;
        [Purchasely setPaywallActionsInterceptor:^(PLYPresentationAction action,
                                                     PLYPresentationActionParameters * _Nullable params,
                                                     PLYPresentationInfo * _Nullable infos,
                                                     void (^ _Nonnull onProcessActionHandler)(BOOL)) {
            PurchaselyRN *strongSelf = weakSelf;
            if (!strongSelf) {
                onProcessActionHandler(YES);
                return;
            }

            NSString *actionKind = V6StringFromAction(action);
            if (![kV6InterceptorKinds containsObject:actionKind]) {
                // JS did not register this kind — fall through to native default.
                onProcessActionHandler(YES);
                return;
            }

            NSString *callbackId = [[NSUUID UUID] UUIDString];
            kV6InterceptorCallbacks[callbackId] = ^(NSString *result) {
                // Map InterceptResult → bool the native interceptor expects.
                //   - success / failed → JS handled the action: don't proceed natively.
                //   - notHandled       → let the SDK perform its default behavior.
                BOOL proceed = [result isEqualToString:@"notHandled"];
                onProcessActionHandler(proceed);
            };

            // Serialize info + payload.
            NSMutableDictionary *info = [NSMutableDictionary new];
            if (infos.contentId != nil) {
                info[@"contentId"] = infos.contentId;
            }
            if (infos.presentationId != nil) {
                // Surface the loaded PLYPresentation if we still have it cached.
                PLYPresentation *cached = nil;
                for (PLYPresentation *p in PurchaselyRN.presentationsLoaded) {
                    if ([p.id isEqualToString:infos.presentationId]) {
                        cached = p;
                        break;
                    }
                }
                NSMutableDictionary *presentationMap = [NSMutableDictionary new];
                presentationMap[@"screenId"] = infos.presentationId;
                presentationMap[@"id"] = infos.presentationId;
                if (infos.placementId != nil) {
                    presentationMap[@"placementId"] = infos.placementId;
                }
                if (cached != nil) {
                    NSDictionary *full = V6PresentationToMap(cached);
                    [presentationMap addEntriesFromDictionary:full];
                }
                info[@"presentation"] = presentationMap;
            }

            NSMutableDictionary *payloadOut = [NSMutableDictionary new];
            if (params != nil) {
                switch (action) {
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
                        // iOS has no closeReason yet — default to "button"
                        // (cf. contract: iOS closeReason always null/button until fix).
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
                            V6StringFromWebCheckoutProvider(params.webCheckoutProvider);
                        break;
                    }
                    default:
                        break;
                }
            }

            NSMutableDictionary *event = [NSMutableDictionary new];
            event[@"requestId"] = @"";
            event[@"callbackId"] = callbackId;
            event[@"kind"] = actionKind;
            event[@"info"] = info;
            event[@"payload"] = payloadOut;
            [strongSelf v6EmitEvent:kV6EventActionIntercepted body:event];
        }];
    });
}

RCT_EXPORT_METHOD(v6UnregisterInterceptor:(NSString *)kind) {
    V6EnsureInternalState();
    [kV6InterceptorKinds removeObject:kind];
    if (kV6InterceptorKinds.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [Purchasely setPaywallActionsInterceptor:nil];
        });
    }
}

RCT_EXPORT_METHOD(v6CompleteInterceptor:(NSString *)callbackId result:(NSString *)result) {
    V6EnsureInternalState();
    void (^cb)(NSString *) = kV6InterceptorCallbacks[callbackId];
    if (cb != nil) {
        [kV6InterceptorCallbacks removeObjectForKey:callbackId];
        cb(result);
    }
}

#pragma mark - Start options

RCT_EXPORT_METHOD(v6ApplyStartOptions:(NSDictionary *)options) {
    if (![options isKindOfClass:[NSDictionary class]]) { return; }
    id allowDeeplink = options[@"allowDeeplink"];
    if ([allowDeeplink isKindOfClass:[NSNumber class]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [Purchasely readyToOpenDeeplink:[allowDeeplink boolValue]];
        });
    }
    // `allowCampaigns` is honored on Android via the consent manager; on iOS
    // the equivalent is not exposed publicly yet — JS clients receive the value
    // back through the start payload but iOS does not yet act on it.
    id allowCampaigns = options[@"allowCampaigns"];
    if ([allowCampaigns isKindOfClass:[NSNumber class]] && ![allowCampaigns boolValue]) {
        RCTLogWarn(@"[v6] allowCampaigns(false) is not bridged on iOS yet");
    }
}

@end
