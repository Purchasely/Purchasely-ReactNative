# Design — Migrate the iOS native bridge from Objective-C to Swift

**Created:** 2026-09-08
**Reviewed:** 2026-09-08 (adversarial review by two models; every count and claim
below was re-verified against the code after that review)
**Status:** implemented (`feat/ios-swift-bridge-spec`, PR #298)
**Scope:** `packages/purchasely/ios/` only. No JavaScript API change, no Android
change.

---

## 1. Goal

Make the iOS half of the React Native bridge Swift.

1. **Maintainability.** `PurchaselyRN.m` is 2086 lines of Objective-C with 63
   exported methods, file-scope mutable statics and 13 static C functions. Swift
   gives optionals, `switch` over the SDK enums, and no header to keep in sync.
2. **Language alignment.** The native iOS SDK is Swift. The Flutter bridge is
   Swift. `PurchaselyView.swift`, `PurchaselyViewManager.swift` and
   `PLYTransitionFactory.swift` in this repo are already Swift. Only the main
   module is not.
3. **Remove the `@objc`-only limit on the SDK API.** Precisely: the Objective-C
   bridge sees the SDK through its generated `Purchasely-Swift.h`, so it sees
   only the `@objc` surface. Swift removes that limit. It does **not** remove the
   `public`-only limit. Verified against the framework's plain
   `arm64-apple-ios-simulator.swiftinterface`: `PLYPromoOffer` exposes only
   `vendorId` and `storeOfferId`, so the two gaps the bridge documents at
   `PurchaselyRN.m:1992` and `PLYPlan+Hybrid.m:52-60` stay closed in Swift too.
   What Swift genuinely unlocks, all `public` and non-`@objc` in that file:
   `PLYTransition.init(type:height:width:...)` (line 994), its `drawer(height:)`
   and `popin(width:height:)` factories (1009-1010), the `PLYDimension` enum
   (1150), and `PLYPresentationBuilder.from(screenId:)` (756). The first is the
   entire reason `PLYTransitionFactory.swift` exists.

### Non-goals

- No TurboModule migration. Section 11 gives the analysis and the reason.
- No change to the JavaScript API, the exported constants, the event names, or
  the dictionary keys the JS layer reads.
- No change to `PurchaselyView.swift` or `PurchaselyViewManager.{m,swift}`.
- No Android change, no Flutter change, no documentation-repo change.

---

## 2. Current state, with evidence

Every number here was re-counted after review. The first draft had six wrong.

| Item | Value | Evidence |
|---|---|---|
| Main module | `ios/PurchaselyRN.m`, 2086 lines | `wc -l` |
| Exported methods | 63, of which 7 use `RCT_REMAP_METHOD` | lines 694, 869, 935, 955, 1052, 1066, 1111 |
| JS module name | `Purchasely`, on class `PurchaselyRN` | `RCT_EXPORT_MODULE(Purchasely);` line 360 |
| Exported constants | **60 keys** | `constantsToExport`, lines 472–533. `enums.ts:4` builds the JS enums from them. |
| Exported events | 11 names | `supportedEvents` line 1298 |
| Delegates | `PLYEventDelegate`, `PLYUserAttributeDelegate`, `PLYWebRedemptionDelegate` | `PurchaselyRN.h` |
| Serialization | **15 files**, 540 lines, 7 categories plus one aggregate header | `ios/Classes/Hybrid/` |
| File-scope state | 3 collections, 1 lock object, plus `_sharedViewController` and `_sharedEmitter` | lines 43–53, 362–365 |
| Static C functions | 13 in `PurchaselyRN.m`, plus 2 `FOUNDATION_EXPORT` free functions in a Hybrid header | `rg '^static [a-zA-Z].*\(.*\) \{'`; `PLYPlan+Hybrid.h:15-17` |
| `dispatch_async(main)` | **34** | `rg -c 'dispatch_async'` |
| Blocking primitives | none | no `dispatch_semaphore`, no `group_wait`, no `dispatch_sync` |
| Architecture | legacy bridge on the New Architecture interop layer | `codegenConfig: null`; `React/Fabric/.../LegacyViewManagerInterop/` present in RN 0.86 |
| Already Swift | `PurchaselyView.swift` (318), `PurchaselyViewManager.swift` (27), `PLYTransitionFactory.swift` (57) | `wc -l` |
| Tests | `PurchaselyRNTests.m` **535** lines, `PurchaselyViewTests.swift` **785** lines | `wc -l`. `CLAUDE.md` says 330 and 265; `CLAUDE.md` is stale. |
| `CLAUDE.md` references | 9 lines name the files being moved | lines 75, 76, 99, 441, 591, 604, 623, 711, 724 |

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
target sets `SWIFT_OBJC_BRIDGING_HEADER` for this pod). It must stay and it must
keep importing the React headers. If it is deleted, every Swift file in the pod
loses the React types and the build fails pointing at the wrong file.

