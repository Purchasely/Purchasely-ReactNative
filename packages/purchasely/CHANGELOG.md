# Changelog

All notable changes to `react-native-purchasely` are documented in this file.

## [Unreleased]

## [6.0.0] — 2026-07-21

First stable release of Purchasely 6 for React Native. Native SDKs: iOS pod
`Purchasely` **6.0.0**, Android `io.purchasely:*` **6.0.1**.

### Changed (breaking)

- Public model types renamed to the `PLY*` prefix for cross-SDK parity with
  Flutter: `PurchaselyPlan`→`PLYPlan`, `PurchaselyProduct`→`PLYProduct`,
  `PurchaselyOffer`→`PLYPromoOffer`, `PurchaselySubscription`→`PLYSubscription`,
  `PurchaselySubscriptionOffer`→`PLYSubscriptionOffer`, `PurchaselyEvent*`→
  `PLYEvent*`, `PurchaselyEventsNames`→`PLYEventName`, `PurchaselyUserAttribute`
  →`PLYUserAttribute`, `PurchaselyPromotionalOfferSignature`→
  `PLYPromotionalOfferSignature`, `DynamicOffering`→`PLYDynamicOffering`. The
  `Purchasely` class and `PurchaselyBuilder` keep their names. The dead legacy
  `PurchaselyPresentation` type was removed (use the v6 `PLYPresentation`).

### Added

- `PLYPlan` offer-phase fields (`hasOfferPrice`, `offerPrice`, `offerAmount`,
  `offerDuration`, `offerPeriod`) and `basePlanId`, emitted under identical keys
  on iOS and Android.
- `PLYPromoOffer.publicId`.
- 8 analytics events on `PLYEventName` (`IN_APP_RENEWED`, `PLACEMENT_OPENED`,
  `PURCHASE_FROM_STORE_TAPPED`, `STORE_PRODUCT_FETCH_FAILED`, `WEB_CHECKOUT_*`).
- `userSubscriptionsHistory({ invalidateCache })` cache flag.
- Client-side `timeout` option on `restoreAllProducts` /
  `silentRestoreAllProducts`.
- `Purchasely.builder(...).automaticDeeplinkHandling(bool)` (Android-only).
- iOS `drawer` / `popin` transitions now honour `width` and pixel `height`
  (via a Swift `PLYDimension` shim); Android transitions now honour
  `backgroundColors` and map `inlinePaywall`.
- `getDynamicOfferings()` round-trips `billingPlanType`.

## [6.0.0-rc.3] — 2026-07-10

### Changed

- Native SDKs bumped to **6.0.0-rc.3** (iOS pod `Purchasely`, Android
  `io.purchasely:*`). The rc.3 header ships the renamed iOS entry points
  (`clientPresentationDisplayed(with:)`, `setDefaultPresentationDismissHandler`),
  so the bridge now calls them directly — the runtime
  `respondsToSelector:` guards and rc.2 fallbacks were removed.
- Android packages and the example app now use Kotlin **2.3.21**, matching the
  metadata version used to publish the rc.3 native Android SDK.
- The iOS bridge now consumes rc.3's `screenId` and `PLYPurchaseResult` APIs
  while preserving the existing JavaScript result ordinals; the pod deployment
  target is **iOS 15.1**, matching React Native 0.86.

### Fixed

- `Purchasely.clientPresentationDisplayed(presentation)` /
  `Purchasely.clientPresentationClosed(presentation)` are **kept** (they had
  been wrongly removed by the v6 migration — the native SDKs keep this API).
  Same JS signature as v5: pass the presentation resolved by
  `request.preload()`. The bridges resolve the loaded native presentation from
  their per-request registry by `screenId` (fallback `placementId`); if none
  matches, a warning is logged and the call is a no-op. On iOS the underlying
  native call was renamed (`clientPresentationOpened` →
  `clientPresentationDisplayed`); Android is unchanged.

## [6.0.0-rc.2] — 2026-07-03

### Added — v6 cross-platform builder API (Flutter parity)

- `Purchasely.apiKey(apiKey)` — Flutter-compatible alias of `Purchasely.builder(apiKey)`.
- `Purchasely.allowDeeplink(allow)` / `Purchasely.allowCampaigns(allow)` — runtime
  toggles. `allowDeeplink` / `allowCampaigns` are also chain modifiers on
  `Purchasely.builder(...)` and, when present, are forwarded to the native
  SDK through a single `applyStartOptions(...)` call.
