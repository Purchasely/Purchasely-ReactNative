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
  Purchasely.logLevelDebug
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

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT
