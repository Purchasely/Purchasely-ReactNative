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
  - `Purchasely.presentation` — the `PresentationBuilder` (`.placement(id)`,
    `.screen(id)`, `.default()`).
  - `Purchasely.interceptAction(kind, handler)` — typed action interception.
- `PresentationBuilder.build()` returns a **`PresentationRequest`** with a
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
| `Purchasely.clientPresentationDisplayed(...)` / `Purchasely.clientPresentationClosed(...)` | **Removed** — Client/BYOS presentations use the `PLYPresentationRequest` lifecycle (`display()` / `close()`). |
| `FetchPresentationParameters` / `PresentPresentation*Parameters` / `PresentProductParameters` / `PresentPlanParameters` / `PaywallActionInterceptorResult` | **Removed** — replaced by the `PLYPresentationBuilder` / `interceptAction(kind, handler)` types. |
| `setUserAttributeWithInt / setUserAttributeWithDouble` / `…WithIntArray / …WithDoubleArray` | **Added** — Flutter-compatible aliases of the `WithNumber / WithNumberArray` setters. |

### New v6 helpers (Flutter parity)

- `Purchasely.apiKey(key)` — alias of `Purchasely.builder(key)` (Flutter `Purchasely.apiKey(...)`).
- `Purchasely.allowCampaigns(allow)` — runtime toggle for automatic campaigns (callable after `start()`).
- `Purchasely.listenToEvents(cb)` / `Purchasely.stopListeningToEvents()` — Flutter-compatible aliases of `addEventListener` / `removeEventListener`.
- `Purchasely.listenToPurchases(cb)` / `Purchasely.stopListeningToPurchases()` — Flutter-compatible aliases of `addPurchasedListener` / `removePurchasedListener`.
- `Purchasely.setUserAttributeListener(listener)` / `Purchasely.clearUserAttributeListener()` — bundle the per-attribute set/remove listeners.
- `Purchasely.getConstants()` is kept for backward compatibility.

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
  .start()
```

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

## Pre-fetching (preload)

### Before (v5 — removed)

```typescript
const presentation = await Purchasely.fetchPresentation({ placementId: 'ONBOARDING' })
const result = await Purchasely.presentPresentation({ presentation })
```

### After (v6)

```typescript
const request = Purchasely.presentation.placement('ONBOARDING').build()
const presentation = await request.preload() // resolves when the screen is loaded
// later, when ready to show it:
const outcome = await request.display()
```

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

> `request.close()` currently dismisses **all** displayed presentations (the
> native SDK does not yet expose a per-request close). If you stack
> presentations, closing one will dismiss the others.

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
  `purchaseWithPlanVendorId`, `signPromotionalOffer`, `isEligibleForIntroOffer`,
  `setDynamicOffering`, `getDynamicOfferings`, `removeDynamicOffering`,
  `clearDynamicOfferings`.
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
- **Client (BYOS) presentations**: handled via the `PLYPresentationRequest`
  lifecycle (`preload()` → inspect `PLYPresentationType.CLIENT` → render your
  own UI). The old `clientPresentationDisplayed` /
  `clientPresentationClosed` helpers are removed.
- **Misc**: `setLogLevel`, `setLanguage`, `setThemeMode`, `setDebugMode`,
  `revokeDataProcessingConsent`, `getConstants`.
- **Embedded component**: `PLYPresentationView` — unchanged.

---

## Need a hand?

Use the Purchasely AI plugin / skills (`purchasely-integrate`,
`purchasely-review`, `purchasely-debug`) to scan your project and apply this
migration automatically.
