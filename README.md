# react-native-purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store and Huawei App Gallery.

## Installation

```sh
npm install react-native-purchasely

# Mandatory if you want to use Google Play Store also
npm install @purchasely/react-native-purchasely-google
```

## Usage

```js
import Purchasely, {
  LogLevels,
  Attributes,
  ProductResult,
  RunningMode,
  PLYPaywallAction,
} from 'react-native-purchasely';

Purchasely.startWithAPIKey(
  'afa96c76-1d8e-4e3c-a48f-204a3cd93a15',
  ['Google'], // list of stores for Android, accepted values: Google, Huawei and Amazon
  null, // your user id
  LogLevels.DEBUG, // log level, should be warning or error in production
  RunningMode.FULL // running mode
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

try {
  const result = await Purchasely.presentPresentationForPlacement({
    placementVendorId: 'onboarding',
    contentId: 'my_content_id',
    isFullscreen: true,
  });

  switch (result.result) {
    case ProductResult.PRODUCT_RESULT_PURCHASED:
    case ProductResult.PRODUCT_RESULT_RESTORED:
      if (result.plan != null) {
        console.log('User purchased ' + result.plan.name);
      }
      break;
    case ProductResult.PRODUCT_RESULT_CANCELLED:
      break;
  }
} catch (e) {
  console.error(e);
}

```

## 🏁 Documentation

A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com/quick-start/sdk-installation/react-native-sdk)
