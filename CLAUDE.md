# Claude AI Context for Purchasely React Native SDK

## Project Overview

**Purchasely React Native SDK** is a comprehensive In-App Purchase and Subscription management solution for React Native applications. It provides a bridge between React Native and native Purchasely SDKs for iOS and Android, supporting multiple app stores.

**📚 Documentation:**
- **For SDK Users:** See [`sdk_public_doc.md`](../sdk_public_doc.md) - Complete SDK integration and usage guide
- **For Contributors/AI:** This file (CLAUDE.md) - Codebase architecture, development, and contribution guide

| Property | Value |
|----------|-------|
| Current Version | 5.6.1 |
| React Native | 0.83.1 |
| TypeScript | 5.2.2 (strict mode) |
| Node.js | v20.19.4 (see `.nvmrc`) |
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

### Test Files

| File | Purpose | Lines |
|------|---------|-------|
| `packages/purchasely/src/__tests__/index.test.ts` | Main API method tests | ~823 |
| `packages/purchasely/src/__tests__/types.test.ts` | Type validation tests | ~503 |
| `packages/purchasely/src/__tests__/enums.test.ts` | Enumeration tests | ~306 |
| `packages/purchasely/src/__tests__/PLYPresentationView.test.tsx` | Component tests | ~266 |
| `packages/purchasely/src/__mocks__/testUtils.ts` | Shared test utilities | - |
| `packages/purchasely/ios/PurchaselyTests/PurchaselyRNTests.m` | iOS bridge tests | ~330 |
| `packages/purchasely/ios/PurchaselyTests/PurchaselyViewTests.swift` | iOS view tests | ~265 |
| `packages/purchasely/android/src/test/.../PurchaselyModuleTest.kt` | Android module tests | ~508 |

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

> **📖 Complete SDK Documentation:** For full integration guide, API reference, and usage examples, see [`sdk_public_doc.md`](../sdk_public_doc.md)

The following sections provide quick API examples. For comprehensive documentation including:
- Installation & setup instructions
- Complete API reference
- Platform-specific features
- Event listeners & callbacks
- Deeplinks management
- And more...

Refer to the [SDK Public Documentation](../sdk_public_doc.md).

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
- Kotlin: 2.1+
- Java: 17
- Gradle: 8.14

---

## Testing

The SDK includes comprehensive test coverage across TypeScript, iOS, and Android platforms.

### Test Structure

**TypeScript/Jest Tests** (`packages/purchasely/src/__tests__/`)

| Test File | Purpose | Lines |
|-----------|---------|-------|
| `index.test.ts` | Main API tests for all public methods | ~823 |
| `types.test.ts` | Type definition validation tests | ~503 |
| `enums.test.ts` | Enumeration value tests | ~306 |
| `PLYPresentationView.test.tsx` | React component tests | ~266 |

- **Mocks & Utilities:** `packages/purchasely/src/__mocks__/testUtils.ts`
- **Framework:** Jest with React Native preset
- **Total Test Coverage:** ~1,900 lines of TypeScript tests

**iOS Tests (XCTest)** (`packages/purchasely/ios/PurchaselyTests/`)

| Test File | Purpose | Lines | Language |
|-----------|---------|-------|----------|
| `PurchaselyRNTests.m` | Bridge module integration tests | ~330 | Objective-C |
| `PurchaselyViewTests.swift` | View component tests | ~265 | Swift |

- **Framework:** XCTest (built-in iOS testing framework)
- **Test Target:** Configured in `Info.plist`
- **Coverage:** Native bridge methods, view lifecycle, event handling

**Android Tests (JUnit)** (`packages/purchasely/android/src/test/`)

| Test File | Purpose | Lines |
|-----------|---------|-------|
| `PurchaselyModuleTest.kt` | Bridge module unit tests | ~508 |

- **Framework:** JUnit 4.13.2
- **Testing Dependencies:**
  - Mockito 5.11.0 (mocking framework)
  - Mockito Kotlin 5.2.1 (Kotlin extensions)
  - Kotlinx Coroutines Test 1.7.3 (async testing)
- **Coverage:** React Native bridge methods, async operations, error handling

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
# TypeScript/Jest tests (CI-enabled)
yarn test                    # All tests
yarn test --coverage         # With coverage
yarn test --watch           # Watch mode