---

## 3. The React Native constraints that shape the design

Verified in `example/node_modules/react-native` at 0.86.0.

1. **A Swift native module still needs an Objective-C shim.** React Native finds
   legacy modules through class methods named `__rct_export__*`, generated by the
   `RCT_EXPORT_METHOD` and `RCT_EXTERN_METHOD` macros
   (`RCTBridgeModule.h:322-329`). Swift cannot emit those. `PurchaselyViewManager.m`
   is the existing example of the pattern in this repo.
2. **The shim is parsed as text, not linked.** `RCTModuleMethod` parses the
   selector string and resolves it on the class. A mismatch between a shim line
   and its Swift `@objc` signature produces **no compile error**. It fails at run
   time in the client app. Section 7 is the gate.
3. **The JS name is the first selector segment, and there is no public remap
   macro.** `RCTBridgeModule.h:310-323` exports `RCT_EXTERN_METHOD` and
   `RCT_EXTERN__BLOCKING_SYNCHRONOUS_METHOD` only; the remap form is
   `_RCT_EXTERN_REMAP_METHOD`, private by its underscore. So the 7
   `RCT_REMAP_METHOD` sites cannot be transcribed as remaps. **Design rule:** every
   exported Swift method carries an explicit `@objc(selector:)` whose first
   segment equals its JS name. Verified on the 7 sites: 5 already satisfy that
   (`isAnonymous` 694, `userAttribute` 869, `getBuiltInAttribute` 935,
   `getAnonymousUserId` 955, `productWithIdentifier` 1111), so exactly two
   selectors change —
   `restoreAllProducts` becomes `restoreAllProducts:reject:` (today
   `resolve:reject:`, line 1052) and `silentRestoreAllProducts` becomes
   `silentRestoreAllProducts:reject:` (today `silentRestoreWithResolve:reject:`,
   line 1066). A selector is not JS-visible, so this changes nothing for
   clients, and it makes the shim 63 identical `RCT_EXTERN_METHOD` lines.
4. **The module name must be exported once, by one class.** The shim uses
   `RCT_EXTERN_REMAP_MODULE(Purchasely, PurchaselyRN, RCTEventEmitter)`; the
   plain `RCT_EXTERN_MODULE` form would rename the module to `PurchaselyRN` and
   break every JS call. Two classes claiming one name is a failure mode to avoid
   on principle. It is **not** what commit `81c5a65` was: that was a
   main-queue module-holder deadlock, `requiresMainQueueSetup=true` plus a
   concurrent `NativeModules.PurchaselyView` resolution, `dispatch_sync` onto a
   blocked main queue. Which is constraint 7 below, not this one.
5. **Nil reaches a Swift thunk unchecked in a Release build.**
   `RCTModuleMethod.mm:399-457` puts the "must not be null" enforcement inside
   `#if RCT_DEBUG`. A client Release build performs no null check. Objective-C
   tolerates a nil argument today (`PurchaselyRN.m:657`, `:772`, and the
   `isKindOfClass:` guards at `:708`); a Swift `@objc func` with a non-optional
   `String` parameter traps in the bridging thunk. **Design rule:** every
   object-typed parameter of an exported method is declared Optional, whatever
   the shim annotation says. `NSNumber` parameters stay `_Nonnull` in the shim,
   because `RCTModuleMethod.mm:414-431` forces that for `NSNumber`.
6. **`RCTEventEmitter` overrides.** In Swift: `override func supportedEvents() ->
   [String]!`, `override func constantsToExport() -> [AnyHashable: Any]!`,
   `override static func requiresMainQueueSetup() -> Bool`, plus
   `startObserving`/`stopObserving`. `RCTEventEmitter` also exports
   `addListener:` and `removeListeners:` of its own (`RCTEventEmitter.m:96,115`),
   which matters to the gate in section 7. The existing `shouldEmit` gate stays.
7. **`requiresMainQueueSetup` keeps its current value on both classes.** Do not
   "clean it up". `PurchaselyViewManager.swift:11-19` documents why it returns
   `false`, and commit `81c5a65` is the incident.
