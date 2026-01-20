# Purchasely React Native CLI Test Project

This is a test project demonstrating the Purchasely React Native SDK integration with React Native CLI (bare workflow).

## Prerequisites

- Node.js 18+
- npm or yarn
- For iOS: macOS with Xcode 15+, CocoaPods
- For Android: Android Studio with SDK 24+, JDK 17+

## Installation

```bash
# Install dependencies
npm install

# For iOS (on macOS only)
cd ios && pod install && cd ..
```

## Running the App

### iOS (macOS only)

```bash
# Start Metro bundler
npm start

# In another terminal, run iOS
npm run ios

# Or open in Xcode
open ios/RNPurchaselyTest.xcworkspace
```

### Android

```bash
# Start Metro bundler
npm start

# In another terminal, run Android
npm run android

# Or open in Android Studio
# Open the android folder in Android Studio
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

## Project Structure

```
rn-purchasely-test/
├── App.tsx              # Main application with Purchasely integration
├── index.js             # Entry point
├── package.json         # Dependencies
├── android/             # Android native project
│   ├── app/
│   │   ├── build.gradle
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       └── java/com/rnpurchaselytest/
│   ├── build.gradle
│   └── settings.gradle
└── ios/                 # iOS native project
    ├── Podfile
    ├── RNPurchaselyTest/
    │   ├── AppDelegate.swift
    │   └── Info.plist
    └── RNPurchaselyTest.xcodeproj/
```

## Troubleshooting

### iOS Build Issues

1. Make sure you have Xcode 15+ installed
2. Run `cd ios && pod install` to install CocoaPods dependencies
3. If pods fail, try: `cd ios && pod deintegrate && pod install`
4. Clean the build: `cd ios && xcodebuild clean`

### Android Build Issues

1. Make sure Android SDK 24+ is installed
2. Make sure JDK 17+ is installed
3. Clean the build: `cd android && ./gradlew clean`
4. If Gradle sync fails, try: `cd android && ./gradlew --refresh-dependencies`

### Metro Bundler Issues

1. Clear Metro cache: `npx react-native start --reset-cache`
2. Clear watchman: `watchman watch-del-all`

## Documentation

For more information, visit:
- [Purchasely Documentation](https://docs.purchasely.com/docs/installation-react-native)
- [React Native Documentation](https://reactnative.dev/docs/getting-started)
