# iOS Bridge Objective-C → Swift Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 2086-line Objective-C `PurchaselyRN.m` and the 540 lines of Objective-C serialization categories with Swift, behind a thin Objective-C export shim, with no change to the JavaScript contract.

**Architecture:** One `@objc(PurchaselyRN) class PurchaselyRN: RCTEventEmitter` split into 6 Swift files by domain, plus `PurchaselyRN.m` reduced to `RCT_EXTERN_REMAP_MODULE` + 63 `RCT_EXTERN_METHOD` lines. The 7 serialization categories become Swift extensions under `ios/Classes/Serialization/`. Two pull requests: serialization first, then the module.

**Tech Stack:** Swift 5, XCTest, CocoaPods (mixed ObjC/Swift pod), React Native 0.86 legacy bridge on the New Architecture interop layer, Purchasely native iOS SDK 6.1.0.

**Spec:** `docs/superpowers/specs/2026-09-08-ios-bridge-swift-migration-design.md` — read it before Task 1. This plan argues from it and does not repeat its reasoning.

**Revision note (2026-09-08):** two adversarial reviews of the first draft found 12 blocking errors, all of one kind — Swift written from memory for SDK calls instead of read off the SDK's Swift interface. Every SDK symbol in this plan is now verified, and Global Constraint 0 plus the verified-symbol table exist so an executor never has to guess one.

---

## Global Constraints

Every task's requirements implicitly include this section.

0. **Never write an SDK symbol you have not read.** The Purchasely SDK is Swift, and its Objective-C surface differs from its Swift surface: names get nested, properties become setters, optionality changes. Before writing any `Purchasely.*`, `PLY*` type, enum case or method, read it:

   ```bash
   SI=example/ios/Pods/Purchasely/Purchasely/Frameworks/Purchasely.xcframework/ios-arm64_x86_64-simulator/Purchasely.framework/Modules/Purchasely.swiftmodule/arm64-apple-ios-simulator.swiftinterface
   rg -n 'func userLogin|enum PLYLogLevel' "$SI"          # a symbol
   awk '/class PLYPlan :/,/^}/' "$SI"                     # a whole type
   ```

   The SDK source is also on this machine at `/Users/kevin/Purchasely/iOS/Sources/Purchasely/`, which is where the JSON wire keys live (`enum CodingKeys`). A plan snippet is a starting point, not an authority: if it disagrees with the interface, the interface wins and you report the discrepancy.

1. **The JS contract cannot change.** 63 exported JS method names with their argument counts, 60 `constantsToExport` keys **and values**, 11 `supportedEvents` names, every serializer dictionary key, and each key's absence policy.
2. **New Swift files go under `ios/Classes/`,** never a new top-level `ios/` subdirectory. `react-native-purchasely.podspec:19` is `"ios/*.{h,m,mm,swift}", "ios/Classes/**/*.{h,m,mm,swift}"`. A file outside those two globs is not in the pod.
3. **Every exported method carries an explicit `@objc(selector:)`** whose first selector segment equals its JS name. `RCT_EXTERN_REMAP_METHOD` is not public in RN 0.86 (`RCTBridgeModule.h:310-323`), so the shim cannot remap. Copy the selector from the annotation into the shim; never retype it.
4. **Optionality: the shim annotation and the Swift type are two different decisions.**
   - In the **shim**, copy the existing annotation from `PurchaselyRN.m` exactly, `_Nonnull` and `_Nullable` included. RN reads them only under `#if RCT_DEBUG` (`RCTModuleMethod.mm:399-457`), so they are documentation, not a Release guarantee.
   - In **Swift**, every object-typed parameter is Optional (`String?`, `NSDictionary?`, `[Any]?`, `NSNumber?`) **regardless of the annotation**, precisely because there is no Release check and nil reaches the thunk. A non-optional Swift parameter traps.
   - A parameter that is a **C primitive today** (`BOOL`, `NSInteger`, `double`) stays that primitive. It cannot be nil and changing it changes the selector.
5. **Every enum value written into a dictionary uses `.rawValue`.** A Swift enum in `[String: Any]` bridges to an opaque box that the bridge drops silently — the key arrives `undefined`.
6. **Absence policy is per field, never uniform.** Read the guard in the Objective-C source for every key. Four policies exist: omitted when nil (`PLYSubscription+Hybrid.m:22-28`, documented to clients in `types.ts:138-141`), explicit `NSNull` (`PurchaselyRN.m:1426`), coalesced to a value (`:1150`), and **omitted when empty** (`PLYPlan+Hybrid.m:120`, `commitmentInfo.count > 0` on a non-optional array — an `if let` there is wrong, it needs `if !isEmpty`). In Swift, `dict["k"] = nil` **removes** the key.
7. **`NSLock` is not reentrant; `@synchronized` is.** One `withLock { }` per original `@synchronized` block, preserving its exact lexical scope. No SDK call, no callback invocation, and no `await` inside a locked region.
8. **No blocking primitive in production code.** No `DispatchSemaphore`, no `group.wait()`, no `dispatch_sync`, no `RunLoop.run(until:)`. `XCTestExpectation` waiting in the test target is exempt.
9. **Preserve every dispatch boundary and every capture, exactly as found.**
   - If the Objective-C body calls the SDK directly, the Swift body calls it directly. **Do not add a `DispatchQueue.main.async`** — `userLogin` (`PurchaselyRN.m:660`) has none, and adding one changes when the call runs.
   - If it is inside `dispatch_async(dispatch_get_main_queue(), ...)`, keep it there, as `async`, never `sync`, never `await`.
   - `weak` only where Objective-C has `__weak` (`:1535`, `:1604`, `:1762`, `:1916`). Never a blanket `[weak self]`.
   - Registration order is a dispatch boundary too: an observer registered after a call returns stays after it, not inside its completion.
10. **Two promise layers.** `preloadPresentation` and `displayPresentation` resolve their native promise `@(YES)` immediately after triggering (`:1581`, `:1747`); the public JS promise settles later through events. Resolve the native acknowledgement exactly once and never from a later callback.
11. **`requiresMainQueueSetup` returns `YES` for `PurchaselyRN`** (`PurchaselyRN.m:1447`) **and `false` for `PurchaselyViewManager`** (`PurchaselyViewManager.swift:20`). The two differ on purpose. Do not "align" them — commit `81c5a65` is the incident.
12. **`ios/react-native-purchasely-Bridging-Header.h` must never be deleted.** CocoaPods compiles the pod's Swift with `-import-underlying-module`, and this file is what puts the React headers into the umbrella. Deleting it breaks every Swift file in the pod with a message pointing elsewhere.
13. **Commands.**

    ```bash
    # from the repo root
    UDID=$(xcrun simctl list devices booted -j | jq -r '[.devices[][]][0].udid')
    cd example/ios && pod install                      # after adding a file or editing the podspec
    xcodebuild test -workspace example.xcworkspace -scheme react-native-purchasely-Unit-Tests \
      -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO
    xcodebuild -workspace example.xcworkspace -scheme example \
      -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO build
    # the framework-layout job, which is what catches `@objc internal`
    USE_FRAMEWORKS=static pod install && xcodebuild -workspace example.xcworkspace \
      -scheme react-native-purchasely -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO build
    pod install                                        # restore the default layout
    ```

---

## Verified symbol table

Read off `arm64-apple-ios-simulator.swiftinterface` and the SDK sources on 2026-09-08. Every one of these was wrong in the first draft of this plan. Use these, not your memory.

| What you need | The real Swift symbol | Trap it replaces |
|---|---|---|
| Log level type | `PLYLogger.PLYLogLevel`, cases `.debug .info .warn .error` (`:1458`) | not top-level `PLYLogLevel` |
| Set the log level | `Purchasely.setLogLevel(_:)` (`:1256`) | not an assignable `Purchasely.logLevel` |
| Attribute type | `Purchasely.PLYAttribute` (`:1337`) | not top-level |
| Theme mode | `Purchasely.PLYThemeMode` (`:1368`) | not top-level |
| Legal basis | `PLYDataProcessingLegalBasis`, cases `.optional .essential` (`:53`) | `PLYLegalBasis` does not exist |
| Login | `Purchasely.userLogin(with:shouldRefresh:)` (ObjC `userLoginWith:shouldRefresh:`, `PurchaselyRN.m:660`) | not `userLogin(with:completion:)` |
| Intro-offer eligibility | `PLYPlan.isUserEligibleForIntroductoryOffer(completion:)` (`:653`) | **not** `isEligibleForIntroductoryOffer` — that name recurses |
| Localized price | `PLYPlan.localizedFullPrice(language:)` (`:691`) | `price(with:)` does not exist |
| Transition init | `PLYTransition.init(type:height:width:heightPercentage:backgroundColors:dismissible:)` (`:994`), `.drawer(height:)` / `.popin(width:height:)` (`:1009`) | this is what replaces `PLYTransitionFactory` |
| Dimension | `PLYDimension` enum (`:1150`) | |
| Purchase result | `PLYPurchaseResult` has **four** cases, `.purchased .cancelled .restored .none` (`:806`) | `.none` maps to **nil**, not to cancelled |
| Purchase notification | the literal string `"ply_purchasedSubscription"` (`PurchaselyRN.m:638`) | there is no `Notification.Name` constant |
| App technology | `Purchasely.setAppTechnology(.reactNative)`, called in `-init` (`PurchaselyRN.m:467`) | it is in `init`, not `start` |

**No SDK model type has a no-argument initializer.** `PLYPlan`, `PLYProduct`, `PLYSubscription`, `PLYOfferSignature` and `PLYPresentationPlan` expose only `required init(from decoder:)`. They are `Decodable`, so a test fixture is built with `JSONDecoder` — Task 1 gives the wire keys.

**`- (NSDictionary *)asDictionary` imports into Swift as a method,** `asDictionary()`, not a property: Swift imports only an ObjC `@property` as a property. So the Swift replacement is declared `@objc func asDictionary() -> [String: Any]`, a method, and the call shape is then identical in both languages before and after the port. That is what lets Task 1's test file stay frozen through Tasks 2–4.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `ios/PurchaselyTests/SerializationFixtures.swift` | Decodes the 5 model fixtures from JSON, so tests have populated instances | 1 |
| `ios/PurchaselyTests/SerializationContractTests.swift` | Locks every serializer's key set, value types and absence policy | 1 |
| `ios/Classes/Serialization/PLYPlan+Bridge.swift` | `PLYPlan` → dictionary, the 2 billing-plan-type mappers | 2 |
| `ios/Classes/Serialization/PLYProduct+Bridge.swift` | `PLYProduct` → dictionary | 3 |
| `ios/Classes/Serialization/PLYSubscription+Bridge.swift` | `PLYSubscription` → dictionary | 3 |
| `ios/Classes/Serialization/PLYOfferSignature+Bridge.swift` | `PLYOfferSignature` → dictionary | 3 |
| `ios/Classes/Serialization/PLYPresentationPlan+Bridge.swift` | `PLYPresentationPlan` → dictionary | 3 |
| `ios/Classes/Serialization/UIColor+PLYHex.swift` | Hex string → `UIColor` | 4 |
| `ios/PurchaselyTests/BridgeExportContractTests.swift` | Locks the 63 JS names, the module name, the 60 constants with values, the 11 events | 5 |
| `ios/PurchaselyTests/PurchaselyRNTests.swift` | The ported unit tests | 6 |
| `ios/PurchaselyRN.swift` | The class, state, lock, constants, events, observing, the 3 delegate conformances, `PLYRNLogWarn` use | 8 |
| `ios/PurchaselyRN+Lifecycle.swift` | start, identity, deeplinks, language, log level, theme, consent, synchronize | 9 |
| `ios/PurchaselyRN+Attributes.swift` | The 21 attribute methods and the legal-basis mapper | 10 |
| `ios/PurchaselyRN+Products.swift` | Products, plans, subscriptions, purchase, restore, offerings, promo offers | 11 |
| `ios/PurchaselyRN+Presentations.swift` | Preload, display, close, back, BYOS, transitions, the 6 static members, the delegate bodies | 12 |
| `ios/PurchaselyRN+Interceptors.swift` | Register, unregister, complete, the 30-second timeout | 13 |
| `ios/PurchaselyRN.m` | Export shim + `PLYRNLogWarn` definition | 14 |

**Exclusive method ownership.** Every exported method belongs to exactly one task. `synchronize` is Task 9's (it was listed in both 9 and 11 in the first draft, which would produce a duplicate `@objc` declaration). `isEligibleForIntroOffer` is Task 11's, even though it sits inside Task 9's source range. Before writing a method, confirm your task owns it; if two tasks name it, stop and report.

---

## Orchestrator amendments (2026-09-08, after the Task 1 review)

Binding on every task, at the same level as the Global Constraints. Read this block with lines 1-119.

**A1. One branch, one pull request.** Every task commits to `feat/ios-swift-bridge-spec`, which is pull
request #298. Ignore each phase's `Branch:` line and Task 15's `git push` / `gh pr create` block: the
orchestrator pushes, and no task creates a branch or a pull request.

**A2. `PLYSubscription` is NOT ported. It stays Objective-C.**
`packages/purchasely/ios/Classes/Hybrid/PLYSubscription+Hybrid.{h,m}` survives phase 1 unchanged, and
Task 3 does **not** create `PLYSubscription+Bridge.swift`.

Why: `PLYSubscription.init(from:)` resolves `.product` through `ProductRepository.shared`, which is
`internal` to the Purchasely module with no injection seam — the SDK's own source carries
`#warning("This decoding depends on ProductRepository, which cannot be injected")`, the interface marks the
class `@_hasMissingDesignatedInitializers`, and its only other initializer is `internal`. So no fixture can
be built, and `integration_test/` never calls `userSubscriptions` either. A port would therefore be the only
change in this migration with **no automated coverage at any level**, on the one serializer whose per-field
absence policy is documented to clients in `types.ts:138-141`, and whose `subscriptionSource` is the single
remaining Global-Constraint-5 `.rawValue` hazard among the five.

After Tasks 2-3, its `self.plan.asDictionary` and `self.product.asDictionary` calls resolve to **Swift**
`@objc` extension methods, reached through a hand-written `@interface PLYPlan (BridgeSerialization)`
forward declaration in the `.m`. Task 4 keeps `Purchasely_Hybrid.h` alive with only the declarations that
remain.

**A2 correction (after the Task 2 review).** An earlier draft of this block claimed that getting that seam
wrong would fail the iOS build jobs. **That is false.** An Objective-C message send to a Swift `@objc`
extension method is Objective-C *runtime* dispatch and creates no link-time reference, and the forward
declaration is never checked against the Swift symbol. So if a later task drops `@objc` from
`PLYPlan.asDictionary` or `PLYProduct.asDictionary`, every build stays green and the first
`userSubscriptions` call from JS crashes with `unrecognized selector sent to instance`.

The tie is therefore a **test**, not the compiler: `SerializationContractTests` asserts
`PLYPlan.instancesRespond(to: NSSelectorFromString("asDictionary"))` and the same for `PLYProduct`. That is
what makes the seam fail loudly in CI. Consequently **`@objc` on those two `asDictionary` methods is
permanent, not a phase-1 scaffold** — Task 14 must NOT reduce them to `internal` while
`PLYSubscription+Hybrid.m` exists.

