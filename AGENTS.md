# AGENTS.md

Guidance for every AI coding agent working in this repository.

## Overview

Purchasely React Native SDK: a bridge from React Native to the native Purchasely iOS and Android SDKs (App Store, Google Play, Huawei, Amazon).

- SDK user docs: `sdk_public_doc.md`. v5 to v6 mapping: `MIGRATION-v6.md`. Release steps: `RELEASE.md`. Native version map: `VERSIONS.md`. Contribution rules: `CONTRIBUTING.md`.
- The SDK is v6 builder API only. The v5 paywall methods (`start({...})`, `presentPresentationForPlacement`, `fetchPresentation`, `setPaywallActionInterceptorCallback`, ...) are removed.

| Property | Value |
|----------|-------|
| Current version | 6.2.0 |
| Native iOS SDK | 6.2.0 (`packages/purchasely/react-native-purchasely.podspec`) |
| Native Android SDK | 6.2.0 (`packages/purchasely/android/build.gradle`) |
| React Native | 0.86.0 |
| TypeScript | 5.8 strict |
| Node.js | 22 (`.nvmrc`, `engines` >= 22.11) |
| Yarn | 3.6.1 workspaces, `nodeLinker: node-modules` |
| iOS deployment target | 15.1 |
| Android | minSdk 23, Java 11, Kotlin 2.3.21 (`gradle.properties`) |

## Repository layout

Yarn workspaces (`packages/*` and `example`).

- `packages/purchasely` (`react-native-purchasely`): core bridge. TypeScript in `src/` (`index.ts`, `types.ts`, `enums.ts`, `interfaces.ts`, `startBuilder.ts`, `presentation.ts`, `interceptor.ts`, `components/PLYPresentationView.tsx`). iOS in `ios/` (`PurchaselyRN.m`, `PurchaselyView.swift`, `PurchaselyViewManager.swift`). Android in `android/src/main/java/com/reactnativepurchasely/` (`PurchaselyModule.kt`, `PurchaselyViewManager.kt`).
- `packages/google`, `amazon`, `huawei`, `android-player`: `@purchasely/react-native-purchasely-*` store and player packages. Five packages are published in total.
- `example/`: reference app, also the host for native tests and E2E.
- `integration_test/`: E2E scripts and test index (`E2E_TEST_INDEX.md`).
- `test-projects/`: Expo and RN CLI test apps. They have their own `CLAUDE.md`; follow it there.

## Commands (repo root)

```bash
yarn install            # postinstall patches RN CLI permissions
yarn all:prepare        # Builder Bob build of all packages (all:clean to clean)
yarn lint               # ESLint (yarn lint --fix to fix)
yarn typecheck          # TypeScript
yarn test               # Jest (packages/purchasely)
yarn example:start | example:ios | example:android
```

Per-package: `purchasely:prepare`, `google:prepare`, `amazon:prepare`, `huawei:prepare`, `player:prepare` (and `:clean`).
Build issues: `yarn all:clean && yarn install && yarn all:prepare`. Metro cache: `yarn example:start --reset-cache`. Pods: `cd example/ios && pod install --repo-update`.

## Code conventions

- TypeScript strict, ESNext, `react-jsx`. ESLint and Prettier: 4 spaces, single quotes, no semicolons, ES5 trailing commas.
- Names: `PascalCase` components, `PLY` prefix for public enums and types, `camelCase` functions, `SCREAMING_SNAKE_CASE` event constants, `_` prefix for private properties.
- Conventional Commits: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`. Keep PRs small. Discuss API changes with maintainers first.
- Follow existing patterns. All native methods are Promise-based. User attributes carry a GDPR legal basis parameter.

## Adding or changing public API

1. Add the interface in `interfaces.ts` and the types in `types.ts` (enums in `enums.ts`).
2. Implement in `index.ts` (or the matching builder file) and export it.
3. Implement iOS in `PurchaselyRN.m` (`RCT_EXPORT_METHOD`, `RCTPromiseResolveBlock`).
4. Implement Android in `PurchaselyModule.kt` (`@ReactMethod`, `Promise`).
5. Keep iOS and Android at parity: same methods, same event names, same enum values. Update both bridge test suites.
6. Add tests (below).

## Testing

- TypeScript: Jest with the `react-native` preset, in `packages/purchasely/src/__tests__/`. Mock native modules with `src/__mocks__/testUtils.ts`. Cover success and error cases for every new public method, type, component behavior and listener. `yarn test`.
- iOS XCTest: `packages/purchasely/ios/PurchaselyTests/` (`PurchaselyRNTests.m`, `PurchaselyViewTests.swift`).
- Android JUnit 4 with Mockito and mockito-kotlin: `packages/purchasely/android/src/test/java/com/reactnativepurchasely/`.
- Native tests need the React Native dependencies, so they do not run from their own package directory (`./gradlew test` in `packages/purchasely/android` fails). Run them through the example project, as CI does:

```bash
cd example/android && ./gradlew :react-native-purchasely:testDebugUnitTest
cd example/ios && xcodebuild test -workspace example.xcworkspace \
  -scheme react-native-purchasely-Unit-Tests -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO
