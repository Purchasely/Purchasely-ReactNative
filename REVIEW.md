# REVIEW.md

The review and merge rules of the Purchasely SDKs: Android, iOS, React Native, Flutter and
Cordova. Each repo has a copy of this file. Sections 1 to 4 are the same in each copy. Section 5
is the part of that repo.

We cannot replace a released SDK version. Maven Central, npm and pub.dev keep each published
version, and the integrating apps keep the version they shipped in the stores. A fix is a new
version, and each app developer must ship an app update to get it. A backend flag can limit
some failures before that update. So we control a change before the merge, and again before the
release.

Words in this file:

- **Author**: the person who wrote the change, or who drove the agent that wrote it.
- **Platform reviewer**: an engineer of the platform that the change affects, who is not the
  author. For a bridge change (React Native, Flutter, Cordova), an engineer of the native SDK
  that the change affects.
- **SDK lead**: the lead of the mobile SDKs (`kherembourg`).

## 1. Tiers

The behavior that a change can break sets the tier. The author and the size of the diff do not.
Each tier includes the checks of the lower tiers.

| Tier | Meaning | Before merge | Before release |
|------|---------|--------------|----------------|
| **T0** | No effect on an integrating app at runtime, at build time or in its store review. | The required checks ran on the head commit and passed. All review threads are resolved. One approval from a team member who is not the author. | No test for this change. The release checklist of the repo still applies to every release. |
| **T1** | A contained runtime change that QA can see. | The approval comes from a platform reviewer. | Smoke test of the sample app on the affected area. |
| **T2** | Can break integrating apps, revenue or app start; or QA cannot easily see it; or an app needs an update to recover. | The SDK lead is the author or approves. A deep AI review of the final code (Greptile, or a Codex review at high effort), with its threads resolved. The PR body fills **Integrator impact** and **Mitigation after release**. | A row in the release test plan of the repo for each affected flow (purchase, restore, paywall display, start), run in the release QA. A release candidate when the change touches purchase or start. Migration steps in the version note when an app must change. |
| **T3** | Controls publication, artifact integrity, signing, credentials, release permissions or a required check. Also a change that deletes data on purpose with no way to recover it. | A second approval from a person who is not the author. An engineer of another SDK platform can give it. Do not use the admin bypass. | The release checklist of the repo, with a record of the artifact, its destination, its version and the publication permissions. A dry run where the registry has one. |

## 2. The matrix

The highest tier of all the rows that a PR matches is the tier of the PR. When a file matches
two rows, the more specific row wins. Section 5 gives the paths of each area in the repo.

