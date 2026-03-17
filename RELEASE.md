# Release Process for Purchasely React Native SDK

This document describes the step-by-step process for releasing a new version of the Purchasely React Native SDK. Publishing to npm is **automated via CI** — creating a GitHub release triggers the publish workflow.

## Prerequisites

- Node.js v20+ (see `.nvmrc`)
- Yarn 3.6.1+
- `gh` CLI authenticated with push access to the repository
- npm Trusted Publishers configured (see [npm Setup](#npm-trusted-publisher-setup) — one-time only)

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

Update the Purchasely Android SDK version in all 5 build.gradle files:

| File | Dependency |
|------|-----------|
| `packages/purchasely/android/build.gradle` | `api 'io.purchasely:core:{ANDROID_VERSION}'` |
| `packages/google/android/build.gradle` | `implementation 'io.purchasely:google-play:{ANDROID_VERSION}'` |
| `packages/amazon/android/build.gradle` | `implementation 'io.purchasely:amazon:{ANDROID_VERSION}'` |
| `packages/huawei/android/build.gradle` | `implementation 'io.purchasely:huawei-services:{ANDROID_VERSION}'` |
| `packages/android-player/android/build.gradle` | `implementation 'io.purchasely:player:{ANDROID_VERSION}'` |

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

Replace all occurrences of the old version string with `{VERSION}` in:

- **`packages/purchasely/src/__tests__/index.test.ts`** (~lines 185, 206)
- **`packages/purchasely/src/__tests__/types.test.ts`** (~lines 331, 342)

### 6. Update Documentation

Update version references in **`CLAUDE.md`**:
- Properties table (Current Version, Native iOS SDK, Native Android SDK)
- Native Dependencies section (iOS SDK version, Android core version)
- Version Compatibility table

### 7. Update the Yarn Lock File

```bash
yarn install
```

This ensures `yarn.lock` reflects any dependency changes.

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
git push -u origin version/{VERSION}
```

### 10. Create Pull Request

```bash
gh pr create --base main --title "Version {VERSION}" --body "..."
```

Wait for all CI checks to pass:
- lint
- test
- build-android
- build-ios

### 11. Merge the PR

After CI passes and PR is approved:
```bash
gh pr merge --merge
```

### 12. Create GitHub Release (triggers automated npm publish)

```bash
git checkout main
git pull origin main
gh release create {VERSION} --target main --title "{VERSION}" --notes "## React Native SDK {VERSION}

### Native SDK updates
- **iOS SDK:** {OLD_IOS} → {IOS_VERSION}
- **Android SDK:** {OLD_ANDROID} → {ANDROID_VERSION}
"
```

This automatically triggers `.github/workflows/publish.yml` which:
1. Runs the full CI pipeline (lint, test, build-android, build-ios)
2. Verifies all package.json versions match the release tag
3. Publishes all 5 packages to npm with OIDC provenance

### 13. Verify Publication

```bash
npm view react-native-purchasely version
npm view @purchasely/react-native-purchasely-google version
npm view @purchasely/react-native-purchasely-amazon version
npm view @purchasely/react-native-purchasely-huawei version
npm view @purchasely/react-native-purchasely-android-player version
```

All should return `{VERSION}`.

## Published Packages

| Package | npm |
|---------|-----|
| `react-native-purchasely` | [npmjs.com](https://www.npmjs.com/package/react-native-purchasely) |
| `@purchasely/react-native-purchasely-google` | [npmjs.com](https://www.npmjs.com/package/@purchasely/react-native-purchasely-google) |
| `@purchasely/react-native-purchasely-amazon` | [npmjs.com](https://www.npmjs.com/package/@purchasely/react-native-purchasely-amazon) |
| `@purchasely/react-native-purchasely-huawei` | [npmjs.com](https://www.npmjs.com/package/@purchasely/react-native-purchasely-huawei) |
| `@purchasely/react-native-purchasely-android-player` | [npmjs.com](https://www.npmjs.com/package/@purchasely/react-native-purchasely-android-player) |

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
| `VERSIONS.md` | Version mapping table |
| `CLAUDE.md` | Version references in properties and docs |
| `packages/purchasely/src/__tests__/index.test.ts` | Test version expectations |
| `packages/purchasely/src/__tests__/types.test.ts` | Test version expectations |
| `yarn.lock` | Dependency lock file |

## npm Trusted Publisher Setup

> One-time setup per package. Already configured — only needed if adding a new package.

For each package, go to `https://www.npmjs.com/package/<PACKAGE_NAME>/access`:
1. Section **Trusted Publishers** → **GitHub Actions**
2. Repository owner: `Purchasely`
3. Repository name: `Purchasely-ReactNative`
4. Workflow filename: `publish.yml`
5. Environment: *(leave empty)*

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

### Publish Fails with "forbidden" or OIDC error

- Verify Trusted Publisher is configured on npmjs.com for the failing package
- Ensure the workflow filename matches exactly: `publish.yml`
- Ensure the repository name matches: `Purchasely/Purchasely-ReactNative`

### Publish Fails with Version Mismatch

The release tag must match exactly the version in all `package.json` files. Release tags should be bare versions (e.g., `5.7.2`), not prefixed with `v`.

## Recommendations

1. **Always update tests** when bumping versions to avoid CI failures
2. **Run full test suite locally** before pushing to catch issues early
3. **Update CLAUDE.md** alongside version bumps to keep docs in sync
4. **Update VERSIONS.md** to maintain the version history for documentation
5. **Use semantic versioning**:
   - MAJOR: Breaking API changes
   - MINOR: New features, backward compatible
   - PATCH: Bug fixes, backward compatible
