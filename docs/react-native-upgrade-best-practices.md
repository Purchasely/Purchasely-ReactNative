# React Native Upgrade Best Practices

> **Last Updated:** January 2026
> **Purpose:** Reusable guide for future React Native version upgrades in SDK projects

This document captures general best practices for upgrading React Native in SDK/library projects. For version-specific breaking changes, consult the official React Native release notes.

---

## Table of Contents

1. [Pre-Upgrade Checklist](#pre-upgrade-checklist)
2. [Understanding Version Coupling](#understanding-version-coupling)
3. [Phased Migration Strategy](#phased-migration-strategy)
4. [Essential Tools](#essential-tools)
5. [Native Bridge Considerations](#native-bridge-considerations)
6. [Testing Strategy](#testing-strategy)
7. [Common Breaking Changes by Category](#common-breaking-changes-by-category)
8. [Monorepo-Specific Guidance](#monorepo-specific-guidance)
9. [Version-Specific Quick Reference](#version-specific-quick-reference)

---

## Pre-Upgrade Checklist

Before starting any React Native upgrade:

### 1. Audit Current State
- [ ] Document current RN version and all related tooling versions
- [ ] List all native modules and their New Architecture compatibility
- [ ] Check [React Native Directory](https://reactnative.directory/) for dependency compatibility
- [ ] Note any custom native code in iOS (`*.m`, `*.mm`, `*.swift`) and Android (`*.kt`, `*.java`)
- [ ] Run current test suite to establish baseline

### 2. Review Target Version
- [ ] Read the official release blog post at `reactnative.dev/blog`
- [ ] Check minimum requirements (Node.js, Xcode, Gradle, Kotlin)
- [ ] Review breaking changes section
- [ ] Note deprecated APIs that affect your codebase

### 3. Prepare Environment
- [ ] Update local development tools to meet requirements
- [ ] Create feature branch for migration
- [ ] Set up CI to test against both old and new versions (temporarily)
- [ ] Establish rollback plan

### 4. Establish Metrics
- [ ] App startup time
- [ ] Module initialization time
- [ ] Memory usage during key operations
- [ ] Build times for both platforms

---

## Understanding Version Coupling

### For SDK/Library Projects

**peerDependencies Pattern (Recommended):**
```json
{
  "peerDependencies": {
    "react": "*",
    "react-native": "*"
  },
  "devDependencies": {
    "react": "19.x.x",
    "react-native": "0.8x.x"
  }
}
```

**Why this pattern:**
- SDK consumers can use any RN version
- `devDependencies` only affects development/testing
- Flexibility without forcing consumer upgrades

**Native Bridge Considerations:**
- iOS: Use `s.dependency "React-Core"` without version constraint
- Android: Use `api 'com.facebook.react:react-native:+'` for dynamic versioning

### Files That Pin Versions

| File Type | Purpose | Update Strategy |
|-----------|---------|-----------------|
| `package.json` devDeps | Development environment | Update for team consistency |
| Example app `package.json` | Reference implementation | Update to match target version |
| Test project `package.json` | CI testing | Update or maintain multiple versions |
| `.nvmrc` | Node.js version | Update to meet minimum requirements |
| `gradle-wrapper.properties` | Gradle version | Update per RN requirements |
| `Podfile` | iOS dependencies | Usually auto-detected |

---

## Phased Migration Strategy

### Recommended Approach: Incremental Upgrades

```
Current Version
      ↓
Minor Version Steps (if large gap)
      ↓
Second-to-Last Major Version
      ↓
Enable New Features/Architecture
      ↓
Latest Version
      ↓
Optimize/Clean Up
```

### Phase Template

**Phase 1: Assessment (1-2 days)**
- Review breaking changes documentation
- Audit dependencies for compatibility
- Create migration branch
- Identify high-risk areas

**Phase 2: Incremental Upgrade (1-3 days per version)**
- Use Upgrade Helper for file-by-file changes
- Update dependencies one version at a time
- Fix build errors before runtime testing
- Document all changes made

**Phase 3: Feature Migration (1-5 days)**
- Enable new architecture features
- Test with feature flags
- Address deprecation warnings
- Migrate deprecated APIs

**Phase 4: Validation (2-3 days)**
- Full test suite execution
- Performance comparison
- Platform-specific testing
- Edge case verification

**Phase 5: Rollout**
- Update documentation
- Prepare changelog
- Consider phased release

---

## Essential Tools

### React Native Upgrade Helper
**URL:** https://react-native-community.github.io/upgrade-helper/

**Usage:**
1. Select your current version
2. Select target version
3. Review file-by-file diff
4. Apply changes systematically
5. Mark files as done

**Best Practices:**
- Don't skip versions in the helper for large jumps
- Pay attention to inline comments (insights about specific changes)
- Keep the helper open during entire migration

### React Native CLI Upgrade
```bash
# Automatic upgrade with git-based merging
npx react-native upgrade

# Upgrade to specific version
npx react-native upgrade 0.83.0
```

**When to use CLI vs Manual:**
- CLI: Clean projects, small version jumps
- Manual (Upgrade Helper): Complex projects, many customizations

### React Native Directory
**URL:** https://reactnative.directory/

**Filter by:**
- "New Architecture" support
- Platform (iOS/Android)
- Maintenance status

### Additional Tools
| Tool | Purpose |
|------|---------|
| `npx expo-codemod` | Automatic code transformations |
| Flipper | Debugging during migration |
| React DevTools | Component render analysis |

---

## Native Bridge Considerations

### iOS Native Modules

**Standard Module Registration:**
```objc
// Pre-New Architecture (still works via interop)
RCT_EXPORT_MODULE()
RCT_EXPORT_METHOD(methodName:(NSString *)param
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
```

**TurboModules (New Architecture):**
```typescript
// NativeYourModule.ts (Codegen spec)
import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  methodName(param: string): Promise<boolean>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('YourModule');
```

**Migration Strategy:**
1. Legacy modules work via interop layer in New Architecture
2. Create codegen spec for TurboModules when ready
3. Both can coexist during transition

### Android Native Modules

**Standard Module:**
```kotlin
class YourModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName() = "YourModule"

    @ReactMethod
    fun methodName(param: String, promise: Promise) {
        // Implementation
    }
}
```

**Package Registration:**
```kotlin
class YourPackage : ReactPackage {
    override fun createNativeModules(context: ReactApplicationContext) =
        listOf(YourModule(context))

    override fun createViewManagers(context: ReactApplicationContext) =
        emptyList<ViewManager<*, *>>()
}
```

**TurboModule Enhancement:**
```kotlin
// Add ReactModuleInfo for TurboModule support
override fun getReactModuleInfoProvider() = ReactModuleInfoProvider {
    mapOf(
        YourModule.NAME to ReactModuleInfo(
            name = YourModule.NAME,
            className = YourModule.NAME,
            canOverrideExistingModule = false,
            needsEagerInit = false,
            isCxxModule = false,
            isTurboModule = true
        )
    )
}
```

### Native View Components

**Legacy Pattern (works via Fabric interop):**
```typescript
import { requireNativeComponent } from 'react-native';
const NativeView = requireNativeComponent('YourViewName');
```

**Fabric Pattern:**
```typescript
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
const NativeView = codegenNativeComponent<NativeProps>('YourViewName');
```

---

## Testing Strategy

### Test Pyramid for RN Upgrades

```
         ┌─────────────────┐
         │   E2E Tests     │  ← Detox, Maestro
         │   (Selective)   │
         ├─────────────────┤
         │  Integration    │  ← Example App Manual Testing
         │  Tests          │
         ├─────────────────┤
         │   Unit Tests    │  ← Jest (most important)
         └─────────────────┘
```

### Test Checklist by Phase

**After Build Success:**
- [ ] All Jest unit tests pass
- [ ] TypeScript compiles without errors
- [ ] No new lint warnings

**After App Runs:**
- [ ] App launches on iOS simulator
- [ ] App launches on Android emulator
- [ ] Hot reload works
- [ ] Native modules load correctly

**Functional Testing:**
- [ ] All critical user flows work
- [ ] Native bridge methods return expected values
- [ ] Event listeners fire correctly
- [ ] Async operations complete

**Platform-Specific:**
- [ ] iOS: Test on physical device
- [ ] iOS: Test production build
- [ ] Android: Test release APK
- [ ] Android: Test with ProGuard/R8

### Mocking Strategy for Tests

**Legacy NativeModules:**
```javascript
jest.mock('react-native', () => ({
  ...jest.requireActual('react-native'),
  NativeModules: {
    YourModule: {
      methodName: jest.fn().mockResolvedValue(true),
    },
  },
}));
```

**TurboModules (if migrated):**
```javascript
jest.mock('./NativeYourModule', () => ({
  default: {
    methodName: jest.fn().mockResolvedValue(true),
  },
}));
```

---

## Common Breaking Changes by Category

### Build System Changes

| Category | What to Check |
|----------|---------------|
| Gradle | Version in `gradle-wrapper.properties` |
| Kotlin | Version in root `build.gradle` |
| AGP | Android Gradle Plugin version |
| Xcode | Minimum version in release notes |
| CocoaPods | May need `pod install --repo-update` |
| Node.js | Minimum version in `.nvmrc` |

### JavaScript/TypeScript Changes

| Category | Common Issues |
|----------|---------------|
| Deep imports | `react-native/Libraries/...` → root imports |
| Event emitters | API changes, thread safety |
| Component deprecations | SafeAreaView, StatusBar methods |
| Hooks | ESLint rule updates |

### Native Code Changes

| Platform | Common Issues |
|----------|---------------|
| iOS | Header includes, macro changes, Swift version |
| Android | Class visibility changes, Kotlin nullability, package moves |
| Both | Module registration, view manager patterns |

### Architecture Changes

| Era | Key Characteristics |
|-----|---------------------|
| Pre-0.68 | Bridge-only architecture |
| 0.68-0.81 | New Architecture optional |
| 0.82+ | New Architecture mandatory |

---

## Monorepo-Specific Guidance

### Package Coordination

**Upgrade Order:**
1. Core SDK package first
2. Platform-specific packages (in parallel)
3. Example apps
4. Test projects

**Version Consistency:**
```json
// Root package.json
{
  "resolutions": {
    "react-native": "0.83.x"
  }
}
```

### Metro Configuration

**Monorepo Metro Config:**
```javascript
// metro.config.js
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const path = require('path');

const config = {
  watchFolders: [path.resolve(__dirname, '../../packages')],
  resolver: {
    nodeModulesPaths: [
      path.resolve(__dirname, 'node_modules'),
      path.resolve(__dirname, '../../node_modules'),
    ],
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
```

### Workspace Tools

| Tool | Purpose |
|------|---------|
| Yarn Workspaces | Package management |
| Turborepo | Build orchestration, caching |
| `@rnx-kit/metro-config` | Metro in monorepos |
| `@rnx-kit/metro-resolver-symlinks` | Symlink resolution |

---

## Version-Specific Quick Reference

### Checking Current Requirements

```bash
# Check RN version
npx react-native --version

# Check Node version
node --version

# Check installed RN info
npx react-native info
```

### Release Cadence

React Native releases approximately every 60 days. For enterprise stability:
- Wait 2-4 weeks after release for patch versions
- Target versions that remain "latest" for at least 3 months
- Monitor [React Native releases](https://github.com/facebook/react-native/releases)

### Breaking Changes Reference URLs

| Version | Release Notes URL |
|---------|-------------------|
| Latest | https://reactnative.dev/blog |
| Specific | https://reactnative.dev/blog/YYYY/MM/DD/react-native-X.XX |
| Changelog | https://github.com/facebook/react-native/blob/main/CHANGELOG.md |

### Architecture Feature Flags

**Android (`gradle.properties`):**
```properties
# Enable New Architecture
newArchEnabled=true

# Enable Hermes (default in recent versions)
hermesEnabled=true
```

**iOS (Environment or Podfile):**
```bash
# Environment variable
RCT_NEW_ARCH_ENABLED=1 bundle exec pod install

# Or in Podfile
ENV['RCT_NEW_ARCH_ENABLED'] = '1'
```

---

## Quick Decision Guide

### Should I Upgrade?

**Upgrade Now If:**
- Security vulnerabilities in current version
- Blocking bug fixed in newer version
- New feature needed for business requirement
- Current version losing support

**Delay Upgrade If:**
- Critical dependencies not compatible
- Major release deadline approaching
- Insufficient testing resources
- New version < 4 weeks old

### How Many Versions to Jump?

| Gap | Recommendation |
|-----|----------------|
| 1-2 minor versions | Direct upgrade |
| 3-4 minor versions | Consider intermediate step |
| Major version change | Always use intermediate steps |
| Architecture change (e.g., New Arch) | Dedicated migration phase |

---

## Troubleshooting Common Issues

### Build Failures

```bash
# Clean everything and retry
yarn clean  # or npm run clean
cd ios && pod deintegrate && pod install
cd android && ./gradlew clean
```

### Metro Issues

```bash
# Clear Metro cache
npx react-native start --reset-cache

# Or with Expo
npx expo start --clear
```

### CocoaPods Issues

```bash
cd ios
pod deintegrate
pod cache clean --all
pod install --repo-update
```

### Android Gradle Issues

```bash
cd android
./gradlew clean
./gradlew --stop
rm -rf ~/.gradle/caches
./gradlew build
```

---

## Maintenance

**Update this document when:**
- Completing a React Native upgrade
- Discovering new best practices
- React Native release cadence changes
- New Architecture becomes the only option (post-0.82)

**Review annually for:**
- Outdated tool recommendations
- Changed URLs
- Deprecated practices
