# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This directory contains two test projects demonstrating the Purchasely React Native SDK integration. The test projects are separate from the main SDK repository and serve as integration testing and demonstration environments.

**Key Context**: These test projects import `react-native-purchasely` as a dependency. The actual SDK source code lives in the parent directory (`../packages/`). These test projects demonstrate different integration approaches (Expo vs React Native CLI) for the same SDK.

## Project Architecture

### 1. expo-purchasely-test/
Expo-managed workflow test project using development builds (required for native modules).

**Technology Stack**:
- Expo ~54.0 with React Native 0.81.5
- Requires development builds (cannot use Expo Go due to native modules)
- iOS minimum: 15.1, Android minimum: SDK 24

**Key Configuration**:
- `app.json`: Expo config with build properties plugin for iOS/Android deployment targets
- Uses StoreKit 2 on iOS (`storeKit1: false`)

### 2. rn-purchasely-test/
React Native CLI bare workflow test project.

**Technology Stack**:
- React Native 0.79.2
- iOS requires CocoaPods, Xcode 15+
- Android requires SDK 24+, JDK 17+

**Key Configuration**:
- Standard RN CLI structure with `android/` and `ios/` native directories
- Uses StoreKit 2 on iOS (`storeKit1: false`)

## Common Development Commands

### Expo Project (expo-purchasely-test/)
```bash
cd expo-purchasely-test
npm install

# iOS (requires macOS with Xcode 15+)
npx expo run:ios

# Android
npx expo run:android

# Development server
npm start
```

### React Native CLI Project (rn-purchasely-test/)
```bash
cd rn-purchasely-test
npm install

# iOS setup (macOS only)
cd ios && pod install && cd ..

# iOS development
npm run ios
# Or: open ios/RNPurchaselyTest.xcworkspace

# Android development
npm run android

# Development server
npm start

# Linting
npm run lint

# Testing
npm test
```

## Purchasely SDK Integration Pattern

Both test projects follow the same SDK integration pattern in `App.tsx`:

### 1. SDK Initialization (on mount)
```typescript
const configured = await Purchasely.start({
  apiKey: 'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d', // Demo API key
  storeKit1: false, // Use StoreKit 2 on iOS
  logLevel: LogLevels.DEBUG,
  runningMode: RunningMode.FULL,
  androidStores: ['Google'],
});
```

**Important**: SDK must be initialized before any other Purchasely calls. Both projects use the demo API key for testing.

### 2. Post-Initialization Setup
After successful initialization:
- `Purchasely.setLanguage('en')` - Set display language
- `Purchasely.readyToOpenDeeplink(true)` - Enable deeplink handling

### 3. Presentation Flow (Paywalls)

**Option A: Fetch then Present (two-step)**
```typescript
// Step 1: Pre-fetch presentation data
const presentation = await Purchasely.fetchPresentation({
  placementId: 'ONBOARDING',
  contentId: null,
});

// Step 2: Present the fetched presentation
const result = await Purchasely.presentPresentation({
  presentation: presentation,
  isFullscreen: true,
});
```

**Option B: Direct Presentation (one-step)**
```typescript
const result = await Purchasely.presentPresentationForPlacement({
  placementVendorId: 'ONBOARDING',
  isFullscreen: true,
});
```

### 4. Result Handling
Both approaches return a `ProductResult`:
- `PRODUCT_RESULT_PURCHASED` - User completed a purchase
- `PRODUCT_RESULT_RESTORED` - User restored previous purchases
- `PRODUCT_RESULT_CANCELLED` - User dismissed without action

The result object includes `result.plan` with purchase details when applicable.

### 5. Presentation Type Checking
Before presenting, check `presentation.type`:
- `PLYPresentationType.DEACTIVATED` - Presentation disabled in console
- `PLYPresentationType.CLIENT` - Client-side presentation (requires custom handling)
- `PLYPresentationType.NORMAL` - Standard server-rendered presentation

## Common Issues and Solutions

### iOS Build Issues
1. **CocoaPods not installed**: Run `cd ios && pod install`
2. **Stale pods**: `cd ios && pod deintegrate && pod install`
3. **Build cache issues**: `cd ios && xcodebuild clean`
4. **Wrong Xcode version**: Requires Xcode 15+
5. **Opening wrong project**: Always open `.xcworkspace`, not `.xcodeproj`

### Android Build Issues
1. **Missing SDK**: Ensure Android SDK 24+ is installed via Android Studio
2. **Wrong JDK**: Requires JDK 17+ (check with `java -version`)
3. **Gradle cache**: `cd android && ./gradlew clean`
4. **Dependency sync**: `cd android && ./gradlew --refresh-dependencies`

### Metro Bundler Issues
1. **Cache problems**: `npx react-native start --reset-cache`
2. **Watchman issues**: `watchman watch-del-all`

### Expo-Specific Issues
1. **Cannot use Expo Go**: Purchasely requires native modules, must use development build
2. **Missing development build**: Run `npx expo run:ios` or `npx expo run:android`

## SDK Dependencies

Both projects require these Purchasely packages:
- `react-native-purchasely` - Core SDK
- `@purchasely/react-native-purchasely-google` - Google Play integration
- `@purchasely/react-native-purchasely-android-player` - Android video player

Version alignment is critical - all Purchasely packages should use the same version (currently 5.6.1).

## Testing Configuration

**Demo API Key**: `fcb39be4-2ba4-4db7-bde3-2a5a1e20745d`
**Test Placement ID**: `ONBOARDING`

When testing with your own Purchasely account:
1. Replace the API key in `App.tsx`
2. Replace placement IDs with your configured placements from the Purchasely console
3. Ensure placements are properly configured with products in the Purchasely dashboard

## Documentation Links
- [Purchasely React Native Docs](https://docs.purchasely.com/docs/installation-react-native)
- [Expo Documentation](https://docs.expo.dev/)
- [React Native Documentation](https://reactnative.dev/)