8. **iOS codegen emits Objective-C++ only.**
   `@react-native/codegen/lib/generators/modules/` contains `GenerateModuleObjCpp`
   and no Swift generator. A TurboModule therefore keeps an Objective-C++ file.

---

## 4. Approach

**Chosen: one Swift class, split by domain, plus a shim.**

`@objc(PurchaselyRN) class PurchaselyRN: RCTEventEmitter`, split into 6 files
with one `extension` per domain. `PurchaselyRN.m` keeps its name and drops to
about 70 lines. The 7 Hybrid categories become Swift extensions.

Reasons: it reuses the pattern already proven in this repo
(`PurchaselyViewManager.swift` plus a 20-line `.m`); it adds no abstraction; each
resulting file is reviewable in one pass.

**Rejected: one 2000-line `PurchaselyRN.swift`.** Not reviewable, not reliable to
edit.

**Rejected: a plain-Swift core plus a thin `@objc` bridge layer.** About 126
declarations instead of 63, to serve a TurboModule decision that is deferred.

**Rejected: port one method at a time.** 63 temporary `@objc` boundaries.

---

## 5. Target file layout

Note the directory: `ios/Classes/Serialization/`, **not** `ios/Serialization/`.
The podspec's `source_files` is `"ios/*.{h,m,mm,swift}",
"ios/Classes/**/*.{h,m,mm,swift}"` (`react-native-purchasely.podspec:19`), so a
new top-level `ios/` subdirectory is not in the pod and the build fails with
unresolved identifiers.

| File | After |
|---|---|
| `ios/PurchaselyRN.m` | Kept. `RCT_EXTERN_REMAP_MODULE` plus 63 `RCT_EXTERN_METHOD` lines, plus one non-variadic log helper (see below). |
| `ios/PurchaselyRN.h` | **Deleted.** No host app imports it, and its React imports are covered by the bridging-header file. |
| `ios/PurchaselyRN.swift` | New. The class, the statics, `constantsToExport` (60 keys), `supportedEvents` (11), `startObserving`/`stopObserving`, `requiresMainQueueSetup`, the 3 delegates. |
| `ios/PurchaselyRN+Lifecycle.swift` | New. `start` and its `NSNotificationCenter` observer (line 638, so the handler keeps `@objc func purchasePerformed()`, called by selector), `userLogin`, `userLogout`, `isAnonymous`, `getAnonymousUserId`, `handleDeeplink`, `readyToOpenDeeplink`, `allowDeeplink`, `allowCampaigns`, `setLanguage`, `setLogLevel`, `setThemeMode`, `setDebugMode`, `userDidConsumeSubscriptionContent`, `revokeDataProcessingConsent` with `mapPurposesFromStrings:` (line 1240), `synchronize`. |
| `ios/PurchaselyRN+Attributes.swift` | New. The 20 attribute methods, the built-in attributes, the legal-basis mapper (line 705). |
| `ios/PurchaselyRN+Products.swift` | New. `allProducts`, `productWithIdentifier`, `planWithIdentifier`, `userSubscriptions`, `userSubscriptionsHistory`, purchase, restore, offerings, `signPromotionalOffer`, `isEligibleForIntroOffer`. |
| `ios/PurchaselyRN+Presentations.swift` | New. Preload, display, close, back, `closeAllScreens`, the default dismiss handler, the BYOS methods, `presentationBuilderFor` (line 206), the transition and dimension parsing that replaces `PLYTransitionFactory`, and the 5 static members `PurchaselyView.swift` calls. |
| `ios/PurchaselyRN+Interceptors.swift` | New. Register, unregister, complete, the 30-second timeout. |
| `ios/Classes/Serialization/PLYPlan+Bridge.swift` | New, from `PLYPlan+Hybrid.m` (145 lines), including the two billing-plan-type mappers as `@objc static` members (see section 12). |
| `ios/Classes/Serialization/PLYProduct+Bridge.swift` | New |
| `ios/Classes/Serialization/PLYSubscription+Bridge.swift` | New |
| `ios/Classes/Serialization/PLYOfferSignature+Bridge.swift` | New |
| `ios/Classes/Serialization/PLYPresentationPlan+Bridge.swift` | New |
| `ios/Classes/Serialization/UIColor+PLYHex.swift` | New, from `UIColor+PLYHelper.m` (66 lines). A hex parser, not a serializer. |
| `ios/Classes/Hybrid/` | **Deleted**, all 15 files. |
| `ios/Classes/Hybrid/UIViewController+Hybrid.{h,m}` | **Deleted, not ported.** It has no caller: `PurchaselyRN.m:1822` `[presentation close]` is the `PLYPresentation` protocol method, not this category. A UIKit category shipped in a library that adds a `-close` selector to every view controller in the host app is a liability with no user. Its tests go with it. |
| `ios/react-native-purchasely-Bridging-Header.h` | Kept, plus a comment carrying section 2's build fact so nobody deletes it. |
| `ios/PLYTransitionFactory.swift` | **Deleted.** Its only reason was that Objective-C cannot build a `PLYTransition`; its only consumer is `PurchaselyRN.m`. Its logic folds into `+Presentations.swift`, and the `#if __has_include(<react_native_purchasely/...-Swift.h>)` block in `PurchaselyRN.m` goes with it. |
| `ios/Purchasely.xcodeproj` | **Deleted.** No CI job and no `pod install` reads it, and it still lists `PurchaselyRN.m` and a `Purchasely-Bridging-Header.h` that does not exist. |
| `ios/PurchaselyViewManager.m`, `PurchaselyViewManager.swift`, `PurchaselyView.swift` | Not touched. |
| `react-native-purchasely.podspec` | One line: `s.swift_versions = ['5.0']`. `source_files` already covers `ios/Classes/**`. |