```

- E2E (`integration_test/`, runner component `example/src/E2ETestRunner.tsx`): tests T1..Tn print `[E2E:Tn:PASS|FAIL]` markers. A crash-regression test does not fail, its markers disappear, and the runner's missing-marker check catches it. Android can assert native bounds with `uiautomator`; iOS cannot (accessibility tree only), so iOS is capture only. E2E must never gate `publish.yml`.
- Local iOS E2E: Homebrew `idb` breaks under Python 3.14. Use a Python 3.12 venv with `fb-idb` and `IDB=<venv>/bin/idb bash integration_test/run_e2e_ios.sh <UDID>`.

## Testing scope of the bridge

The bridge tests its own code and its calls to the native SDK. The native SDK tests its own behavior after the bridge calls it.

Test these three things:

1. **The bridge code.** Argument parsing, type conversion, default values, validation, error mapping, and the no-op of a platform-specific method.
2. **The call to the native SDK.** The JS, TypeScript or Dart call reaches the native bridge with the expected method name and argument format, and the native bridge accepts that format.
3. **The result that the bridge can see.** When the call has a completion (callback, promise, `Future` result or returned value), check it on a real device in the E2E suite: success or error, and the returned value. Examples: `setUserAttribute` has a listener callback, and `getUserAttribute` returns the value that was set. When the call has no completion (for example `emit`), stop at points 1 and 2.

Do not test:

- What the native SDK does after the call: network requests, backend reception, event delivery, StoreKit or Google Play Billing behavior. The native SDK owns this part.
- The backend or an analytics database (for example ClickHouse) to prove that a call worked.
- New iOS tests that swizzle a native SDK method. Existing swizzle tests stay.

## CI/CD

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | PR to `main` or `release/**`, push to `main`, `merge_group`, `workflow_call`, `workflow_dispatch` | Lint, test, native builds, native tests |
| `e2e-android.yml`, `e2e-ios.yml` | PR touching bridge paths, `workflow_dispatch` | Device E2E against the real backend |
| `publish.yml` | release published, `workflow_dispatch` | Run CI, check versions, publish 5 packages |

`ci.yml` jobs: `lint`, `test`, `build-android` (also runs the JUnit suite), `build-ios`, `iOS Build (use_frameworks!)`, `iOS Unit Tests (bridge)`, `build-rn-0-86-android`, `build-rn-0-86-ios`.

- No workflow rebuilds on a push to an open PR (no `synchronize`). They run when the PR opens, reopens or leaves draft, and on demand with the `run-ci` label: `gh pr edit <n> --add-label run-ci`. The run removes the label. Each job filters `labeled` events to `run-ci`.
- `push` to `main` runs `ci.yml` in full to seed the shared cache scope. PR caches are not readable from other branches.
- The `e2e-ios` concurrency group is global, so a push on another PR cancels a running iOS E2E. A short failure during setup is a cancellation: read the log.
- `brew install idb-companion` in `e2e-ios.yml` needs the newest full Xcode on the runner; the job restores the Xcode 16.x selection before building the app (RN 0.86 needs Xcode >= 16.1).
- Check whether a CI failure is an environment problem (runner image, Xcode, cache) before suspecting the code.

## Releases

Follow `RELEASE.md`. Tags are bare versions (`6.1.1`), never `v6.1.1`. Publishing is CI-driven through npm Trusted Publishing (OIDC, `--provenance`). `publish.yml` derives the npm dist-tag from the release tag and the published version; never hardcode `latest`.

Maintenance of an older major (5.x):
- Branch `release/5.x` from the last 5.x release commit, not from `main`. A bump PR to `main` would regress `main`. Do not rebase on `main` or cherry-pick.
- Use the `RELEASE.md`, `prepare.sh` and `ci.yml` of that commit, not those of `main`.
- npm refuses a dist-tag that parses as a SemVer range (`5.x`, `v5`, `5`). `publish.yml` on `main` uses `release-<major>` for older majors; verify with `npm publish --dry-run --tag <value>`.
- Run the publish through `workflow_dispatch` on `main`, so the workflow of `main` is the one that runs.
- On `macos-latest` (Xcode 26) clang rejects the `fmt` bundled with old RN versions. Pin `build-ios` to `macos-15` on old branches and scope cache keys to the image.

## Git workflow

- Never commit to `main`. Use a feature branch (`fix/<desc>`, `feat/<desc>`).
- Never merge `main` into a feature branch. Use `git rebase origin/main`, then `git push --force-with-lease`.
- Always set the PR base branch explicitly.
- All tests must pass before merge, including pre-existing failures: fix them in your change.
- Validate edited workflow YAML before pushing: `ruby -e "require 'yaml'; YAML.safe_load(File.read('.github/workflows/<file>'))"`.

## Agent tooling

- Prefer `fd`, `rg`, `ast-grep`, `jq`, `yq`. If `rg` is broken in a sandbox, use `grep -rn`.
- Use git worktrees and sub-agents to parallelize.
- Scope changes to what was requested. Do not touch adjacent files or upgrade dependencies unless asked.
- Before you report a task as done: run lint, typecheck and tests, check real CI status, and list each deliverable with its true status.
