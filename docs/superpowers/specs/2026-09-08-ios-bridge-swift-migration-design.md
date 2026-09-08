# Design — Migrate the iOS native bridge from Objective-C to Swift

**Created:** 2026-09-08
**Status:** design, waiting for review
**Scope:** `packages/purchasely/ios/` only. No JavaScript API change, no Android change.

---

## 1. Goal

Make the iOS half of the React Native bridge Swift, for three reasons the user
stated:

1. **Maintainability.** `PurchaselyRN.m` is 2086 lines of Objective-C with 63
   exported methods, file-scope mutable statics and 13 static C functions. Swift
   gives optionals, exhaustive `switch` over the SDK enums, and no header to keep
   in sync.
2. **Language alignment.** The native iOS SDK is Swift. The Flutter bridge is
   Swift. `PurchaselyView.swift`, `PurchaselyViewManager.swift` and
   `PLYTransitionFactory.swift` in this repo are already Swift. Only the main
   module is not.
3. **Reach the full SDK API.** The Objective-C bridge sees the SDK only through
   its generated `Purchasely-Swift.h`, so it sees only the `@objc` surface.
   `PLYTransitionFactory.swift` exists exactly because of that limit: its own
   header comment says `PurchaselyRN.m` cannot construct a `PLYTransition`.
   A Swift module removes the whole class of workaround.

### Non-goals

- No TurboModule migration. Section 11 gives the analysis and the reason.
- No change to the JavaScript API, the exported constants, the event names or
  the dictionary keys the JS layer reads.
- No change to `PurchaselyView.swift`, `PurchaselyViewManager.swift` or
  `PLYTransitionFactory.swift`, apart from 5 call sites (section 6).
- No Android change, no Flutter change, no documentation-repo change.

---

## 2. Current state, with evidence

| Item | Value | Evidence |
|---|---|---|
| Main module | `ios/PurchaselyRN.m`, 2086 lines | `wc -l` |
| Exported methods | 63 | `rg -c 'RCT_EXPORT_METHOD\|RCT_REMAP_METHOD'` |
| JS module name | `Purchasely`, on class `PurchaselyRN` | `RCT_EXPORT_MODULE(Purchasely);` at line 360 |
| Exported constants | 34 keys | `constantsToExport` at line 471 |
| Exported events | 11 names | `supportedEvents` at line 1298 |
| Delegates | `PLYEventDelegate`, `PLYUserAttributeDelegate`, `PLYWebRedemptionDelegate` | `PurchaselyRN.h` |
| Serialization | 14 files, 540 lines, 7 Objective-C categories | `ios/Classes/Hybrid/` |
| File-scope statics | 4 collections plus a `dispatch_once` initializer, 1 static emitter | lines 40–71 |
| Static C functions | 13 | `rg '^static [a-zA-Z].*\(.*\) \{'` |
| `dispatch_async(main)` calls | about 40 | `rg -c 'dispatch_async'` |
| Blocking primitives | none | no `dispatch_semaphore`, no `group_wait`, no `dispatch_sync` |
| Architecture | legacy bridge on the New Architecture interop layer | `codegenConfig: null`; `React/Fabric/.../LegacyViewManagerInterop/` present in RN 0.86 |
| Already Swift | `PurchaselyView.swift` (318), `PurchaselyViewManager.swift` (27), `PLYTransitionFactory.swift` (57) | `wc -l` |
| Tests | `PurchaselyRNTests.m` (Objective-C, 330), `PurchaselyViewTests.swift` (265, `@testable import react_native_purchasely`) | `ios/PurchaselyTests/` |

### The load-bearing build fact

The pod's Swift files see `RCTEventEmitter` and `RCTViewManager` with only
`import Foundation`. The reason is in the generated
`react-native-purchasely.debug.xcconfig`:

```
OTHER_SWIFT_FLAGS = $(inherited) -D COCOAPODS -import-underlying-module \
  -Xcc -fmodule-map-file="${SRCROOT}/${MODULEMAP_FILE}" ...
```

`-import-underlying-module` exposes the pod's generated umbrella header to the
pod's own Swift files. The umbrella imports every `ios/*.h`, and
`ios/react-native-purchasely-Bridging-Header.h` is the file that imports
`RCTBridgeModule.h`, `RCTEventEmitter.h`, `RCTViewManager.h` and
`RCTComponent.h`.

