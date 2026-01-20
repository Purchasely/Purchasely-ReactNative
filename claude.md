# Claude AI Context for Purchasely React Native SDK

## Project Overview

**Purchasely React Native SDK** is a comprehensive In-App Purchase and Subscription management solution for React Native applications. It provides a bridge between React Native and native Purchasely SDKs for iOS and Android, supporting multiple app stores.

| Property | Value |
|----------|-------|
| Current Version | 5.6.1 |
| React Native | 0.79.2 |
| TypeScript | 5.2.2 (strict mode) |
| Node.js | v20 (see `.nvmrc`) |
| Package Manager | Yarn 3.6.1 (workspaces) |
| Native iOS SDK | 5.6.2 |
| Native Android SDK | 5.6.0 |

### Supported App Stores
- Apple App Store (iOS)
- Google Play Store (Android)
- Huawei App Gallery (Android)
- Amazon Appstore (Android)

---

## Architecture

### Monorepo Structure

```
ReactNative_SDK/
├── packages/
│   ├── purchasely/              # Core React Native bridge (main package)
│   ├── google/                  # Google Play Billing integration
│   ├── amazon/                  # Amazon Appstore integration
│   ├── huawei/                  # Huawei Mobile Services integration
│   └── android-player/          # Android media player utility
├── example/                     # Reference application
├── test-projects/               # Test applications (Expo & RN)
└── .github/                     # CI/CD workflows
```

### NPM Packages

| Package | Description |
|---------|-------------|
| `react-native-purchasely` | Core SDK with universal components |
| `@purchasely/react-native-purchasely-google` | Google Play specific bindings |
| `@purchasely/react-native-purchasely-amazon` | Amazon Appstore specific bindings |
| `@purchasely/react-native-purchasely-huawei` | Huawei HMS specific bindings |
| `@purchasely/react-native-purchasely-android-player` | Android player utility |

---

## Key Files Reference

### Core Source Files

| File | Purpose | Lines |
|------|---------|-------|
| `packages/purchasely/src/index.ts` | Main module with all public APIs | ~560 |
| `packages/purchasely/src/types.ts` | TypeScript type definitions | ~250 |
| `packages/purchasely/src/enums.ts` | All enumerations | ~127 |
| `packages/purchasely/src/interfaces.ts` | Parameter interfaces | ~140 |
| `packages/purchasely/src/components/PLYPresentationView.tsx` | Embeddable paywall component | - |

### Native iOS Bridge

| File | Purpose |
|------|---------|
| `packages/purchasely/ios/PurchaselyRN.h` | Native module header |
| `packages/purchasely/ios/PurchaselyRN.m` | Main iOS bridge implementation (~1500 lines) |
| `packages/purchasely/ios/PurchaselyView.swift` | Embedded presentation view |
| `packages/purchasely/ios/PurchaselyViewManager.swift` | View lifecycle manager |

### Native Android Bridge

| File | Purpose |
|------|---------|
| `packages/purchasely/android/.../PurchaselyModule.kt` | Main Android bridge module |
| `packages/purchasely/android/.../PurchaselyPackage.kt` | React Native package registration |
| `packages/purchasely/android/.../PurchaselyViewManager.kt` | View manager |
| `packages/purchasely/android/.../PLYProductActivity.kt` | Product presentation activity |
| `packages/purchasely/android/.../PLYSubscriptionsActivity.kt` | Subscriptions activity |

### Configuration Files

| File | Purpose |
|------|---------|
| `package.json` | Root workspace configuration |
| `tsconfig.json` | TypeScript configuration (strict mode) |
| `tsconfig.build.json` | Build-specific TypeScript config |
| `.eslintrc.js` | ESLint configuration |
| `.prettierrc` | Prettier formatting rules |
| `turbo.json` | Turbo build orchestration |
| `.yarnrc.yml` | Yarn 3 workspace settings |

---

## Development Commands

### Setup & Installation

```bash
# Install dependencies
yarn install

# Build all packages
yarn all:prepare

# Clean all builds
yarn all:clean
```

### Running the Example App

```bash
# Start Metro bundler
yarn example:start

# Run on iOS simulator
yarn example:ios

# Run on Android emulator
yarn example:android
```

### Code Quality

```bash
# Run ESLint
yarn lint

# TypeScript type checking
yarn typecheck

# Run tests
yarn test

# Run tests with coverage
yarn test --coverage
```

