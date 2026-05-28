# Changelog

All notable changes to `react-native-purchasely` are documented in this file.

## [6.0.0-beta.0] — Unreleased

### Added — v6 cross-platform builder API

The v6 façade is a chainable, type-safe API that mirrors the v6 Android/iOS
SDKs. It ships alongside the legacy v5 API for backwards compatibility — both
can be used in the same app during migration.

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
- **5 new native events**: `PURCHASELY_V6_LOADED`, `PURCHASELY_V6_PRESENTED`,
  `PURCHASELY_V6_CLOSE_REQUESTED`, `PURCHASELY_V6_DISMISSED`,
  `PURCHASELY_V6_ACTION_INTERCEPTED`.

### Native bridges

- **Android**: `PurchaselyV6Bridge` (Kotlin object) wired to the v6 SDK builder
  (`PLYPresentationBase.builder()`) — direct mapping of every contract item.
- **iOS**: `PurchaselyRN (V6)` category implemented on top of the legacy
  `fetchPresentationFor:contentId:fetchCompletion:completion:` while the
  native v6 SDK lands. The bridge synthesizes the 5-field outcome and the
  `onPresented(presentation?, error?)` callback per contract workarounds.
  `closeReason` stays `null` on iOS until the native pipeline exposes it.

### Breaking changes

None — the legacy v5 API stays exported and behaves exactly as in 5.x. New code
should use the v6 builders.

### Deprecated

- `Purchasely.start({...})` → use `PurchaselyBuilder.apiKey(...).start()`.
- `Purchasely.presentPresentationForPlacement({...})` → use
  `PresentationBuilder.placement(...).build().display()`.
- `Purchasely.setPaywallActionInterceptorCallback(...)` → use
  `interceptAction(kind, handler)` per action kind.

### iOS TODOs (tracked in the bridge code)

- Wire `closeReason` once the native iOS SDK exposes the dismissal reason.
- Map `screenId` directly when iOS adds a dedicated property (currently
  aliased to `presentation.id`).
- Drop the synthesized `onPresented` once the native callback ships.

## [5.7.3] and earlier

See [git history](https://github.com/Purchasely/Purchasely-ReactNative/commits/main)
for releases prior to v6.
