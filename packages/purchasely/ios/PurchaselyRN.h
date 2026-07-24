//
//  PurchaselyRN.h
//  Purchasely-ReactNative
//
//  Created by Jean-François GRANG on 15/11/2020.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
@import Purchasely;

@interface PurchaselyRN: RCTEventEmitter <RCTBridgeModule, PLYEventDelegate>

@property (nonatomic, retain) UIViewController* presentedPresentationViewController;

@property (class, nonatomic, strong) UIViewController *sharedViewController;

@property (nonatomic, assign) Boolean shouldReopenPaywall;

@property (nonatomic, assign) Boolean shouldEmit;

/// Look up a presentation that was preloaded through `preloadPresentation:` by
/// its bridge `requestId`. Used by the embedded `PLYPresentationView` to reuse a
/// presentation the JS layer already preloaded (instead of loading it again).
+ (nullable id<PLYPresentation>)loadedPresentationForRequestId:(nonnull NSString *)requestId;

/// Look up a presentation preloaded via `preloadPresentation:` matching the
/// given screen/placement identifiers, atomically removing it from the
/// registry — a matched presentation is single-use, claimed by whichever
/// embedded `PLYPresentationView` resolves it first. Used by the
/// `presentation` prop path, which carries a screen dict but no `requestId`.
+ (nullable id<PLYPresentation>)takeLoadedPresentationMatchingScreenId:(nullable NSString *)screenId
                                                            placementId:(nullable NSString *)placementId
    NS_SWIFT_NAME(takeLoadedPresentation(matchingScreenId:placementId:));

/// Evict a preloaded presentation's entry from the request registry without
/// closing or affecting anything on screen. Hardening for an embedded
/// `PLYPresentationView` that unmounts without ever dismissing (e.g. the host
/// navigates away), which would otherwise leak the entry forever since only
/// `emitPresentationDismissed(forId:outcome:)` purged it before. Mirrors
/// Android's `PurchaselyModule.evictPresentationRequest`. No-op if
/// `requestId` is nil or not a key in the registry.
+ (void)evictPresentationRequestId:(nullable NSString *)requestId
    NS_SWIFT_NAME(evictPresentationRequest(_:));

/// Emit a `PURCHASELY_PRESENTATION_DISMISSED` event for an embedded
/// `PLYPresentationView`, keyed by the id the JS component is routing on (the
/// bridge `requestId` when the view reuses a preloaded presentation, or a
/// component-generated id on the `presentation`/fresh `placementId` paths).
/// Mirrors the 5-field outcome the full-screen `displayPresentation:` path
/// emits, and purges `routingId`'s entry from the registry the same way (a
/// no-op if it was never a key there).
+ (void)emitPresentationDismissedForId:(nonnull NSString *)routingId
                                outcome:(nonnull PLYPresentationOutcome *)outcome
    NS_SWIFT_NAME(emitPresentationDismissed(forId:outcome:));

/// Emit a `PURCHASELY_PRESENTATION_CLOSE_REQUESTED` event for `requestId` —
/// the native SDK requesting a close on its own (native close button, swipe,
/// hardware back). Never emitted for a JS-programmatic `request.close()`
/// (`closePresentation:` clears the presentation's `onCloseRequested` before
/// closing it). Does not gate the dismissal: `onDismissed` /
/// `PURCHASELY_PRESENTATION_DISMISSED` still follows normally.
+ (void)emitPresentationCloseRequestedForId:(nonnull NSString *)requestId
    NS_SWIFT_NAME(emitPresentationCloseRequested(forId:));

/// Emit a `PRESENTATION_VIEWED` analytics event to JS for an embedded
/// `PLYPresentationView` that has just appeared on screen. The iOS native SDK
/// only fires this event through its own full-screen display flow
/// (`display()` / `showController:`); a manually embedded controller renders
/// correctly but never triggers it. Android's SDK DOES fire it for embedded
/// views, so the embedded view calls this to reach cross-platform parity — the
/// paywall is genuinely on screen at this point. No-op if the emitter is not
/// observing.
+ (void)emitEmbeddedPresentationViewedForRequestId:(nullable NSString *)requestId
                                        placementId:(nullable NSString *)placementId;

@end