**The log helper.** `PurchaselyRN.m` has 11 `RCTLogWarn` / `NSLog` calls (lines
317, 579, 605, 779, 1275, 1842, 1881, 1892, 1907, 1956, 2057). `RCTLogWarn` is a
variadic macro (`RCTLog.h:37`) over the variadic C function
`_RCTLogNativeInternal` (`RCTLog.h:152`), and Swift imports neither. So the shim
keeps one non-variadic function, `void PLYRNLogWarn(NSString *message)`, that
calls `RCTLogWarn(@"%@", message)`. This is the one exception to "no logic in the
shim".

**Three members to delete, not port.** All three are provably dead: their only
readers are the tests.

| Member | Evidence |
|---|---|
| `sharedViewController` (class property) | `PurchaselyRN.m:362-376` is its whole accessor. No caller in the module. Only `PurchaselyRNTests.m` reads it. |
| `shouldReopenPaywall` | Written `NO` once at line 464. Never read. |
| `presentedPresentationViewController` | Written at 1692 and 1810. Never read. |

Deleting them removes the trickiest ownership question of the port (a mutable
class-wide storage whose getter re-creates a controller after its setter receives
nil) instead of translating it.

`readyToOpenDeeplink` is exported and no `src/` code calls it — only the Jest
mocks name it. **Decision: port it as is.** It is a v5 leftover, and removing an
export is a separate cleanup with its own risk. Do not delete it silently.

---

## 6. Call sites outside the new files

`PurchaselyView.swift` calls 5 static members of `PurchaselyRN`. Some reach Swift
through an `NS_SWIFT_NAME` alias in `PurchaselyRN.h`, some through the Swift
importer's automatic translation. Both mechanisms disappear with the header, so
the 5 Swift declarations must be written to reproduce the exact names:

| Line | Call site, unchanged | Required Swift declaration |
|---|---|---|
| 110 | `emitEmbeddedPresentationViewed(forRequestId:placementId:)` | `static func emitEmbeddedPresentationViewed(forRequestId requestId: String?, placementId: String?)` |
| 216 | `loadedPresentation(forRequestId:)` | `static func loadedPresentation(forRequestId requestId: String) -> (any PLYPresentation)?` |
| 229 | `takeLoadedPresentation(matchingScreenId:placementId:)` | `static func takeLoadedPresentation(matchingScreenId: String?, placementId: String?) -> (any PLYPresentation)?` |
| 237, 257 | `emitPresentationDismissed(forId:outcome:)` | `static func emitPresentationDismissed(forId routingId: String, outcome: PLYPresentationOutcome)` |
| 297 | `evictPresentationRequest(_:)` | `static func evictPresentationRequest(_ requestId: String?)` |

**Target: zero diff in `PurchaselyView.swift`.** These 5 stay `static`, become
`internal`, are not `@objc`, and are not in the shim: they are Swift-to-Swift
calls. `PurchaselyViewTests.swift` reaches them through `@testable import`.

---

## 7. The shim parity gate

The failure mode: a shim line and a Swift signature disagree, nothing complains
at build time, and the client app throws "method not found" at run time.

