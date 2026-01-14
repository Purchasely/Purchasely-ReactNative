# Purchasely Expo Test Project

This is a test project demonstrating the Purchasely React Native SDK integration with Expo.

## Prerequisites

- Node.js 18+
- npm or yarn
- For iOS: macOS with Xcode 15+
- For Android: Android Studio with SDK 24+

## Installation

```bash
# Install dependencies
npm install

# For iOS (on macOS only)
cd ios && pod install && cd ..
```

## Running the App

### Development Build (Required for native modules)

Since Purchasely uses native code, you need to create a development build:

```bash
# iOS (on macOS)
npx expo run:ios

# Android
npx expo run:android
```

### Alternative: EAS Build

You can also use EAS Build for cloud builds:

```bash
# Install EAS CLI
npm install -g eas-cli

# Configure EAS
eas build:configure

# Build for iOS
eas build --platform ios --profile development

# Build for Android
eas build --platform android --profile development
```

## SDK Integration

The app demonstrates:

1. **SDK Initialization** - Using `Purchasely.start()` with API key and configuration
2. **Fetch Presentation** - Using `Purchasely.fetchPresentation()` to pre-load paywalls
3. **Present Presentation** - Using `Purchasely.presentPresentation()` to display paywalls

## Configuration

The Purchasely SDK is configured in `App.tsx`:

```typescript
const configured = await Purchasely.start({
  apiKey: 'YOUR_API_KEY',
  storeKit1: false, // Use StoreKit 2 on iOS
  logLevel: LogLevels.DEBUG,
  runningMode: RunningMode.FULL,
  androidStores: ['Google'],
});
```

## Troubleshooting

### iOS Build Issues

1. Make sure you have Xcode 15+ installed
2. Run `cd ios && pod install` to install CocoaPods dependencies
3. Clean the build: `cd ios && xcodebuild clean`

### Android Build Issues

1. Make sure Android SDK 24+ is installed
2. Clean the build: `cd android && ./gradlew clean`

## Documentation

For more information, visit:
- [Purchasely Documentation](https://docs.purchasely.com/docs/installation-react-native)
- [Expo Documentation](https://docs.expo.dev/)
