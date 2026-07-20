# React Native Purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store, and Huawei App Gallery.

## 🚀 Installation

```sh
npm install react-native-purchasely
```

## 🔧 Setup

> **v6** — the SDK is initialized and paywalls are displayed with the chainable
> builder API. The legacy v5 paywall API (`start({...})`, `startWithAPIKey`,
> `presentPresentationForPlacement`, `fetchPresentation`,
> `setPaywallActionInterceptorCallback`, …) has been **removed**. See
> [`MIGRATION-v6.md`](./MIGRATION-v6.md) for the full old→new mapping.

Add the following code in the root of your project (typically `App.tsx` in a React Native project):

```ts
import Purchasely from 'react-native-purchasely'

const configured = await Purchasely.builder('afa96c76-1d8e-4e3c-a48f-204a3cd93a15')
    .stores(['google']) // Android stores: 'google' | 'huawei' | 'amazon'
    .appUserId(null) // your user ID, or null for anonymous
    .logLevel('debug') // 'warn' or 'error' in production
    .runningMode('full') // 'observer' (default) | 'full'
    .allowDeeplink(true)
    .storekitVersion('storeKit2') // iOS only
    .start()

if (!configured) {
    console.log('Purchasely SDK not properly initialized')
} else {
    console.log('Purchasely SDK is initialized')
    setupPurchasely()
}
```

## 🎬 Usage

### 1️⃣ Full Screen Paywall

```ts
import Purchasely from 'react-native-purchasely'

try {
    // display() resolves at dismiss with a PresentationOutcome
    const outcome = await Purchasely.presentation
        .placement('composer')
        .backgroundColor('#FFFFFFFF')
        .build()
        .display()

    if (outcome.error) {
        console.error(outcome.error.message)
    } else if (
        outcome.purchaseResult === 'purchased' ||
        outcome.purchaseResult === 'restored'
    ) {
        console.log('User purchased ' + outcome.plan?.name)
    } else {
        console.log('Dismissed: ' + outcome.closeReason)
    }
} catch (e) {
    console.error(e)
}
```

### 2️⃣ Nested View Paywall

The embedded `PLYPresentationView` component is part of the **core** API and is
unchanged in v6. Pass a `placementId` directly — no manual pre-fetch step is
required.

```ts
import { Text, View } from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { Header } from 'react-native/Libraries/NewAppScreen';
import { Section } from './Section.tsx';
import { PLYPresentationView } from 'react-native-purchasely';

export const PaywallScreen: React.FC<NativeStackScreenProps<any>> = ({ navigation }) => {
  const callback = (result: any) => {
    console.log('### Paywall closed, result is ' + result.result);
    navigation.goBack();
  };

  return (
    <View style={{ flex: 1 }}>
      <Header />
      <PLYPresentationView
        placementId="ACCOUNT"
        flex={7}
        onPresentationClosed={(res) => callback(res)}
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

### 3️⃣ Custom Screens inside a flow

Register one React component with `AppRegistry`, then register its name after
the SDK starts. Purchasely mounts that component when a flow reaches a screen
configured as client-authored in the Console.

```tsx
// index.js
AppRegistry.registerComponent(
  'PurchaselyCustomScreen',
  () => PurchaselyCustomScreen,
)

// after await Purchasely.builder(...).start()
Purchasely.setCustomScreenProvider({
  componentName: 'PurchaselyCustomScreen',
})

function PurchaselyCustomScreen(props: PLYCustomScreenProps) {
  const { presentation, executeConnection, back, close } =
    usePurchaselyCustomScreen(props)

  return (
    <View>
      <Text>{presentation.screenId}</Text>
      {presentation.connections?.map((connection, index) => (
        <Button
          key={connection.id ?? index}
          title={connection.id ?? 'Continue'}
          onPress={() => executeConnection(connection.id ?? undefined)}
        />
      ))}
      <Button title="Back" onPress={back} />
      <Button title="Close flow" onPress={close} />
    </View>
  )
}
```

The presentation in the props identifies the exact native flow-step instance;
always use it for connection, back, and close actions. Custom Screen hosting is
for flow steps. It is not supported inside `PLYPresentationView` or as a
standalone native-hosted client screen.

Custom Screen hosting requires React Native 0.74 or newer; the rest of the SDK
keeps its existing React Native compatibility range.

## 📖 Documentation

A complete documentation is available on our website: [Purchasely Docs](https://docs.purchasely.com/quick-start/sdk-installation/react-native-sdk).

Migrating from v5? See [`MIGRATION-v6.md`](./MIGRATION-v6.md) for the complete
old→new mapping of every removed v5 paywall method.

## 🛠️ Developer Guide

### 1️⃣ Clone the Repository

```sh
git clone https://github.com/Purchasely/Purchasely-ReactNative.git
cd repo
```

### 2️⃣ Install Dependencies

```sh
yarn install
```

### 3️⃣ Prepare all the packages

```sh
yarn all:prepare
```

### 4️⃣ Run the Example App

```sh
yarn example:android

# after example:android is done building run:
yarn example:start
```


### Troubleshooting

If you encounter issues with the example app, ensure that you have the latest version of Android Studio and that your Android SDK is up to date. You may also need to run `yarn android:clean` to clear any cached builds.

If it's about Hermes engine and node, check if you have a file `.xcode.env.local` in example/ios
If you do, remove it:
```sh
rm -rf example/ios/.xcode.env.local
```

You can also check the node link in /user/local/bin to ensure it points to the correct version of your node installation:
```sh
ls -l /usr/local/bin/node
```
If not, do the following:
```sh
rm -rf /usr/local/bin/node
ln -s $(which node) /usr/local/bin/node
```