**Consequence:** that file is not dead code despite its misleading name (no
target sets `SWIFT_OBJC_BRIDGING_HEADER` for this pod). It must stay, and it
must keep importing the React headers. If it is deleted, every Swift file in the
pod loses the React types and the build fails in a way that points at the wrong
file.

---

## 3. The React Native constraints that shape the design

These are the platform facts, verified in `example/node_modules/react-native`
at 0.86.0. They are the reason the migration is not a mechanical translation.

1. **A Swift native module still needs an Objective-C shim.** React Native
   discovers legacy modules through class methods named `__rct_export__*`, which
   the `RCT_EXPORT_METHOD` and `RCT_EXTERN_METHOD` macros generate. Swift cannot
   emit those. So a Swift module needs a `.m` file with
   `RCT_EXTERN_REMAP_MODULE(...)` plus one `RCT_EXTERN_METHOD(...)` per exported
   method. `ios/PurchaselyViewManager.m` is the existing example of this pattern
   in the repo.
2. **The shim is parsed as text, not linked.** `RCTModuleMethod` parses the
   selector string at registration and resolves it on the class
   (`RCTModuleMethod.h` exposes `moduleClass` and `selector`). A mismatch between
   a shim line and its Swift `@objc` signature produces **no compile error**. It
   fails at run time in the client app. This is the single largest risk of the
   project, and section 7 is the gate for it.
3. **The exported name is a contract.** `RCT_EXPORT_MODULE(Purchasely)` gives the
   JS name `Purchasely` on class `PurchaselyRN`, so the shim needs
   `RCT_EXTERN_REMAP_MODULE(Purchasely, PurchaselyRN, RCTEventEmitter)`. The
   plain `RCT_EXTERN_MODULE` form would rename the module to `PurchaselyRN` and
   break every JS call.
4. **One class per exported module name, at every commit.** Two classes
   registering the same name is what froze the whole process in commit
   `81c5a65`. No phase of this migration may have an Objective-C `PurchaselyRN`
   and a Swift `PurchaselyRN` registered together.
5. **`RCTEventEmitter` overrides.** In Swift: `override func supportedEvents() ->
   [String]!`, `override func constantsToExport() -> [AnyHashable: Any]!`,
   `override static func requiresMainQueueSetup() -> Bool`, plus
   `startObserving`/`stopObserving`. The existing `shouldEmit` gate must be kept:
   `sendEvent` before `startObserving` logs a React Native warning.
6. **iOS codegen emits Objective-C++ only.**
   `@react-native/codegen/lib/generators/modules/` contains `GenerateModuleObjCpp`
   and has no Swift generator. So a TurboModule always keeps an Objective-C++
   adapter file. This is why a TurboModule does not serve goal 2.

---

## 4. Approach

**Chosen: one Swift class, split by domain, plus a shim.**

`@objc(PurchaselyRN) class PurchaselyRN: RCTEventEmitter`, split into 5 files
with one `extension` per domain. `PurchaselyRN.m` keeps its name and its place
but drops to about 70 lines with no logic. The 7 Hybrid categories become Swift
extensions on the SDK model types.

Reasons: it reuses the pattern already proven in this repo
(`PurchaselyViewManager.swift` plus a 20-line `.m`); it adds no abstraction; and
each resulting file is small enough to read and to review in one pass.

**Rejected: one single `PurchaselyRN.swift` of about 2000 lines.** Fewer files,
but a file that size is not reviewable and not reliable to edit.

**Rejected: a plain-Swift core plus a thin `@objc` bridge layer.** It would be
ready for a TurboModule and testable without `@objc` seams, but it needs about
126 declarations instead of 63 — one core function and one bridge function per
method. The TurboModule decision is deferred, so the layer serves nothing today.

**Rejected: port one method at a time.** It needs 63 temporary `@objc`
boundaries and it breaks constraint 4 above.

---

## 5. Target file layout

