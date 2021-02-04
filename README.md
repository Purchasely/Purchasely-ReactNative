# react-native-purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store and Huawei App Gallery.

## Installation

```sh
npm install react-native-purchasely
```

## Usage

```js
import Purchasely from "react-native-purchasely";

// ...

Purchasely.startWithAPIKey(
  'afa96c76-1d8e-4e3c-a48f-204a3cd93a15',
  ['Google'],
  null,
  LogLevels.WARNING
);

Purchasely.presentProductWithIdentifier(
  'PURCHASELY_PLUS',
  null,
  (msg) => {
    console.error(msg);
  },
  (someData) => {
    console.log(someData);
  }
);
```

## 🏁 Documentation

A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com/quick-start/sdk-installation/react-native-sdk)