**Timing of that hazard — it is not live yet.** The fix lot tried to demonstrate it and could not, which is
the useful result. Today `PurchaselyRN.m` still calls `asDictionary` at **15 sites** and imports the pod's
generated `react_native_purchasely-Swift.h`, so the compiler *does* check those two selectors: dropping
`@objc` right now fails the build with 8 errors, it does not produce a green build. The runtime-only,
uncompiler-checked seam goes live **only after Task 14** strips `PurchaselyRN.m` to the export shim and
removes those 15 call sites. From that commit onward `PLYSubscription+Hybrid.m`'s hand-written
`@interface PLYPlan (BridgeSerialization)` forward declaration is the sole consumer, nothing checks it, and
the selector test is the only guard.

So **Task 14 owns the mutation proof that was unreachable earlier**: after the swap, drop `@objc` from
`PLYPlan.asDictionary`, and observe the selector test go **red while the build stays green**. That
observation is the acceptance criterion for this seam, and it is only possible once Task 14 has landed.

Upgrade path: port it when the SDK gives `ProductRepository` an injection seam (the SDK already carries that
as a TODO). Until then a follow-up ticket tracks it.

**A3. Two gate limitations that no task may paper over.** The Task 1 gate structurally cannot cover:
- `PLYPlan`'s ten StoreKit-resolved keys (`price`, `amount`, `localizedAmount`, `introAmount`,
  `currencyCode`, `currencySymbol`, `period`, `introPrice`, `introDuration`, `introPeriod`) — they need a
  loaded `SKProduct`, so they are only ever asserted *absent*. **Task 2's reviewer hand-diffs those ten emit
  blocks** against `PLYPlan+Hybrid.m:75-123`.
- `PLYPlan.commitmentInfo`'s six sub-keys — `commitmentInfo` is populated only by `ProductRepository` after
  an SK2 load and is explicitly not `Codable`.
Neither may be "fixed" by relaxing an assertion.

---

# PHASE 1 — Serialization (Pull Request 1)

Branch: `feat/ios-swift-serialization`, based on `main`.

## Task 1: Lock the serialization contract before touching it

The safety of all of phase 1 is this task. It snapshots the **current Objective-C** output, so it must be written and green before any `.m` is deleted.

**Files:**
- Create: `packages/purchasely/ios/PurchaselyTests/SerializationFixtures.swift`
- Create: `packages/purchasely/ios/PurchaselyTests/SerializationContractTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `SerializationFixtures` (5 decoded model instances plus 5 empty-field variants) and `SerializationContractTests`. Tasks 2–4 must keep the tests green **without editing them**. If one fails, the port is wrong.

- [ ] **Step 1: Read the five serializers and record every key**

```bash
cd packages/purchasely/ios/Classes/Hybrid
grep -nE 'forKey:|if \(' PLYPlan+Hybrid.m PLYProduct+Hybrid.m PLYSubscription+Hybrid.m \
  PLYOfferSignature+Hybrid.m PLYPresentationPlan+Hybrid.m
```

For each key record: the key name, the value type Objective-C writes, and **which of the four absence policies of Global Constraint 6 applies** — read the guard, do not assume. Two traps found in review:

- `PLYOfferSignature`'s `nonce` and `timestamp` guards are **dead code**. `nonce` is a non-optional `UUID` and `timestamp` a non-optional `Double` (`.swiftinterface:628-630`), so `[self.nonce UUIDString]` and `[NSNumber numberWithDouble:]` never return nil. Both keys are **always present**.
- `PLYPlan`'s `commitmentInfo` guard is `count > 0` on a non-optional array, not a nil check. It needs `if !isEmpty`, and an `if let` there would emit `[]` where JS expects `undefined`.

- [ ] **Step 2: Write the fixtures**

No model type has a no-argument initializer — they expose only `required init(from decoder:)` — so `PLYPlan()` does not compile. All five are `Decodable`, so decode them. The wire keys below come from each model's `enum CodingKeys` in `/Users/kevin/Purchasely/iOS/Sources/Purchasely/common/Model/`.

Create `packages/purchasely/ios/PurchaselyTests/SerializationFixtures.swift`:

```swift
//
//  SerializationFixtures.swift
//  Decoded model instances for the serialization contract tests.
//
//  The SDK's model types have no public no-argument initializer, only
//  `init(from decoder:)`. So a fixture is JSON. The wire keys are each type's
//  `enum CodingKeys` in /Users/kevin/Purchasely/iOS/Sources/Purchasely/.
//
//  Each type gets TWO fixtures: `populated`, with every optional field set,
//  and `sparse`, with only the required fields. The pair is what proves the
//  per-field absence policy, which is the one thing Swift silently changes.
//

import Foundation
import Purchasely

enum SerializationFixtures {

    static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // MARK: - PLYPlan
    // CodingKeys: vendor_id, public_id, id, distribution_type, level, name,
    //             store_product_id, is_visible, promo_offers

    static let planPopulatedJSON = """
    {
      "vendor_id": "PLAN_MONTHLY",
      "public_id": "plan_abc",
      "id": "1",
      "distribution_type": "renewing_subscription",
      "name": "Monthly",
      "store_product_id": "com.example.monthly",
      "is_visible": true
    }
    """

    /// Only what the decoder requires. Every optional stays absent, which is
    /// what makes the omission assertions meaningful.
    static let planSparseJSON = """
    { "vendor_id": "PLAN_MONTHLY", "id": "1" }
    """

    static func plan(populated: Bool) throws -> PLYPlan {
        try decode(PLYPlan.self, populated ? planPopulatedJSON : planSparseJSON)
    }

    // MARK: - the four others
    //
    // Write these the same way, reading the CodingKeys from the SDK sources:
    //   PLYProduct         id, public_id, vendor_id, name, plans, icon
    //   PLYSubscription    id, plan, store_type, next_renewal_at, cancelled_at,
    //                      original_purchased_at, purchased_at, offer_type,
    //                      environment, store_country, is_family_shared,
    //                      subscription_status, content_id, offer_identifier,
    //                      cumulated_revenues_in_usd, subscription_duration_in_days,
    //                      subscription_duration_in_weeks,
    //                      subscription_duration_in_months, stripe_purchase_id,
    //                      stripe_checkout_session_id
    //   PLYOfferSignature  key_identifier, plan_vendor_id, offer_identifier,
    //                      offer_signature, offer_nonce, offer_timestamp
    //   PLYPresentationPlan plan_vendor_id, store_product_id, offer_id,
    //                      offer_vendor_id, default, commitment_billing_type
    //
    // PLYSubscription's sparse fixture MUST omit next_renewal_at and
    // cancelled_at: those two keys are the ones types.ts:138-141 documents to
    // clients as absent on iOS, and they are the most valuable assertion here.
    // PLYOfferSignature has NO nullable key — see Step 1.
}
```

If a fixture fails to decode, the JSON is wrong, not the model. Read that type's `init(from:)` in the SDK source: some fields are decoded with `decode` (required) and some with `decodeIfPresent` (optional), and only the required ones must appear in the sparse fixture.

- [ ] **Step 3: Write the failing test**

Note `asDictionary()` with parentheses throughout: the Objective-C method imports into Swift as a method, and Task 2 keeps it a method precisely so this file never changes.

Create `packages/purchasely/ios/PurchaselyTests/SerializationContractTests.swift`:

```swift
//
//  SerializationContractTests.swift
//  Locks the bridge's serialization contract across the Objective-C → Swift
//  port. Written against the Objective-C categories, kept green unchanged by
//  the Swift extensions that replace them. Do not relax an assertion to make a
//  port pass: types.ts documents this behaviour to clients.
//

import XCTest
import Purchasely
@testable import react_native_purchasely

final class SerializationContractTests: XCTestCase {

    // MARK: - PLYPlan
    //
    // Fill these three sets from Step 1's output. The lists below are the
    // shape; Step 1 is the authority.

    /// Emitted on every plan, populated or sparse. The five `offer*` keys are
    /// deliberate safe defaults: the SDK's PLYTagHelper is `private` and takes
    /// an internal type, so no bridge can compute a real promotional-offer
    /// price — in Objective-C or in Swift. Do not "fix" them during the port.
    /// See the comment at PLYPlan+Hybrid.m:22-30.
    private static let planAlwaysPresent: Set<String> = [
        "vendorId", "hasIntroductoryPrice", "type", "hasFreeTrial",
        "hasOfferPrice", "offerPrice", "offerAmount", "offerDuration",
        "offerPeriod",
    ]

    /// Present on the populated fixture, ABSENT on the sparse one — not
    /// NSNull, not an empty string.
    private static let planNullable: Set<String> = [
        "name", "productId", "price", "amount", "localizedAmount",
        "introAmount", "currencyCode", "currencySymbol", "period",
        "introPrice", "introDuration", "introPeriod", "commitmentInfo",
    ]

    /// Keys whose value must bridge as an NSNumber. Global Constraint 5: a
    /// Swift enum written without `.rawValue` becomes an opaque box the RN
    /// bridge drops, and the key arrives `undefined`.
    private static let planNumericKeys: Set<String> = [
        "type", "hasIntroductoryPrice", "hasFreeTrial", "hasOfferPrice",
        "offerAmount",
    ]

    func testPlanAlwaysPresentKeysSurviveBothFixtures() throws {
        for populated in [true, false] {
            let dict = try SerializationFixtures.plan(populated: populated).asDictionary()
            for key in Self.planAlwaysPresent {
                XCTAssertNotNil(dict[key], "plan(populated: \(populated)) lost '\(key)'")
            }
        }
    }

    func testPlanNullableKeysArePresentWhenPopulated() throws {
        let dict = try SerializationFixtures.plan(populated: true).asDictionary()
        // Only assert the keys the populated fixture actually sets. A key here
        // that the fixture does not set belongs in the sparse assertion only —
        // widen the fixture rather than weakening this test.
        for key in ["name", "productId"] {
            XCTAssertNotNil(dict[key], "a populated plan must emit '\(key)'")
        }
    }

    func testPlanNullableKeysAreAbsentWhenSparse() throws {
        let dict = try SerializationFixtures.plan(populated: false).asDictionary()
        for key in Self.planNullable {
            XCTAssertNil(
                dict[key],
                """
                '\(key)' must be ABSENT on a sparse plan — not NSNull and not \
                an empty string. types.ts documents the omission and the JS \
                layer reads `undefined`.
                """
            )
        }
    }

    func testPlanNumericKeysBridgeAsNumbers() throws {
        let dict = try SerializationFixtures.plan(populated: true).asDictionary()
        for key in Self.planNumericKeys {
            XCTAssertTrue(
                dict[key] is NSNumber,
                "plan['\(key)'] is \(type(of: dict[key])), expected NSNumber — write .rawValue"
            )
        }
    }

    func testPlanCommitmentInfoIsOmittedWhenEmptyNotEmittedAsAnEmptyArray() throws {
        // PLYPlan+Hybrid.m:120 guards on `count > 0`, not on nil. An `if let`
        // in the Swift port would emit [] and the JS layer would stop reading
        // the key as absent.
        let dict = try SerializationFixtures.plan(populated: false).asDictionary()
        XCTAssertNil(dict["commitmentInfo"])
    }
}
```

Then add one section per remaining serializer, following the same four-test shape. The key tables, read off the four `.m` files in review:

| Type | Always present | Absent on the sparse fixture | Must be `NSNumber` |
|---|---|---|---|
| `PLYProduct` | `vendorId`, `plans` | `name` | — |
| `PLYSubscription` | `plan`, `product`, `subscriptionSource` | `nextRenewalDate`, `cancelledDate`, `commitmentProgress` | `subscriptionSource` |
| `PLYOfferSignature` | `planVendorId`, `identifier`, `signature`, `keyIdentifier`, `nonce`, `timestamp` | **none** | `timestamp` |
| `PLYPresentationPlan` | `default` | `offerId`, `offerVendorId`, `storeProductId`, `planVendorId` | `default` |

`PLYProduct["plans"]` is an array of dictionaries and must be `[]`, never absent, when the native array is empty.

- [ ] **Step 4: Run the test against the Objective-C categories**

```bash
cd example/ios && pod install
UDID=$(xcrun simctl list devices booted -j | jq -r '[.devices[][]][0].udid')
xcodebuild test -workspace example.xcworkspace \
  -scheme react-native-purchasely-Unit-Tests \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

Expected: every test PASSES. A compile error fails the whole bundle, so there is no "some pass, some fail" state to aim for — get it compiling first.

If a key assertion fails, **the test is wrong, not the code**: go back to Step 1 and correct the sets from the `.m` files. That is the only acceptable reason to edit this file after this task.

- [ ] **Step 5: Commit**

```bash
git add packages/purchasely/ios/PurchaselyTests/SerializationFixtures.swift \
        packages/purchasely/ios/PurchaselyTests/SerializationContractTests.swift
git commit -m "test(ios): lock the serialization contract before the Swift port

Snapshots the key sets, the per-field absence policy and the value types
the Objective-C categories produce today, on a populated and a sparse
fixture each, so the Swift port cannot change them silently. The absence
policy is the live hazard: Swift removes a key assigned nil, and types.ts
documents to clients which keys the iOS bridge omits.

Fixtures are decoded from JSON because no SDK model type has a
no-argument initializer."
```

---

## Task 2: Port `PLYPlan+Hybrid` to Swift

The largest serializer (145 lines) and the only one whose header other Objective-C files import.

**Files:**
- Create: `packages/purchasely/ios/Classes/Serialization/PLYPlan+Bridge.swift`
- Delete: `packages/purchasely/ios/Classes/Hybrid/PLYPlan+Hybrid.{h,m}`
- Modify: `packages/purchasely/ios/PurchaselyRN.m` — the `#import` at `:13`, the calls at `:1189` and `:1209`, and the eligibility call at `:647`
- Modify: `packages/purchasely/ios/Classes/Hybrid/PLYProduct+Hybrid.m:9` — it imports `PLYPlan+Hybrid.h`
- Modify: `packages/purchasely/ios/Classes/Hybrid/Purchasely_Hybrid.h:11`
- Test: none edited. `SerializationContractTests` must pass unchanged.

**Interfaces produced,** all callable from Objective-C during phase 1:
- `PLYPlan.asDictionary() -> [String: Any]` — `@objc public func`, **a method, not a property**, so the call shape is identical to the Objective-C category's in both languages
- `PLYPlan.rnString(fromBillingPlanType:) -> String` — `@objc public static func`, selector `rnStringFromBillingPlanType:`
- `PLYPlan.billingPlanType(fromRNString:) -> PLYBillingPlanType` — `@objc public static func`, selector `billingPlanTypeFromRNString:`

**Not produced: no eligibility wrapper.** The first draft wrapped `isEligibleForIntroductoryOffer`, which recursed into itself. The SDK method is `isUserEligibleForIntroductoryOffer(completion:)` and it is already `@objc`, so the wrapper has no reason to exist — Step 4 repoints the one caller at the SDK directly.

- [ ] **Step 1: Confirm the baseline is green**

Run the test command of Global Constraint 13. Expected: `SerializationContractTests` PASSES against the Objective-C category. This is the baseline the port must not move.

- [ ] **Step 2: Find every Objective-C consumer of the header you are about to delete**

```bash
cd packages/purchasely/ios
rg -n 'PLYPlan\+Hybrid.h|asDictionary|PLYBillingPlanType(To|From)RNString|isEligibleForIntroductoryOffer' \
  PurchaselyRN.m Classes/Hybrid/
```

Expected hits, all of which this task must handle:

| Site | What it needs |
|---|---|
| `Classes/Hybrid/Purchasely_Hybrid.h:11` | drop the import |
| `Classes/Hybrid/PLYProduct+Hybrid.m:9` | drop the import; it calls `plan.asDictionary` on each plan, which keeps working through the generated Swift header |
| `PurchaselyRN.m:13` | drop the import |
| `PurchaselyRN.m:1189` | `PLYBillingPlanTypeFromRNString(x)` → `[PLYPlan billingPlanTypeFromRNString:x]` |
| `PurchaselyRN.m:1209` | `PLYBillingPlanTypeToRNString(x)` → `[PLYPlan rnStringFromBillingPlanType:x]` |
| `PurchaselyRN.m:647` | `isEligibleForIntroductoryOffer:` → `isUserEligibleForIntroductoryOfferWithCompletion:` |

If `rg` finds a site not in this table, handle it too and note it in the commit.

- [ ] **Step 3: Write `PLYPlan+Bridge.swift`**

Read `ios/Classes/Hybrid/PLYPlan+Hybrid.m` in full first, then translate key for key in source order. **Verify every SDK accessor against the interface (Global Constraint 0) before you write it** — the first draft of this plan used `price(with:)`, which does not exist; the real accessor is `localizedFullPrice(language:)` (`.swiftinterface:691`).

```swift
//
//  PLYPlan+Bridge.swift
//  Serializes a PLYPlan for the React Native bridge.
//  Ported from PLYPlan+Hybrid.m. The key set, the per-key absence policy and
//  the value types are a client contract — see SerializationContractTests and
//  types.ts.
//
//  `asDictionary()` is a METHOD, matching how the Objective-C category imported
//  into Swift, so the contract tests read the same before and after the port.
//
//  `@objc public` is temporary: PurchaselyRN.m and PLYProduct+Hybrid.m still
//  call this during phase 1, and a framework-layout target's generated header
//  carries only public declarations. Task 14 reduces it to `internal`.
//

import Foundation
import Purchasely

@objc public extension PLYPlan {

    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        // Unconditional keys, in PLYPlan+Hybrid.m order so a diff of the two
        // files reads straight down. `.rawValue` on the enum — Constraint 5.
        dict["vendorId"] = vendorId
        dict["type"] = type.rawValue

        // Guarded keys: Objective-C omitted them when nil, so Swift must too.
        // Write the guard explicitly even though `dict[k] = nil` also removes
        // the key: it documents the policy and it survives a later edit that
        // introduces a non-optional default.
        if let name {
            dict["name"] = name
        }

        // commitmentInfo: `count > 0` on a NON-optional array (Constraint 6).
        // `if let` here would emit [] and break the JS reader.
        if !commitmentInfo.isEmpty {
            dict["commitmentInfo"] = commitmentInfo.map { /* per m:97-109 */ }
        }

        return dict
    }

    // MARK: - billing plan type wire values

    /// Replaces the C function `PLYBillingPlanTypeToRNString`. A free Swift
    /// function cannot be `@objc`, so this is a static member and
    /// `PurchaselyRN.m` calls `[PLYPlan rnStringFromBillingPlanType:x]`.
    @objc(rnStringFromBillingPlanType:)
    static func rnString(fromBillingPlanType type: PLYBillingPlanType) -> String {
        // Verify these case names against the interface before compiling.
        switch type {
        case .upFront: return "upFront"
        case .monthly: return "monthly"
        case .unspecified: return "unspecified"
        @unknown default: return "unspecified"
        }
    }

    /// Replaces `PLYBillingPlanTypeFromRNString`. Unknown and nil map to
    /// `.unspecified`, as the C function did.
    @objc(billingPlanTypeFromRNString:)
    static func billingPlanType(fromRNString value: String?) -> PLYBillingPlanType {
        switch value {
        case "upFront": return .upFront
        case "monthly": return .monthly
        default: return .unspecified
        }
    }
}
```

```bash
# before compiling, confirm the enum and the accessors
SI=example/ios/Pods/Purchasely/Purchasely/Frameworks/Purchasely.xcframework/ios-arm64_x86_64-simulator/Purchasely.framework/Modules/Purchasely.swiftmodule/arm64-apple-ios-simulator.swiftinterface
rg -n -A6 'enum PLYBillingPlanType' "$SI"
awk '/class PLYPlan :/,/^}/' "$SI"
```

- [ ] **Step 4: Update all six Objective-C sites from Step 2's table**

The generated Swift header is already imported at `PurchaselyRN.m:24-28`, so no new import is needed there. `PLYProduct+Hybrid.m` needs that same `#if __has_include` block, copied verbatim from `PurchaselyRN.m:24-28`, in place of its `PLYPlan+Hybrid.h` import.

At `:647` the call becomes:

```objc
[plan isUserEligibleForIntroductoryOfferWithCompletion:^(BOOL isEligible) { ... }];
```

That is the SDK's own `@objc` method. Confirm the exact Objective-C selector before editing:

```bash
rg -n 'isUserEligibleForIntroductoryOffer' \
  example/ios/Pods/Headers/Public/Purchasely/Purchasely-Swift.h 2>/dev/null \
  || rg -n 'isUserEligibleForIntroductoryOffer' "$SI"
```

- [ ] **Step 5: Delete the Objective-C category and reinstall the pod**

```bash
git rm packages/purchasely/ios/Classes/Hybrid/PLYPlan+Hybrid.h \
       packages/purchasely/ios/Classes/Hybrid/PLYPlan+Hybrid.m
cd example/ios && pod install
```

- [ ] **Step 6: Run the tests and both builds**

Run all four commands in Global Constraint 13. Expected: tests PASS with `SerializationContractTests` unedited, and both builds succeed.

The framework-layout build is not optional here: it is the one that catches `@objc internal` instead of `@objc public`, and it fails nowhere else.

- [ ] **Step 7: Restore the default pod install and commit**

```bash
cd example/ios && pod install
git add -A packages/purchasely/ios example/ios/Podfile.lock
git commit -m "refactor(ios): port the PLYPlan serializer to Swift

The two FOUNDATION_EXPORT C mappers become @objc static members, since a
free Swift function cannot be @objc, and all six Objective-C call sites
move with them — PLYProduct+Hybrid.m imported that header too.

asDictionary stays a method, not a property, so its call shape is
identical in Objective-C and Swift and the contract tests are untouched.

The intro-offer eligibility category method is deleted rather than
ported: the SDK's own isUserEligibleForIntroductoryOffer is already
@objc, so the one caller now uses it directly."
```

---

## Task 3: Port the four remaining dictionary serializers

**Files:**
- Create: `packages/purchasely/ios/Classes/Serialization/PLYProduct+Bridge.swift`
- Create: `packages/purchasely/ios/Classes/Serialization/PLYSubscription+Bridge.swift`
- Create: `packages/purchasely/ios/Classes/Serialization/PLYOfferSignature+Bridge.swift`
- Create: `packages/purchasely/ios/Classes/Serialization/PLYPresentationPlan+Bridge.swift`
- Delete: the four matching `Classes/Hybrid/*+Hybrid.{h,m}` pairs
- Modify: `packages/purchasely/ios/Classes/Hybrid/Purchasely_Hybrid.h`

**Interfaces:**
- Consumes: the `@objc public extension` pattern established in Task 2.
- Produces: `asDictionary() -> [String: Any]` as an `@objc public func` — **a method, not a property** — on each of the four types.

- [ ] **Step 1: Run the tests to confirm the four sections currently pass**

Run the command in Task 1 Step 3. Expected: PASS against the Objective-C categories. This is the baseline the port must not move.

- [ ] **Step 2: Port the four files**

One file each, same shape as Task 2 Step 3, same header comment. Translate key for key, in source order, from the matching `.m`. The four rules that decide correctness:

- **Read the guard, then choose the Swift form** (Constraint 6). `if (x != nil)` → `if let`. `count > 0` on a non-optional array → `if !isEmpty`. A guard on a non-optional value is dead code and the key is unconditional — `PLYOfferSignature`'s `nonce` and `timestamp` are exactly that, so both keys are always present.
- **Every enum value gets `.rawValue`** (Constraint 5). In these four files that is `PLYSubscription.subscriptionSource` (`PLYSubscription+Hybrid.m:18`) and `PLYPresentationPlan.default`. `PLYProduct+Hybrid.m` has **no** `type` key — do not add one.
- **An empty array serializes to `[]`, it does not vanish:** `dict["plans"] = plans.map { $0.asDictionary() }`. Check whether `plans` is optional in the interface before adding a `??`.
- **`asDictionary()` is a method** on the type you are porting and on every type it calls into.

`PLYSubscription+Bridge.swift` carries the date formatting. Keep the format string byte-identical:

```swift
private let ply_bridgeDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    // Byte-identical to PLYSubscription+Hybrid.m. The JS layer parses this.
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    return formatter
}()

@objc public extension PLYSubscription {
    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["plan"] = plan.asDictionary()
        dict["subscriptionSource"] = subscriptionSource.rawValue
        // Omitted when nil — types.ts:138-141 documents this to clients as the
        // one place iOS and Android deliberately differ.
        if let next = nextRenewalDate {
            dict["nextRenewalDate"] = ply_bridgeDateFormatter.string(from: next)
        }
        if let cancelled = cancelledDate {
            dict["cancelledDate"] = ply_bridgeDateFormatter.string(from: cancelled)
        }
        return dict
    }
}
```

A file-scope `let` in Swift is initialized lazily and thread-safely, so the formatter is created once instead of per call as the Objective-C code did. That is a behaviour improvement with no contract effect: `DateFormatter` is thread-safe for reading after configuration.

- [ ] **Step 3: Delete the four Objective-C pairs, drop their imports, reinstall**

```bash
cd packages/purchasely/ios/Classes/Hybrid
git rm PLYProduct+Hybrid.h PLYProduct+Hybrid.m PLYSubscription+Hybrid.h PLYSubscription+Hybrid.m \
       PLYOfferSignature+Hybrid.h PLYOfferSignature+Hybrid.m \
       PLYPresentationPlan+Hybrid.h PLYPresentationPlan+Hybrid.m
cd ../../../../../example/ios && pod install
```

Edit `Purchasely_Hybrid.h` so it imports only what still exists.

- [ ] **Step 4: Run the tests and both builds**

Run all four commands in Global Constraint 13. Expected: all PASS with no assertion edited, and both builds succeed. A failure on an absence test means a guard was translated to the wrong Swift form in Step 2.

- [ ] **Step 5: Commit**

```bash
git add -A packages/purchasely/ios example/ios/Podfile.lock
git commit -m "refactor(ios): port the four remaining serializers to Swift

Each guarded Objective-C assignment keeps an explicit if-let, because
Swift removes a key assigned nil and types.ts documents which keys the
iOS bridge omits. Enum values are written as .rawValue: a Swift enum in
[String: Any] bridges to a box the RN bridge drops silently."
```

---

## Task 4: Port the hex parser, delete the unused UIKit category, close phase 1

**Files:**
- Create: `packages/purchasely/ios/Classes/Serialization/UIColor+PLYHex.swift`
- Delete: `packages/purchasely/ios/Classes/Hybrid/` in full (`UIColor+PLYHelper.{h,m}`, `UIViewController+Hybrid.{h,m}`, `Purchasely_Hybrid.h`)
- Modify: `packages/purchasely/ios/PurchaselyRN.m` (remove the `Purchasely_Hybrid.h` and `UIColor+PLYHelper.h` imports at `:13-14`)
- Modify: `packages/purchasely/react-native-purchasely.podspec`
- Modify: `packages/purchasely/ios/PurchaselyTests/PurchaselyRNTests.m` (drop the `UIViewController` category tests, if any)

**Interfaces:**
- Consumes: nothing from Tasks 2–3.
- Produces: `UIColor.ply_fromHex(_:) -> UIColor?` (`@objc public static func`, selector `ply_fromHex:`).

- [ ] **Step 1: Prove the UIViewController category has no caller**

```bash
cd packages/purchasely
rg -n 'ply_close|\] close\]|\.close\(\)' ios/ src/
rg -n 'UIViewController' ios/
```

Expected: the only `close` calls are on `PLYPresentation` (`PurchaselyRN.m:1822`) and on `PLYPresentationRequest`, both protocol methods of the SDK, not this category. If a real caller appears, **stop and report** — the spec's decision to delete rather than port assumed there is none.

- [ ] **Step 2: Write the failing hex-parser test**

Append to `SerializationContractTests.swift`:

```swift
    // MARK: - UIColor hex parsing

    func testHexParserAcceptsTheFormsTheBackendSends() {
        // Values and expectations read off UIColor+PLYHelper.m. A paywall's
        // JSON carries colours in these forms.
        // UIColor+PLYHelper.m accepts RRGGBB and RRGGBBAA, with or without a
        // leading '#', after trimming whitespace. Nothing else.
        func rgba(_ hex: String) -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
            guard let color = UIColor.ply_fromHex(hex) else { return nil }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (r, g, b, a)
        }

        for form in ["#FF0000", "FF0000", "  #FF0000  "] {
            // `guard let (a, b) = optionalTuple` does not compile; the pattern
            // needs `case let ...?`.
            guard case let (r, g, b, a)? = rgba(form) else {
                return XCTFail("'\(form)' must parse")
            }
            XCTAssertEqual(r, 1.0, accuracy: 0.01, form)
            XCTAssertEqual(g, 0.0, accuracy: 0.01, form)
            XCTAssertEqual(b, 0.0, accuracy: 0.01, form)
            XCTAssertEqual(a, 1.0, accuracy: 0.01, form)
        }

        // RRGGBBAA: the alpha byte is last.
        guard case let (_, _, _, alpha)? = rgba("#00000080") else {
            return XCTFail("8-digit form must parse")
        }
        XCTAssertEqual(alpha, 0.5, accuracy: 0.01)
    }

    func testHexParserRejectsGarbageInsteadOfTrapping() {
        // The nil case stays commented out until Step 5: the Objective-C
        // parameter is non-optional, so it does not compile before then.
        XCTAssertNil(UIColor.ply_fromHex(nil))
        XCTAssertNil(UIColor.ply_fromHex(""))
        XCTAssertNil(UIColor.ply_fromHex("   "))
        XCTAssertNil(UIColor.ply_fromHex("#12"))       // too short
        XCTAssertNil(UIColor.ply_fromHex("#1234567"))  // 7 digits
        // Behaviour change: the Objective-C version ignored the scanner
        // result and returned opaque black here. See the Task 4 commit.
        XCTAssertNil(UIColor.ply_fromHex("#GGGGGG"))   // 6 chars, not hex
    }
```

Before writing the expectations, read `UIColor+PLYHelper.m:14-66` and add one case per accepted form it handles (3, 6 and 8 digits, with and without `#`, whatever it really supports). Do not invent forms it rejects today.

- [ ] **Step 3: Run to see exactly how it fails**

Run the test command of Global Constraint 13.

The pod's umbrella header already imports `UIColor+PLYHelper.h`, so Swift **can** see the Objective-C `ply_fromHex` today. Two specific failures are expected, and they matter:

1. **Compile error on `ply_fromHex(nil)`.** The Objective-C parameter is non-optional `NSString *`, so the `nil` case cannot be written until the Swift version exists. Comment out that line with `// TODO(step-5)` and re-run.
2. **`"#GGGGGG"` returns opaque black, not nil.** `UIColor+PLYHelper.m:33-34` calls `scanHexInt:` and casts the result to `(void)`, ignoring failure, so a non-hex 6-character string scans to 0 and produces black.

That second one is a **deliberate behaviour change**, not a port: the Swift version returns nil. It is the right change — a malformed colour should fall back, not silently paint a paywall black — but it must be labelled. Keep the assertion, mark it `// behaviour change, see the commit message`, and expect it red until Step 4.