| File | After |
|---|---|
| `ios/PurchaselyRN.m` | Kept. Shim only: the remap module macro and 63 `RCT_EXTERN_METHOD` lines. |
| `ios/PurchaselyRN.h` | **Deleted.** No host app imports it (`rg PurchaselyRN` finds no reference in `example/ios` or `test-projects`), and its React imports are covered by the bridging-header file. |
| `ios/PurchaselyRN.swift` | New. The class, the statics, `constantsToExport`, `supportedEvents`, `startObserving`/`stopObserving`, `requiresMainQueueSetup`, the 3 delegates, the `reject(_:with:)` helper. |
| `ios/PurchaselyRN+Attributes.swift` | New. The 20 attribute methods, the built-in attributes, the legal-basis mapper (currently line 705). |
| `ios/PurchaselyRN+Products.swift` | New. `allProducts`, `productWithIdentifier`, `planWithIdentifier`, `userSubscriptions`, `userSubscriptionsHistory`, purchase, restore, synchronize, offerings, `signPromotionalOffer`, `isEligibleForIntroOffer`. |
| `ios/PurchaselyRN+Presentations.swift` | New. `preloadPresentation`, `displayPresentation`, `closePresentation`, `goBackToPreviousScreen`, `closeAllScreens`, the default dismiss handler, the BYOS methods, and the 5 static helpers `PurchaselyView.swift` calls. |
| `ios/PurchaselyRN+Interceptors.swift` | New. `registerActionInterceptor`, `unregisterActionInterceptor`, `completeActionInterceptor`, the 30-second timeout. |
| `ios/Serialization/PLYPlan+Bridge.swift` | New, from `PLYPlan+Hybrid.m` (145 lines, the largest). |
| `ios/Serialization/PLYProduct+Bridge.swift` | New, from `PLYProduct+Hybrid.m`. |
| `ios/Serialization/PLYSubscription+Bridge.swift` | New, from `PLYSubscription+Hybrid.m`. |
| `ios/Serialization/PLYOfferSignature+Bridge.swift` | New, from `PLYOfferSignature+Hybrid.m`. |
| `ios/Serialization/PLYPresentationPlan+Bridge.swift` | New, from `PLYPresentationPlan+Hybrid.m`. |
| `ios/Serialization/UIColor+PLYHex.swift` | New, from `UIColor+PLYHelper.m` (66 lines). |
| `ios/Serialization/UIViewController+PLYClose.swift` | New, from `UIViewController+Hybrid.m` (16 lines). |
| `ios/Classes/Hybrid/` | **Deleted**, all 14 files, `Purchasely_Hybrid.h` included. |
| `ios/react-native-purchasely-Bridging-Header.h` | Kept, plus a comment that states section 2's build fact so nobody deletes it. |
| `ios/Purchasely.xcodeproj` | **Deleted.** A leftover: no CI job and no `pod install` reads it, and it still lists `PurchaselyRN.m` and a `Purchasely-Bridging-Header.h` that does not exist. It becomes wrong the moment phase 2 lands. |
| `ios/PurchaselyViewManager.m`, `PurchaselyViewManager.swift`, `PurchaselyView.swift`, `PLYTransitionFactory.swift` | Not touched. |
| `packages/purchasely/react-native-purchasely.podspec` | One line: `s.swift_versions = ['5.0']`. `source_files` already covers `*.swift`, and the test spec already covers `**/*.swift`. |

`PLYTransitionFactory.swift` deserves a note. It exists only so the Objective-C
file can build a `PLYTransition`. After phase 2 it is dead weight, and its
`#if __has_include(<react_native_purchasely/react_native_purchasely-Swift.h>)`
dance in `PurchaselyRN.m` disappears with it. **Decision:** phase 2 folds it
into `PurchaselyRN+Presentations.swift` and deletes the file, because leaving it
keeps a workaround for a problem that no longer exists. It is 57 lines and it has
no external consumer (`rg PLYTransitionFactory` finds only itself and
`PurchaselyRN.m`).

---

## 6. Call sites to update outside the new files

`PurchaselyView.swift` calls 5 static members of `PurchaselyRN`. Four of them
carry an `NS_SWIFT_NAME` alias in `PurchaselyRN.h`; the fifth is auto-translated
by the Swift importer. Both mechanisms disappear with the header, so the 5 Swift
declarations must be written to keep the exact names the call sites use:

| Line | Call site, unchanged | Required Swift declaration |
|---|---|---|
| 110 | `emitEmbeddedPresentationViewed(forRequestId:placementId:)` | `static func emitEmbeddedPresentationViewed(forRequestId requestId: String?, placementId: String?)` |
| 216 | `loadedPresentation(forRequestId:)` | `static func loadedPresentation(forRequestId requestId: String) -> (any PLYPresentation)?` |
| 229 | `takeLoadedPresentation(matchingScreenId:placementId:)` | `static func takeLoadedPresentation(matchingScreenId: String?, placementId: String?) -> (any PLYPresentation)?` |
| 237, 257 | `emitPresentationDismissed(forId:outcome:)` | `static func emitPresentationDismissed(forId routingId: String, outcome: PLYPresentationOutcome)` |
| 297 | `evictPresentationRequest(_:)` | `static func evictPresentationRequest(_ requestId: String?)` |

