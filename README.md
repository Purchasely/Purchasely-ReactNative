# Cordova plugin Purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store and Huawei App Gallery.

## Installation

```sh
cordova plugin add @purchasely/cordova-plugin-purchasely
```

## Usage

```js
Purchasely.startWithAPIKey('API_KEY', ['Google'], null, Purchasely.LogLevel.DEBUG, false);

Purchasely.presentPresentationWithIdentifier(
    'my_presentation_id',
    (callback) => {
        console.log(callback);
        if(callback.result == Purchasely.PurchaseResult.CANCELLED) {
            console.log("User cancelled purchased");
        } else {
            console.log("User purchased " + callback.plan.name);
        }
    },
    (error) => {
        console.log("Error with purchase : " + error);
    }
);
```

## 🏁 Documentation

A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com/quick-start/sdk-installation/cordova)
