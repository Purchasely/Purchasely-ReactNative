# React Native Purchasely

Purchasely helps React Native apps display paywalls and manage in-app purchases and subscriptions on the App Store, Google Play, Huawei AppGallery and Amazon Appstore.

## Installation

```sh
npm install react-native-purchasely
```

Install the Android store package(s) you need at the same version as the core package:

```sh
npm install @purchasely/react-native-purchasely-google
npm install @purchasely/react-native-purchasely-android-player # optional video support
```

All Purchasely React Native packages must use the exact same version.

## Initialization (v6)

The v5 paywall API (`start({...})`, `startWithAPIKey`, `fetchPresentation`, `presentPresentationForPlacement`, `setPaywallActionInterceptorCallback`, `onProcessAction`, `readyToOpenDeeplink`, …) has been removed. Use the builder API:

```ts
import Purchasely from 'react-native-purchasely'

const configured = await Purchasely.builder('YOUR_API_KEY')
  .appUserId(null)              // optional
  .runningMode('full')          // 'observer' (default) | 'full'
  .logLevel('debug')            // 'debug' | 'info' | 'warn' | 'error'
  .stores(['google'])           // Android only: 'google' | 'huawei' | 'amazon'
  .storekitVersion('storeKit2') // iOS only: 'storeKit1' | 'storeKit2'
  .allowDeeplink(true)          // call when your navigation is ready
  .allowCampaigns(true)
  .start()
```

## Display a paywall

```ts
const outcome = await Purchasely.presentation
  .placement('ONBOARDING')
  .contentId('content_123')
  .build()
  .display()

if (outcome.error) {
  console.error(outcome.error.message)
} else if (outcome.purchaseResult === 'purchased' || outcome.purchaseResult === 'restored') {
  console.log('Purchased plan:', outcome.plan)
} else {
  console.log('Dismissed:', outcome.closeReason)
}
```

Use `Purchasely.presentation.screen('SCREEN_ID')` to target a specific screen, or `.default()` for the SDK default placement. `build()` returns a request with `preload()`, `display()`, `close()` and `back()`.

## Action interception

```ts
Purchasely.interceptAction('purchase', async (_info, payload) => {
  if (payload?.kind !== 'purchase') return 'notHandled'

  const handled = await myBilling.purchase(payload.plan.productId)
  return handled ? 'success' : 'failed'
})

Purchasely.interceptAction('navigate', async (_info, payload) => {
  if (payload?.kind !== 'navigate') return 'notHandled'
  await Linking.openURL(payload.url)
  return 'success'
})
```

Handlers return `'success' | 'failed' | 'notHandled'`; there is no `onProcessAction` in v6.

## Embedded paywall

`PLYPresentationView` remains available for embedded paywalls:

```tsx
import { PLYPresentationView } from 'react-native-purchasely'

<PLYPresentationView
  placementId="ACCOUNT"
  flex={1}
  onPresentationClosed={(result) => console.log(result)}
/>
```

## Migration guide

See [`MIGRATION-v6.md`](../../MIGRATION-v6.md) for the complete v5 → v6 mapping and platform limitations.

## Documentation

Full documentation: [Purchasely Docs](https://docs.purchasely.com/quick-start/sdk-installation/react-native-sdk).