### Package-Specific Commands

```bash
# Build individual packages
yarn purchasely:prepare
yarn google:prepare
yarn amazon:prepare
yarn huawei:prepare
yarn player:prepare

# Clean individual packages
yarn purchasely:clean
yarn google:clean
yarn amazon:clean
yarn huawei:clean
yarn player:clean
```

---

## Code Conventions

### TypeScript Standards

- **Strict mode enabled** - No implicit any, no unused variables
- **Target:** ESNext
- **Module:** ESNext with Bundler resolution
- **JSX:** react-jsx (automatic runtime)

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Components | PascalCase | `PLYPresentationView` |
| Enums | PascalCase with PLY prefix | `PLYPresentationAction` |
| Private properties | Underscore prefix | `_view`, `_controller` |
| Event constants | SCREAMING_SNAKE_CASE | `PURCHASELY_EVENTS` |
| Functions | camelCase | `fetchPresentation` |

### Formatting (Prettier)

- **Indentation:** 4 spaces
- **Semicolons:** No
- **Quotes:** Single quotes
- **Trailing commas:** ES5 style

### Commit Messages (Conventional Commits)

```
fix: description     # Bug fixes
feat: description    # New features
refactor: description # Code refactoring
docs: description    # Documentation
test: description    # Test updates
chore: description   # Tooling/config changes
```

---

## Public API Overview

### Initialization

```typescript
import Purchasely, { LogLevels, RunningMode } from 'react-native-purchasely'

await Purchasely.start({
  apiKey: 'YOUR_API_KEY',
  androidStores: ['Google'], // or ['Huawei', 'Amazon']
  storeKit1: false,          // iOS: use StoreKit 2
  userId: 'user_id',         // optional
  logLevel: LogLevels.DEBUG,
  runningMode: RunningMode.FULL
})
```

### Presentation Methods

```typescript
// Fetch presentation data
const presentation = await Purchasely.fetchPresentation({
  placementVendorId: 'ONBOARDING',
  contentId: 'content_123'
})

// Present full-screen paywall
const result = await Purchasely.presentPresentationForPlacement({
  placementVendorId: 'ONBOARDING',
  isFullscreen: true
})

// Present specific product or plan
await Purchasely.presentProductWithIdentifier('product_id')
await Purchasely.presentPlanWithIdentifier('plan_id')
```

### Event Listening

```typescript
// General events
const listener = Purchasely.addEventListener((event) => {
  console.log(event.name, event.properties)
})

// Purchase events
const purchaseListener = Purchasely.addPurchasedListener((event) => {
  console.log('Purchase:', event.plan)
})

// Clean up
listener.remove()
purchaseListener.remove()
```

### User Management

```typescript
// Login/logout
await Purchasely.userLogin('user_id')
await Purchasely.userLogout()

// User attributes (with GDPR legal basis)
await Purchasely.setUserAttributeWithString('name', 'John', PLYLegalBasis.CONTRACT)
await Purchasely.setUserAttributeWithNumber('age', 25)
await Purchasely.setUserAttributeWithBoolean('premium', true)
await Purchasely.setUserAttributeWithDate('birthdate', new Date())

// Retrieve attributes
const attrs = await Purchasely.userAttributes()
const name = await Purchasely.userAttribute('name')
```

### Product & Subscription Data

```typescript
// Get all products
const products = await Purchasely.allProducts()

// Get specific product/plan
const product = await Purchasely.productWithIdentifier('product_id')
const plan = await Purchasely.planWithIdentifier('plan_id')

// User subscriptions
const subscriptions = await Purchasely.userSubscriptions()
const history = await Purchasely.userSubscriptionsHistory()
```

### Embedded Paywall Component

```tsx
import { PLYPresentationView } from 'react-native-purchasely'

<PLYPresentationView
  placementId="ONBOARDING"
  flex={1}
  onPresentationClosed={(result) => {
    console.log('Closed with result:', result)
  }}
/>
```

---

## Key Enums

```typescript
// Product result states
enum ProductResult {
  PURCHASED,
  CANCELLED,
  RESTORED
}

// Log levels
enum LogLevels {
  DEBUG,
  INFO,
  WARNING,
  ERROR
}

// Running modes
enum RunningMode {
  TRANSACTION_ONLY,  // Handle transactions only
  OBSERVER,          // Observe transactions
  PAYWALL_OBSERVER,  // Observe paywalls
  FULL               // Full functionality
}

// Theme modes
enum PLYThemeMode {
  LIGHT,
  DARK,
  SYSTEM
}
```

