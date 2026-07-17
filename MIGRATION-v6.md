# Migrating to Purchasely React Native SDK v6

Purchasely React Native SDK **v6 is paywall-API-only**: the legacy v5 paywall
API has been **REMOVED** (not deprecated). Calling any of the removed methods
will fail to compile (TypeScript) and the methods no longer exist at runtime.

This guide maps every removed v5 paywall method to its v6 replacement and lists
the methods that are **unchanged**.

> **Tip — let the AI help you migrate.** The Purchasely AI plugin and the
> `purchasely-integrate`, `purchasely-review` and `purchasely-debug` skills can
> read your integration and rewrite the v5 paywall calls to the v6 builder API
> for you. Point them at the files that call `Purchasely.start`,
> `presentPresentationForPlacement`, `fetchPresentation`,
> `setPaywallActionInterceptorCallback`, etc.

---

## TL;DR

- The paywall surface is now built around three entry points exposed on the
  `Purchasely` default export:
  - `Purchasely.builder(apiKey)` — chainable SDK start.
  - `Purchasely.presentation` — the `PLYPresentationBuilder` (`.placement(id)`,
    `.screen(id)`, `.defaultSource()`). `.default()` remains a valid alias of
    `.defaultSource()` (it matches the iOS entry-point name).
  - `Purchasely.interceptAction(kind, handler)` — typed action interception.
- `PLYPresentationBuilder.build()` returns a **`PLYPresentationRequest`** with a
  lifecycle (`preload()`, `display(transition?)`, `close()`, `back()`).
- `display()` resolves at **dismiss** with a 5-field `PLYPresentationOutcome`
  (`{ presentation, purchaseResult, plan, closeReason, error }`).