- [ ] **Step 4: Port the parser**

Source: `UIColor+PLYHelper.m:14-66`. It trims whitespace, strips one leading `#`, rejects anything that is not 6 or 8 hex digits, and scans with `NSScanner`.

```swift
//
//  UIColor+PLYHex.swift
//  Ported from UIColor+PLYHelper.m. Parses the colour forms a paywall's
//  backend JSON carries. `@objc public` is temporary — see PLYPlan+Bridge.swift.
//

import UIKit

@objc public extension UIColor {

    /// Returns nil for any string it cannot parse. Never traps: the input is
    /// backend data, not a local constant.
    @objc(ply_fromHex:)
    static func ply_fromHex(_ hex: String?) -> UIColor? {
        guard var string = hex?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else { return nil }

        if string.hasPrefix("#") {
            string.removeFirst()
        }
        // UIColor+PLYHelper.m accepts RRGGBB and RRGGBBAA only. It does NOT
        // accept the 3-digit short form — do not add it here, that would be a
        // behaviour change dressed up as a port.
        guard string.count == 6 || string.count == 8,
              let code = UInt32(string, radix: 16) else { return nil }

        // The Objective-C version used NSScanner and ignored its result, so a
        // string such as "GGGGGG" scanned to 0 and produced opaque black.
        // UInt32(_:radix:) returns nil instead, which is strictly better and
        // the reason testHexParserRejectsGarbageInsteadOfTrapping exists.
        func channel(_ shift: UInt32) -> CGFloat {
            CGFloat((code >> shift) & 0xff) / 0xff
        }

        if string.count == 6 {
            return UIColor(red: channel(16), green: channel(8), blue: channel(0), alpha: 1.0)
        }
        return UIColor(red: channel(24), green: channel(16), blue: channel(8), alpha: channel(0))
    }
}
```

- [ ] **Step 5: Uncomment the nil case and run the tests**

Restore the `ply_fromHex(nil)` assertion — the Swift parameter is `String?`, so it compiles now — and delete the `TODO(step-5)` marker. Run all four commands in Global Constraint 13. Expected: all PASS, both builds succeed.

- [ ] **Step 6: Delete the rest of `Classes/Hybrid/`, fix the imports, add `swift_versions`**

```bash
git rm -r packages/purchasely/ios/Classes/Hybrid
```

In `packages/purchasely/ios/PurchaselyRN.m`, delete the two now-dangling imports:

```objc
#import "Purchasely_Hybrid.h"
#import "UIColor+PLYHelper.h"
```

In `packages/purchasely/react-native-purchasely.podspec`, after `s.requires_arc = true`:

```ruby
  # The pod is Swift-majority since 6.2.0. CocoaPods warns without this.
  s.swift_versions = ['5.0']
```

Delete any `UIViewController` category test from `PurchaselyRNTests.m`.

- [ ] **Step 7: Verify the directory is gone and everything builds**

```bash
cd /Users/kevin/Purchasely/React_Native
fd . packages/purchasely/ios/Classes    # expect: only Serialization/*.swift
cd example/ios && pod install
UDID=$(xcrun simctl list devices booted -j | jq -r '[.devices[][]][0].udid')
xcodebuild test -workspace example.xcworkspace -scheme react-native-purchasely-Unit-Tests \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
xcodebuild -workspace example.xcworkspace -scheme example -destination "id=$UDID" \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```

Expected: tests PASS, `BUILD SUCCEEDED`, and `fd` lists 6 Swift files and nothing else.

- [ ] **Step 8: Commit and open the phase 1 pull request**

```bash
git add -A packages/purchasely example/ios/Podfile.lock
git commit -m "refactor(ios): finish the serialization port, drop Classes/Hybrid

The UIViewController (Hybrid) category is deleted, not ported: it has no
caller ([presentation close] is the PLYPresentation protocol method), and
a library that adds a -close selector to every view controller in the
host app is a liability with no user.

One deliberate behaviour change in the hex parser: the Objective-C version
cast scanHexInt:'s result to (void), so a malformed 6-character string such
as #GGGGGG scanned to 0 and painted opaque black. The Swift version returns
nil and the caller falls back. Every well-formed input parses identically.

Adds s.swift_versions to the podspec, now that the pod is Swift-majority."
git push -u origin feat/ios-swift-serialization
gh pr create --base main --title "refactor(ios): port the bridge serialization to Swift" \
  --body "Phase 1 of the iOS Objective-C to Swift migration. Spec: docs/superpowers/specs/2026-09-08-ios-bridge-swift-migration-design.md

540 lines of Objective-C categories become 6 Swift files. No exported method moves and no bridge contract is touched.

The safety net is SerializationContractTests, written first against the Objective-C output: key sets, per-field absence policy, and enum value types. Not one assertion was edited to make a port pass.

Phase 2 (the 2086-line module) is a separate PR."
```

Wait for CI green, including `iOS Build (use_frameworks!)` and `e2e-ios` T1–T30, before starting Task 5.

---

# PHASE 2 — The module (Pull Request 2)

Branch: `feat/ios-swift-bridge`, based on `main` after phase 1 merges.

**The sequencing rule for this phase.** A Swift `@objc(PurchaselyRN)` class cannot coexist with the Objective-C `PurchaselyRN` class: duplicate Objective-C class names. So Tasks 8–13 build the Swift class under the temporary name **`PurchaselyBridge`**, with **no export macro of any kind**, so React Native never sees two modules claiming the name `Purchasely` (Global Constraint: the `81c5a65` class of failure). Task 14 renames it and deletes the Objective-C implementation in one commit. Until Task 14 the Swift class is unregistered code that compiles and is unit-tested through `@testable import`.

## Task 5: Lock the module's export contract before touching it

Like Task 1, this runs against the **current Objective-C module** and must be green before any port. It is the gate the spec's section 7 describes.

**Files:**
- Create: `packages/purchasely/ios/PurchaselyTests/BridgeExportContractTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `BridgeExportContractTests`, which Tasks 8–14 must keep green. Task 14 is the one that proves it has teeth.

- [ ] **Step 1: Write the failing test**

The gate reads React Native's own export table. `RCT_EXPORT_METHOD` and `RCT_EXTERN_METHOD` both generate a class method named `__rct_export__…` returning `const RCTMethodInfo *` (`RCTBridgeModule.h:322-329`), and `RCTMethodInfo` is `{ const char *const jsName; const char *const objcName; const BOOL isSync; }` (`RCTBridgeModule.h:53-57`). The JS name is `jsName` when non-empty, else `objcName` up to its first colon, trimmed — copied from `RCTModuleMethod.mm:485-508`.

Create `packages/purchasely/ios/PurchaselyTests/BridgeExportContractTests.swift`:

```swift
//
//  BridgeExportContractTests.swift
//  The parity gate for the Objective-C → Swift port of the bridge module.
//
//  The export shim is parsed as TEXT at registration, not linked: a Swift
//  @objc signature that disagrees with its RCT_EXTERN_METHOD line produces no
//  compile error and fails at run time in a client app with "method not
//  found". This test turns all 63 of those runtime risks into one CI failure.
//
//  It reads the same table React Native reads. RCTMethodInfo comes from
//  RCTBridgeModule.h, which the pod's umbrella already exposes, so this file
//  needs no import beyond the pod itself.
//

import XCTest
import ObjectiveC
@testable import react_native_purchasely

final class BridgeExportContractTests: XCTestCase {

    // MARK: - the contract

    /// The 63 JS method names `src/` calls on `NativeModules.Purchasely`.
    /// This is the client contract. Adding a name here is a feature; losing
    /// one is a breaking change. Generated with:
    ///   rg -o 'RCT_(EXPORT|REMAP)_METHOD\((\w+)' -r '$2' ios/PurchaselyRN.m
    static let expectedJSNames: Set<String> = [
        "start", "isEligibleForIntroOffer", "setLogLevel", "userLogin",
        "handleDeeplink", "userLogout", "isAnonymous", "setThemeMode",
        "setAttribute", "setUserAttributeWithString",
        "setUserAttributeWithBoolean", "setUserAttributeWithNumber",
        "setUserAttributeWithInt", "setUserAttributeWithDouble",
        "setUserAttributeWithDate", "setUserAttributeWithStringArray",
        "setUserAttributeWithBooleanArray", "setUserAttributeWithNumberArray",
        "setUserAttributeWithIntArray", "setUserAttributeWithDoubleArray",
        "incrementUserAttribute", "decrementUserAttribute", "userAttribute",
        "userAttributes", "clearUserAttribute", "clearUserAttributes",
        "clearBuiltInAttributes", "getBuiltInAttributes", "getBuiltInAttribute",
        "setLanguage", "userDidConsumeSubscriptionContent",
        "getAnonymousUserId", "readyToOpenDeeplink", "allowDeeplink",
        "allowCampaigns", "signPromotionalOffer", "purchaseWithPlanVendorId",
        "restoreAllProducts", "silentRestoreAllProducts", "synchronize",
        "allProducts", "productWithIdentifier", "planWithIdentifier",
        "userSubscriptions", "userSubscriptionsHistory", "setDynamicOffering",
        "getDynamicOfferings", "removeDynamicOffering", "clearDynamicOfferings",
        "revokeDataProcessingConsent", "setDebugMode", "closeAllScreens",
        "preloadPresentation", "displayPresentation",
        "setDefaultPresentationDismissHandler",
        "removeDefaultPresentationDismissHandler", "closePresentation",
        "goBackToPreviousScreen", "clientPresentationDisplayed",
        "clientPresentationClosed", "registerActionInterceptor",
        "unregisterActionInterceptor", "completeActionInterceptor",
    ]

    /// The 11 event names. `src/` subscribes to these by string.
    static let expectedEvents: [String] = [
        "PURCHASELY_EVENTS",
        "PURCHASE_LISTENER",
        "USER_ATTRIBUTE_SET_LISTENER",
        "USER_ATTRIBUTE_REMOVED_LISTENER",
        "WEB_REDEMPTION_LISTENER",
        "PURCHASELY_PRESENTATION_LOADED",
        "PURCHASELY_PRESENTATION_PRESENTED",
        "PURCHASELY_PRESENTATION_CLOSE_REQUESTED",
        "PURCHASELY_PRESENTATION_DISMISSED",
        "PURCHASELY_DEFAULT_PRESENTATION_DISMISSED",
        "PURCHASELY_ACTION_INTERCEPTED",
    ]

    /// The 60 constant keys. `enums.ts:4` builds the JS enums from them, so a
    /// lost key is a `undefined` enum member in a client app.
    static let expectedConstantKeys: Set<String> = [
        "logLevelDebug", "logLevelInfo", "logLevelWarn", "logLevelError",
        "productResultPurchased", "productResultCancelled",
        "productResultRestored", "sourceAppStore", "sourcePlayStore",
        "sourceHuaweiAppGallery", "sourceAmazonAppstore", "sourceStripe",
        "sourceNone", "firebaseAppInstanceId", "airshipChannelId",
        "airshipUserId", "batchInstallationId", "adjustId", "appsflyerId",
        "oneSignalExternalId", "oneSignalUserId", "mixpanelDistinctId",
        "clevertapId", "sendinblueUserEmail", "iterableUserId",
        "iterableUserEmail", "atInternetIdClient", "amplitudeUserId",
        "amplitudeDeviceId", "mparticleUserId", "customerIoUserId",
        "customerIoUserEmail", "branchUserDeveloperIdentity",
        "moEngageUniqueId", "batchCustomUserId", "consumable",
        "nonConsumable", "autoRenewingSubscription", "nonRenewingSubscription",
        "unknown", "runningModeObserver", "runningModeFull",
        "presentationTypeNormal", "presentationTypeFallback",
        "presentationTypeDeactivated", "presentationTypeClient",
        "themeLight", "themeDark", "themeSystem",
        "userAttributeSourcePurchasely", "userAttributeSourceClient",
        "userAttributeString", "userAttributeBoolean", "userAttributeInt",
        "userAttributeFloat", "userAttributeDate",
        "userAttributeStringArray", "userAttributeIntArray",
        "userAttributeFloatArray", "userAttributeBooleanArray",
    ]

    // MARK: - the tests

    func testModuleIsExportedAsPurchasely() {
        // RCT_EXPORT_MODULE_NO_LOAD defines +moduleName (RCTBridgeModule.h:100).
        // The plain RCT_EXTERN_MODULE form would make this "PurchaselyRN" and
        // break every JS call.
        XCTAssertEqual(PurchaselyRN.moduleName(), "Purchasely")
    }

    func testExportedJSNamesAreExactlyTheContract() {
        let actual = Self.exportedJSNames()
        XCTAssertEqual(
            actual, Self.expectedJSNames,
            """
            Exported JS names drifted.
              missing: \(Self.expectedJSNames.subtracting(actual).sorted())
              extra:   \(actual.subtracting(Self.expectedJSNames).sorted())
            A missing name is a breaking change for client apps.
            """
        )
    }

    func testExportedMethodCountMatches() {
        XCTAssertEqual(Self.exportedEntries().count, 63)
    }

    func testConstantsToExportKeepsAllSixtyKeys() {
        let constants = PurchaselyRN().constantsToExport() as? [String: Any] ?? [:]
        let actual = Set(constants.keys)
        XCTAssertEqual(
            actual, Self.expectedConstantKeys,
            """
            constantsToExport drifted.
              missing: \(Self.expectedConstantKeys.subtracting(actual).sorted())
              extra:   \(actual.subtracting(Self.expectedConstantKeys).sorted())
            enums.ts builds the JS enums from these keys.
            """
        )
    }

    func testEveryConstantIsANumberNotAnOpaqueEnumBox() {
        // Global constraint 5. Every one of the 60 values is a numeric ordinal
        // today. A Swift enum written without .rawValue would arrive undefined.
        for (key, value) in Self.liveConstants() {
            XCTAssertTrue(
                value is NSNumber,
                "constant '\(key)' is \(type(of: value)), expected NSNumber — write .rawValue"
            )
        }
    }

    /// The 60 constants with their exact numeric values, captured from the
    /// Objective-C module before the port.
    ///
    /// The key set alone is not enough: an ordinal can change without any key
    /// changing, and `enums.ts` maps these numbers straight into the JS enums,
    /// so a shifted value silently mislabels every event a client receives.
    /// Generate this dictionary ONCE, in Step 2, by printing the live values,
    /// then paste it here as a literal and never regenerate it.
    static let expectedConstants: [String: Int] = [
        // Paste Step 2's output here. Example shape:
        //   "logLevelDebug": 0,
        //   "productResultPurchased": 0,
    ]

    func testConstantValuesAreUnchanged() {
        let live = Self.liveConstants().compactMapValues { ($0 as? NSNumber)?.intValue }
        XCTAssertEqual(
            live, Self.expectedConstants,
            "a constant's numeric value changed; enums.ts maps these into the JS enums"
        )
    }

    /// `constantsToExport` is an optional protocol requirement, not a member of
    /// `PurchaselyRN.h`, so reach it through the protocol rather than calling it
    /// directly on the concrete type.
    static func liveConstants() -> [String: Any] {
        let module = PurchaselyRN()
        guard let bridgeModule = module as? RCTBridgeModule,
              let constants = type(of: bridgeModule).constantsToExport?() else {
            XCTFail("PurchaselyRN does not export constants")
            return [:]
        }
        return constants as? [String: Any] ?? [:]
    }

    func testSupportedEventsKeepsItsOrderAndContent() {
        let actual = PurchaselyRN().supportedEvents() as? [String] ?? []
        XCTAssertEqual(actual, Self.expectedEvents)
    }