# iOS tests (XCTest) - Run locally or in example app context
# Native tests require React Native dependencies from the example app
cd packages/purchasely/ios
xcodebuild test -workspace Purchasely.xcworkspace -scheme Purchasely -destination 'platform=iOS Simulator,name=iPhone 15'

# Android tests (JUnit) - Run locally or in example app context
# Native tests require React Native dependencies from the example app
cd packages/purchasely/android
./gradlew test              # Run unit tests
./gradlew testDebugUnitTest # Run debug variant tests
```

**Note:** Native tests (iOS XCTest and Android JUnit) require React Native dependencies and should be run locally or within the example app context. They cannot run in CI as standalone jobs. TypeScript tests run in CI automatically.

### Test Guidelines

When adding new features:

1. **TypeScript Tests** - Add tests in `src/__tests__/` for:
   - New public API methods
   - Type definitions and interfaces
   - Component behavior
   - Event listeners

2. **iOS Tests** - Add tests in `ios/PurchaselyTests/` for:
   - Native bridge method implementations
   - View component lifecycle
   - Platform-specific behavior
   - Error handling and edge cases

3. **Android Tests** - Add tests in `android/src/test/` for:
   - Native module method implementations
   - Async operations and promises
   - Platform-specific behavior
   - Error handling and edge cases

4. **Cross-Platform Parity** - Ensure tests verify consistent behavior across iOS and Android

---

## CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/ci.yml`):

### CI Jobs

1. **lint** (ubuntu-latest) - TypeScript + ESLint checks, type checking
2. **test** (ubuntu-latest) - TypeScript/Jest unit tests with coverage
3. **build-library** (ubuntu-latest) - Build TypeScript package with Builder Bob
4. **build-android** (ubuntu-latest) - Build Android example app with Gradle caching
5. **build-ios** (macos-latest) - Build iOS example app with CocoaPods caching

**Note:** Native tests (Android JUnit and iOS XCTest) are not included in CI as they require React Native dependencies from the example app context. Run these tests locally during development.

### CI Commands Reference

```yaml
# Lint & Type Check
yarn lint
yarn typecheck

# TypeScript Tests (CI-enabled)
yarn test --maxWorkers=2 --coverage

# Build Library
yarn prepare
```

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

### Adding Tests

**TypeScript Tests:**
1. Create test file in `packages/purchasely/src/__tests__/`
2. Use Jest and React Native Testing Library
3. Mock native modules using `src/__mocks__/testUtils.ts`
4. Test both success and error cases
5. Run `yarn test` to verify

**iOS Tests (XCTest):**
1. Add test methods to `PurchaselyRNTests.m` or `PurchaselyViewTests.swift`
2. Use XCTestCase and XCTestExpectation for async tests
3. Test native bridge methods and view lifecycle
4. Run tests from Xcode or via xcodebuild

**Android Tests (JUnit):**
1. Add test methods to `PurchaselyModuleTest.kt`
2. Use JUnit 4 annotations (@Test, @Before, @After)
3. Use Mockito for mocking React Native bridge
4. Test with `./gradlew test` from android directory

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
# Documentation
sdk_public_doc.md                    # SDK user documentation (integration & usage)
claude.md                            # This file (codebase context for AI/developers)
CONTRIBUTING.md                      # Contribution guidelines
VERSIONS.md                          # SDK version compatibility matrix
docs/react-native-upgrade-best-practices.md  # RN upgrade guide for future migrations

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

# TypeScript tests
packages/purchasely/src/__tests__/index.test.ts
packages/purchasely/src/__tests__/types.test.ts
packages/purchasely/src/__tests__/enums.test.ts
packages/purchasely/src/__tests__/PLYPresentationView.test.tsx
packages/purchasely/src/__mocks__/testUtils.ts

# iOS tests
packages/purchasely/ios/PurchaselyTests/PurchaselyRNTests.m
packages/purchasely/ios/PurchaselyTests/PurchaselyViewTests.swift

# Android tests
packages/purchasely/android/src/test/java/com/reactnativepurchasely/PurchaselyModuleTest.kt

# Example app
example/src/App.tsx

# Configuration
package.json
tsconfig.json
turbo.json
```
