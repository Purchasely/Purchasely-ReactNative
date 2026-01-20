# Purchasely Test Projects

This directory contains two test projects demonstrating the Purchasely React Native SDK integration.

## Projects

### 1. expo-purchasely-test

A test project using **Expo** (managed workflow with development build).

- **Location:** `./expo-purchasely-test/`
- **Prerequisites:** Node.js 18+, Expo CLI
- **Documentation:** See [expo-purchasely-test/README.md](./expo-purchasely-test/README.md)

### 2. rn-purchasely-test

A test project using **React Native CLI** (bare workflow).

- **Location:** `./rn-purchasely-test/`
- **Prerequisites:** Node.js 18+, Xcode 15+ (iOS), Android Studio (Android)
- **Documentation:** See [rn-purchasely-test/README.md](./rn-purchasely-test/README.md)

## Quick Start

### For Expo Project

```bash
cd expo-purchasely-test

# Install dependencies
npm install

# iOS (requires macOS with Xcode)
npx expo run:ios

# Android
npx expo run:android
```

### For React Native CLI Project

```bash
cd rn-purchasely-test

# Install dependencies
npm install

# iOS (requires macOS with Xcode)
cd ios && pod install && cd ..
npm run ios

# Android
npm run android
```

## SDK Features Demonstrated

Both projects demonstrate the following Purchasely SDK features:

1. **SDK Initialization** - `Purchasely.start()` with configuration options
2. **Fetch Presentation** - `Purchasely.fetchPresentation()` to pre-load paywalls
3. **Present Presentation** - `Purchasely.presentPresentation()` to display paywalls
4. **Direct Presentation** - `Purchasely.presentPresentationForPlacement()` as an alternative

## Configuration

Both projects use the same demo API key for testing:

```typescript
apiKey: 'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d'
```

Replace this with your own API key from the Purchasely console.

## Documentation

- [Purchasely Documentation](https://docs.purchasely.com/docs/installation-react-native)
- [Expo Documentation](https://docs.expo.dev/)
- [React Native Documentation](https://reactnative.dev/)