| Area | Typical signals | Tier |
|------|-----------------|------|
| Docs, README, code comments | `docs/`, `*.md`, comments only | T0 |
| Process docs | `AGENTS.md`, `REVIEW.md`, release docs | T1. The SDK lead is the author or approves. |
| Sample app UI | screens and texts of the sample apps | T0 |
| Sample app configuration | API key, backend host, Builder options, application id, signing, install scripts | T1 |
| Tests: new tests, corrected tests | test folders | T0 |
| Tests: a removed test or a weaker assertion | test folders | The tier of the risk that the test controls. |
| Internal refactor, no behavior change, no public declaration changed | internal code only | T1 |
| Logs and debug tools | logger, log levels | T1. T2 if it runs on the main thread or logs user data. |
| Paywall rendering, layout, components, localization | renderer, layout engine, fonts, images, string files | T1. T2 if it can block a display or a purchase, crash the app, change the format arguments of a string, or change action handling, flow navigation or TV focus. |
| Media player | video and audio players | T1 for the appearance. T2 for lifecycle, threads, the shared audio session or resource ownership. |
| Backend API contract | request and response models, parsers, endpoints | T1. T2 if a parse failure can block a display or a purchase. |
| Network and security | TLS, hosts, proxy, API key and headers, interceptors, compression, timeouts, retries | T2: a failure affects every call of every app. |
| Analytics and SDK events | event names, properties, triggers, identity, delivery, deduplication | T2: a wrong event corrupts dashboards and A/B test results, and QA does not see it. T1 for an implementation change that keeps all of these. |
| Public API | any public declaration that an integrating app can use (section 5) | T2. A breaking change also needs migration steps in the version note, and a major version or an exception that the SDK lead writes in the PR body. |
| Purchase, restore, entitlements, receipts and tokens | store billing clients, transaction observers, sync with the backend, web checkout | T2 |
| User identity | login, logout, anonymous ID, purchase transfer, the cache of each user | T2 |
| Start, lifecycle, threads | `start()`, application hooks, coroutines and dispatchers, main thread work, background tasks | T2: a crash or an ANR at start hits every user of every integrating app. |
| Local data and migrations | SharedPreferences, DataStore, UserDefaults, Keychain, caches, file formats | T2: we cannot roll back data on a device. |
| Deeplinks and webviews | deeplink routing, redemption links, preview links, webview settings and navigation | T2: input from outside the app. |
| Campaigns and triggers | trigger evaluation, capping, exposure | T2: an error can show a paywall to every user. |
| Consent and privacy | consent, legal basis, data processing purposes, redaction, data export | T2: legal risk that QA does not see. |
| Crash handler and telemetry | uncaught exception handler, telemetry exporter | T2: it can hide crashes of the app or send data to the wrong place. |
| Backend configuration and its defaults | the configuration model and its default values | T2: it is the rollback path of rule 5. |
| Build compatibility and runtime dependencies | min OS, compile SDK, language and toolchain versions, store billing libraries, any dependency of a published artifact (also transitive) | T2 |
| Build-only and test-only dependencies | test libraries, build plugins with no effect on the published artifact | T1 |
| Consumer rules, library manifest, consumer lint | `consumer-rules.pro`, the `AndroidManifest.xml` of a library, published lint checks | T2: they act only in the build or the release build of the app. |
| Privacy manifest, required-reason APIs, permissions | `PrivacyInfo.xcprivacy`, manifest permissions | T2: the store review of the app can reject it. |
| Generated or rewritten files | files that a script builds or rewrites | T2 |
| Hybrid bridge, contained change | bridge code that keeps the arguments, defaults, type mappings, errors, results, callbacks and listener lifetime | T1 |
| Hybrid bridge, contract change | a change to one of the items above, or to purchase, restore, identity or entitlement behavior, also with no signature change | T2 |
| Native SDK version in a bridge | the native pins: `build.gradle`, `.podspec`, `Package.swift`, `plugin.xml`, lockfiles | T2 minimum, or the highest tier of the native changes that the new version brings. Keep all native pins at the same version. |
| CI: comments and formatting | workflow files, no behavior change | T0 |
| CI: tests and reports | test workflows, CI scripts, Actions version bumps | T1 |
| Publication, signing, credentials, required checks | publish workflows and scripts, signing, secrets, `permissions:`, the composition of the published artifact, a required check | T3, wherever the code is. |
| The release | version tag, GitHub release, publication to the registry | T3 |

## 3. Rules

1. **Do not count the author as a reviewer.** Do not count an agent as a reviewer. Its review
   is evidence for the human reviewers.
2. **Bind the checks to the head commit.** Before the merge, the required checks ran on the
   head commit and passed. A skipped check is not a pass: start the run again (section 5 says
   how).
3. **Keep or renew the approval after new commits.**
   - For T2 and T3, a new commit that changes production code, build files or CI needs a new
     approval from the platform reviewer.
   - A commit that changes only T0 files or process docs keeps the approval.
   - A rebase keeps the approval when `git range-diff <old-base>..<old-head> <new-base>..<new-head>`
     shows no change in the commits of the PR. Write the old and new head SHAs and the result in a
     PR comment. Then run the required checks on the new head.
   - The repos do not dismiss stale approvals automatically. The person who merges checks the
     approval against these rules.
4. **Change a tier with a reason.** Anyone, and an AI review, can propose a higher tier. A human
   reviewer confirms the tier. To lower a tier, write the reason in the PR body and get the
   agreement of the SDK lead and of a reviewer who is not the author. Do not go below a row of
   the matrix.
5. **Add a kill switch when you can.** Give a T2 feature a backend configuration flag that turns
   it off, and test the off state. In the PR, write the flag path, the off value, the platforms
   and any app setting that overrides it. The SDK reads the configuration only after the
   configuration response of `start()`. So a flag cannot stop code that runs before it: the
   start path, data migrations, the crash handler. Examples:
   - `telemetry.mode` = `"disabled"`: Android and iOS.
   - `user_subscription_auto_fetch_activated` = `false`: Android and iOS. It stops only the
     automatic subscription fetch.
   - `allow_campaigns` = `false`: Android and iOS. On iOS, an explicit app setting overrides it.
   - `request_body_gzip_enabled` = `false`: Android.

## 4. The PR body

Every PR body has these three sections:

```markdown
## Tier
<T0, T1, T2 or T3>: <the row of the matrix that sets it, and the evidence>.

## Integrator impact
What an integrating app sees or must do. Copy the "Impact for the application" line of the
version note when the repo has one. "None" when apps see no difference.

## Mitigation after release
How we limit the damage if this change is wrong in a released version: the backend flag
(rule 5), a hotfix release, a workaround for app developers. "Not needed" for T0.
```

Add them to the sections that the repo already asks for (section 5). Do not repeat a section
that the repo already has under another name. When the `pr-ready` skill writes the body, keep
its headings (`What`, `Why`, `How to verify`, `Notes`, `Deploy`, `Greptile`) and add the three
sections after `Why`. A PR body does not replace a required file (version note, feature doc).

## 5. This repo: React Native

The bridge calls the native iOS and Android SDKs. Most features go through the same three files:
`src/index.ts`, `ios/PurchaselyRN.m` and
`android/src/main/java/com/reactnativepurchasely/PurchaselyModule.kt`. A change in these files
can match many rows of the matrix. Classify it by the behavior that it changes.

Paths that start with `src/`, `ios/` or `android/`, and `react-native-purchasely.podspec`, are
under `packages/purchasely/`.

### Paths of each area

These paths are examples. Classify every other file by the behavior it can change.

| Area | Paths |
|------|-------|
| Public API | the exports of `src/index.ts` and the declarations that they expose: `types.ts`, `enums.ts`, `interfaces.ts`, `events.ts`, `presentationTypes.ts`, `startBuilder.ts`, `presentation.ts`, `interceptor.ts`, `redemption.ts`, `components/PLYPresentationView.tsx`. `bob build` generates their `.d.ts` files in `lib/typescript/packages/purchasely/src/`. Git ignores `lib/`, so the review reads the source. The four other packages export no JavaScript API (`export {}`). `android/build.gradle` declares `api 'io.purchasely:core'`, so the app also sees the public API of the native Android SDK. `sdk_public_doc.md` is a reference, not the full list. |
| Hybrid bridge, JS side | `src/` except `__tests__/` and `__mocks__/`: `index.ts`, `startBuilder.ts`, `presentation.ts`, `interceptor.ts`, `events.ts`, `redemption.ts`, `components/PLYPresentationView.tsx` |
| Hybrid bridge, iOS side | `ios/PurchaselyRN.h`, `ios/PurchaselyRN.m`, `ios/PurchaselyView.swift`, `ios/PurchaselyViewManager.m`, `ios/PurchaselyViewManager.swift`, `ios/PLYTransitionFactory.swift`, `ios/Classes/Hybrid/`, `ios/react-native-purchasely-Bridging-Header.h` |
| Hybrid bridge, Android side | `android/src/main/java/com/reactnativepurchasely/`, `android/src/main/res/`, and the `android/src/` folders of `packages/google`, `packages/amazon`, `packages/huawei` and `packages/android-player` |
| Purchase and restore | the purchase, restore and interceptor code in `src/index.ts`, `src/interceptor.ts`, `ios/PurchaselyRN.m`, `ios/PurchaselyView.swift`, `PurchaselyModule.kt`. Also the store modules: `packages/google/android/`, `packages/amazon/android/`, `packages/huawei/android/` |
| User identity, start, deeplinks, consent, user attributes, events | `src/index.ts`, `src/startBuilder.ts`, `ios/PurchaselyRN.m`, `PurchaselyModule.kt` |
| Native SDK version in a bridge | `react-native-purchasely.podspec` (`s.dependency "Purchasely"`); the five `packages/*/android/build.gradle` (`io.purchasely:core`, `google-play`, `amazon`, `huawei-services`, `player`); `example/ios/Podfile.lock`. Record the versions in `VERSIONS.md` and in the version table of `AGENTS.md`. This repo has no `Package.swift`, no `plugin.xml` and no Gradle lockfile. The `purchaselyVersion` constant in `src/index.ts` is the bridge version, not a native pin. |
| Build compatibility | `android/build.gradle` (minSdk 23, Java 11), `android/gradle.properties` (Kotlin, compile and target SDK), `react-native-purchasely.podspec` (iOS 15.1), `peerDependencies` of each `package.json`, `.nvmrc`, `yarn.lock` |
| Consumer rules, library manifest | `android/consumer-rules.pro`, the `android/src/main/AndroidManifest.xml` of the five packages |
| Sample app UI | `example/src/` screens, except `E2ETestRunner.tsx` |
| Sample app configuration | `example/src/App.tsx` (Builder options, stores, running mode), `example/android/app/build.gradle` (application id `com.purchasely.demo`), `example/ios/example.xcodeproj` (bundle id), `example/ios/Podfile`, `example/ios/example/Info.plist`, `example/ios/example/PrivacyInfo.xcprivacy`, `test-projects/` (see its `CLAUDE.md`) |
| Tests | `src/__tests__/`, `src/__mocks__/`, `ios/PurchaselyTests/`, `android/src/test/`, `integration_test/`, `example/src/E2ETestRunner.tsx` |
| CI | `.github/workflows/ci.yml`, `e2e-android.yml`, `e2e-ios.yml`, `cache-cleanup.yml`, `.github/actions/setup/action.yml` |
| Generated or rewritten files | `prepare.sh` and `publish.sh` rewrite the versions of the five `package.json` and the `purchaselyVersion` constant |
| Publication | `.github/workflows/publish.yml`, `publish.sh`, `prepare.sh`, the `files` and `react-native-builder-bob` blocks of each `package.json` |
| Process docs | `AGENTS.md`, `REVIEW.md`, `RELEASE.md`, `CONTRIBUTING.md`, `VERSIONS.md`, `MIGRATION-v6.md`, `sdk_public_doc.md`, `.github/pull_request_template.md` |