- `Purchasely.listenToEvents(cb)` / `Purchasely.stopListeningToEvents()` and
  `Purchasely.listenToPurchases(cb)` / `Purchasely.stopListeningToPurchases()` —
  Flutter-compatible aliases of the existing `addEventListener` /
  `removeEventListener` / `addPurchasedListener` / `removePurchasedListener`.
- `Purchasely.setUserAttributeListener(listener)` /
  `Purchasely.clearUserAttributeListener()` — bundle the per-attribute
  set/remove listener registration.
- `setUserAttributeWithInt / setUserAttributeWithDouble` and
  `setUserAttributeWithIntArray / setUserAttributeWithDoubleArray` — Flutter
  parity aliases that delegate to the existing number setters.
- The action interceptor now normalises `info.presentation` against the full
  v6 contract (audience, AB-test, campaign, flow, language, plans, metadata,
  height) so handlers can rely on the same shape as `presentation.preload()`.
- `<PLYPresentationView request={...} />`: the embedded view now accepts a
  preloaded `PLYPresentationRequest`. It reuses the presentation already loaded
  by `request.preload()` (resolved natively by the request's `requestId`)
  instead of loading a second time — aligned with the native iOS/Android and
  Flutter SDKs. `PLYPresentationRequest` exposes a public `requestId` getter for
  this, and `onPresentationClosed` is now typed with `PLYPresentationViewResult`.

### Removed — obsolete v5 surface (Flutter parity)

- `Purchasely.close()` (top-level) — use `request.close()` on a
  `PLYPresentationRequest`.
- `Purchasely.displaySubscriptionCancellationInstruction()` — removed on
  RN to match Flutter v6 (cancellation UX is owned by the OS/App Store).
- Public types: `FetchPresentationParameters`,
  `PresentPresentationParameters`, `PresentPresentationWithIdentifierParameters`,
  `PresentPresentationPlacementParameters`, `PresentProductParameters`,
  `PresentPlanParameters`, `PaywallActionInterceptorResult`, `PLYPaywallInfo`,
  `PresentPresentationResult`, `FetchPresentationResult`.
- iOS `PurchaselyRN` no longer exposes `presentationsLoaded` /
  `setPresentationsLoaded:` / `findPresentationLoadedFor:` — the v6 bridge
  tracks requests by `requestId` only.
- Android `PurchaselyModule` no longer registers a separate
  `presentationsLoaded` list; per-request `PLYPresentationBase.Prepared`
  handles are now tracked via `activeLoadedPresentations` /
  `activePresentationRequests`.

### Native bridges

- iOS / Android `toRNMap` / `presentationToMap` now forward `campaignId` and
  `flowId` so the cross-platform bridge matches Flutter v6.
- iOS `PurchaselyRN` `readyToOpenDeeplink:` is kept as a native alias of
  `allowDeeplink:` (legacy callers). JS v6 users should prefer
  `Purchasely.builder(...).allowDeeplink(true).start()`.

### Testing & CI

- E2E runner now covers T1–T20 (was T1–T13). T14–T20 are the Flutter v6
  parity tests: extended user attribute types, bulk attribute operations,
  increment / decrement, catalog lookup, dynamic offerings, `screen(id)`
  with modal / popin transitions, and the config-setter smoke test.
- `run_e2e.sh` / `run_e2e_ios.sh` and the matching GitHub workflows now
  accept / report T1–T20 (timeout raised to 10 min).
- `e2e-android.yml` and `e2e-ios.yml` now run on `pull_request` (in
  addition to schedule / push / workflow_dispatch), filtered to the files
  that affect each workflow.
- `ci.yml` runs the Purchasely Android native unit tests
  (`:react-native-purchasely:testDebugUnitTest`) after the Android example
  build so every PR validates the Kotlin bridge.
The v6 façade is a chainable, type-safe API that mirrors the v6 Android/iOS
SDKs. It is now the **only** paywall API — the legacy v5 paywall methods have
been removed (see Breaking changes below).

- **`PurchaselyBuilder`** chained start (`apiKey(...).runningMode(...).start()`)
  replacing the multi-argument `Purchasely.start({...})`.
- **`PresentationBuilder`** with `.placement(id)`, `.screen(id)`, `.default()`
  factory methods, callback chain (`onLoaded`, `onPresented`,
  `onCloseRequested`, `onDismissed`), and `.build()` returning a
  `PresentationRequest`.
- **`PresentationRequest`** with `.preload()`, `.display(transition?)`,
  `.close()`, `.back()`. The `display()` Promise resolves at **dismiss**
  (not at trigger) with a 5-field `PresentationOutcome`.
- **`PresentationOutcome`**: `{ presentation, purchaseResult, plan, closeReason,
  error }`. Exclusion rule: `error != null ⇒ closeReason == null`.
- **`interceptAction(kind, handler)`** with typed payloads per action kind
  (`navigate`, `purchase`, `close`, `closeAll`, `openPresentation`,
  `openPlacement`, `webCheckout`, `login`, `restore`, `promoCode`). Handler
  returns `'success' | 'failed' | 'notHandled'`.
- **`removeActionInterceptor(kind)`** / **`removeAllActionInterceptors()`**.
- **5 native presentation events**: `PURCHASELY_PRESENTATION_LOADED`,
  `PURCHASELY_PRESENTATION_PRESENTED`,
  `PURCHASELY_PRESENTATION_CLOSE_REQUESTED`,
  `PURCHASELY_PRESENTATION_DISMISSED`,
  `PURCHASELY_ACTION_INTERCEPTED`.

### Native bridges

- **Android**: v6 presentation and interceptor wiring lives directly in
  `PurchaselyModule.kt` and uses the native v6 builder (`PLYPresentationBase.builder()`).
- **iOS**: v6 presentation and interceptor wiring lives directly in
  `PurchaselyRN.m`. The bridge uses the native v6 builder/interceptor APIs where
  available and still synthesizes missing fields such as `closeReason` until the
  native iOS pipeline exposes them.

### Breaking changes — v5 paywall API removed (v6)

The legacy v5 **paywall** API has been **removed** (not deprecated). The removed
methods no longer exist on the `Purchasely` export and will fail to compile.
Migrate to the v6 builders — see [`MIGRATION-v6.md`](../../MIGRATION-v6.md) for
the full old→new mapping. The Purchasely AI plugin / skills can assist the
migration.

Removed → replacement:

- `Purchasely.start({...})` / `startWithAPIKey(...)` →
  `Purchasely.builder(apiKey).<...>.start()`.
- `fetchPresentation({...})` →
  `Purchasely.presentation.placement(id).build().preload()`.
- `presentPresentationForPlacement({...})` →
  `Purchasely.presentation.placement(id).build().display()`.
- `presentPresentationWithIdentifier({...})` →
  `Purchasely.presentation.screen(id).build().display()`.
- `presentProductWithIdentifier(...)` →
  `Purchasely.presentation.screen(id).contentId(c).build().display()`.
- `presentPlanWithIdentifier(...)` →
  `Purchasely.presentation.screen(id).build().display()`.
- `showPresentation` / `hidePresentation` / `closePresentation` →
  request lifecycle (`request.display()` / `request.close()`).
- `setPaywallActionInterceptorCallback(...)` + `onProcessAction(...)` →
  `Purchasely.interceptAction(kind, handler)` (handler returns
  `'success' | 'failed' | 'notHandled'`).
- `setDefaultPresentationResultCallback(...)` /
  `setDefaultPresentationResultHandler(...)` →
  `request.onDismissed(outcome => ...)`.
- `readyToOpenDeeplink(true)` →
  `Purchasely.builder(apiKey).allowDeeplink(true).start()`.
- `presentSubscriptions()` → **removed** on both iOS and Android; the native v6
  SDKs no longer ship a built-in subscription-list UI. Build your own from
  `userSubscriptions()`.

The default `runningMode` is now `'observer'` (v5 defaulted to full control of
the purchase flow). Pass `.runningMode('full')` to keep the previous behaviour.

**Unchanged**: all CORE methods (user, products, subscription data, attributes,
listeners) and the embedded `PLYPresentationView` component behave exactly as in 5.x.
Client/BYOS presentations keep `clientPresentationDisplayed` /
`clientPresentationClosed`; preload through the v6 `PLYPresentationRequest`
lifecycle, render your own UI, then notify with these two methods.

### iOS TODOs (tracked in the bridge code)

- Wire `closeReason` once the native iOS SDK exposes the dismissal reason.
- Map `screenId` directly when iOS adds a dedicated property (currently
  aliased to `presentation.id`).
- Drop the synthesized `onPresented` once the native callback ships.

## [5.7.3] and earlier

See [git history](https://github.com/Purchasely/Purchasely-ReactNative/commits/main)
for releases prior to v6.