**The gate — one XCTest that reads the exported table the way React Native does.**

1. `class_copyMethodList(object_getClass(PurchaselyRN.self))` and keep the
   selectors named `__rct_export__*`. **Do not walk the superclass chain:**
   `RCTEventEmitter` exports `addListener:` and `removeListeners:` itself
   (`RCTEventEmitter.m:96,115`), so the whole-chain count is 65, not 63.
2. Call each IMP for its `UnsafePointer<RCTMethodInfo>`. Call it with that C
   return type; an object-returning `perform` is wrong.
3. `RCTParseMethodSignature(info.objcName, &args)` returns the selector string.
   Then `XCTAssertTrue(PurchaselyRN.instancesRespond(to:
   NSSelectorFromString(sel)))`.
4. Assert the set of resolved **JS names** equals a literal array of the 63
   names. The JS name, not the selector, is the client contract, and this step is
   what catches the `RCT_REMAP_METHOD` trap of constraint 3: a wrong selector
   with a valid count and a resolvable target would otherwise pass.

Feasible: `React-Core-umbrella.h:77` exports `RCTModuleMethod.h`, and
`RCTParseMethodSignature` is an exported symbol of `React.framework`.

**Why not `RCTModuleMethod` itself.** Building one and reading `.selector`
relies on `RCTAssert` at `RCTModuleMethod.mm:212`, which compiles to nothing when
`RCT_DEBUG=0` and otherwise raises an Objective-C exception through Swift test
frames — a test-host crash, not a failed assertion. `RCTParseMethodSignature`
gives the same answer in both flavors.

**Fallback if `import React` does not resolve in the Swift test target:** a
30-line Objective-C test file. React headers are provably reachable from the
Objective-C test target today (`PurchaselyRNTests.m:9`). A Node text parser is
not needed, and step 4 above also replaces the separate Jest gate the first draft
proposed.

---

## 8. Translation rules

### 8.1 State and concurrency

| Today | After | Why |
|---|---|---|
| 3 collections plus a lock object, built in `ensurePresentationState()` through `dispatch_once` | `private static var` on the class | Swift initializes a static lazily, once, thread-safely. `dispatch_once` and the initializer disappear. |
| `@synchronized (kPresentationStateLock) { ... }` | `NSLock` behind a scoped helper: `stateLock.withLock { ... }`, one call per original block | **`NSLock` is not reentrant and `@synchronized` is.** `closePresentation` has two separate locked blocks in one closure with `[presentation close]` between them (`PurchaselyRN.m:1807`, `:1826`). Hoisting `lock()` plus `defer { unlock() }` to the closure would hold the lock across an SDK call and deadlock on the second acquisition. **Preserve every block's exact lexical scope, and keep SDK calls and callback invocations outside it** — `completeActionInterceptor` already invokes its callback outside the lock (`:2079`) and must keep doing so, removing the entry from the map inside the lock first. |
| 30-second interceptor timeout | `DispatchQueue.main.asyncAfter` | Unchanged. |
| 34 `dispatch_async(dispatch_get_main_queue(), ^{...})` | `DispatchQueue.main.async { ... }` | Stays `async`. Not `sync`. Not `await`: `await` changes when the SDK call runs relative to its caller. |
| Block capture semantics | **Preserve per closure.** Keep `weak` exactly where Objective-C has `__weak` (lines 1535, 1604, 1762, 1916) and strong elsewhere. | A blanket `[weak self]` changes operation lifetime: `start` retains `self` until its callback completes (`:625`), purchase failure through `:1024`. And `guard let self else { resolve(nil) }` would be actively wrong — see 8.4. The existing `__weak` closures return silently and own no promise, which is why they can be weak. |
| 0 blocking primitives | 0 blocking primitives | Hard project rule. This bans production code; `XCTestExpectation` waiting in the test target is exempt (`PurchaselyViewTests.swift` already waits). |

`_sharedEmitter` is weak (`:365`) and stays weak static storage.

The reason the capture question is small, verified: the only instance member the
strongly capturing blocks use is the `reject:with:` helper, at 18 sites (627,
651, 679, 989, 992, 1025, 1033, 1042, 1047, 1061, 1074, 1086, 1106, 1123, 1139,
1157, 1176), and it reads no instance state (`:1454-1456`). The `self.shouldEmit`
and `sendEventWithName` uses are all in delegate methods, not in blocks.
**Make `reject:with:` a `static func`.** Those closures then capture nothing and
the whole class of hang disappears. The per-closure rule above still governs, in
case a block is found that does touch instance state.

