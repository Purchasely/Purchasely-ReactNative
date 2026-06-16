# Changelog

All notable changes to `react-native-purchasely` are documented in this file.

## [6.0.0] — Unreleased

### Added — v6 cross-platform builder API

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

### Breaking changes — v5 paywall API removed

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
listeners, `clientPresentationDisplayed` / `clientPresentationClosed`) and the
embedded `PLYPresentationView` component behave exactly as in 5.x.

### iOS TODOs (tracked in the bridge code)

- Wire `closeReason` once the native iOS SDK exposes the dismissal reason.
- Map `screenId` directly when iOS adds a dedicated property (currently
  aliased to `presentation.id`).
- Drop the synthesized `onPresented` once the native callback ships.

## [5.7.3] and earlier

See [git history](https://github.com/Purchasely/Purchasely-ReactNative/commits/main)
for releases prior to v6.