- **All CORE methods are UNCHANGED** — see [Unchanged](#whats-unchanged).

---

## Removed v5 paywall API → v6 replacement

| Removed v5 method | v6 replacement |
|-------------------|----------------|
| `Purchasely.start({ apiKey, androidStores, storeKit1, userId, logLevel, runningMode })` | `Purchasely.builder(apiKey).appUserId(userId).runningMode('full').logLevel('error').stores(['google']).storekitVersion('storeKit2').start()` |
| `Purchasely.startWithAPIKey(apiKey, stores, userId, logLevel, runningMode)` | `Purchasely.builder(apiKey).appUserId(userId).runningMode('full').start()` |
| `Purchasely.fetchPresentation({ placementId })` | `Purchasely.presentation.placement(id).build().preload()` |
| `Purchasely.presentPresentationForPlacement({ placementVendorId })` | `Purchasely.presentation.placement(id).build().display()` |
| `Purchasely.presentPresentationWithIdentifier({ presentationVendorId })` | `Purchasely.presentation.screen(id).build().display()` |
| `Purchasely.presentPresentation({ presentation })` | preload then display the same request: `const req = Purchasely.presentation.placement(id).build(); await req.preload(); await req.display()` |
| `Purchasely.presentProductWithIdentifier(productId, …)` | `Purchasely.presentation.screen(id).contentId(contentId).build().display()` |
| `Purchasely.presentPlanWithIdentifier(planId, …)` | `Purchasely.presentation.screen(id).build().display()` |
| `Purchasely.showPresentation()` / `Purchasely.presentPresentation(...)` | request lifecycle: `request.display()` |
| `Purchasely.hidePresentation()` / `Purchasely.closePresentation()` | request lifecycle: `request.close()` |
| `Purchasely.setPaywallActionInterceptorCallback(cb)` + `Purchasely.onProcessAction(bool)` | `Purchasely.interceptAction(kind, handler)` — handler returns `'success' \| 'failed' \| 'notHandled'` (no more `onProcessAction`) |
| `Purchasely.setDefaultPresentationResultCallback(cb)` / `setDefaultPresentationResultHandler(cb)` | `Purchasely.setDefaultPresentationDismissHandler(outcome => …)` — global handler for presentations the SDK opens itself (campaigns, deeplinks, Promoted IAP). For paywalls **you** display, use `request.onDismissed(outcome => …)` instead. |
| `Purchasely.readyToOpenDeeplink(true)` | `Purchasely.builder(apiKey).allowDeeplink(true).start()` |
| `Purchasely.close()` (top-level) | `request.close()` on a `PLYPresentationRequest` |
| `Purchasely.displaySubscriptionCancellationInstruction()` | **Removed** — cancellation UX is owned by the OS/App Store; the SDK no longer opens it. |
| `Purchasely.clientPresentationDisplayed(...)` / `Purchasely.clientPresentationClosed(...)` | **Kept — NOT removed.** Same JS API as v5; pass the presentation obtained from `preload()`. Only the underlying iOS native call was renamed (`clientPresentationOpened` → `clientPresentationDisplayed`), which is invisible to JS. |
| `FetchPresentationParameters` / `PresentPresentation*Parameters` / `PresentProductParameters` / `PresentPlanParameters` / `PaywallActionInterceptorResult` | **Removed** — replaced by the `PLYPresentationBuilder` / `interceptAction(kind, handler)` types. |
| `setUserAttributeWithInt / setUserAttributeWithDouble` / `…WithIntArray / …WithDoubleArray` | **Added** — Flutter-compatible aliases of the `WithNumber / WithNumberArray` setters. |

### New v6 helpers (Flutter parity)

- `Purchasely.apiKey(key)` — alias of `Purchasely.builder(key)` (Flutter `Purchasely.apiKey(...)`).
- `Purchasely.allowCampaigns(allow)` — runtime toggle for automatic campaigns (callable after `start()`).
- `Purchasely.listenToEvents(cb)` / `Purchasely.stopListeningToEvents()` — Flutter-compatible aliases of `addEventListener` / `removeEventListener`.
- `Purchasely.listenToPurchases(cb)` / `Purchasely.stopListeningToPurchases()` — Flutter-compatible aliases of `addPurchasedListener` / `removePurchasedListener`.
- `Purchasely.setUserAttributeListener(listener)` / `Purchasely.clearUserAttributeListener()` — bundle the per-attribute set/remove listeners.
- `Purchasely.closeAllScreens()` — closes every displayed Purchasely screen,
  regardless of which `PLYPresentationRequest` opened it. Distinct from
  `request.close()`, which is scoped to a single request on iOS (Android's
  `request.close()` already dismisses everything, since the native SDK has no
  per-request close there yet).
- `Purchasely.userLogout(clearUserAttributes = true)` — both native SDKs
  already accept this parameter; it is now exposed instead of being hardcoded
  (iOS always passed `true`) / omitted (Android). Pass `false` to log out
  without clearing locally-stored user attributes.

---

## Initialization

### Before (v5 — removed)

```typescript
import Purchasely, { LogLevels, RunningMode } from 'react-native-purchasely'

await Purchasely.start({
  apiKey: 'YOUR_API_KEY',
  androidStores: ['Google'],
  storeKit1: false,
  userId: 'user_id',
  logLevel: LogLevels.ERROR,
  runningMode: RunningMode.FULL,
})

Purchasely.readyToOpenDeeplink(true)
```

### After (v6)

```typescript
import Purchasely from 'react-native-purchasely'

const configured = await Purchasely.builder('YOUR_API_KEY')
  .appUserId('user_id')        // optional, defaults to anonymous
  .runningMode('full')         // 'observer' (default) | 'full'
  .logLevel('error')           // 'debug' | 'info' | 'warn' | 'error'
  .allowDeeplink(true)         // replaces readyToOpenDeeplink(true)
  .allowCampaigns(true)        // automatic campaigns
  .stores(['google'])          // Android only: 'google' | 'huawei' | 'amazon'
  .storekitVersion('storeKit2')// iOS only: 'storeKit1' | 'storeKit2'
  .handleDeeplink(coldStartUrl)// optional cold-start deeplink, see note below
  .start()
```

> **Cold-start deeplink — `.handleDeeplink(deeplink)`.** Hand the SDK the
> deeplink that launched the app from a cold start. At process launch the
> deeplink listener is not registered yet, so the builder **stores the deeplink
> and replays it once `start()` has completed** — a paywall opened by a deeplink
> is therefore not lost during startup. For deeplinks received while the app is
> already running, keep using the top-level `Purchasely.handleDeeplink(url)`
> method (see
> [Deeplinks](#deeplinks-campaigns--the-default-dismiss-handler)).

> **⚠️ Major breaking change — the default `runningMode` is now `'observer'`
> (v5 effectively defaulted to `full`).** This is a **silent behavioural change**:
> it does **not** produce a compile error, so an app that previously let
> Purchasely own the purchase flow will **stop doing so** after upgrading unless
> it explicitly passes `.runningMode('full')`. Audit every `start()`/`builder()`
> call. The change is consistent across platforms (iOS, Android, Flutter, React
> Native), including the native fallback: any unknown/unset value now resolves to
> `observer`, never `full`.

---

## Displaying a paywall

### Before (v5 — removed)

```typescript
const result = await Purchasely.presentPresentationForPlacement({
  placementVendorId: 'ONBOARDING',
  contentId: 'my_content_id',
  isFullscreen: true,
})

switch (result.result) {
  case ProductResult.PRODUCT_RESULT_PURCHASED:
  case ProductResult.PRODUCT_RESULT_RESTORED:
    console.log('Purchased', result.plan?.name)
    break
  case ProductResult.PRODUCT_RESULT_CANCELLED:
    break
}
```

### After (v6)

`display()` resolves at **dismiss** with a `PLYPresentationOutcome`:

```typescript
const outcome = await Purchasely.presentation
  .placement('ONBOARDING')
  .contentId('my_content_id')
  .build()
  .display()

// outcome: { presentation, purchaseResult, plan, closeReason, error }
if (outcome.error) {
  console.error(outcome.error.message)
} else if (outcome.purchaseResult === 'purchased' || outcome.purchaseResult === 'restored') {
  console.log('Purchased', outcome.plan?.name)
} else {
  console.log('Dismissed', outcome.closeReason) // 'button' | 'backSystem' | 'programmatic'
}
```

`purchaseResult` is now a string union (`'purchased' | 'cancelled' | 'restored'`)
instead of the `ProductResult` ordinal enum.

### Targeting a specific screen / product / plan

```typescript
// Specific presentation by screen id (was presentPresentationWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').build().display()

// Specific product (was presentProductWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').contentId('CONTENT_ID').build().display()

// Specific plan (was presentPlanWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').build().display()
```

---

## Presentation builder options

`Purchasely.presentation` (a `PLYPresentationBuilder`) chains modifiers before
`.build()`:

| Modifier | Effect |
|----------|--------|
| `.contentId(id)` | Preselects a product/plan content id (was the `contentId` parameter on the v5 present\* calls). |
| `.backgroundColor(hex)` | Overrides the paywall background colour, e.g. `'#101828'`. |
| `.progressColor(hex)` | Overrides the loading-indicator colour. |
| `.displayCloseButton(bool)` | Toggles the close button. |
| `.displayBackButton(bool)` | Toggles the back button. |

```typescript
await Purchasely.presentation
  .placement('ONBOARDING')
  .contentId('my_content_id')
  .backgroundColor('#101828')
  .progressColor('#FFFFFF')
  .displayCloseButton(false)
  .displayBackButton(false)
  .build()
  .display()
```

> **⚠️ Platform difference for the button/colour toggles.** On **Android** these
> are **full toggles** — `true` shows the element, `false` hides it. On **iOS**
> they are **removal-only**: only passing `false` has an effect (it hides the
> element); passing `true` does **not** force-show an element the screen did not
> already define. Design for the `false` case and treat the shown state as the
> screen default.

---

## Display transitions — `display(transition?)`

`request.display()` accepts an optional transition object describing **how** the
paywall is presented:

```typescript
await request.display({
  type: 'drawer',                          // presentation style, see table
  dismissible: true,                       // allow interactive dismissal
  width:  { type: 'percentage', value: 100 },
  height: { type: 'percentage', value: 60 },
  backgroundColors: { light: '#FFFFFF', dark: '#000000' },
})
```

| `type` | Description |
|--------|-------------|
| `'fullScreen'` | Full-screen (default). |
| `'push'` | Pushed onto the navigation stack. |
| `'modal'` | Modal presentation. |
| `'drawer'` | Bottom drawer sized by `width` / `height`. |
| `'popin'` | Centered pop-in sized by `width` / `height`. |
| `'inlinePaywall'` | Inline within your own layout. |

- `width` / `height` are **dimension objects** — `{ type: 'pixel' | 'percentage', value }`
  — and are used to size `drawer` / `popin` transitions.
- `dismissible` (bool) controls whether the user can dismiss the transition
  interactively.
- `backgroundColors` sets the scrim/background per theme: `{ light, dark }`.

> **v5 → v6 dimension change.** The v5 `heightPercentage` field is **replaced**
> by `height: { type: 'percentage', value }` (and, symmetrically, `width`).

> **iOS ceiling on `width` / pixel `height` (SDK 6.0.0-rc.3).** iOS now uses the
> real v6 display path (`type`, `height` as a percentage, `dismissible`,
> `backgroundColors` all honoured) instead of a hardcoded legacy screen type.
> However the native SDK only bridges a legacy 0–1 `heightPercentage` to
> Objective-C in this release — not the typed pixel/percentage `PLYDimension`
> Swift API. So on iOS: `height: { type: 'percentage', value }` works;
> `height: { type: 'pixel', ... }` and `width` (any type) are accepted but
> silently ignored (native falls back to its own content-hugging sizing), with
> a console warning. Android honours `width` / `height` for both units.

---

## Pre-fetching (preload)

### Before (v5 — removed)

```typescript
const presentation = await Purchasely.fetchPresentation({ placementId: 'ONBOARDING' })
const result = await Purchasely.presentPresentation({ presentation })
```

### After (v6)

`preload()` resolves with a **`PLYLoadedPresentation`** once the screen is fully
loaded. It is a lightweight handle that **delegates back to the originating
request**, so you can drive either the request or the loaded handle:

```typescript
const request = Purchasely.presentation.placement('ONBOARDING').build()

const loaded = await request.preload()  // PLYLoadedPresentation, screen is ready
// …later, when ready to show it (both forms are equivalent):
const outcome = await loaded.display()  // or: await request.display()
```

`PLYLoadedPresentation` exposes the same lifecycle as the request —
`display(transition?)`, `close()` and `back()` — each delegating to the request
it was preloaded from.

> **Platform difference for `close()`.** On **Android**, `close()` dismisses
> **all** currently displayed presentations (a limitation of the native SDK,
> which does not yet expose a per-presentation close). On **iOS**, `close()`
> dismisses only the targeted presentation. Account for this if you stack
> presentations.

---

## Presentation lifecycle (show / hide / close)

The imperative `showPresentation` / `hidePresentation` / `closePresentation`
methods are replaced by the request lifecycle:

```typescript
const request = Purchasely.presentation.placement('ONBOARDING').build()

request.display()  // show
request.close()    // hide / close
request.back()     // navigate back inside a multi-step (Flow) presentation
```

> **Platform difference for `close()`.** On **Android**, `request.close()`
> currently dismisses **all** displayed presentations (the native SDK does not
> yet expose a per-request close), so if you stack presentations, closing one
> will dismiss the others. On **iOS**, only the targeted presentation is closed.

---

## Action interceptor

`setPaywallActionInterceptorCallback` + `onProcessAction` are replaced by
`Purchasely.interceptAction(kind, handler)`. Register **one handler per action
kind**; the handler returns `'success' | 'failed' | 'notHandled'` instead of
calling `onProcessAction(true/false)`.

### Before (v5 — removed)

```typescript
Purchasely.setPaywallActionInterceptorCallback((result) => {
  if (result.action === PLYPaywallAction.PURCHASE) {
    MyPurchaseSystem.purchase(result.parameters.plan.productId)
    Purchasely.onProcessAction(false)
  } else {
    Purchasely.onProcessAction(true)
  }
})
```

### After (v6)

```typescript
import { Linking } from 'react-native'

Purchasely.interceptAction('purchase', async (info, payload) => {
  if (payload?.kind === 'purchase') {
    const ok = await MyPurchaseSystem.purchase(payload.plan.productId)
    return ok ? 'success' : 'failed'
  }
  return 'notHandled'
})

Purchasely.interceptAction('navigate', async (info, payload) => {
  if (payload?.kind === 'navigate') {
    Linking.openURL(payload.url)
    return 'success'
  }
  return 'notHandled'
})

// Cleanup
Purchasely.removeActionInterceptor('purchase')
Purchasely.removeAllActionInterceptors()
```

Known action kinds: `close`, `closeAll`, `login`, `navigate`, `purchase`,
`restore`, `openPresentation`, `openPlacement`, `promoCode`, `webCheckout`.

> The `kind` argument and the `payload.kind` discriminant are typed by the
> `PLYPresentationActionKind` string union — this is the **only** action
> vocabulary in v6. The v5 `PLYPaywallAction` enum has been **removed**.

---

## Deeplinks, campaigns & the default dismiss handler

```typescript
// Allow deeplinks (replaces readyToOpenDeeplink(true)) — set at start:
await Purchasely.builder('YOUR_API_KEY').allowDeeplink(true).start()
```

There are **two distinct paywall flows** — don't conflate them:

### 1. Paywalls **you** display

When your app instantiates the presentation, read the result from that request
(`await display()` or `request.onDismissed(...)`):

```typescript
const outcome = await Purchasely.presentation.placement('ONBOARDING').build().display()
```

### 2. Paywalls the **SDK** opens itself (campaigns, deeplinks, Promoted IAP)

Your app never calls `display()` for these, so there is no request to attach a
callback to. Register the **global default dismiss handler** instead. It is the
v6 replacement for `setDefaultPresentationResultCallback` /
`setDefaultPresentationResultHandler`, and mirrors the native
`Purchasely.setDefaultPresentationDismissHandler`:

```typescript
import Purchasely from 'react-native-purchasely'

const subscription = Purchasely.setDefaultPresentationDismissHandler((outcome) => {
  // outcome: { presentation, purchaseResult, plan, closeReason, error }
  // `presentation` is always populated here — use it to tell which
  // campaign/deeplink screen closed.
  console.log(
    'SDK paywall dismissed:',
    outcome.presentation?.screenId,
    outcome.purchaseResult, // 'purchased' | 'restored' | 'cancelled' | null
    outcome.closeReason     // 'button' | 'backSystem' | 'programmatic' | null
  )
})

// Only one handler is active at a time — calling again replaces it.
// Remove it (e.g. on unmount) with either:
subscription.remove()
// …or:
Purchasely.removeDefaultPresentationDismissHandler()
```

> **Platform note.** `closeReason` mirrors the native `PLYCloseReason`
> (`button` / `backSystem` / `programmatic`) and is `null` when the SDK does not
> report a reason. The iOS interactive dismiss (swipe-down / nav pop) maps to
> `backSystem` for parity with Android's system back.

```typescript
// `isDeeplinkHandled` was RENAMED to `handleDeeplink` (matches the native SDK):
const handled = await Purchasely.handleDeeplink('app://ply/presentations/')
```

---

## Synchronize (now awaitable)

`Purchasely.synchronize()` previously returned `void` (fire-and-forget). The v6
native SDKs expose completion callbacks (iOS `synchronize(success:failure:)`,
Android `synchronize(onSuccess:(PLYPlan?)->Unit, onError:(PLYError?)->Unit)`),
so the bridge now returns a **`Promise<boolean>`** that resolves when the
receipt synchronization completes and rejects on failure.

This is **source-compatible**: existing fire-and-forget callers keep working
(they just ignore the returned promise). New code can await it:

```typescript
try {
  await Purchasely.synchronize() // resolves when the sync finishes
  console.log('Synchronized')
} catch (e) {
  console.error('Synchronize failed', e) // e.g. PLYError.NoStoreConfigured
}
```

> In Observer mode after a host-side purchase, `await Purchasely.synchronize()`
> before chaining a follow-up placement so the receipt is uploaded first.

---

## What's UNCHANGED

All **core** SDK methods are unchanged in name, signature, and behaviour. Only
the v5 *paywall* surface was removed (plus `synchronize`, which gained an
awaitable result — see above). The following keep working exactly as in v5:

- **User**: `userLogin`, `userLogout`, `getAnonymousUserId`, `isAnonymous`.
- **Products**: `allProducts`, `productWithIdentifier`, `planWithIdentifier`,
  `purchaseWithPlanVendorId`, `isEligibleForIntroOffer`,
  `setDynamicOffering`, `getDynamicOfferings`, `removeDynamicOffering`,
  `clearDynamicOfferings`.

> **`signPromotionalOffer` — iOS only, changed on Android.** iOS keeps its
> full StoreKit promotional-offer-signing behaviour, unchanged. Android has no
> native equivalent: the Android bridge used to permanently reject every call
> (`"Not supported on Android"`); it now resolves as a no-op success instead,
> so `await Purchasely.signPromotionalOffer(...)` no longer throws on
> Android — just don't rely on the shape of the resolved value there.
- **Subscriptions data**: `userSubscriptions`, `userSubscriptionsHistory`,
  `restoreAllProducts`, `silentRestoreAllProducts`,
  `userDidConsumeSubscriptionContent`.

> **Removed:** `presentSubscriptions()` no longer exists (iOS **and** Android).
> The native v6 SDKs dropped the built-in subscription-list UI — build your own
> screen from `userSubscriptions()` / `userSubscriptionsHistory()`.
- **Attributes**: `setUserAttributeWith{String,Number,Boolean,Date,StringArray,NumberArray,BooleanArray}`,
  `incrementUserAttribute`, `decrementUserAttribute`, `userAttributes`,
  `userAttribute`, `clearUserAttribute`, `clearUserAttributes`,
  `clearBuiltInAttributes`, `setAttribute`.
- **Listeners**: `addEventListener` / `removeEventListener`,
  `addPurchasedListener` / `removePurchasedListener`,
  `addUserAttributeSetListener` / `removeUserAttributeSetListener`,
  `addUserAttributeRemovedListener` / `removeUserAttributeRemovedListener`.
- **Client (BYOS) presentations**: `clientPresentationDisplayed(presentation)`
  / `clientPresentationClosed(presentation)` — unchanged. Preload via the
  request lifecycle (`preload()` → inspect `PLYPresentationType.CLIENT` →
  render your own UI), then notify Purchasely with these two methods, passing
  the presentation resolved by `preload()`. (Internally, the iOS native call
  was renamed `clientPresentationOpened` → `clientPresentationDisplayed`; no
  JS change.)
- **Misc**: `setLogLevel`, `setLanguage`, `setThemeMode`, `setDebugMode`,
  `revokeDataProcessingConsent`.
- **Embedded component**: `PLYPresentationView` — unchanged.

---

## Breaking changes in this release

- **`Purchasely.getConstants()` is no longer exposed publicly** (was
  previously kept for backward compatibility). It leaked a raw, 60+-field
  numeric blob — including dead v5 residue — as public API; every typed enum
  in this package (`LogLevels`, `SubscriptionSource`, `Attributes`, …) already
  reads the equivalent native constants internally, so use those instead of
  reading `getConstants()` fields directly. If you were reading a specific
  field, look for its typed enum equivalent.
- **`onesignalPlayerId` / `Attributes.ONESIGNAL_PLAYER_ID` removed** (iOS-only,
  no Android equivalent, and being removed from the native SDK). Replaced by
  `Attributes.ONESIGNAL_EXTERNAL_ID` / `Attributes.ONESIGNAL_USER_ID`, which
  both natives actually support.
- **`runningModeTransactionOnly` / `runningModePaywallObserver` removed** from
  `getConstants()`'s output (moot now that it's internal-only) — pure v5
  residue with no corresponding `RunningMode` enum case.
- **`purchaseResultFromOrdinal` no longer exported from the package root.** It
  was always documented `@internal`; only the public barrel re-export is
  removed — the SDK's own use of it (mapping `PLYPresentationOutcome.purchaseResult`)
  is unaffected.

## Need a hand?

Use the Purchasely AI plugin / skills (`purchasely-integrate`,
`purchasely-review`, `purchasely-debug`) to scan your project and apply this
migration automatically.
