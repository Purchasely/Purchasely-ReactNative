# Release Process for Purchasely React Native SDK

This document describes the step-by-step process for releasing a new version of the Purchasely React Native SDK.

## Prerequisites

- Node.js v20+ (see `.nvmrc`)
- Yarn 3.6.1+
- macOS with Xcode 15+ (for iOS builds)
- Android Studio with SDK 24+ (for Android builds)
- npm publishing access to `react-native-purchasely` and `@purchasely/*` packages

## Version Update Steps

### 1. Create a Release Branch

```bash
git checkout main
git pull origin main
git checkout -b version/{VERSION}
```

### 2. Update Native SDK Dependencies (if applicable)

#### iOS SDK Version

Update the Purchasely iOS SDK version in:

**`packages/purchasely/react-native-purchasely.podspec`** (line ~23):
```ruby
s.dependency "Purchasely", '{IOS_VERSION}'
```

#### Android SDK Version

Update the Purchasely Android SDK version in:

**`packages/purchasely/android/build.gradle`** (line ~143):
```groovy
api 'io.purchasely:core:{ANDROID_VERSION}'
```

**`packages/google/android/build.gradle`** (line ~133):
```groovy
implementation 'io.purchasely:google-play:{ANDROID_VERSION}'
```

**`packages/amazon/android/build.gradle`** (line ~131):
```groovy
implementation 'io.purchasely:amazon:{ANDROID_VERSION}'
```

**`packages/huawei/android/build.gradle`** (line ~135):
```groovy
implementation 'io.purchasely:huawei-services:{ANDROID_VERSION}'
```

**`packages/android-player/android/build.gradle`** (line ~141):
```groovy
implementation 'io.purchasely:player:{ANDROID_VERSION}'
```

### 3. Run the Prepare Script

```bash
./prepare.sh {VERSION}
```

This script updates:
- Version in all `package.json` files (purchasely, google, huawei, amazon, android-player)
- Cross-package dependency references
- `purchaselyVersion` constant in `packages/purchasely/src/index.ts`
- Builds all packages with `yarn all:prepare`

### 4. Update Version History

Add a new row to **`VERSIONS.md`**:

```markdown
| {VERSION} | {IOS_VERSION} | {ANDROID_VERSION} |
```

### 5. Update Test Files

Update the SDK version expectations in test files:

**`packages/purchasely/src/__tests__/index.test.ts`** (~lines 185, 206):
```typescript
'{VERSION}'  // Update version string in start() tests
```

**`packages/purchasely/src/__tests__/types.test.ts`** (~lines 331, 342):
```typescript
sdk_version: '{VERSION}',
// ...
expect(event.properties.sdk_version).toBe('{VERSION}')
```

### 6. Update the Yarn Lock File

```bash
yarn install
```

This ensures `yarn.lock` reflects any dependency changes.

### 7. Verify iOS Builds Locally

```bash
cd example/ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ../..
```

Build the example app to verify compilation:
```bash
cd example/ios
xcodebuild -workspace example.xcworkspace -scheme example -configuration Debug -destination 'generic/platform=iOS' build
```

### 8. Run Tests

```bash
yarn test
yarn lint
yarn typecheck
```

### 9. Commit and Push

```bash
git add .
git commit -m "chore: Bump package versions to {VERSION}"
git push origin version/{VERSION}
```

### 10. Create Pull Request

Create a PR targeting `main` and wait for all CI checks to pass:
- lint
- test
- build-android
- build-ios

### 11. Merge and Tag

After PR approval and merge:
```bash
git checkout main
git pull origin main
git tag v{VERSION}
git push origin v{VERSION}
```

### 12. Publish to npm

```bash
./publish.sh {VERSION} true
```

This publishes all packages:
- `react-native-purchasely`
- `@purchasely/react-native-purchasely-google`
- `@purchasely/react-native-purchasely-huawei`
- `@purchasely/react-native-purchasely-amazon`
- `@purchasely/react-native-purchasely-android-player`

## Files Changed During Version Update

| File | Changes |
|------|---------|
| `packages/purchasely/package.json` | Version number |
| `packages/purchasely/src/index.ts` | `purchaselyVersion` constant |
| `packages/google/package.json` | Version + purchasely dependency |
| `packages/huawei/package.json` | Version + purchasely dependency |
| `packages/amazon/package.json` | Version + purchasely dependency |
| `packages/android-player/package.json` | Version number |
| `packages/purchasely/react-native-purchasely.podspec` | iOS SDK version (if updated) |
| `packages/purchasely/android/build.gradle` | Android SDK version (if updated) |
| `packages/google/android/build.gradle` | Android SDK version (if updated) |
| `packages/amazon/android/build.gradle` | Android SDK version (if updated) |
| `packages/huawei/android/build.gradle` | Android SDK version (if updated) |
| `packages/android-player/android/build.gradle` | Android SDK version (if updated) |
| `example/ios/Podfile` | iOS SDK version (if updated) |
| `VERSIONS.md` | Version mapping table |
| `packages/purchasely/src/__tests__/index.test.ts` | Test version expectations |
| `packages/purchasely/src/__tests__/types.test.ts` | Test version expectations |
| `yarn.lock` | Dependency lock file |

## Common Issues

### CI Fails with "lockfile would have been modified"

The `yarn.lock` file wasn't updated after changing dependencies. Run:
```bash
yarn install
git add yarn.lock
git commit --amend --no-edit
git push --force-with-lease
```

### iOS Build Fails with "CocoaPods could not find compatible versions"

The CI needs `--repo-update` to fetch the latest pod specs. This is already configured in `.github/workflows/ci.yml`. If running locally:
```bash
cd example/ios
pod install --repo-update
```

### Test Fails with Version Mismatch

Update the hardcoded version strings in the test files (see Step 5).

## Recommendations

1. **Always update tests** when bumping versions to avoid CI failures
2. **Run full test suite locally** before pushing to catch issues early
3. **Verify iOS builds** with `pod install --repo-update` before pushing
4. **Update VERSIONS.md** to maintain the version history for documentation
5. **Use semantic versioning**:
   - MAJOR: Breaking API changes
   - MINOR: New features, backward compatible
   - PATCH: Bug fixes, backward compatible
