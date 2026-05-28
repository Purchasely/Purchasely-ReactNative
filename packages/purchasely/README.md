# React Native Purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store, and Huawei App Gallery.

## 🚀 Installation

```sh
npm install react-native-purchasely
```

## 🔧 Setup

Add the following code in the root of your project (typically `App.tsx` in a React Native project):

```ts
import Purchasely, { LogLevels, RunningMode } from 'react-native-purchasely';

Purchasely.startWithAPIKey(
  'afa96c76-1d8e-4e3c-a48f-204a3cd93a15',
  ['Google'], // List of stores for Android, accepted values: Google, Huawei, and Amazon
  null, // Your user ID
  LogLevels.DEBUG, // Log level, should be warning or error in production
  RunningMode.FULL // Running mode
).then(
  (configured) => {
    if (!configured) {
      console.log('Purchasely SDK not properly initialized');
      return;
    }

    console.log('Purchasely SDK is initialized');
    setupPurchasely();
  },
  (error) => {
    console.log('Purchasely SDK initialization error', error);
  }
);
```

## 🎬 Usage

### 1️⃣ Full Screen Paywall

```ts
import React from 'react';
import { Button, View } from 'react-native';
import Purchasely, { ProductResult } from 'react-native-purchasely';

const FullScreenPaywall = () => {
  const showPaywall = async () => {
    try {
      const result = await Purchasely.presentPresentationForPlacement({
        placementVendorId: 'composer',
        loadingBackgroundColor: '#FFFFFFFF',
      });

      console.log('Result is ' + result.result);

      switch (result.result) {
        case ProductResult.PRODUCT_RESULT_PURCHASED:
        case ProductResult.PRODUCT_RESULT_RESTORED:
          if (result.plan != null) {
            console.log('User purchased ' + result.plan.name);
          }
          break;
        case ProductResult.PRODUCT_RESULT_CANCELLED:
          console.log('User cancelled');
          break;
      }
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
      <Button title="Show Paywall" onPress={showPaywall} />
    </View>
  );
};

export default FullScreenPaywall;
```

### 2️⃣ Nested View Paywall

```ts
import { Text, View } from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { Header } from 'react-native/Libraries/NewAppScreen';
import { Section } from './Section.tsx';
import Purchasely, {
  PLYPresentationView,
  PresentPresentationResult,
  ProductResult,
  PurchaselyPresentation,
} from 'react-native-purchasely';
import { useEffect, useState } from 'react';

export const PaywallScreen: React.FC<NativeStackScreenProps<any>> = ({ navigation }) => {
  const [purchaselyPresentation, setPurchaselyPresentation] = useState<PurchaselyPresentation>();

  useEffect(() => {
    fetchPresentation();
  }, []);

  const fetchPresentation = async () => {
    try {
      setPurchaselyPresentation(
        await Purchasely.fetchPresentation({
          placementId: 'ONBOARDING',
          contentId: null,
        })
      );
    } catch (e) {
      console.error(e);
    }
  };

  const callback = (result: PresentPresentationResult) => {
    console.log('### Paywall closed');
    console.log('### Result is ' + result.result);
    switch (result.result) {
      case ProductResult.PRODUCT_RESULT_PURCHASED:
      case ProductResult.PRODUCT_RESULT_RESTORED:
        if (result.plan != null) {
          console.log('User purchased ' + result.plan.name);
        }
        break;
      case ProductResult.PRODUCT_RESULT_CANCELLED:
        console.log('User cancelled');
        break;
    }
    navigation.goBack();
  };

  if (purchaselyPresentation == null) {
    return (
      <View>
        <Text>Loading ...</Text>
      </View>
    );
  }

  return (
    <View style={{ flex: 1 }}>
      <Header />
      <PLYPresentationView
        placementId="ACCOUNT"
        flex={7}
        presentation={purchaselyPresentation}
        onPresentationClosed={(res: PresentPresentationResult) => callback(res)}
      />
      <View style={{ flex: 3, justifyContent: 'center', alignItems: 'center' }}>
        <Section>
          <Text>Your own React Native content</Text>
        </Section>
      </View>
    </View>
  );
};
```