    // MARK: - reading React Native's export table

    private typealias RCTExportFn =
        @convention(c) (AnyObject, Selector) -> UnsafePointer<RCTMethodInfo>

    /// Every (jsName, objcName) pair the module exports.
    ///
    /// Reads the metaclass method list, NOT the superclass chain: RCTEventEmitter
    /// exports addListener: and removeListeners: of its own
    /// (RCTEventEmitter.m:96,115), which would make the count 65.
    static func exportedEntries() -> [(jsName: String, objcName: String)] {
        // Labelled, matching the return type: Swift does not convert between
        // arrays of differently labelled tuples.
        var entries: [(jsName: String, objcName: String)] = []
        var count: UInt32 = 0
        guard let metaclass = object_getClass(PurchaselyRN.self),
              let methods = class_copyMethodList(metaclass, &count) else {
            return entries
        }
        defer { free(methods) }

        for index in 0..<Int(count) {
            let selector = method_getName(methods[index])
            guard NSStringFromSelector(selector).hasPrefix("__rct_export__") else {
                continue
            }
            let fn = unsafeBitCast(method_getImplementation(methods[index]), to: RCTExportFn.self)
            let info = fn(PurchaselyRN.self, selector).pointee
            let objcName = String(cString: info.objcName)
            entries.append((jsName(info: info, objcName: objcName), objcName))
        }
        return entries
    }

    static func exportedJSNames() -> Set<String> {
        Set(exportedEntries().map(\.jsName))
    }