### 8.2 Enums

**Outbound — the trap that compiles.** `PurchaselyRN.m` boxes enums explicitly:
`@(presentation.type)` at `:147`, `@(type)` at `:1366`, `@(source)` and
`@(processingLegalBasis)` at `:1372-1373`, and `PLYSubscription+Hybrid.m:18`,
`PLYPlan+Hybrid.m:40`. A Swift enum placed directly in `[String: Any]` bridges to
an opaque Swift box, which is none of `NSNumber`, `NSString`, `NSArray` or
`NSDictionary`, so the bridge conversion drops the value. It compiles and the key
arrives as `undefined`. **Rule: write `.rawValue` on every enum value**, and the
snapshot tests assert the value type (`is NSNumber`), not only the key set.

**Inbound.** `setLogLevel:(NSInteger)` (`:656`), `setThemeMode:(NSInteger)`
(`:701`), `setAttribute:(NSInteger)` (`:715`) accept any integer today.
`PLYLogLevel(rawValue:)` returns nil for an unknown one. **Rule: every inbound
raw value gets an explicit fallback** — the current default, plus one
`PLYRNLogWarn`. Never a force-unwrap.

**Exhaustiveness.** The SDK's `.swiftinterface` marks nothing `@frozen`, so a
`switch` with no `default` compiles with a "may have additional unknown values"
warning and traps at run time on an unknown case. Keep the exhaustive switch,
and allow `@unknown default` where a sane fallback exists — the pattern
`PurchaselyView.swift:288` already uses.

**Numeric widths.** `incrementUserAttribute` uses 32-bit `intValue` (`:857`);
the transition parsing uses `intValue` and `floatValue`. Keep each width. And
`(NSInteger)value` at `:740` runs after a `fmod(value, 1.0) == 0` test that
`1e300` passes: in C the cast yields garbage, in Swift `Int(value)` is a fatal
error. Use `Int(exactly:)` with a fallback to the double path.

### 8.3 The 13 static C functions

`stringFromPresentationAction`, `presentationActionFromString`,
`stringFromWebCheckoutProvider`, `purchaseResultOrdinal`, `closeReasonToRNString`
and `runningModeFromOrdinal` become `internal` static functions or enum
extensions. `presentationToMap`, `presentationErrorToMap` and
`loadedClientPresentationForMap` become `internal` static functions in
`+Presentations.swift` — **`internal`, not `private`**: `+Interceptors.swift`
calls `presentationToMap` (`:1967`) and touches the shared state (`:1928`), and
Swift's private-in-extension exception applies only within one file.
`applyPresentationDisplayOptions`, `plyParseDimensionMap` and
`plyTransitionFromMap` become static functions; `plyTransitionFromMap` calls the
SDK's Swift `PLYTransition` initializer and replaces `PLYTransitionFactory`.
`extractPresentationTargets:...` has four `__autoreleasing` out-parameters and
becomes a function returning a small `PresentationTargets` struct.
`ensurePresentationState` disappears.

### 8.4 Absence, per field

**There is no blanket rule, and a blanket rule would be a breaking change.** The
current bridge deliberately mixes three policies, and `types.ts` documents the
mix:

- **Key omitted when nil.** `PLYSubscription+Hybrid.m:22-28` omits
  `nextRenewalDate` and `cancelledDate`. `types.ts:138-141` states it: "The iOS
  bridge omits the key when the native date is `nil`; Android reports an explicit
  `null`. Never read it as an empty string." Also `PLYPlan+Hybrid.m:67` and
  `PLYPresentationPlan+Hybrid.m:16`.
- **Explicit `NSNull`.** The web-redemption body (`PurchaselyRN.m:1426`), whose
  policy `PurchaselyRN.h` documents and `PurchaselyRNTests.m` already tests.
- **Coalesced to a value.** A nil subscription array iterates to `[]`, not null
  (`:1150`). A nil error reaches the reject helper and yields code `"0"` with a
  nil message (`:1455`, `:1138`) — so keep the helper's parameter nullable and
  write `error?.code ?? 0`. A force-unwrap, an early return, or an optional `map`
  each change that behavior.

**Rule:** the port carries each field's existing policy unchanged. Swift makes
this a live hazard, because `dict["k"] = nil` **removes** the key. Where the
policy is `NSNull`, write `NSNull()`. Where it is omission, guard the assignment.
The snapshot tests of section 10 must cover a populated case and an absent case
for every serializer.