Publication: npm, five packages (`react-native-purchasely` and
`@purchasely/react-native-purchasely-{google,amazon,huawei,android-player}`). A published GitHub
release starts `publish.yml`, also `workflow_dispatch`. It runs `ci.yml`, checks that the five
versions match the tag, sets the npm dist-tag from the tag, and publishes with `--provenance`.
`publish.sh` publishes by hand with no `--tag` and no `--provenance`: it can move `latest` to a
maintenance release. Use `publish.yml`.

### Checks of this repo

- **CI on the head commit:** `ci.yml` runs when the PR opens, reopens or leaves draft. A push to
  the PR does not start it. After each push, add the `run-ci` label
  (`gh pr edit <n> --add-label run-ci`). The run removes it. On a PR from a fork or from
  Dependabot, remove the label by hand before you add it again.
- **Jobs of `ci.yml`:** `lint` (lint, typecheck, build, example typecheck and lint), `test`
  (Jest), `build-android` (example build and the Android JUnit suite), `build-ios`,
  `iOS Build (use_frameworks!)`, `iOS Unit Tests (bridge)`, `build-rn-0-86-android`,
  `build-rn-0-86-ios`. `main` has no required check, so GitHub does not block the merge. The
  person who merges reads the checks of the head commit.
- **E2E:** `e2e-android.yml` and `e2e-ios.yml` run on a real device against the real backend.
  They run only when the PR changes a path of their `paths:` list. On such a PR, `run-ci` also
  starts them again. They never gate `publish.yml`. Scenarios: `integration_test/E2E_TEST_INDEX.md`.
- **Public API:** no check in CI. The platform reviewer reads the diff of the exports of
  `src/`. For a packaging change, run `yarn all:prepare`, then `npm publish --dry-run` in each
  package.
- **Release checklist:** `RELEASE.md`. It waits for the `ci.yml` checks. This repo has no
  release test plan file. The E2E suites run on demand (`workflow_dispatch`), and
  `integration_test/E2E_TEST_INDEX.md` lists their scenarios.
- **The PR also has:** for a new or changed public method, type, component or listener: Jest
  tests, both native bridge test suites, and iOS and Android at parity. For a native SDK bump:
  all native pins at the same version, `VERSIONS.md` and the version table of `AGENTS.md`.
  `yarn test && yarn lint && yarn typecheck` pass. For a workflow change, the YAML validation
  of `AGENTS.md`.

Section 5 of the other repos:
<https://github.com/Purchasely/Purchasely-Android-Sources/blob/develop/REVIEW.md>.

### Not in place yet

- A `CODEOWNERS` file that requests the right reviewers for the T2 and T3 paths. Until then,
  the author requests them.
- A public API check in CI (a report of the exported declarations, compared on each PR).
- Labels `tier:T0` to `tier:T3`. Until then, the tier is in the PR body.
- A release test plan file for each version, for the "Before release" column of section 1.
- Required checks on `main`. Today `main` needs one approval and has no required check. It
  also lets admins bypass the rules, allows force pushes, and does not require resolved
  conversations or dismiss stale approvals.