## 🆕 Migration to v6.x

`react-native-purchasely@6` introduces a cross-platform builder API that
mirrors the native Android/iOS v6 SDKs. The legacy v5 API stays available
during the transition — the v6 façade ships side-by-side and is the
recommended way to integrate going forward.

The v6 contract is documented in
`reports/v6-presentation-comparison-v3-claude/BRIDGE-CONTRACT.md` (internal).

### Initialization

```ts
// v5 (deprecated, still works)
await Purchasely.start({
  apiKey: 'YOUR_API_KEY',
  androidStores: ['Google'],
  storeKit1: false,
  userId: 'user_id',
  logLevel: LogLevels.DEBUG,
  runningMode: RunningMode.FULL,
})

// v6
import { PurchaselyBuilder } from 'react-native-purchasely'

await PurchaselyBuilder.apiKey('YOUR_API_KEY')
  .appUserId('user_id')
  .runningMode('full')          // 'observer' | 'full'
  .logLevel('debug')            // 'debug' | 'info' | 'warn' | 'error'
  .allowDeeplink(true)
  .allowCampaigns(true)
  .storekitVersion('storeKit2') // iOS only
  .stores(['google'])           // Android only
  .start()
```

### Paywall display

```ts
// v5
const result = await Purchasely.presentPresentationForPlacement({
  placementVendorId: 'ONBOARDING',
  isFullscreen: true,
})

// v6
import { PresentationBuilder } from 'react-native-purchasely'

const request = PresentationBuilder.placement('ONBOARDING')
  .contentId('content_123')
  .onLoaded((presentation) => { /* preload complete */ })
  .onPresented((presentation, error) => { /* presentation visible (or error) */ })
  .onCloseRequested(() => { /* user asked to close */ })
  .onDismissed((outcome) => { /* see outcome contract below */ })
  .build()

// Resolves at DISMISS with the 5-field outcome (not at trigger).
const outcome = await request.display({ type: 'fullScreen' })

// Or use `.screen('SCREEN_ID')` to target a presentation directly.
// Or `.default()` to use the SDK default placement.
```

### Action interceptor

```ts
// v5: single global handler dispatched by switch on `action`
Purchasely.setPaywallActionInterceptorCallback((result) => {
  switch (result.action) {
    case PLYPaywallAction.PURCHASE:
      Purchasely.onProcessAction(true)
      break
    /* ... */
  }
})

// v6: one typed interceptor per action kind, returning an InterceptResult
import { interceptAction } from 'react-native-purchasely'

interceptAction('purchase', async ({ presentation }, payload) => {
  if (payload?.kind === 'purchase') {
    console.log('user wants to buy', payload.plan.vendorId)
  }
  // 'success' | 'failed' | 'notHandled'
  // 'notHandled' lets the SDK run its default flow for the action.
  return 'notHandled'
})

interceptAction('navigate', async (_info, payload) => {
  if (payload?.kind === 'navigate') {
    Linking.openURL(payload.url)
    return 'success'
  }
  return 'notHandled'
})
```

### Outcome (5 fields)

The v6 `PresentationOutcome` exposes the full close context:

```ts
interface PresentationOutcome {
  presentation?: Presentation | null
  purchaseResult?: 'purchased' | 'cancelled' | 'restored' | null
  plan?: PurchaselyPlan | null
  closeReason?: 'button' | 'backSystem' | 'programmatic' | null
  error?: PresentationError | null
}
```

Exclusion rule: `error != null` ⇒ `closeReason == null`.

> **iOS notes (temporary).** Until the iOS native v6 lands, the bridge
> synthesizes the 5-field outcome from the legacy callbacks. `closeReason`
> stays `null` and `screenId` is mapped from `presentation.id`.

## 📖 Documentation

A complete documentation is available on our website: [Purchasely Docs](https://docs.purchasely.com/quick-start/sdk-installation/react-native-sdk).