    /// Copied from RCTModuleMethod.mm:485-508 so the test agrees with the
    /// runtime instead of guessing.
    private static func jsName(info: RCTMethodInfo, objcName: String) -> String {
        if let raw = info.jsName {
            let explicit = String(cString: raw)
            if !explicit.isEmpty { return explicit }
        }
        let head = objcName.split(separator: ":", maxSplits: 1).first.map(String.init) ?? objcName
        return head.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 2: Capture the 60 constant values, then run the suite**

`expectedConstants` starts empty, so fill it from the live module first. Add a throwaway test that prints them, run it once, paste its output into the literal, then delete the throwaway:

```swift
func testPrintConstantsForTheLiteral() {
    let live = Self.liveConstants().compactMapValues { ($0 as? NSNumber)?.intValue }
    for (key, value) in live.sorted(by: { $0.key < $1.key }) {
        print("        \"\(key)\": \(value),")
    }
}
```

Then run the whole class:

```bash
cd example/ios
UDID=$(xcrun simctl list devices booted -j | jq -r '[.devices[][]][0].udid')
xcodebuild test -workspace example.xcworkspace -scheme react-native-purchasely-Unit-Tests \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO \
  -only-testing:react-native-purchasely-Unit-Tests/BridgeExportContractTests 2>&1 | tail -40
```

Expected: every test PASSES against the Objective-C module. A failure means one of the four literals is wrong — fix the literal from the live output, not the code.

- [ ] **Step 3: Prove the gate has teeth**

`RCT_EXPORT_METHOD(closeAllScreens)` at `PurchaselyRN.m:1289` is followed by a `{ ... }` body, so commenting out the macro line alone leaves a dangling block and a **compile error**, not a test failure. Replace the macro with a plain declaration instead, which un-exports the method while keeping the file valid:

```objc
// RCT_EXPORT_METHOD(closeAllScreens) {
- (void)closeAllScreens {
    dispatch_async(dispatch_get_main_queue(), ^{
        [Purchasely closeAllScreens];
    });
}
```

Re-run Step 2. Expected: `testExportedJSNamesAreExactlyTheContract` FAILS naming `closeAllScreens` missing, and `testExportedMethodCountMatches` FAILS with 62. Restore the macro and re-run: PASS.

Do not skip this step. A gate nobody has seen fail is not a gate.

- [ ] **Step 4: Commit**

```bash
git add packages/purchasely/ios/PurchaselyTests/BridgeExportContractTests.swift
git commit -m "test(ios): lock the bridge export contract before the Swift port

Reads React Native's own __rct_export__ table and asserts the 63 JS
method names, the module name, the 60 constant keys with numeric values,
and the 11 event names. The shim is parsed as text, so a Swift signature
that disagrees with it fails only at run time in a client app; this turns
that into a CI failure. Verified it fails when an export is removed."
```

---

## Task 6: Port the unit tests to Swift, before the implementation moves

Doing this first makes the test suite language-stable: Tasks 8–14 change the implementation under an unchanged Swift test file. A Swift test can already call the Objective-C `PurchaselyRN` class methods — `PurchaselyView.swift:110` does it in production.

**Files:**
- Create: `packages/purchasely/ios/PurchaselyTests/PurchaselyRNTests.swift`
- Delete: `packages/purchasely/ios/PurchaselyTests/PurchaselyRNTests.m`

**Interfaces:**
- Consumes: the Objective-C `PurchaselyRN` surface, unchanged.
- Produces: `PurchaselyRNTests`, a Swift XCTest that Tasks 8–14 keep green.

- [ ] **Step 1: Read the Objective-C tests and list what they assert**

```bash
rg -n '^- \(void\)test|^\s*XCTAssert' packages/purchasely/ios/PurchaselyTests/PurchaselyRNTests.m
```

535 lines. Note which tests exercise `sharedViewController`, `shouldReopenPaywall` or `presentedPresentationViewController` — Task 7 deletes those three members, so those tests go with them and must not be ported.

- [ ] **Step 2: Port test by test**

Create `PurchaselyRNTests.swift` with `import XCTest` and `@testable import react_native_purchasely`. **XCTest, not Swift Testing:** a CocoaPods test spec requires `XCTestCase` (`react-native-purchasely.podspec:26-29`).

Translation rules:

```swift
// Objective-C                                  Swift
// XCTAssertEqualObjects(a, b)          →       XCTAssertEqual(a, b)
// XCTAssertNil(a)                      →       XCTAssertNil(a)
// [NSNull null]                        →       NSNull()
// XCTestExpectation + waitForExpect…   →       unchanged (constraint 8 exempts tests)
// [PurchaselyRN requiresMainQueueSetup] →      see below: optional requirement
```

`constantsToExport`, `requiresMainQueueSetup` and `supportedEvents` are **optional protocol requirements** (`RCTBridgeModule.h:114`, `:340`, `:358`) and are not redeclared in `PurchaselyRN.h`, so a direct call on the concrete Swift type does not compile. Reach them through the protocol, as `BridgeExportContractTests.liveConstants()` does:

```swift
guard let requires = (PurchaselyRN.self as? RCTBridgeModule.Type)?.requiresMainQueueSetup?() else {
    return XCTFail("PurchaselyRN does not declare requiresMainQueueSetup")
}
XCTAssertTrue(requires)   // PurchaselyRN.m:1447 returns YES
```

For a method that exists on neither the header nor the protocol, use a runtime lookup (`NSSelectorFromString` plus `perform`) rather than adding it to the header just to satisfy a test.

The web-redemption body tests are the important ones. They assert which keys hold `NSNull` on a success and on a failure alike (`PurchaselyRN.h` documents the policy), which is exactly the behaviour Global Constraint 6 protects.

The five keys are `isSuccess`, `context`, `replay`, `errorCode`, `errorMessage` (`PurchaselyRN.m:1433-1439`). **There is no `error` key** — the first draft of this plan asserted one:

```swift
func testWebRedemptionBodyCarriesTheSameFiveKeysOnSuccessAndFailure() {
    let success = PurchaselyRN.webRedemptionBody(
        withSuccess: true, hasContext: false, subscription: nil,
        replay: false, errorCode: nil, errorMessage: nil
    )
    let failure = PurchaselyRN.webRedemptionBody(
        withSuccess: false, hasContext: false, subscription: nil,
        replay: false, errorCode: "42", errorMessage: "boom"
    )
    XCTAssertEqual(Set(success.keys),
                   ["isSuccess", "context", "replay", "errorCode", "errorMessage"])
    XCTAssertEqual(Set(success.keys), Set(failure.keys))

    // NSNull, not an absent key: this payload's policy differs from the
    // subscription serializer's, and the JS shape must not change between a
    // success and a failure. See spec section 8.4.
    XCTAssertTrue(success["errorCode"] is NSNull)
    XCTAssertTrue(success["errorMessage"] is NSNull)
    XCTAssertTrue(success["context"] is NSNull)
    XCTAssertEqual(failure["errorCode"] as? String, "42")
}
```

Check the real Swift name of `+webRedemptionBodyWithSuccess:hasContext:subscription:replay:errorCode:errorMessage:` before writing it; the Swift importer decides it, and Task 12 must produce whatever name this test uses.

Two more translation notes for this file:

- **The event-recorder subclass.** `PurchaselyRNTests.m:479-506` subclasses `PurchaselyRN` and overrides `sendEventWithName:body:` to capture emissions, which is how `emitPresentationCloseRequestedForId:` is tested. Keep that pattern in Swift: `private final class RecordingBridge: PurchaselyRN { override func sendEvent(withName name: String!, body: Any!) { ... } }`. Task 12 must therefore keep `emitPresentationCloseRequested(forId:)` reachable.
- **`shouldEmit` is declared `Boolean`,** not `BOOL` (`PurchaselyRN.h:38`). Objective-C's `Boolean` imports into Swift as `UInt8`, so compare it against `0` until Task 8 replaces it with a real Swift `Bool`.

- [ ] **Step 3: Run the ported tests against the Objective-C implementation**

```bash
git rm packages/purchasely/ios/PurchaselyTests/PurchaselyRNTests.m
cd example/ios && pod install
xcodebuild test -workspace example.xcworkspace -scheme react-native-purchasely-Unit-Tests \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

Expected: every ported test PASSES, and the count of executed tests is at least what `PurchaselyRNTests.m` ran minus the ones tied to the three dead members.

- [ ] **Step 4: Commit**

```bash
git add -A packages/purchasely/ios/PurchaselyTests example/ios/Podfile.lock
git commit -m "test(ios): port the bridge unit tests to Swift XCTest

Done before the implementation moves, so the port of the module runs
under an unchanged Swift test file. XCTestCase, not Swift Testing: a
CocoaPods test spec requires it."
```

---

## Task 7: Delete the three dead members

Each is provably dead, and deleting them removes the hardest ownership question of the port instead of translating it.

**Files:**
- Modify: `packages/purchasely/ios/PurchaselyRN.h` (drop 3 property declarations)
- Modify: `packages/purchasely/ios/PurchaselyRN.m:362-376`, `:464`, `:1692`, `:1810`
- Modify: `packages/purchasely/ios/PurchaselyTests/PurchaselyRNTests.swift`

**Interfaces:**
- Consumes: `PurchaselyRNTests.swift` from Task 6.
- Produces: a `PurchaselyRN` with no `sharedViewController`, no `shouldReopenPaywall` and no `presentedPresentationViewController`.

- [ ] **Step 1: Re-prove they are dead**

```bash
cd packages/purchasely
rg -n 'sharedViewController|shouldReopenPaywall|presentedPresentationViewController' ios/ src/ ../../example/
```

Expected: `sharedViewController` appears only in its own accessor (`PurchaselyRN.m:362-376`), its header line, and the tests. `shouldReopenPaywall` appears at `:464` (a write) and its header line. `presentedPresentationViewController` appears at `:1692` and `:1810` (both writes) and its header line. **If any read appears in production code, stop and report.**

- [ ] **Step 2: Delete the tests that cover them**

Remove those test methods from `PurchaselyRNTests.swift`.

- [ ] **Step 3: Run to verify the suite is green without them**

Run the command in Task 6 Step 3. Expected: PASS.

- [ ] **Step 4: Delete the members**

In `PurchaselyRN.h`, delete:

```objc
@property (nonatomic, retain) UIViewController* presentedPresentationViewController;
@property (class, nonatomic, strong) UIViewController *sharedViewController;
@property (nonatomic, assign) Boolean shouldReopenPaywall;
```

In `PurchaselyRN.m`, delete the static at `:362`, the getter and setter at `:367-376`, the write at `:464`, and the two writes at `:1692` and `:1810`. At `:1692` the surrounding line is `strongSelf.presentedPresentationViewController = presentation.controller;` — delete only that statement, and check whether `strongSelf` still has another use in that block; if not, the `strongSelf` binding goes too.

- [ ] **Step 5: Run everything**

```bash
cd example/ios && xcodebuild test -workspace example.xcworkspace \
  -scheme react-native-purchasely-Unit-Tests -destination "id=$UDID" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
xcodebuild -workspace example.xcworkspace -scheme example -destination "id=$UDID" \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```

Expected: tests PASS, `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add -A packages/purchasely/ios
git commit -m "refactor(ios): drop three dead members of the bridge module

sharedViewController's only reader was its own accessor and a test;
shouldReopenPaywall was written once and never read; and
presentedPresentationViewController was written twice and never read.
Deleting them removes the trickiest ownership question of the Swift port
(class-wide mutable storage whose getter recreates a controller after its
setter receives nil) instead of translating it."
```

---

## Task 8: The Swift class skeleton, unregistered

**Files:**
- Create: `packages/purchasely/ios/PurchaselyRN.swift` (class name `PurchaselyBridge` until Task 14)
- Test: `packages/purchasely/ios/PurchaselyTests/BridgeSkeletonTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces, all used by Tasks 9–13:
  - `class PurchaselyBridge: RCTEventEmitter` — **no `@objc(...)` name, no export macro** (see the phase 2 sequencing rule)
  - `static func withState<T>(_ body: () -> T) -> T` — the scoped lock
  - `static var presentationsByRequest: [String: any PLYPresentation]`
  - `static var interceptorCallbacks: [String: (String) -> Void]`
  - `static var interceptorKinds: Set<String>`
  - `static func reject(_ reject: RCTPromiseRejectBlock, with error: Error?)`
  - `static func purchaseResultOrdinal(_:) -> NSNumber?` — Optional, `.none` → nil
  - `override init()`, which calls `Purchasely.setAppTechnology(.reactNative)`
  - the three delegate conformances, with stub bodies until Task 12
  - `override func constantsToExport() -> [AnyHashable: Any]!`
  - `override func supportedEvents() -> [String]!`
  - `override static func requiresMainQueueSetup() -> Bool`
  - `override func startObserving()` / `stopObserving()`
  - `func emitPresentationEvent(_ name: String, body: [String: Any]?)`

- [ ] **Step 1: Write the failing test**

Create `packages/purchasely/ios/PurchaselyTests/BridgeSkeletonTests.swift`:

```swift
import XCTest
@testable import react_native_purchasely

final class BridgeSkeletonTests: XCTestCase {

    func testConstantsMatchTheObjectiveCModuleExactly() {
        // The Swift class must produce the same 60 keys and the same values as
        // the module it replaces. Comparing the two directly is stronger than
        // comparing either to a literal list.
        let objc = PurchaselyRN().constantsToExport() as? [String: NSNumber] ?? [:]
        let swift = PurchaselyBridge().constantsToExport() as? [String: NSNumber] ?? [:]
        XCTAssertEqual(swift, objc)
    }

    func testSupportedEventsMatchTheObjectiveCModuleExactly() {
        let objc = PurchaselyRN().supportedEvents() as? [String] ?? []
        let swift = PurchaselyBridge().supportedEvents() as? [String] ?? []
        XCTAssertEqual(swift, objc)
    }

    func testRequiresMainQueueSetupIsTrue() {
        // PurchaselyRN.m:1447 returns YES. Asserted as a literal, not against
        // the Objective-C class, because a wrong value in BOTH would pass.
        XCTAssertTrue(PurchaselyBridge.requiresMainQueueSetup())
    }

    func testSequentialLockedBlocksDoNotDeadlock() {
        // Constraint 7 in one assertion: two sequential withState calls are the
        // shape closePresentation uses (PurchaselyRN.m:1807 and :1826). If an
        // executor hoists lock()/defer to the enclosing closure, the second
        // acquisition deadlocks and this test times out rather than failing
        // fast — the timeout IS the signal.
        //
        // The real reentrancy proof lives in Task 12's closePresentation test;
        // this one only guards the helper.
        PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds.insert("a") }
        PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds.insert("b") }
        XCTAssertEqual(PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds },
                       Set(["a", "b"]))
        PurchaselyBridge.withState { PurchaselyBridge.interceptorKinds.removeAll() }
    }

    func testRejectWithNilErrorProducesCodeZeroAndNoMessage() {
        // PurchaselyRN.m:1455 messages a nil error and gets code "0" with a nil
        // message. Swift must not force-unwrap or return early here.
        var code: String?
        var message: String?
        PurchaselyBridge.reject({ c, m, _ in code = c; message = m }, with: nil)
        XCTAssertEqual(code, "0")
        XCTAssertNil(message)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the command in Task 6 Step 3. Expected: compile error, `cannot find 'PurchaselyBridge' in scope`.

- [ ] **Step 3: Write the skeleton**

Create `packages/purchasely/ios/PurchaselyRN.swift`. Copy the 60 constants from `PurchaselyRN.m:472-533` and the 11 events from `:1298-1314`, in the same order.

```swift
//
//  PurchaselyRN.swift
//  The React Native bridge module. Split across PurchaselyRN+*.swift by
//  domain; this file holds the class, its shared state and the RCTEventEmitter
//  overrides.
//
//  NAMED `PurchaselyBridge` UNTIL THE SWAP COMMIT. A Swift @objc(PurchaselyRN)
//  class cannot coexist with the Objective-C PurchaselyRN, and two classes
//  claiming the JS module name `Purchasely` must never both be registered.
//  This class carries no export macro, so React Native does not see it yet.
//

import Foundation
import Purchasely

class PurchaselyBridge: RCTEventEmitter,
                        PLYEventDelegate,
                        PLYUserAttributeDelegate,
                        PLYWebRedemptionDelegate {
    // The three conformances are declared HERE, in Task 8, because `start`
    // (Task 9) passes `self` as all three (PurchaselyRN.m:623, :634, :636).
    // Their method bodies are Task 12's. Until Task 12 lands, satisfy the
    // protocols with stubs that call PLYRNLogWarn and nothing else, so the
    // class compiles at every commit boundary.

    // MARK: - shared state
    //
    // Ported from the file-scope statics at PurchaselyRN.m:43-53. Swift
    // initializes a static lazily and exactly once, thread-safely, so
    // ensurePresentationState() and its dispatch_once are gone.

    /// requestId → the captured presentation, so events can replay it.
    static var presentationsByRequest: [String: any PLYPresentation] = [:]
    /// callbackId → the completion to call when JS replies with an InterceptResult.
    static var interceptorCallbacks: [String: (String) -> Void] = [:]
    /// Which interceptor kinds JS has registered.
    static var interceptorKinds: Set<String> = []

    /// Serialises every access to the three collections above. Bridge methods
    /// run on a background queue while the interceptor completions run on the
    /// main queue.
    ///
    /// `NSLock` is NOT reentrant and `@synchronized` was. So: one `withState`
    /// per original `@synchronized` block, never nested, and never wrapping an
    /// SDK call or a callback invocation. `closePresentation` is the case that
    /// proves it — it takes the lock twice with an SDK close in between.
    private static let stateLock = NSLock()

    static func withState<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    /// Mirrors the Android bridge's INTERCEPTOR_TIMEOUT_MS = 30_000L.
    static let interceptorTimeoutSeconds: TimeInterval = 30

    // MARK: - init
    //
    // `-init` calls `setAppTechnology:PLYAppTechnologyReactNative`
    // (PurchaselyRN.m:467) and sets shouldEmit = NO. Both must survive: the app
    // technology is what tags every event this SDK sends as React Native.

    override init() {
        super.init()
        Purchasely.setAppTechnology(.reactNative)
    }

    /// Weak, as `_sharedEmitter` was at PurchaselyRN.m:365.
    static weak var sharedEmitter: PurchaselyBridge?

    /// Gate from PurchaselyRN.m: drop events before startObserving. Declared
    /// `Boolean` in the old header, which imported into Swift as `UInt8`; a
    /// real `Bool` here is the one type change in the port.
    var shouldEmit = false

    // MARK: - RCTEventEmitter

    override static func requiresMainQueueSetup() -> Bool {
        // PurchaselyRN.m:1447 returns YES. Do NOT "align" this with
        // PurchaselyViewManager.swift:20, which returns false on purpose for a
        // different reason — Global Constraint 11, and commit 81c5a65.
        true
    }

    override func supportedEvents() -> [String]! {
        [
            "PURCHASELY_EVENTS",
            "PURCHASE_LISTENER",
            "USER_ATTRIBUTE_SET_LISTENER",
            "USER_ATTRIBUTE_REMOVED_LISTENER",
            "WEB_REDEMPTION_LISTENER",
            // cross-platform bridge events; the names mirror the Android bridge.
            "PURCHASELY_PRESENTATION_LOADED",
            "PURCHASELY_PRESENTATION_PRESENTED",
            "PURCHASELY_PRESENTATION_CLOSE_REQUESTED",
            "PURCHASELY_PRESENTATION_DISMISSED",
            "PURCHASELY_DEFAULT_PRESENTATION_DISMISSED",
            "PURCHASELY_ACTION_INTERCEPTED",
        ]
    }

    override func constantsToExport() -> [AnyHashable: Any]! {
        // 60 keys. enums.ts builds the JS enums from them, so every key and
        // every value is a client contract. `.rawValue` on every enum
        // (constraint 5) — a bare enum value would be dropped by the bridge.
        // Note the QUALIFIED enum names. `PLYLogLevel` is nested under
        // `PLYLogger` (.swiftinterface:1458); `PLYAttribute` and `PLYThemeMode`
        // are nested under `Purchasely` (:1337, :1368). The unqualified names
        // do not compile. Verify each one — Global Constraint 0.
        //
        // `purchaseResultOrdinal` returns NSNumber?, and these three cases are
        // never `.none`, so force them into the dictionary explicitly rather
        // than letting a nil silently drop a key.
        [
            "logLevelDebug": PLYLogger.PLYLogLevel.debug.rawValue,
            "logLevelInfo": PLYLogger.PLYLogLevel.info.rawValue,
            "logLevelWarn": PLYLogger.PLYLogLevel.warn.rawValue,
            "logLevelError": PLYLogger.PLYLogLevel.error.rawValue,
            "productResultPurchased": Self.purchaseResultOrdinal(.purchased) ?? 0,
            "productResultCancelled": Self.purchaseResultOrdinal(.cancelled) ?? 1,
            "productResultRestored": Self.purchaseResultOrdinal(.restored) ?? 2,
            // … the remaining 53, in PurchaselyRN.m:472-533 order.
            // BridgeExportContractTests.expectedConstants holds the exact
            // values; that test is how you know you transcribed them right.
        ]
    }

    override func startObserving() {
        shouldEmit = true
        Self.sharedEmitter = self
    }

    override func stopObserving() {
        shouldEmit = false
    }

    /// Wrapper around sendEvent that honours the shouldEmit gate.
    func emitPresentationEvent(_ name: String, body: [String: Any]?) {
        guard shouldEmit else { return }
        sendEvent(withName: name, body: body ?? [:])
    }

    // MARK: - errors

    /// Ported from `-reject:with:` (PurchaselyRN.m:1454-1456), made `static`
    /// on purpose: it reads no instance state, so the 18 closures that called
    /// it capture nothing and the whole [weak self] question disappears.
    ///
    /// The error stays Optional: `PurchaselyRN.m:1455` messages a nil error and
    /// gets code "0" with a nil message. Reproduce that, do not force-unwrap
    /// and do not return early.
    static func reject(_ reject: RCTPromiseRejectBlock, with error: Error?) {
        let nsError = error as NSError?
        reject("\(nsError?.code ?? 0)", nsError?.localizedDescription, error)
    }

    /// Ported from `purchaseResultOrdinal` (PurchaselyRN.m:178-186).
    ///
    /// Returns **nil** for `.none`, exactly as the Objective-C function did.
    /// `PLYPurchaseResult` has four cases (`.swiftinterface:806`), and a
    /// dismissal with no purchase is `.none`. Mapping it to a number would put
    /// `purchaseResult: 1` — cancelled — on the wire for every plain dismissal.
    /// The call sites rely on `dict[key] = nil` removing the key.
    ///
    /// Do not copy the fallback in `PurchaselyView.swift:282`; it answers a
    /// different question.
    static func purchaseResultOrdinal(_ result: PLYPurchaseResult) -> NSNumber? {
        switch result {
        case .purchased: return 0
        case .cancelled: return 1
        case .restored: return 2
        case .none: return nil
        @unknown default: return nil
        }
    }
}
```

Then transcribe the remaining 55 constants. Verify each SDK enum case name against the `.swiftinterface` rather than guessing; `@(PLYAttributeFirebaseAppInstanceId)` becomes `PLYAttribute.firebaseAppInstanceId.rawValue` only if that is what the interface says.

- [ ] **Step 4: Run the tests**

Run the command in Task 6 Step 3. Expected: all `BridgeSkeletonTests` PASS. `testConstantsMatchTheObjectiveCModuleExactly` is the one that catches a mistyped constant, and it compares against the live Objective-C module, so it cannot be fooled by a typo in a literal list.

- [ ] **Step 5: Add the log helper now, not in Task 14**

Swift cannot call `RCTLogWarn`: it is a variadic macro (`RCTLog.h:37`) over a variadic C function. Tasks 9–13 need it for the enum fallbacks, so define it here rather than leaving `NSLog` markers to sweep up later.

In `packages/purchasely/ios/PurchaselyRN.m`, above the existing `@implementation`:

```objc
void PLYRNLogWarn(NSString *message) {
    RCTLogWarn(@"%@", message);
}
```

In `packages/purchasely/ios/react-native-purchasely-Bridging-Header.h`, next to the React imports:

```objc
/// Non-variadic wrapper around RCTLogWarn, for the Swift side. Defined in
/// PurchaselyRN.m. RCTLogWarn itself is a variadic macro Swift cannot see.
FOUNDATION_EXPORT void PLYRNLogWarn(NSString *message);
```

Confirm it is reachable by calling it once from `PurchaselyRN.swift` and building. Task 14 keeps both pieces; the shim inherits the definition.

- [ ] **Step 6: Commit**

```bash
git add packages/purchasely/ios/PurchaselyRN.swift \
        packages/purchasely/ios/PurchaselyRN.m \
        packages/purchasely/ios/react-native-purchasely-Bridging-Header.h \
        packages/purchasely/ios/PurchaselyTests/BridgeSkeletonTests.swift
git commit -m "feat(ios): add the Swift bridge class skeleton, unregistered

Named PurchaselyBridge and carrying no export macro until the swap
commit, so React Native never sees two classes claiming the JS module
name Purchasely. Holds the shared state behind a scoped NSLock helper
(NSLock is not reentrant and @synchronized was), the 60 constants, the 11
events, and a static reject helper — static so the 18 closures that use
it capture nothing."
```

---

## Tasks 9–13: The five domain extensions

These five tasks share one shape, so it is written once here. **Each is a transliteration of a known line range under the Global Constraints, not a design task.** Do not redesign a method while porting it.

**The shape of each task:**

- [ ] **Step 1: Read the source range in full.** Not skim. Every method in the range.
- [ ] **Step 2: Write the failing test.** One test per method that has observable behaviour without a live SDK: the payload it builds, the mapping it applies, the fallback it takes. A method whose whole body is one SDK call gets no unit test; E2E covers it.
- [ ] **Step 3: Run to verify it fails.**
- [ ] **Step 4: Write the extension**, method by method, in source order.
- [ ] **Step 5: Run the tests, plus `BridgeSkeletonTests` and `BridgeExportContractTests`.** All green.
- [ ] **Step 6: Commit** with `refactor(ios): port <domain> to Swift`.

**The worked example, to copy for every exported method.** `userLogin` at `PurchaselyRN.m:668-682`:

```swift
// Objective-C:
//   RCT_EXPORT_METHOD(userLogin:(NSString *)userId
//                     resolve:(RCTPromiseResolveBlock)resolve
//                     reject:(RCTPromiseRejectBlock)reject) { … }

extension PurchaselyBridge {

    /// Constraint 3: the explicit @objc selector, whose first segment is the JS
    /// name. The shim line in PurchaselyRN.m copies this selector verbatim.
    /// Constraint 4: `userId` is Optional. The bridge's null check is behind
    /// #if RCT_DEBUG, so a client Release build passes nil straight into this
    /// thunk and a non-optional String would trap.
    @objc(userLogin:resolve:reject:)
    func userLogin(
        _ userId: String?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        // Constraint 9: no [weak self]. The Objective-C block captured self
        // strongly and the closure body uses only the static reject helper, so
        // it captures nothing at all.
        DispatchQueue.main.async {
            Purchasely.userLogin(with: userId ?? "") { isNewUser in
                resolve(isNewUser)
            }
        }
    }
}
```

### Task 9: `PurchaselyRN+Lifecycle.swift`

**Files:** Create `packages/purchasely/ios/PurchaselyRN+Lifecycle.swift`. Test: `packages/purchasely/ios/PurchaselyTests/BridgeLifecycleTests.swift`.

**Source ranges:** `PurchaselyRN.m:536-705` (`start` and its builder-payload parsing, `runningModeFromOrdinal` at `:259`), `:656-705` (`setLogLevel`, `setThemeMode`), `:668-705` (`userLogin`, `userLogout`, `isAnonymous`, `handleDeeplink`), `:955-1000` (`getAnonymousUserId`, `readyToOpenDeeplink`, `allowDeeplink`, `allowCampaigns`), `:1240-1295` (`revokeDataProcessingConsent` and `mapPurposesFromStrings:`), `:625-638` (the delegate registrations and the `NSNotificationCenter` observer, all **after** `startWithInitialized:` returns), plus `setLanguage`, `setDebugMode`, `userDidConsumeSubscriptionContent`, `synchronize`.

**This task owns 16 exported methods, `synchronize` included.** `isEligibleForIntroOffer` sits inside the range above but belongs to **Task 11** — skip it. Do not port a method your task does not own (see Exclusive method ownership).

**Interfaces produced:** 16 `@objc` exported methods, plus `@objc func purchasePerformed()` — **called by selector** from the notification centre at `:638`, so it keeps `@objc` even though no Swift code calls it.

**Depends on Task 8** for the three delegate conformances: `start` passes `self` as the event, user-attribute and web-redemption delegate (`:623`, `:634`, `:636`). If those conformances are missing from `PurchaselyRN.swift`, stop and report rather than adding them here.

**The three traps in this range.** All three were wrong in the first draft of this plan; these are the verified forms.

```swift
// 1. Inbound raw values, and the qualified enum name. `setLogLevel:` takes an
//    NSInteger today, so the Swift parameter stays a primitive (Constraint 4);
//    the ordinal may be anything, and PLYLogLevel(rawValue:) returns nil for an
//    unknown one — never force-unwrap it.
//
//    PLYLogLevel is nested under PLYLogger, and the setter is a FUNCTION:
//    `Purchasely.logLevel = x` does not exist (.swiftinterface:1256, :1458).
@objc(setLogLevel:)
func setLogLevel(_ logLevel: Int) {
    guard let level = PLYLogger.PLYLogLevel(rawValue: logLevel) else {
        PLYRNLogWarn("Unknown log level \(logLevel), keeping the current one")
        return
    }
    Purchasely.setLogLevel(level)
}

// 2. The observer is registered AFTER `startWithInitialized:` returns, at
//    PurchaselyRN.m:638 — OUTSIDE the completion, alongside setEventDelegate:
//    and setUserAttributeDelegate:. Putting it inside the completion means a
//    failed start never registers it, and changes the timing (Constraint 9).
//
//    The name is the literal string "ply_purchasedSubscription". There is no
//    Notification.Name constant for it.
NotificationCenter.default.addObserver(
    self, selector: #selector(purchasePerformed),
    name: Notification.Name("ply_purchasedSubscription"), object: nil
)

// 3. `Int(exactly:)` on the value itself, with NO `.rounded()`.
//    PurchaselyRN.m:735-745 receives a plain `double` and takes the integer
//    path only when `fmod(value, 1.0) == 0`. Rounding first would store 2.5 as
//    the integer 3. Int(exactly:) returns nil for a fractional, NaN, infinite
//    or out-of-range value, which is the fmod behaviour plus the 1e300 fix.
if let asInt = Int(exactly: value) {
    // integer path
} else {
    // double path, exactly as the Objective-C else branch
}
```

### Task 10: `PurchaselyRN+Attributes.swift`

**Files:** Create `packages/purchasely/ios/PurchaselyRN+Attributes.swift`. Test: `packages/purchasely/ios/PurchaselyTests/BridgeAttributesTests.swift`.

**Source ranges:** `PurchaselyRN.m:705-955` — the legal-basis mapper at `:705`, then the `setUserAttributeWith*` methods, `incrementUserAttribute`, `decrementUserAttribute`, `userAttribute`, `userAttributes`, `clearUserAttribute`, `clearUserAttributes`, `clearBuiltInAttributes`, `getBuiltInAttributes`, `getBuiltInAttribute`, `setAttribute`.

**Interfaces produced: 21 `@objc` exported methods** (count them off the `RCT_EXPORT_METHOD` / `RCT_REMAP_METHOD` lines in the range; the first draft said 20) plus the mapper below.

**The traps:**

```swift
// 1. The legal-basis mapper takes a STRING, not an ordinal, and returns
//    PLYDataProcessingLegalBasis. `PLYLegalBasis` does not exist.
//    PurchaselyRN.m:707-712 upper-cases the input, matches "ESSENTIAL", and
//    falls back to .optional for nil, a non-string and anything unknown.
//    enums.ts:87-90 sends 'ESSENTIAL' and 'OPTIONAL'.
static func legalBasis(from value: String?) -> PLYDataProcessingLegalBasis {
    value?.uppercased() == "ESSENTIAL" ? .essential : .optional
}
```

`incrementUserAttribute` uses `intValue` at `:857`, which in Objective-C is 32-bit. Swift's `NSNumber.intValue` is native-width `Int`, so write **`Int(number.int32Value)`** to keep the truncation behaviour. The array setters take `NSArray` — declare them `[Any]?` per Constraint 4. `userAttribute` reads arrays back; check what the iOS read path returns and keep it (this is where the Android bridge needed `Arguments.makeNativeArray`, per the T14 fix).

Write a unit test for the mapper: `"ESSENTIAL"`, `"essential"`, `"OPTIONAL"`, `"nonsense"` and `nil`. It is four lines of code guarding the GDPR legal basis of all 21 attribute methods.

### Task 11: `PurchaselyRN+Products.swift`

**Files:** Create `packages/purchasely/ios/PurchaselyRN+Products.swift`. Test: `packages/purchasely/ios/PurchaselyTests/BridgeProductsTests.swift`.

**Source ranges:** `PurchaselyRN.m:1000-1240` — `purchaseWithPlanVendorId`, `restoreAllProducts`, `silentRestoreAllProducts`, `allProducts`, `productWithIdentifier`, `planWithIdentifier`, `userSubscriptions`, `userSubscriptionsHistory`, `setDynamicOffering`, `getDynamicOfferings`, `removeDynamicOffering`, `clearDynamicOfferings`, `signPromotionalOffer`, `isEligibleForIntroOffer`.

**Interfaces produced: 14 `@objc` exported methods.** `synchronize` is **Task 9's**, not this task's — declaring it here too produces an invalid `@objc` redeclaration.

**The traps:**

```swift
// 1. The two selectors that change (constraint 3). Their JS name must not.
@objc(restoreAllProducts:reject:)          // was resolve:reject:
@objc(silentRestoreAllProducts:reject:)    // was silentRestoreWithResolve:reject:

// 2. A nil array coalesces to [], it does not vanish (PurchaselyRN.m:1150).
resolve((subscriptions ?? []).map { $0.asDictionary() })

// 3. The billing-plan-type mappers are now on PLYPlan, from phase 1 Task 2.
//    In Swift call them by their Swift names, not the @objc selectors:
//    PLYPlan.billingPlanType(fromRNString: value)
```

### Task 12: `PurchaselyRN+Presentations.swift`

The largest and riskiest extension. **Read the whole range before writing anything.**

**Files:** Create `packages/purchasely/ios/PurchaselyRN+Presentations.swift`. Test: `packages/purchasely/ios/PurchaselyTests/BridgePresentationsTests.swift`.

**Source ranges:** `PurchaselyRN.m:76-320` and `:378-458` (the presentation helpers and the event emitters — `:455` is `emitPresentationCloseRequestedForId:`, which the first draft's range missed: `stringFromPresentationAction`, `presentationActionFromString`, `stringFromWebCheckoutProvider`, `presentationToMap`, `presentationErrorToMap`, `closeReasonToRNString`, `applyPresentationDisplayOptions`, `plyParseDimensionMap`, `plyTransitionFromMap`), `:206` (`presentationBuilderFor`), `:1296-1450` (the 3 delegate methods and the web-redemption body), `:1489-1516` (`extractPresentationTargets`), `:1517-1900` (`preloadPresentation`, `displayPresentation`, the default dismiss handler, `closePresentation`, `goBackToPreviousScreen`, `closeAllScreens`, the BYOS methods and `loadedClientPresentationForMap`).

**Interfaces produced:**
- 9 `@objc` exported methods
- `static func presentationToMap(_ presentation: any PLYPresentation) -> [String: Any]` — **`internal`, not `private`**: Task 13 calls it. Swift's private-in-extension exception is per file.
- `static func webRedemptionBody(withSuccess:hasContext:subscription:replay:errorCode:errorMessage:) -> [String: Any]` — keep the exact Swift name Task 6's test uses. Five keys: `isSuccess`, `context`, `replay`, `errorCode`, `errorMessage`, with `NSNull` for the absent ones on every branch (`:1426-1440`)
- `static func emitPresentationCloseRequested(forId:)` (`PurchaselyRN.h:69`, `PurchaselyRN.m:455`) — three ported tests drive it through a `sendEvent`-overriding subclass, so it must stay reachable
- the bodies of the three delegate conformances Task 8 declared: `eventTriggered(_:properties:)` (`:1345`), the user-attribute methods, and `webRedemptionCompleted(result:)` (`:1402`). Replace Task 8's stubs.
- The 5 static members `PurchaselyView.swift` calls, with the exact signatures in spec section 6. **Target: zero diff in `PurchaselyView.swift`.**
- `struct PresentationTargets { var placementId: String?; var presentationId: String?; var contentId: String?; var isDefault: Bool }`, replacing the four `__autoreleasing` out-parameters

**The traps:**

```swift
// 1. The lock, per original @synchronized block. closePresentation
//    (PurchaselyRN.m:1803-1829) is the shape that forbids hoisting:
@objc(closePresentation:)
func closePresentation(_ requestId: String?) {
    guard let requestId else { return }
    DispatchQueue.main.async {
        // Block 1: read. The SDK close is OUTSIDE it (constraint 7).
        let presentation = Self.withState { Self.presentationsByRequest[requestId] }
        if let presentation {
            // Programmatic close: clear onCloseRequested first so it can never
            // re-emit CLOSE_REQUESTED for this call.
            presentation.onCloseRequested = nil
            presentation.close()
        } else {
            Purchasely.closeAllScreens()
        }
        // Block 2: remove. A second withState, NOT nested in the first —
        // NSLock is not reentrant and nesting deadlocks the main thread.
        Self.withState { Self.presentationsByRequest[requestId] = nil }
    }
}

// 2. The native promise resolves once, immediately (constraint 10).
//    PurchaselyRN.m:1581 and :1747 do `resolve(@(YES))` right after triggering;
//    the public JS promise settles later through events. Never resolve or
//    reject this promise from onDismissed, onPresented or a fetch completion.
request.preload(completion: onFetchCompletion)
resolve(true)

// 3. Keep `weak` exactly where Objective-C has __weak: :1535, :1604, :1762,
//    :1916. Those closures return silently and own no promise. Everywhere else
//    capture strongly, as the Objective-C blocks did.

// 4. plyTransitionFromMap now calls the SDK's Swift initializer directly —
//    PLYTransition.init(type:height:width:heightPercentage:backgroundColors:dismissible:)
//    at .swiftinterface:994, public and non-@objc. This is what replaces
//    PLYTransitionFactory, and it is goal 3 of the spec in one line.
```

**One test this task must write.** `closePresentation` is where a widened lock deadlocks the main thread, so prove the two-block shape survives:

```swift
func testClosePresentationTakesTheLockTwiceWithoutDeadlocking() {
    // No SDK presentation is needed: the requestId is absent from the
    // registry, so this drives the `else` branch — which still acquires the
    // lock twice, once to look up and once to remove. If an executor hoisted
    // lock()/defer to the closure, this times out.
    let bridge = PurchaselyRN()
    let done = expectation(description: "closePresentation returned")
    DispatchQueue.main.async {
        bridge.closePresentation("no-such-request")
        done.fulfill()
    }
    wait(for: [done], timeout: 2.0)
}
```

`PLYTransitionFactory.swift` is **not** deleted in this task — `PurchaselyRN.m` still calls it. Task 14 deletes it.

### Task 13: `PurchaselyRN+Interceptors.swift`

**Files:** Create `packages/purchasely/ios/PurchaselyRN+Interceptors.swift`. Test: `packages/purchasely/ios/PurchaselyTests/BridgeInterceptorsTests.swift`.

**Source ranges:** `PurchaselyRN.m:1900-2086` — `registerActionInterceptor`, `unregisterActionInterceptor`, `completeActionInterceptor`, and the 30-second timeout.

**Interfaces produced:** 3 `@objc` exported methods.

**The traps:**

```swift
// 1. The callback is removed from the map INSIDE the lock and invoked OUTSIDE
//    it. PurchaselyRN.m:2079 already does this and it must stay that way: a
//    callback invoked under the lock can re-enter and deadlock NSLock.
let callback = Self.withState { Self.interceptorCallbacks.removeValue(forKey: callbackId) }
callback?(result)

// 2. The timeout is asyncAfter, never a semaphore (constraint 8). It fires
//    `notHandled` so the native SDK's completion always runs and an action is
//    never frozen for the life of the process.
DispatchQueue.main.asyncAfter(deadline: .now() + Self.interceptorTimeoutSeconds) {
    let stale = Self.withState { Self.interceptorCallbacks.removeValue(forKey: callbackId) }
    stale?("notHandled")
}
```

Write a real unit test for the timeout — it is testable without the SDK:

```swift
func testAStaleInterceptorCallbackIsCompletedWithNotHandled() {
    let done = expectation(description: "notHandled delivered")
    let bridge = PurchaselyBridge()
    PurchaselyBridge.withState {
        PurchaselyBridge.interceptorCallbacks["cb-1"] = { result in
            XCTAssertEqual(result, "notHandled")
            done.fulfill()
        }
    }
    bridge.scheduleInterceptorTimeout(callbackId: "cb-1", after: 0.05)
    wait(for: [done], timeout: 1.0)
}
```

That requires the timeout to be a named method taking its delay, not an inline literal. Make it `func scheduleInterceptorTimeout(callbackId: String, after delay: TimeInterval = PurchaselyBridge.interceptorTimeoutSeconds)`. This is the one place where the port improves testability, and it is worth it: a silent interceptor timeout is a frozen paywall.

---

## Task 14: The swap

One commit. Before it, `PurchaselyRN` is Objective-C and registered; after it, Swift and registered. Never both.

**Files:**
- Modify: `packages/purchasely/ios/PurchaselyRN.swift` and the five `PurchaselyRN+*.swift` (rename the type)
- Replace: `packages/purchasely/ios/PurchaselyRN.m` in full
- Delete: `packages/purchasely/ios/PurchaselyRN.h`
- Delete: `packages/purchasely/ios/PLYTransitionFactory.swift`
- Delete: `packages/purchasely/ios/Purchasely.xcodeproj`
- Modify: `packages/purchasely/ios/PurchaselyTests/BridgeSkeletonTests.swift` and the four other new test files (rename the type)
- Add: `packages/purchasely/ios/PurchaselyTests/BridgeSelectorResolutionTests.swift`

**Interfaces:**
- Consumes: everything Tasks 8–13 produced.
- Produces: `@objc(PurchaselyRN) class PurchaselyRN: RCTEventEmitter`, exported to JS as `Purchasely`.

- [ ] **Step 1: Confirm the starting state is green**

Run the command in Task 6 Step 3. Expected: every test PASSES, including `BridgeExportContractTests` against the still-Objective-C module.

- [ ] **Step 2: Rename the Swift type**

```bash
cd packages/purchasely/ios
rg -l 'PurchaselyBridge' . | xargs sed -i '' 's/PurchaselyBridge/PurchaselyRN/g'
```

Then in `PurchaselyRN.swift`, add the export name and drop the temporary-name comment:

```swift
@objc(PurchaselyRN)
class PurchaselyRN: RCTEventEmitter {
```

The `@objc(PurchaselyRN)` attribute is what creates the collision, so add it in the same edit that deletes the Objective-C `@implementation` (Step 4). Between the two the project does not compile; that is expected and it is why they are one commit.

Note for a future migration of this shape: a Swift class named `PurchaselyRN` **without** `@objc(...)` gets a mangled Objective-C name (`react_native_purchasely.PurchaselyRN`) and cannot collide, so the staging name is only needed for tests that must reference both classes at once — Task 8's cross-implementation constants test is the only one.

- [ ] **Step 3: Fix the tests that compared the two implementations**

`BridgeSkeletonTests` compared `PurchaselyRN` against `PurchaselyBridge`; after the rename both names are the same class. Replace those three comparison tests with assertions against the literal lists already in `BridgeExportContractTests`:

```swift
func testConstantsKeepAllSixtyKeys() {
    let constants = PurchaselyRN().constantsToExport() as? [String: Any] ?? [:]
    XCTAssertEqual(Set(constants.keys), BridgeExportContractTests.expectedConstantKeys)
}

func testSupportedEventsKeepTheirOrder() {
    XCTAssertEqual(PurchaselyRN().supportedEvents() as? [String] ?? [],
                   BridgeExportContractTests.expectedEvents)
}
```

The stronger cross-implementation check has served its purpose: it was green on every commit from Task 8 to Task 13, which is when it could catch a drift.

- [ ] **Step 4: Replace `PurchaselyRN.m` with the shim**

```objc
//
//  PurchaselyRN.m
//  The Objective-C export shim for the Swift bridge module.
//
//  React Native discovers a legacy module through class methods named
//  __rct_export__*, which only these macros can generate; Swift cannot emit
//  them. So this file is not optional, and it is the whole reason
//  BridgeExportContractTests exists: every line below is parsed as TEXT at
//  registration, not linked. A selector here that disagrees with its Swift
//  @objc(...) annotation compiles fine and fails at run time in a client app
//  with "method not found".
//
//  RULE FOR EVERY LINE: copy the selector from the Swift method's explicit
//  @objc(...) annotation, verbatim. Do not retype it.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTLog.h>

// RCTLogWarn is a variadic macro (RCTLog.h:37) over a variadic C function, and
// Swift imports neither. This is the one piece of logic the shim keeps.
void PLYRNLogWarn(NSString *message) {
    RCTLogWarn(@"%@", message);
}

// The JS name is `Purchasely` on the class `PurchaselyRN`, so this must be the
// REMAP form. The plain RCT_EXTERN_MODULE would export it as `PurchaselyRN`
// and break every JS call. BridgeExportContractTests asserts the name.
@interface RCT_EXTERN_REMAP_MODULE(Purchasely, PurchaselyRN, RCTEventEmitter)

// `start` is the reason this file cannot be written from memory: TEN
// segments, the first is an API key and not an options dictionary, and the
// resolve segment is named `initialized:`. Copied from the pre-port
// PurchaselyRN.m:536-545.
RCT_EXTERN_METHOD(start:(NSString * _Nonnull)apiKey
                  stores:(NSArray * _Nullable)stores
                  storeKit1:(BOOL)storeKit1
                  userId:(NSString * _Nullable)userId
                  logLevel:(NSInteger)logLevel
                  runningMode:(NSInteger)runningMode
                  purchaselySdkVersion:(NSString * _Nullable)purchaselySdkVersion
                  startOptions:(NSDictionary * _Nullable)startOptions
                  initialized:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(userLogin:(NSString * _Nonnull)userId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// … the remaining 61, one per Swift @objc(...) selector.

@end
```

**Generate the list; do not type it.** Two sources, and they must agree:

```bash
cd packages/purchasely/ios
# what the Swift side declares
rg -o '@objc\(([^)]+)\)' -r '$1' PurchaselyRN.swift PurchaselyRN+*.swift | sort > /tmp/swift-selectors.txt
# what the pre-port Objective-C exported, with its parameter types and annotations
git show HEAD~1:packages/purchasely/ios/PurchaselyRN.m \
  | rg -A8 'RCT_(EXPORT|REMAP)_METHOD\(' > /tmp/objc-exports.txt
```

Take each shim line's **parameter types and nullability annotations from `/tmp/objc-exports.txt`** (Constraint 4: the annotation is copied, not re-derived) and its **selector from `/tmp/swift-selectors.txt`**. A `BOOL`, `NSInteger` or `double` parameter stays that primitive.

- [ ] **Step 5: Delete the four obsolete files**

```bash
cd packages/purchasely/ios
git rm PurchaselyRN.h PLYTransitionFactory.swift
git rm -r Purchasely.xcodeproj
```

`PurchaselyRN.h` goes because no host app imports it and the React headers reach Swift through `react-native-purchasely-Bridging-Header.h` (Global Constraint 12 — do **not** delete that file too). `Purchasely.xcodeproj` is read by no CI job and no `pod install`, and it still lists the files this task removes.

- [ ] **Step 6: Reduce the phase 1 serializers from `@objc public` to `internal`**

Task 2 and Task 3 made the five serializers plus the hex parser `@objc public` because `PurchaselyRN.m` and `PLYProduct+Hybrid.m` called them from Objective-C. After Step 4 no Objective-C caller remains, so drop both annotations:

```bash
cd packages/purchasely/ios/Classes/Serialization
rg -n '@objc public' .
```

Each `@objc public extension PLYX` becomes `extension PLYX`, and each `@objc(selector:)` on a member with no remaining Objective-C caller goes too. Then rebuild **both** layouts (Global Constraint 13): the framework-layout build is what proves nothing still needs the generated header.

`PLYRNLogWarn` stays exactly as Task 8 left it — the definition in this file and the declaration in the bridging header.

- [ ] **Step 7: Add the selector-resolution test**

This is the second half of the gate. It needs `RCTParseMethodSignature`, which `React-Core-umbrella.h:77` exports through `RCTModuleMethod.h`.

Create `packages/purchasely/ios/PurchaselyTests/BridgeSelectorResolutionTests.swift`:

```swift
import XCTest
import React
@testable import react_native_purchasely

/// Asserts every selector the shim declares actually exists on the Swift class.
/// Separate from BridgeExportContractTests because this one needs a React
/// symbol; the JS-name half of the gate needs nothing but the pod.
final class BridgeSelectorResolutionTests: XCTestCase {

    func testEveryExportedSelectorResolvesOnTheClass() {
        for entry in BridgeExportContractTests.exportedEntries() {
            var arguments: NSArray?
            let selector = RCTParseMethodSignature(entry.objcName, &arguments)
            XCTAssertTrue(
                PurchaselyRN.instancesRespond(to: NSSelectorFromString(selector as String)),
                """
                The shim exports JS name '\(entry.jsName)' with selector \
                '\(selector)', which PurchaselyRN does not implement. Copy the \
                selector from that method's @objc(...) annotation.
                """
            )
        }
    }
}
```

If `import React` does not resolve in the test target, do **not** reach for a text parser. Write the same loop in a 30-line Objective-C test file instead — React headers are reachable from the Objective-C test target, and `PurchaselyRNTests.m` proved it before Task 6 deleted it. Record the choice in the commit message, because it changes the spec's "exactly 3 non-Swift files" definition of done.

- [ ] **Step 8: Build, install, run everything**

```bash
cd example/ios && pod install
UDID=$(xcrun simctl list devices booted -j | jq -r '[.devices[][]][0].udid')
xcodebuild test -workspace example.xcworkspace -scheme react-native-purchasely-Unit-Tests \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO 2>&1 | tail -40
xcodebuild -workspace example.xcworkspace -scheme example -destination "id=$UDID" \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
USE_FRAMEWORKS=static pod install
xcodebuild -workspace example.xcworkspace -scheme react-native-purchasely \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
pod install
```

Expected: every test PASSES and both builds succeed. `BridgeExportContractTests` now runs against the Swift module and is the assertion that the swap kept the contract.

- [ ] **Step 9: Prove the gate still has teeth, on the Swift side**

Two experiments, both reverted:

1. Delete one `RCT_EXTERN_METHOD` line from the shim. Expected: `testExportedJSNamesAreExactlyTheContract` and `testExportedMethodCountMatches` FAIL.
2. Change one shim selector's first segment (for example `userLogin:` → `userLogIn:`). Expected: `testExportedJSNamesAreExactlyTheContract` FAILS naming `userLogin` missing and `userLogIn` extra, **and** `testEveryExportedSelectorResolvesOnTheClass` FAILS.

Restore both and re-run: PASS. Record both outcomes in the commit message.

- [ ] **Step 10: Verify the file inventory**

```bash
cd /Users/kevin/Purchasely/React_Native
fd -e m -e h . packages/purchasely/ios
rg -n 'DispatchSemaphore|dispatch_semaphore|\.wait\(|dispatch_sync|RunLoop.run' \
   packages/purchasely/ios --glob '!PurchaselyTests/*'
```

Expected: the first lists `PurchaselyRN.m`, `PurchaselyViewManager.m`,
`react-native-purchasely-Bridging-Header.h`, plus the Objective-C test file only
if Step 7 needed the fallback. The second returns nothing.

- [ ] **Step 11: Commit**

```bash
git add -A packages/purchasely example/ios/Podfile.lock
git commit -m "refactor(ios)!: the bridge module is Swift

PurchaselyRN.m drops from 2086 lines to an export shim plus one
non-variadic log wrapper, because RCTLogWarn is a variadic macro Swift
cannot see. PurchaselyRN.h, PLYTransitionFactory.swift (its only reason
was that Objective-C cannot build a PLYTransition) and the stale
Purchasely.xcodeproj are deleted.

Two selectors change and neither is JS-visible: restoreAllProducts and
silentRestoreAllProducts now carry selectors whose first segment is their
JS name, because RCT_EXTERN_REMAP_METHOD is not public in RN 0.86.

Gate verified with teeth twice on the Swift side: removing a shim line
fails the JS-name and count tests, and renaming a selector segment fails
both those and the selector-resolution test."
```

---

## Task 15: Correct the documentation

**Files:**
- Modify: `CLAUDE.md` at the **repo root** (`packages/purchasely/CLAUDE.md` does not exist)
- Modify: `docs/superpowers/specs/2026-09-08-ios-bridge-swift-migration-design.md` (status line)

**Interfaces:** none.

- [ ] **Step 1: Find every stale reference**

```bash
rg -n 'PurchaselyRN\.m|PurchaselyRN\.h|PurchaselyRNTests\.m|Classes/Hybrid|PLYTransitionFactory|~1500 lines|~330|~265' CLAUDE.md
```

- [ ] **Step 2: Correct them**

Nine lines name the moved files (75, 76, 99, 441, 591, 604, 623, 711, 724). Also fix the stale test line counts, which appear on **four** lines (99, 100, 441, 442): `CLAUDE.md` says 330 and 265; the real files were 535 and 785 before this work.

And the "Modifying Native Bridge / iOS" section must now say: edit the Swift file for the method, **and** add or update its `RCT_EXTERN_METHOD` line in `PurchaselyRN.m`, copying the selector from the Swift `@objc(...)` annotation. Add the two facts a future contributor cannot infer:

- The shim is parsed as text; a mismatch fails at run time, not at build time. `BridgeExportContractTests` is the gate.
- `react-native-purchasely-Bridging-Header.h` is load-bearing despite its name. Do not delete it.

- [ ] **Step 3: Verify no stale reference remains**

Re-run Step 1. Expected: no hit naming a deleted file.

- [ ] **Step 4: Commit and open the phase 2 pull request**

```bash
git add CLAUDE.md docs/superpowers/specs/2026-09-08-ios-bridge-swift-migration-design.md
git commit -m "docs: point the iOS sections at the Swift bridge

Also corrects two stale test line counts that predate this work."
git push -u origin feat/ios-swift-bridge
gh pr create --base main --title "refactor(ios)!: port the bridge module to Swift" \
  --body "Phase 2 of the iOS Objective-C to Swift migration. Spec: docs/superpowers/specs/2026-09-08-ios-bridge-swift-migration-design.md. Phase 1 (serialization) merged separately.

2086 lines of Objective-C become 6 Swift files plus a ~70-line export shim. No JS API change: same module name, same 63 method names, same 60 constants, same 11 events, same dictionary keys and same per-field absence policy.

The shim is parsed as text at registration, so BridgeExportContractTests reads React Native's own __rct_export__ table and asserts the 63 JS names, the module name, the 60 constants with numeric values, and the 11 events. It was written first, against the Objective-C module, and it has been shown to fail on a removed export and on a renamed selector.

Two selectors change, neither JS-visible: RCT_EXTERN_REMAP_METHOD is not public in RN 0.86, so restoreAllProducts and silentRestoreAllProducts take selectors whose first segment is their JS name.

Also deleted: PurchaselyRN.h, PLYTransitionFactory.swift, the stale Purchasely.xcodeproj, and three dead members (sharedViewController, shouldReopenPaywall, presentedPresentationViewController)."
```

Release vehicle: `6.2.0`. Do not ship either phase in a `6.1.x` patch.

---

## Task 16: CI and E2E acceptance

Phase 1 ends by waiting for CI; phase 2 must too. A green local build and a green XCTest bundle prove nothing about a text-parsed shim reaching JS — only the E2E suite exercises the real path.

**Files:** none. This task inspects CI and fixes whatever it reports.

- [ ] **Step 1: Watch the five gates**

```bash
gh pr checks --watch
```

The five that must be green, all named in the spec:

| Check | What a failure here means |
|---|---|
| `build-ios` | the pod does not compile under static-library linkage |
| `build-rn-0-86-ios` | it does not compile against the supported RN version |
| `iOS Build (use_frameworks!)` | a declaration is not `public` enough for a framework header |
| `iOS Unit Tests (bridge)` | a contract test failed — read which one, do not re-run hoping |
| `e2e-ios` T1–T30 | the shim does not actually reach JS. **This is the acceptance criterion.** |

- [ ] **Step 2: Read an E2E failure before touching anything**

```bash
gh run view --log-failed | rg -i 'T[0-9]+|method not found|unrecognized selector' | head -40
```

`method not found` or `unrecognized selector` names the JS method whose shim line and Swift `@objc(...)` disagree. Fix that one line; do not regenerate the shim.

A test that fails on a *behaviour* rather than a missing method means a translation changed semantics — go back to the Global Constraint it violates (most often 6, 9 or 10) rather than adjusting the test.

- [ ] **Step 3: Confirm the definition of done**

```bash
fd -e m -e h . packages/purchasely/ios
rg -n 'DispatchSemaphore|dispatch_semaphore|\.wait\(|dispatch_sync|RunLoop.run' \
   packages/purchasely/ios --glob '!PurchaselyTests/*'
```

Expected: three files (`PurchaselyRN.m`, `PurchaselyViewManager.m`, `react-native-purchasely-Bridging-Header.h`), plus an Objective-C test file only if Task 14 Step 7 needed the fallback. The second command returns nothing.

- [ ] **Step 4: Report, do not merge**

Post the five check results on the pull request and stop. **Merging needs an explicit go from the user**, whatever CI says.

---

## Appendix: Spec coverage

| Spec section | Task |
|---|---|
| 1 goal 3, unlocking `PLYTransition.init` | 12 trap 4, 14 step 5 |
| 3.3 no public remap macro | Global Constraint 3; 11 trap 1; 14 step 4 |
| 3.4 one class per module name | The phase 2 sequencing rule; 8; 14 |
| 3.5 nil in a Release build | Global Constraint 4; 9 worked example |
| 3.6 `RCTEventEmitter` overrides | 8 |
| 3.7 `requiresMainQueueSetup` | 8 step 3 |
| 5 file layout, incl. the log helper | 8–14; the log helper in 14 step 6 |
| 5 three dead members | 7 |
| 5 delete the `UIViewController` category | 4 |
| 6 zero diff in `PurchaselyView.swift` | 12 interfaces |
| 7 the parity gate | 5; 14 steps 7 and 9 |
| 8.1 lock scope, capture strength | 8 step 3; 12 trap 1; 13 trap 1 |
| 8.2 `.rawValue`, inbound fallback, `Int(exactly:)` | 1, 3, 8, 9 trap 3, 10 |
| 8.3 the 13 static C functions, `internal` not `private` | 9, 12 interfaces |
| 8.4 per-field absence policy, populated **and** absent cases | 1 (both fixtures), 3, 6 |
| 8.5 exported signatures | Global Constraints 3 and 4 |
| 9 the contract, including exact constant **values** | 1, 5 (`expectedConstants`) |
| 10 tests and CI | 1, 5, 6; 4 step 7; 14 step 8; **16** |
| 12 phase 1 `@objc public`, the 2 C functions | 2; reduced to `internal` in 14 step 6 |
| 14 definition of done | 4 step 7; 14 steps 9, 10; 15 step 3; 16 step 3 |
