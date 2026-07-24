# Purchasely React Native CLI Test Project

This is a test project demonstrating the Purchasely React Native SDK integration with React Native CLI (bare workflow).

## Prerequisites

-   Node.js 22.11+
-   npm or yarn
-   For iOS: macOS with Xcode 15+, CocoaPods
-   For Android: Android Studio with SDK 24+, JDK 17+

## Installation

```bash
# Build and consume the local v6 packages
cd ../..
yarn all:prepare
cd test-projects/rn-purchasely-test
npm ci

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
3. **Fullscreen Presentation** - Using `PLYLoadedPresentation.display()` to display a modal paywall
4. **Embedded Presentation** - Using `PLYPresentationView` to display a paywall within the screen

The sample consumes the local v6 packages from `../../packages/` and has the React Native New Architecture enabled (`newArchEnabled=true` on Android and `RCT_NEW_ARCH_ENABLED=1` in the iOS Podfile). It deliberately continues to use the SDK's legacy bridge and view manager through the New Architecture interop layer; no TurboModule migration is part of this sample.

## Manual runtime validation

The Android and iOS CI jobs prove that the app and native ViewManager compile and link. They cannot verify a configured remote paywall, purchase dialog, or keyboard interaction, so validate these cases manually on each platform after configuring the demo placement:

1. Tap **Validate Fullscreen Modal** and **Present Directly (Fullscreen)**. Confirm each paywall opens as a modal and closing it returns to the sample without a blank or frozen screen.
2. Tap **Validate Embedded Paywall**. Confirm `PLYPresentationView` renders only inside its card, can be closed, and updates the status message.
3. Focus any text input rendered by the paywall. Confirm the keyboard does not cover the active field and dismissal restores the original layout.
4. Check the fullscreen and embedded paths on a device with a cutout and gesture navigation. Content must stay within the safe area; on Android API 35+ also verify the status and navigation bar insets under edge-to-edge enforcement.
5. Rotate the device while each presentation is visible. Confirm the paywall stays sized to its container, preserves a usable layout, and does not crash.

## Configuration

The Purchasely SDK is configured in `App.tsx`:

```typescript
const configured = await Purchasely.builder('YOUR_API_KEY')
    .runningMode('full')
    .logLevel('debug')
    .allowDeeplink(true)
    .stores(['google'])
    .storekitVersion('storeKit2')
    .start()
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

-   [Purchasely Documentation](https://docs.purchasely.com/docs/installation-react-native)
-   [React Native Documentation](https://reactnative.dev/docs/getting-started)