### 8.5 Exported-method signatures

Two rules, both from section 3:

- Every exported method carries an explicit `@objc(selector:)` whose first
  segment equals its JS name. The shim line then copies that selector verbatim.
- Every object-typed parameter is declared Optional (`String?`, `NSDictionary?`,
  `[Any]?`). `NSNumber` parameters stay non-optional and `_Nonnull` in the shim.

---

## 9. Contract that must not change

1. The JS module name `Purchasely`.
2. The 63 exported **JS names** and their argument counts. Selectors may change.
3. The **60** `constantsToExport` keys and their exact values. `enums.ts:4` and
   `types.ts` consume them.
4. The 11 `supportedEvents` names.
5. Every dictionary key any serializer produces, its absence policy per field
   (8.4), and its value type (8.2).
6. The two promise layers, which are different things. The native promise of
   `preloadPresentation` and `displayPresentation` resolves `@(YES)` immediately
   after triggering (`:1581`, `:1747`); the public JS promise settles later
   through events (`presentation.ts:371`, `:419`) and the native promise is
   observed only for rejection. **Resolve the native acknowledgement exactly
   once, and do not touch the event path.** Settling it a second time from a
   later callback is the bug the first draft's `[weak self]` rule would have
   introduced.
7. `requiresMainQueueSetup` on both classes.

---

## 10. Tests and CI

### Tests

- `PurchaselyRNTests.m` (535 lines) → `PurchaselyRNTests.swift`, XCTest with
  `@testable import react_native_purchasely`. **XCTest, not Swift Testing:** a
  CocoaPods test spec requires `XCTestCase`. Drop the tests of the three dead
  members and of the `UIViewController` category.
- New: the parity gate of section 7, including the 63-JS-name literal.
- New: the 60-key constants snapshot, keys **and** values.
- New: snapshot tests for the 5 dictionary serializers — key set, value types,
  and a populated plus an absent case per nullable field. Plus behavior tests for
  the hex parser, which is not a serializer. These do not exist today and they are
  the only thing that can catch a silent serialization regression.
- `PurchaselyViewTests.swift` (785 lines): unchanged.
- **Jest catches nothing here.** `src/__mocks__/testUtils.ts` mocks the native
  module. A green `yarn test` is not evidence for this work.

### CI jobs that gate it

| Job | What it proves |
|---|---|
| `build-ios` | The pod compiles, static-library linkage |
| `build-rn-0-86-ios` | Compiles against the supported RN version |
| `iOS Build (use_frameworks!)` | The pod compiles in a **framework-layout** target. `ci.yml:280` sets `USE_FRAMEWORKS: static` and `ci.yml:242-244` says dynamic was dropped on purpose. So this proves static frameworks and header resolution, **not** dynamic linkage. Do not claim dynamic coverage. |
| `iOS Unit Tests (bridge)` | The XCTest bundle, the parity gate included |
| `e2e-ios.yml` | Triggers on `packages/purchasely/ios/**`, so both PRs run **T1–T30** (`e2e-ios.yml:144`) on a simulator. The only gate that exercises the real JS-to-native path. |

E2E is the acceptance criterion for phase 2. A green build proves nothing about a
text-parsed shim.

---

## 11. Why not a TurboModule now

**What it would give clients:** compile-time safety on the exported surface
through codegen; lazy module initialization; direct JSI calls with no JSON
serialization (not measurable here); and protection against the eventual removal
of the legacy architecture.

**What it would cost clients:**

1. A TurboModule needs the New Architecture. Every client still on the legacy
   architecture loses the SDK. `peerDependencies` says `react-native: *`.
2. Codegen accepts a restricted type set. The bridge returns rich dictionaries
   with a per-field absence policy (8.4). They degrade to a plain `Object`, or
   each needs a full spec to write and maintain.
3. iOS codegen emits Objective-C++ only, so a Swift TurboModule keeps a `.mm`
   adapter. **A TurboModule does not remove Objective-C from this project.** It
   moves it, so it does not serve goal 2.

Separate projects: this one is a code-quality change with no client-visible
effect; a TurboModule is a supported-version decision needing its own release and
its own communication. Splitting the Swift code by domain keeps the exported
surface thin, so a later TurboModule replaces the shim and the `@objc`
signatures and keeps everything else. No abstraction is added for it today.

---

## 12. Delivery

Two phases, two pull requests, each green on CI and E2E on its own.