---

## Build System

### React Native Builder Bob

Each package uses Builder Bob to generate:
- `lib/commonjs/` - CommonJS build
- `lib/module/` - ESM build
- `lib/typescript/` - TypeScript declarations

### Turbo Pipeline

Build orchestration with caching:
- `build` - Main build task
- `build:android` - Android native build
- `build:ios` - iOS native build

### Native Dependencies

**iOS (CocoaPods):**
- Purchasely SDK v5.6.2
- Deployment target: iOS 13.4

**Android (Gradle):**
- io.purchasely:core:5.6.0
- Min SDK: 21
- Kotlin: 1.9+
- Java: 11

---

## Testing

### Jest Configuration

```json
{
  "preset": "react-native",
  "modulePathIgnorePatterns": [
    "<rootDir>/example/node_modules",
    "<rootDir>/lib/"
  ]
}
```

### Running Tests

```bash
yarn test                    # All tests
yarn test --coverage         # With coverage
yarn test --watch           # Watch mode
```

---

## CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/ci.yml`):

1. **Lint Job** - TypeScript + ESLint checks
2. **Test Job** - Jest with coverage reporting
3. **Android Build** - Ubuntu runner
4. **iOS Build** - macOS runner

All jobs use Turbo caching for faster incremental builds.

---

## Common Tasks

### Adding a New Public API Method

1. Add TypeScript interface in `packages/purchasely/src/interfaces.ts`
2. Add return type in `packages/purchasely/src/types.ts`
3. Implement in `packages/purchasely/src/index.ts`
4. Implement iOS native method in `packages/purchasely/ios/PurchaselyRN.m`
5. Implement Android native method in `packages/purchasely/android/.../PurchaselyModule.kt`
6. Export from index if needed

### Adding a New Enum

1. Add to `packages/purchasely/src/enums.ts`
2. Ensure native code maps to same values
3. Export from index.ts

### Modifying Native Bridge

**iOS:**
- Edit `PurchaselyRN.m` for methods
- Use `RCT_EXPORT_METHOD` macro
- Use `RCTPromiseResolveBlock` for async

**Android:**
- Edit `PurchaselyModule.kt`
- Use `@ReactMethod` annotation
- Use `Promise` parameter for async

---

## Troubleshooting

### Common Issues

1. **Build failures after dependency updates**
   ```bash
   yarn all:clean && yarn install && yarn all:prepare
   ```

2. **iOS pod issues**
   ```bash
   cd example/ios && pod install --repo-update
   ```

3. **Android build issues**
   ```bash
   cd example/android && ./gradlew clean
   ```

4. **Metro bundler cache**
   ```bash
   yarn example:start --reset-cache
   ```

---

## Version Compatibility

See `VERSIONS.md` for native SDK version mapping:

| React Native SDK | iOS SDK | Android SDK |
|------------------|---------|-------------|
| 5.6.1 | 5.6.2 | 5.6.0 |
| 5.6.0 | 5.6.0 | 5.6.0 |
| ... | ... | ... |

---

## Important Notes for AI Assistance

1. **Always use strict TypeScript** - The project enforces strict mode
2. **Follow existing patterns** - Check similar implementations before adding new code
3. **Test on both platforms** - iOS and Android may have different behaviors
4. **Update types** - Keep `types.ts`, `enums.ts`, and `interfaces.ts` in sync
5. **Native parity** - Both iOS and Android bridges should implement the same methods
6. **Event naming** - Use consistent event names across platforms
7. **Async/await** - All native methods use Promise-based APIs
8. **GDPR compliance** - User attributes support legal basis parameter

---

## Quick Reference Paths

```
# Main source
packages/purchasely/src/index.ts

# Type definitions
packages/purchasely/src/types.ts
packages/purchasely/src/enums.ts
packages/purchasely/src/interfaces.ts

# iOS native
packages/purchasely/ios/PurchaselyRN.m

# Android native
packages/purchasely/android/src/main/java/com/reactnativepurchasely/PurchaselyModule.kt

# Example app
example/src/App.tsx

# Configuration
package.json
tsconfig.json
turbo.json
```
