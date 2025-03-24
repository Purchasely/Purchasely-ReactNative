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

## 📖 Documentation

A complete documentation is available on our website: [Purchasely Docs](https://docs.purchasely.com/quick-start/sdk-installation/react-native-sdk).

