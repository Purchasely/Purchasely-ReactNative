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

await Purchasely.start({
          apiKey: 'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d',
          storeKit1: false, // false to use StoreKit 2 and true to use StoreKit 1
}).then(
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

// ----
// You can also start the SDK with all possible parameters
await Purchasely.start({
  apiKey: 'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d',
  storeKit1: false, // false to use StoreKit 2 and true to use StoreKit 1
  logLevel: LogLevels.DEBUG, // to force log level for debug
  userId: 'test-user', // if you know your user id
  runningMode: RunningMode.FULL, // to set mode manually
  androidStores: ['Google', 'Huawei'], // Google is already set by default, you can add Huawei and Amazon
});
// ----

try {
    const presentation = await Purchasely.fetchPresentation({
      placementId: 'app_launch_demo'
    });

    if (presentation.type === PLYPresentationType.DEACTIVATED) {
      // No paywall to display
      return;
    }

    if (presentation.type === PLYPresentationType.CLIENT) {
      // Display my own paywall
      return;
    }

    //Display Purchasely paywall
    const result = await Purchasely.presentPresentation({
      presentation: presentation,
    });

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

```

## 🏁 Documentation

A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com/quick-start-1/sdk-installation/react-native-sdk)

## Usage with Sample project

Since react-native-purchasely is resolved from the file system instead of NPM
"react-native-purchasely": "file:../purchasely",

A link is necessary between the sample project and the react-native-purchasely project.
Do this to make it happen

```sh
cd purchasely
yarn link

cd sample
yarn link "react-native-purchasely"
```