**Phase 1 — serialization.** The 7 categories become Swift extensions under
`ios/Classes/Serialization/`, `ios/Classes/Hybrid/` deleted (15 files, 540
lines). `PurchaselyRN.m` keeps its logic and calls the new Swift through the
generated `react_native_purchasely-Swift.h`, as it already calls
`PLYTransitionFactory`.

Four mechanics, all temporary:

1. The Objective-C-facing members must be **`@objc public`**, not `@objc
   internal`. A framework-layout target's generated header carries `public` and
   `open` declarations only, and the `use_frameworks!` job builds exactly that.
   `PLYTransitionFactory.swift:22,33` is the working precedent. Phase 2 reduces
   them to `internal`.
2. `PLYBillingPlanTypeToRNString` and `PLYBillingPlanTypeFromRNString` are free C
   functions (`PLYPlan+Hybrid.h:15-17`, `.m:10-23`) called at
   `PurchaselyRN.m:1189` and `:1209`. A free Swift function cannot be `@objc`, and
   a Swift extension member does not replace a C symbol. They become `@objc
   static` members on the plan extension, and **phase 1 must edit those two call
   sites and the two `#import` lines at `PurchaselyRN.m:13-14`.** Phase 1 is not
   a pure add-and-delete.
3. `UIViewController+Hybrid` is deleted, not ported (section 5).
4. Locked by the snapshot tests of section 10, written **before** the port,
   against the current Objective-C output. That is the whole safety of phase 1.

Risk: low. No bridge contract is touched, no exported method moves.

**Phase 2 — the module.** `PurchaselyRN.m` becomes the shim plus the log helper,
`PurchaselyRN.h` is deleted, the 6 Swift files appear, `PLYTransitionFactory` and
`Purchasely.xcodeproj` are deleted, the three dead members go, the tests are
ported, the parity gate lands, `@objc public` drops to `internal`.

Risk: high, concentrated in the shim. The parity gate plus E2E is the answer.

**Release vehicle:** both in `6.2.0`, not a `6.1.x` patch. No client-visible
feature, but the whole native layer of one platform changes and a patch version
does not signal that.

---

## 13. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| A shim line disagrees with its Swift signature, or a `RCT_REMAP_METHOD` becomes a renamed JS method | High. Runtime failure in a client app. | The gate of section 7, whose step 4 asserts JS names, plus E2E T1–T30 |
| A Swift enum lands in a dictionary without `.rawValue` | High. Compiles, arrives as `undefined`. | Rule 8.2 plus value-type assertions in the snapshots |
| An absence policy flips between omitted and `NSNull` | High. Silent, client-visible, and `types.ts` documents the current behavior. | Rule 8.4 plus a present-and-absent case per nullable field |
| A nil argument traps a non-optional Swift parameter in a Release build | High. Crash in a client app, invisible in Debug. | Rule 8.5: every object parameter Optional |
| A locked region is widened and deadlocks on `NSLock` | High. Frozen main thread. | Rule 8.1: one `withLock` per original `@synchronized` block, SDK calls outside |
| The native acknowledgement promise settles twice | Medium. | Contract 9.6 |
| An unknown SDK enum case traps a non-frozen switch | Medium. | `@unknown default` with a fallback where one is sane |
| `react-native-purchasely-Bridging-Header.h` deleted as "dead" | High. Build breaks with a misleading message. | Keep it, comment it, record it in `CLAUDE.md` |
| Phase 1 Swift is `internal` and the framework header omits it | Medium. Phase 1 fails only in the `use_frameworks!` job. | `@objc public` in phase 1 |
| `import React` does not resolve in the Swift test target | Medium. Removes the gate. | The 30-line Objective-C test fallback |

---

## 14. Definition of done

1. `fd -e m -e h . packages/purchasely/ios` lists `PurchaselyRN.m`,
   `PurchaselyViewManager.m`, `react-native-purchasely-Bridging-Header.h`, and —
   only if the section 7 fallback was needed — one Objective-C test file.
2. The 4 iOS CI jobs are green.
3. `e2e-ios.yml` T1–T30 is green.
4. The parity gate exists and fails when a shim line is removed and when a JS
   name changes. Proven by doing both locally.
5. `CLAUDE.md` is corrected on its 9 lines, and its stale test line counts (330
   and 265, really 535 and 785) are fixed.
6. No `DispatchSemaphore`, no `wait`, no `dispatch_sync` in the production code
   of `packages/purchasely/ios/`.