**Target: zero diff in `PurchaselyView.swift`.** Choose the external parameter
labels above and no call site moves. These 5 members stay `static` and become
`internal`, not `@objc`, and they are not in the shim: they are Swift-to-Swift
calls, not exported methods. `PurchaselyViewTests.swift` reaches them through
`@testable import` without change.

`PurchaselyViewTests.swift` uses `@testable import react_native_purchasely`, so
it reaches `internal` members without change.

---

## 7. The shim parity gate

The failure mode: a shim line and a Swift signature disagree, nothing complains
at build time, and the client app throws "method not found" at run time.

**Primary gate — an XCTest that runs React Native's own validator.**

React Native resolves each exported method by scanning the class metaclass for
methods named `__rct_export__*`, calling each to get an `RCTMethodInfo`, and
building an `RCTModuleMethod`. `RCTModuleMethod` resolves the selector on the
class and asserts when it does not exist. So the test does not need to parse
anything:

1. `class_copyMethodList` on `object_getClass(PurchaselyRN.self)`.
2. Keep the selectors whose name begins with `__rct_export__`.
3. For each, call it to obtain the `RCTMethodInfo *`, then
   `RCTModuleMethod(exportedMethod:moduleClass:)`.
4. Assert the count equals the expected number of exported methods, and read
   `.selector` on each. React Native raises when a selector is missing.

This converts all 63 runtime risks into one CI failure, and it also catches a
method dropped from the shim (through the count assertion).

**Risk on the gate itself:** `RCTModuleMethod.h` lives in `React/Base/` and must
be importable. If `import React` does not expose it to Swift, the fallback is a
Node parity script in the existing `yarn test` job: extract the selectors from
`RCT_EXTERN_METHOD(...)` in the shim, extract the `@objc func` signatures from
the Swift files, and compare the sets. Text parsing is more fragile, so it is the
fallback and not the first choice. Phase 2 must prove one of the two works before
the port is called done.

**Second gate — the JS side.** A Jest test that asserts the set of method names
`src/` calls on `NativeModules.Purchasely` is a subset of the shim's exported
names. This catches the opposite error: a method that the port silently dropped.

---

## 8. Translation rules

### 8.1 State and concurrency

| Today | After | Why |
|---|---|---|
| 4 file-scope statics built in `ensurePresentationState()` through `dispatch_once` | `private static var` on the class | Swift initializes a static lazily, exactly once, thread-safely. `dispatch_once` and the initializer function disappear. |
| `@synchronized(kPresentationStateLock)` | one `private static let stateLock = NSLock()`, `lock()` with `defer { unlock() }` | Project rule: `NSLock` for state. Never a serial queue as a mutex. |
| 30-second interceptor timeout | `DispatchQueue.main.asyncAfter` | Unchanged shape. |
| about 40 `dispatch_async(dispatch_get_main_queue(), ^{...})` | `DispatchQueue.main.async { ... }` | Stays `async`. Do not convert to `sync`. Do not convert to `await` in this migration: `await` changes when the SDK call runs relative to its caller. |
| Objective-C blocks capturing `self` strongly | `[weak self]` then `guard let self else { ... }` | The `else` branch must still settle the promise exactly once. `guard let self else { resolve(nil); return }`, never a silent `return`, or the JS promise hangs forever. |
| 0 blocking primitives | 0 blocking primitives | Hard project rule. No `DispatchSemaphore`, no `group.wait()`, no `RunLoop.run(until:)`. `iOS/.swiftlint.yml` in the native repo makes these errors; this repo has no SwiftLint, so review enforces it. |

### 8.2 The 13 static C functions

They become `private` static functions or small extensions:

- `stringFromPresentationAction`, `presentationActionFromString`,
  `stringFromWebCheckoutProvider`, `purchaseResultOrdinal`,
  `closeReasonToRNString`, `runningModeFromOrdinal` become `extension` members
  on the corresponding SDK enum, or private functions when the enum is not
  extensible. Every `switch` becomes exhaustive with no `default`, so a new SDK
  case fails the build instead of falling through silently. **This is a real
  behavior improvement and also a real risk: an SDK minor bump can then break
  the build.** Accepted, because a silent wrong string is worse.
- `presentationToMap`, `presentationErrorToMap`, `loadedClientPresentationForMap`
  become private functions in `PurchaselyRN+Presentations.swift`.
- `applyPresentationDisplayOptions`, `plyParseDimensionMap`,
  `plyTransitionFromMap` become private functions; `plyTransitionFromMap` calls
  the SDK's Swift API directly and replaces `PLYTransitionFactory`.
- `extractPresentationTargets:toPlacement:toPresentation:toContentId:toIsDefault:`
  uses four `__autoreleasing` out-parameters. It becomes a function that returns
  a small private `struct PresentationTargets`.
- `ensurePresentationState` disappears (see 8.1).

### 8.3 Serialization

Each `- (NSDictionary *)asDictionary` becomes a computed property in a Swift
extension. Keep the ability to test them: they stay `internal`, reachable from
`@testable import`.

Two named traps:

- `NSNull`. The Objective-C code writes `[NSNull null]` for an absent value, and
  the JS layer reads `null`. Swift's `[String: Any]` with a `nil` value drops the
  key instead, and the JS layer then reads `undefined`. `types.ts` documents
  nullable subscription fields, and commit `194b1a0` was about exactly that. So
  every optional must map explicitly to `NSNull()`, not to `nil`. Test it.
- Number types. Objective-C `@(intValue)` and Swift `NSNumber(value:)` must
  produce the same JS type. An `Int` where the JS layer expects a float is
  invisible until a client reads it.

The `PLYPlan` category also has `- (void)isEligibleForIntroductoryOffer:(void
(^)(BOOL))completion`, which is behavior and not serialization. It moves with the
plan extension.

---

## 9. Contract that must not change

Any change here is a breaking change for client apps, so each item gets a test
or an explicit check:

1. The JS module name `Purchasely`.
2. The 63 exported method names and their argument counts.
3. The 34 `constantsToExport` keys and their numeric values. `enums.ts` and
   `types.ts` consume them.
4. The 11 `supportedEvents` names.
5. Every dictionary key that any `asDictionary` produces.
6. The promise semantics: `display()` resolves at dismiss, not at trigger. The
   5-field outcome (`presentation`, `purchaseResult`, `plan`, `closeReason`,
   `error`). The `NSNull` policy of the web-redemption body.
7. `requiresMainQueueSetup` keeps its current value. Do not "clean it up".
   `PurchaselyViewManager.swift` documents why the view manager returns `false`.

---

## 10. Tests and CI

### Tests

- `PurchaselyRNTests.m` → `PurchaselyRNTests.swift`, XCTest with `@testable
  import react_native_purchasely`. **XCTest, not Swift Testing:** a CocoaPods test
  spec requires `XCTestCase`. The tested helpers then need neither `@objc` nor a
  public header, which is the point of the port.
- New: the shim parity test of section 7.
- New: dictionary-key snapshot tests for the 7 serializers, asserting the key
  set and the `NSNull` policy. These do not exist today and they are the only
  thing that can catch a silent serialization regression.
- `PurchaselyViewTests.swift`: unchanged.
- **Jest catches nothing here.** `src/__mocks__/testUtils.ts` mocks the native
  module, so the TypeScript suite passes even with a fully broken bridge. Do not
  read a green `yarn test` as evidence for this work.

### CI jobs that gate it

| Job | What it proves |
|---|---|
| `build-ios` | The pod compiles, static-library linkage |
| `build-rn-0-86-ios` | Compiles against the supported RN version |
| `iOS Build (use_frameworks!)` | Compiles under dynamic-framework linkage. Both linkages matter, and Swift-majority pods behave differently under each. |
| `iOS Unit Tests (bridge)` | The XCTest bundle, the parity gate included |
| `e2e-ios.yml` | Triggers on `packages/purchasely/ios/**`, so both PRs run T1–T27 on a simulator. This is the only gate that exercises the real JS-to-native path. |

The E2E suite is the acceptance criterion for phase 2. A green build proves
nothing about a text-parsed shim.

---

## 11. Why not a TurboModule now

Analysed and deferred, on purpose.

**What it would give clients:** compile-time safety on the 63 methods through
codegen; lazy module initialization; direct JSI calls with no JSON serialization
(not measurable here, paywall calls are not a hot path); and protection against
the eventual removal of the legacy architecture.

**What it would cost clients:**

1. A TurboModule needs the New Architecture. Every client still on the legacy
   architecture loses the SDK. `peerDependencies` says `react-native: *`.
2. Codegen accepts a restricted type set. The bridge returns rich dictionaries
   (`PLYPlan`, `PLYSubscription`, the 5-field outcome). They degrade to a plain
   `Object`, or each one needs a full spec to write and to maintain.
3. On iOS, codegen emits Objective-C++ only, so a Swift TurboModule keeps a
   `.mm` adapter. **A TurboModule does not remove Objective-C from this
   project.** It moves it.

So the two projects are separate: this one is a code-quality change with no
client-visible effect, and a TurboModule is a supported-version decision that
needs its own release and its own communication.

**What this design does for it anyway:** splitting the Swift code by domain keeps
the exported surface thin. A later TurboModule replaces the shim and the `@objc`
signatures, and keeps the SDK calls, the serialization and the event emission
unchanged. No speculative abstraction is added for it today.

---

## 12. Delivery

Two phases, two pull requests, each green on CI and E2E on its own.

**Phase 1 — serialization.** The 7 Hybrid categories become Swift extensions,
540 lines out, `ios/Classes/Hybrid/` deleted. `PurchaselyRN.m` keeps its logic
and calls the new Swift extensions through the generated
`react_native_purchasely-Swift.h`, exactly as it already calls
`PLYTransitionFactory`. This means the extension members that Objective-C calls
must be `@objc` for the duration of phase 1, and phase 2 removes those
annotations.

Locked by: the new key-set snapshot tests, written **before** the port, against
the current Objective-C output. That is the whole safety of phase 1.

Two mechanics of phase 1, both temporary:

- The Swift extension members that `PurchaselyRN.m` calls must be `@objc` for
  the duration of phase 1, and phase 2 removes those annotations. A Swift
  extension on an imported `@objc` class is exported to Objective-C as a
  category, which is how the existing `PLYTransitionFactory` already reaches
  `PurchaselyRN.m`.
- `UIViewController+Hybrid.m` adds a `-close` selector to every view controller
  in the host app. The Swift extension keeps the same selector, so the collision
  risk is unchanged, not new. It is still worth renaming to `plyClose` in phase
  2, when no Objective-C caller remains: it is a category on a UIKit class in a
  library, which is exactly the pattern that breaks a host app one SDK release
  later.

Risk: low. No bridge contract is touched, no exported method moves.

**Phase 2 — the module.** `PurchaselyRN.m` becomes a shim,
`PurchaselyRN.h` is deleted, the 5 Swift files appear, `PLYTransitionFactory` and
`Purchasely.xcodeproj` are deleted, the tests are ported, the parity gate lands.

Risk: high, and concentrated in the shim. The parity gate plus E2E is the answer.

**Release vehicle:** both in one minor version, `6.2.0`, not in a `6.1.x` patch.
There is no client-visible feature, but the whole native layer of one platform
changes, and a patch version does not signal that.

**One rule across the two phases:** never two classes registered as the JS module
`Purchasely` at the same time (constraint 4 of section 3).

---

## 13. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| A shim line disagrees with its Swift signature | High. Runtime failure in a client app. | The parity gate of section 7, plus E2E T1–T27 |
| An optional serializes to a dropped key instead of `NSNull` | High. Silent, client-visible. | Key-set snapshot tests written before phase 1 |
| `react-native-purchasely-Bridging-Header.h` gets deleted as "dead" | High. The build breaks with a misleading message. | Keep it, comment it, state it in `CLAUDE.md` |
| Two modules registered under the same JS name | High. Full process freeze, as in `81c5a65`. | One rule, stated in section 12 |
| An exhaustive `switch` breaks the build on an SDK bump | Medium. Build-time, visible. | Accepted on purpose. A silent wrong string is worse. |
| `RCTModuleMethod.h` is not importable from Swift | Medium. It removes the primary gate. | The Node parity script fallback, section 7 |
| `[weak self]` drops a promise that Objective-C used to settle | Medium. A hanging JS promise. | The `guard let self else { settle }` rule of 8.1 |
| A number changes its JS type | Low, but client-visible. | Covered by the snapshot tests |

---

## 14. Definition of done

1. `fd -e m -e h . packages/purchasely/ios` lists exactly 3 files:
   `PurchaselyRN.m` (shim), `PurchaselyViewManager.m` (shim), and
   `react-native-purchasely-Bridging-Header.h`.
2. The 4 iOS CI jobs are green, both linkages included.
3. `e2e-ios.yml` T1–T27 is green.
4. The parity gate exists and fails when a shim line is removed. Proven by
   removing one line locally.
5. `CLAUDE.md` names the new files, in its 8 places that name the old ones.
6. No `DispatchSemaphore`, no `wait`, no `dispatch_sync` anywhere in
   `packages/purchasely/ios/`.
