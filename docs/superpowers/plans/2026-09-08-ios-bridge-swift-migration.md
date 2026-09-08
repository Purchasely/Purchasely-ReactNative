# iOS Bridge Objective-C → Swift Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 2086-line Objective-C `PurchaselyRN.m` and the 540 lines of Objective-C serialization categories with Swift, behind a thin Objective-C export shim, with no change to the JavaScript contract.

**Architecture:** One `@objc(PurchaselyRN) class PurchaselyRN: RCTEventEmitter` split into 6 Swift files by domain, plus `PurchaselyRN.m` reduced to `RCT_EXTERN_REMAP_MODULE` + 63 `RCT_EXTERN_METHOD` lines. The 7 serialization categories become Swift extensions under `ios/Classes/Serialization/`. Two pull requests: serialization first, then the module.

**Tech Stack:** Swift 5, XCTest, CocoaPods (mixed ObjC/Swift pod), React Native 0.86 legacy bridge on the New Architecture interop layer, Purchasely native iOS SDK 6.1.0.

**Spec:** `docs/superpowers/specs/2026-09-08-ios-bridge-swift-migration-design.md` — read it before Task 1. This plan argues from it and does not repeat its reasoning.

---

## Global Constraints

Every task's requirements implicitly include this section. Values are copied verbatim from the spec.

1. **The JS contract cannot change.** 63 exported JS method names, 60 `constantsToExport` keys and values, 11 `supportedEvents` names, every serializer dictionary key, and each key's absence policy.
2. **New Swift files go under `ios/Classes/`,** never a new top-level `ios/` subdirectory. `react-native-purchasely.podspec:19` is `"ios/*.{h,m,mm,swift}", "ios/Classes/**/*.{h,m,mm,swift}"`. A file outside those two globs is not in the pod.
3. **Every exported method carries an explicit `@objc(selector:)`** whose first selector segment equals its JS name. `RCT_EXTERN_REMAP_METHOD` is not public in RN 0.86 (`RCTBridgeModule.h:310-323`), so the shim cannot remap.
4. **Every object-typed parameter of an exported method is Optional** (`String?`, `NSDictionary?`, `[Any]?`). The null check is behind `#if RCT_DEBUG` (`RCTModuleMethod.mm:399-457`), so nil reaches the Swift thunk in a client Release build and traps a non-optional. `NSNumber` parameters stay non-optional and `_Nonnull` in the shim.
5. **Every enum value written into a dictionary uses `.rawValue`.** A Swift enum in `[String: Any]` bridges to an opaque box that the bridge drops silently.
6. **Absence policy is per field, never uniform.** Some keys are omitted when nil (`PLYSubscription+Hybrid.m:22-28`, documented in `types.ts:138-141`), some carry `NSNull` (`PurchaselyRN.m:1426`), some coalesce to a value (`:1150`). In Swift, `dict["k"] = nil` **removes** the key.
7. **`NSLock` is not reentrant; `@synchronized` is.** One `withLock { }` per original `@synchronized` block, preserving its exact lexical scope. No SDK call, no callback invocation, and no `await` inside a locked region.
8. **No blocking primitive in production code.** No `DispatchSemaphore`, no `group.wait()`, no `dispatch_sync`, no `RunLoop.run(until:)`. `XCTestExpectation` waiting in the test target is exempt.
9. **Preserve closure capture strength per closure.** `weak` only where Objective-C has `__weak` (`PurchaselyRN.m:1535`, `:1604`, `:1762`, `:1916`). Never a blanket `[weak self]`.
10. **Two promise layers.** `preloadPresentation` and `displayPresentation` resolve their native promise `@(YES)` immediately after triggering (`:1581`, `:1747`); the public JS promise settles later through events. Resolve the native acknowledgement exactly once and never from a later callback.
11. **`requiresMainQueueSetup` keeps its current value** on both `PurchaselyRN` and `PurchaselyViewManager`. Do not "clean it up" — commit `81c5a65` is the incident.
12. **`ios/react-native-purchasely-Bridging-Header.h` must never be deleted.** CocoaPods compiles the pod's Swift with `-import-underlying-module`, and this file is what puts the React headers into the umbrella. Deleting it breaks every Swift file in the pod with a message pointing elsewhere.
13. **Commands.** Tests: `cd example/ios && UDID=$(xcrun simctl list devices booted -j | jq -r '[.devices[][]][0].udid') && xcodebuild test -workspace example.xcworkspace -scheme react-native-purchasely-Unit-Tests -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO`. After changing the podspec or adding files: `cd example/ios && pod install`.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `ios/PurchaselyTests/SerializationContractTests.swift` | Locks every serializer's key set, value types and absence policy | 1 |
| `ios/Classes/Serialization/PLYPlan+Bridge.swift` | `PLYPlan` → dictionary, intro-offer eligibility, the 2 billing-plan-type mappers | 2 |
| `ios/Classes/Serialization/PLYProduct+Bridge.swift` | `PLYProduct` → dictionary | 3 |
| `ios/Classes/Serialization/PLYSubscription+Bridge.swift` | `PLYSubscription` → dictionary | 3 |
| `ios/Classes/Serialization/PLYOfferSignature+Bridge.swift` | `PLYOfferSignature` → dictionary | 3 |
| `ios/Classes/Serialization/PLYPresentationPlan+Bridge.swift` | `PLYPresentationPlan` → dictionary | 3 |
| `ios/Classes/Serialization/UIColor+PLYHex.swift` | Hex string → `UIColor` | 4 |
| `ios/PurchaselyTests/BridgeExportContractTests.swift` | Locks the 63 JS names, the module name, the 60 constants, the 11 events | 5 |
| `ios/PurchaselyTests/PurchaselyRNTests.swift` | The ported unit tests | 6 |
| `ios/PurchaselyRN.swift` | The class, state, lock, constants, events, observing, the 3 delegates | 8 |
| `ios/PurchaselyRN+Lifecycle.swift` | start, identity, deeplinks, language, log level, theme, consent, synchronize | 9 |
| `ios/PurchaselyRN+Attributes.swift` | The 20 attribute methods and the built-in attributes | 10 |
| `ios/PurchaselyRN+Products.swift` | Products, plans, subscriptions, purchase, restore, offerings, promo offers | 11 |
| `ios/PurchaselyRN+Presentations.swift` | Preload, display, close, back, BYOS, transitions, the 5 static members | 12 |
| `ios/PurchaselyRN+Interceptors.swift` | Register, unregister, complete, the 30-second timeout | 13 |
| `ios/PurchaselyRN.m` | Export shim + `PLYRNLogWarn` | 14 |

---

# PHASE 1 — Serialization (Pull Request 1)

Branch: `feat/ios-swift-serialization`, based on `main`.

## Task 1: Lock the serialization contract before touching it

The safety of all of phase 1 is this task. It snapshots the **current Objective-C** output, so it must be written and green before any `.m` is deleted.

**Files:**
- Create: `packages/purchasely/ios/PurchaselyTests/SerializationContractTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `SerializationContractTests`, whose assertions Tasks 2–4 must keep green unchanged. Do not edit this file in Tasks 2–4; if it fails, the port is wrong.

- [ ] **Step 1: Read the five serializers and write down every key**

Run and keep the output next to you:

```bash
cd packages/purchasely/ios/Classes/Hybrid
grep -n 'forKey:\|dict\[' PLYPlan+Hybrid.m PLYProduct+Hybrid.m PLYSubscription+Hybrid.m \
  PLYOfferSignature+Hybrid.m PLYPresentationPlan+Hybrid.m
```

For each key record three things: the key name, the value type Objective-C writes (`NSString`, `NSNumber`, `NSArray`, `NSDictionary`, `NSNull`), and whether the assignment is inside an `if (x != nil)` guard.

- [ ] **Step 2: Write the failing test**

The SDK model types have no public initializer, so the test cannot build a populated `PLYPlan`. It asserts what it *can*: the key set of an empty instance, and that no nullable key appears when its source is nil. That is precisely the regression this task must catch, because Swift's `dict["k"] = nil` removes a key that Objective-C's guarded assignment also omits — the two agree only if the guard is carried over.

Create `packages/purchasely/ios/PurchaselyTests/SerializationContractTests.swift`:

```swift
//
//  SerializationContractTests.swift
//  Locks the bridge's serialization contract across the Objective-C → Swift
//  port. Written against the Objective-C categories, kept green by the Swift
//  extensions that replace them. Do not relax an assertion to make a port
//  pass: types.ts documents this behaviour to clients.
//

import XCTest
import Purchasely
@testable import react_native_purchasely

final class SerializationContractTests: XCTestCase {

    // MARK: - PLYPlan

    /// Every key `PLYPlan.asDictionary` emits unconditionally.
    /// Read off PLYPlan+Hybrid.m. The five `offer*` keys are deliberate safe
    /// defaults: the iOS SDK's PLYTagHelper is `private` and takes an internal
    /// type, so no bridge can compute a real promotional-offer price — in
    /// Objective-C OR in Swift. Do not "fix" them during the port; the comment
    /// at PLYPlan+Hybrid.m:22-30 explains why, and the spec's goal 3 says Swift
    /// removes the @objc-only limit, not the public-only one.
    private static let planAlwaysPresentKeys: Set<String> = [
        "vendorId", "hasIntroductoryPrice", "type", "hasFreeTrial",
        "hasOfferPrice", "offerPrice", "offerAmount", "offerDuration",
        "offerPeriod",
    ]

    /// Keys `PLYPlan.asDictionary` emits ONLY when the native value is non-nil.
    /// They must be ABSENT, not NSNull and not an empty string, on an empty plan.
    private static let planNullableKeys: Set<String> = [
        "name", "productId", "price", "amount", "localizedAmount",
        "introAmount", "currencyCode", "currencySymbol", "period",
        "introPrice", "introDuration", "introPeriod", "commitmentInfo",
    ]

    func testPlanEmitsItsUnconditionalKeys() {
        let dict = PLYPlan().asDictionary
        for key in Self.planAlwaysPresentKeys {
            XCTAssertNotNil(dict[key], "PLYPlan.asDictionary lost the key '\(key)'")
        }
    }

    func testPlanOmitsItsNullableKeysRatherThanNullingThem() {
        let dict = PLYPlan().asDictionary
        for key in Self.planNullableKeys {
            XCTAssertNil(
                dict[key],
                """
                '\(key)' must be ABSENT when the native value is nil, not NSNull \
                and not an empty string. types.ts documents the omission and the \
                JS layer reads `undefined`.
                """
            )
        }
    }

    func testPlanTypeIsANumberNotAnOpaqueSwiftEnumBox() {
        // Global constraint 5. A Swift enum written without .rawValue bridges
        // to a box the RN bridge drops, so the key would arrive as undefined.
        let dict = PLYPlan().asDictionary
        XCTAssertTrue(
            dict["type"] is NSNumber,
            "PLYPlan.asDictionary['type'] must be an NSNumber (write .rawValue)"
        )
    }

    // MARK: - billing plan type mappers (round trip)

    func testBillingPlanTypeMappersRoundTrip() {
        for wire in ["unspecified", "upFront", "monthly"] {
            let parsed = PLYPlan.billingPlanType(fromRNString: wire)
            XCTAssertEqual(
                PLYPlan.rnString(fromBillingPlanType: parsed), wire,
                "billing plan type '\(wire)' did not survive the round trip"
            )
        }
    }

    func testUnknownBillingPlanTypeFallsBackToUnspecified() {
        XCTAssertEqual(
            PLYPlan.rnString(fromBillingPlanType: PLYPlan.billingPlanType(fromRNString: "nope")),
            "unspecified"
        )
        XCTAssertEqual(
            PLYPlan.rnString(fromBillingPlanType: PLYPlan.billingPlanType(fromRNString: nil)),
            "unspecified"
        )
    }
}
```

Then add, following exactly the same three-test shape (unconditional keys, nullable keys absent, enum keys are `NSNumber`), one section per remaining serializer. The key lists, read off the four `.m` files:

| Type | Unconditional | Nullable — must be absent |
|---|---|---|
| `PLYProduct` | `vendorId`, `plans` | `name` |
| `PLYSubscription` | `plan`, `product`, `subscriptionSource` | `nextRenewalDate`, `cancelledDate`, `commitmentProgress` |
| `PLYOfferSignature` | `planVendorId`, `identifier`, `signature`, `keyIdentifier` | `nonce`, `timestamp` |
| `PLYPresentationPlan` | `default` | `offerId`, `offerVendorId`, `storeProductId`, `planVendorId` |

`PLYSubscription.subscriptionSource` goes in that type's enum-value set: it is `[NSNumber numberWithInt:...]` today (`PLYSubscription+Hybrid.m:18`), so `.rawValue` is mandatory. `PLYProduct["plans"]` is an array of dictionaries and must be `[]`, never absent, when the native array is nil. `nextRenewalDate` and `cancelledDate` are the two keys `types.ts:138-141` documents to clients as omitted on iOS and null on Android — those two assertions are the most valuable in this file.

- [ ] **Step 3: Run the test against the Objective-C categories**

```bash
cd example/ios && pod install
UDID=$(xcrun simctl list devices booted -j | jq -r '[.devices[][]][0].udid')
xcodebuild test -workspace example.xcworkspace \
  -scheme react-native-purchasely-Unit-Tests \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

Expected: the two `billingPlanType` tests FAIL to compile, because `PLYPlan.billingPlanType(fromRNString:)` does not exist yet (Task 2 creates it). Every other test PASSES against the Objective-C categories.

If a key test fails, **the test is wrong, not the code** — go back to Step 1 and correct the key lists from the `.m` files.

- [ ] **Step 4: Comment out the two mapper tests, confirm all green**

Add `// TODO(task-2): unskip` above them and `throw XCTSkip("Task 2 introduces the Swift mappers")` as the body. Re-run Step 3. Expected: all PASS, 2 skipped.

- [ ] **Step 5: Commit**

```bash
git add packages/purchasely/ios/PurchaselyTests/SerializationContractTests.swift
git commit -m "test(ios): lock the serialization contract before the Swift port

Snapshots the key sets, the per-field absence policy and the enum value
types that the Objective-C categories produce today, so the Swift port
cannot change them silently. The absence policy is the live hazard:
Swift removes a key assigned nil, and types.ts documents to clients
which keys the iOS bridge omits."
```

---

## Task 2: Port `PLYPlan+Hybrid` to Swift

The largest serializer (145 lines) and the only one with free C functions that the surviving Objective-C calls.

**Files:**
- Create: `packages/purchasely/ios/Classes/Serialization/PLYPlan+Bridge.swift`
- Delete: `packages/purchasely/ios/Classes/Hybrid/PLYPlan+Hybrid.{h,m}`
- Modify: `packages/purchasely/ios/PurchaselyRN.m:13-14` (the two `#import` lines), `:1189`, `:1209`
- Modify: `packages/purchasely/ios/Classes/Hybrid/Purchasely_Hybrid.h` (drop the `PLYPlan+Hybrid.h` import)
- Test: `packages/purchasely/ios/PurchaselyTests/SerializationContractTests.swift` (unskip only)

**Interfaces:**
- Consumes: `SerializationContractTests` from Task 1.
- Produces, all callable from Objective-C during phase 1:
  - `PLYPlan.asDictionary: [String: Any]` (`@objc public var`)
  - `PLYPlan.isEligibleForIntroductoryOffer(completion: @escaping (Bool) -> Void)` (`@objc public func`)
  - `PLYPlan.rnString(fromBillingPlanType:) -> String` (`@objc public static func`, selector `rnStringFromBillingPlanType:`)
  - `PLYPlan.billingPlanType(fromRNString:) -> PLYBillingPlanType` (`@objc public static func`, selector `billingPlanTypeFromRNString:`)

- [ ] **Step 1: Unskip the two mapper tests**

Remove the `XCTSkip` bodies and the `TODO(task-2)` comments added in Task 1 Step 4.

- [ ] **Step 2: Run to verify they fail**

Run the command in Task 1 Step 3. Expected: compile error, `type 'PLYPlan' has no member 'billingPlanType'`.

- [ ] **Step 3: Write `PLYPlan+Bridge.swift`**

Read `ios/Classes/Hybrid/PLYPlan+Hybrid.m` in full first. Translate it key for key. The mandatory shape:

```swift
//
//  PLYPlan+Bridge.swift
//  Serializes a PLYPlan for the React Native bridge.
//  Ported from PLYPlan+Hybrid.m. The key set, the per-key absence policy and
//  the value types are a client contract — see SerializationContractTests and
//  types.ts. `@objc public` is temporary: PurchaselyRN.m still calls this
//  during phase 1, and a framework-layout target's generated header carries
//  only public declarations. Phase 2 reduces it to `internal`.
//

import Foundation
import Purchasely

@objc public extension PLYPlan {

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [:]

        // Unconditional keys: same order as PLYPlan+Hybrid.m, so a diff of the
        // two files reads straight down.
        dict["vendorId"] = vendorId
        // Constraint 5: .rawValue, never the enum value itself.
        dict["type"] = type.rawValue

        // Guarded keys: Objective-C omitted them when nil, so Swift must too.
        // Writing `dict["price"] = price` with a nil price also removes the
        // key, but write the guard explicitly — it documents the policy and it
        // survives a later refactor that introduces a non-optional default.
        if let price = price(with: nil) {
            dict["price"] = price
        }

        return dict
    }

    func isEligibleForIntroductoryOffer(completion: @escaping (Bool) -> Void) {
        // Same call the Objective-C category made. No blocking wait
        // (constraint 8): the SDK's completion drives ours.
        isEligibleForIntroductoryOffer { isEligible in
            completion(isEligible)
        }
    }

    // MARK: - billing plan type wire values

    /// Replaces the C function `PLYBillingPlanTypeToRNString`. A free Swift
    /// function cannot be `@objc`, so this is a static member and
    /// `PurchaselyRN.m` calls it as `[PLYPlan rnStringFromBillingPlanType:x]`.
    @objc(rnStringFromBillingPlanType:)
    static func rnString(fromBillingPlanType type: PLYBillingPlanType) -> String {
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

Check the real enum case names against the SDK before compiling:

```bash
rg -n 'enum PLYBillingPlanType' -A6 \
  example/ios/Pods/Purchasely/Purchasely/Frameworks/Purchasely.xcframework/ios-arm64_x86_64-simulator/Purchasely.framework/Modules/Purchasely.swiftmodule/arm64-apple-ios-simulator.swiftinterface
```

- [ ] **Step 4: Update the two Objective-C call sites and the imports**

In `packages/purchasely/ios/PurchaselyRN.m`:

```objc
// line 1189 — was: PLYBillingPlanTypeFromRNString(billingPlanType)
[PLYPlan billingPlanTypeFromRNString:billingPlanType]

// line 1209 — was: PLYBillingPlanTypeToRNString(offering.billingPlanType)
[PLYPlan rnStringFromBillingPlanType:offering.billingPlanType]
```

The generated Swift header is already imported at `PurchaselyRN.m:24-28`, so no new import is needed. Remove `PLYPlan+Hybrid.h` from `Classes/Hybrid/Purchasely_Hybrid.h`.

- [ ] **Step 5: Delete the Objective-C category and reinstall the pod**

```bash
git rm packages/purchasely/ios/Classes/Hybrid/PLYPlan+Hybrid.h \
       packages/purchasely/ios/Classes/Hybrid/PLYPlan+Hybrid.m
cd example/ios && pod install
```

- [ ] **Step 6: Run the tests**

Run the command in Task 1 Step 3. Expected: all PASS, 0 skipped. If `PurchaselyRN.m` fails to find `rnStringFromBillingPlanType:`, the cause is `@objc internal` instead of `@objc public` — see the file's own header comment.

- [ ] **Step 7: Build the example app both ways**

```bash
cd example/ios && xcodebuild -workspace example.xcworkspace -scheme example \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
USE_FRAMEWORKS=static pod install && xcodebuild -workspace example.xcworkspace \
  -scheme react-native-purchasely -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```

Expected: both `BUILD SUCCEEDED`. The second is what the `iOS Build (use_frameworks!)` CI job runs, and it is the one that catches `@objc internal`.

- [ ] **Step 8: Restore the default pod install and commit**

```bash
cd example/ios && pod install
git add -A packages/purchasely/ios example/ios/Podfile.lock
git commit -m "refactor(ios): port the PLYPlan serializer to Swift

The two FOUNDATION_EXPORT C mappers become @objc static members, since a
free Swift function cannot be @objc, and PurchaselyRN.m's two call sites
move with them. @objc public is temporary: a framework-layout target's
generated header carries only public declarations."
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
- Produces: `asDictionary: [String: Any]` as an `@objc public var` on each of the four types.

- [ ] **Step 1: Run the tests to confirm the four sections currently pass**

Run the command in Task 1 Step 3. Expected: PASS against the Objective-C categories. This is the baseline the port must not move.

- [ ] **Step 2: Port the four files**

One file each, same shape as Task 2 Step 3, same header comment. Translate key for key, in source order, from the matching `.m`. The three rules that decide correctness, all from Global Constraints:

- A key assigned inside `if (x != nil)` keeps an explicit `if let` guard (constraint 6).
- Every enum value gets `.rawValue` (constraint 5). In these four files that is at least `PLYSubscription.subscriptionSource` (`PLYSubscription+Hybrid.m:18`) and `PLYProduct`'s type field.
- A nil array coalesces to `[]`, it does not vanish: `dict["plans"] = (plans ?? []).map { $0.asDictionary }` (`PurchaselyRN.m:1150` is the precedent).

`PLYSubscription+Bridge.swift` carries the date formatting. Keep the format string byte-identical:

```swift
private let ply_bridgeDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    // Byte-identical to PLYSubscription+Hybrid.m. The JS layer parses this.
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    return formatter
}()

@objc public extension PLYSubscription {
    var asDictionary: [String: Any] {
        var dict: [String: Any] = [:]
        dict["subscriptionSource"] = subscriptionSource.rawValue
        // Omitted when nil — types.ts:138-141 documents this to clients.
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

- [ ] **Step 4: Run the tests**

Run the command in Task 1 Step 3. Expected: all PASS, no assertion edited. A failure on an absence test means a guard was dropped in Step 2.

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
            guard let (r, g, b, a) = rgba(form) else {
                return XCTFail("'\(form)' must parse")
            }
            XCTAssertEqual(r, 1.0, accuracy: 0.01, form)
            XCTAssertEqual(g, 0.0, accuracy: 0.01, form)
            XCTAssertEqual(b, 0.0, accuracy: 0.01, form)
            XCTAssertEqual(a, 1.0, accuracy: 0.01, form)
        }

        // RRGGBBAA: the alpha byte is last.
        guard let (_, _, _, alpha) = rgba("#00000080") else {
            return XCTFail("8-digit form must parse")
        }
        XCTAssertEqual(alpha, 0.5, accuracy: 0.01)
    }

    func testHexParserRejectsGarbageInsteadOfTrapping() {
        XCTAssertNil(UIColor.ply_fromHex(nil))
        XCTAssertNil(UIColor.ply_fromHex(""))
        XCTAssertNil(UIColor.ply_fromHex("   "))
        XCTAssertNil(UIColor.ply_fromHex("#12"))       // too short
        XCTAssertNil(UIColor.ply_fromHex("#1234567"))  // 7 digits
        XCTAssertNil(UIColor.ply_fromHex("#GGGGGG"))   // 6 chars, not hex
    }
```

Before writing the expectations, read `UIColor+PLYHelper.m:14-66` and add one case per accepted form it handles (3, 6 and 8 digits, with and without `#`, whatever it really supports). Do not invent forms it rejects today.

- [ ] **Step 3: Run to verify it fails**

Run the command in Task 1 Step 3. Expected: compile error, `UIColor has no member ply_fromHex` — the Objective-C category's selector is `ply_fromHex:` but it is not visible to Swift under that Swift name until it is Swift.

If it *does* compile and pass, the Objective-C category is already reachable; then keep the test as the port's baseline and continue.

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

- [ ] **Step 5: Run the tests**

Run the command in Task 1 Step 3. Expected: all PASS.

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
        let constants = PurchaselyRN().constantsToExport() as? [String: Any] ?? [:]
        for (key, value) in constants {
            XCTAssertTrue(
                value is NSNumber,
                "constant '\(key)' is \(type(of: value)), expected NSNumber — write .rawValue"
            )
        }
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
        var entries: [(String, String)] = []
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

- [ ] **Step 2: Run it against the Objective-C module**

Run the command in Task 1 Step 3, filtered:

```bash
xcodebuild test -workspace example.xcworkspace -scheme react-native-purchasely-Unit-Tests \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO \
  -only-testing:react-native-purchasely-Unit-Tests/BridgeExportContractTests 2>&1 | tail -30
```

Expected: all 7 tests PASS. A failure here means one of the three literal lists is wrong — regenerate it with the command in the doc comment and fix the list, not the code.

- [ ] **Step 3: Prove the gate has teeth**

Comment out `RCT_EXPORT_METHOD(closeAllScreens)` in `PurchaselyRN.m`, re-run Step 2. Expected: `testExportedJSNamesAreExactlyTheContract` FAILS naming `closeAllScreens` as missing, and `testExportedMethodCountMatches` FAILS with 62. Then restore the line and re-run: PASS.

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
```

The web-redemption body tests are the important ones. They assert which key holds `NSNull` on a success and on a failure alike (`PurchaselyRN.h` documents the policy), which is exactly the behaviour Global Constraint 6 protects:

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
    XCTAssertEqual(Set(success.keys), Set(failure.keys))
    // NSNull, not an absent key — this payload's policy differs from the
    // subscription serializer's. See spec section 8.4.
    XCTAssertTrue(success["error"] is NSNull)
}
```

Check the real Swift name of `+webRedemptionBodyWithSuccess:hasContext:subscription:replay:errorCode:errorMessage:` before writing it; the Swift importer decides it, and Task 14 must keep whatever name this test uses.

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

    func testRequiresMainQueueSetupMatches() {
        XCTAssertEqual(PurchaselyBridge.requiresMainQueueSetup(),
                       PurchaselyRN.requiresMainQueueSetup())
    }

    func testWithStateIsNotReentrantButSequentialBlocksAreFine() {
        // Documents constraint 7. Two sequential locked blocks are the shape
        // closePresentation uses (PurchaselyRN.m:1807 and :1826); nesting them
        // would deadlock, and this test is where that gets noticed.
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

class PurchaselyBridge: RCTEventEmitter {

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

    /// Weak, as `_sharedEmitter` was at PurchaselyRN.m:365.
    static weak var sharedEmitter: PurchaselyBridge?

    /// Gate from PurchaselyRN.m: drop events before startObserving.
    var shouldEmit = false

    // MARK: - RCTEventEmitter

    override static func requiresMainQueueSetup() -> Bool {
        // Keep whatever PurchaselyRN.m:1447 returns. Do not "clean this up".
        false
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
        [
            "logLevelDebug": PLYLogLevel.debug.rawValue,
            "logLevelInfo": PLYLogLevel.info.rawValue,
            "logLevelWarn": PLYLogLevel.warn.rawValue,
            "logLevelError": PLYLogLevel.error.rawValue,
            "productResultPurchased": Self.purchaseResultOrdinal(.purchased),
            // … the remaining 55, in PurchaselyRN.m:472-533 order.
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

    /// Ported from `purchaseResultOrdinal` (PurchaselyRN.m:178).
    static func purchaseResultOrdinal(_ result: PLYPurchaseResult) -> NSNumber {
        // Keep the exact ordinals PurchaselyRN.m produced: PurchaselyView.swift
        // documents that it mirrors them.
        switch result {
        case .purchased: return 0
        case .cancelled: return 1
        case .restored: return 2
        @unknown default: return 1
        }
    }
}
```

Then transcribe the remaining 55 constants. Verify each SDK enum case name against the `.swiftinterface` rather than guessing; `@(PLYAttributeFirebaseAppInstanceId)` becomes `PLYAttribute.firebaseAppInstanceId.rawValue` only if that is what the interface says.

- [ ] **Step 4: Run the tests**

Run the command in Task 6 Step 3. Expected: all `BridgeSkeletonTests` PASS. `testConstantsMatchTheObjectiveCModuleExactly` is the one that catches a mistyped constant, and it compares against the live Objective-C module, so it cannot be fooled by a typo in a literal list.

- [ ] **Step 5: Commit**

```bash
git add packages/purchasely/ios/PurchaselyRN.swift \
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

**Source ranges:** `PurchaselyRN.m:536-705` (`start` and its builder-payload parsing, `runningModeFromOrdinal` at `:259`), `:656-705` (`setLogLevel`, `setThemeMode`), `:668-705` (`userLogin`, `userLogout`, `isAnonymous`, `handleDeeplink`), `:955-1000` (`getAnonymousUserId`, `readyToOpenDeeplink`, `allowDeeplink`, `allowCampaigns`), `:1240-1295` (`revokeDataProcessingConsent` and `mapPurposesFromStrings:`), `:1269` (the `NSNotificationCenter` observer), plus `setLanguage`, `setDebugMode`, `userDidConsumeSubscriptionContent`, `synchronize`.

**Interfaces produced:** 16 `@objc` exported methods, plus `@objc func purchasePerformed()` — that one is **called by selector** from the notification centre at `:638`, so it must keep `@objc` even though nothing calls it in Swift.

**The three traps in this range:**

```swift
// 1. Inbound raw values. setLogLevel:(NSInteger) accepted any integer; the
//    Swift initializer returns nil (constraint: never force-unwrap an SDK enum).
@objc(setLogLevel:)
func setLogLevel(_ logLevel: NSNumber) {   // NSNumber stays non-optional
    guard let level = PLYLogLevel(rawValue: logLevel.intValue) else {
        PLYRNLogWarn("Unknown log level \(logLevel), keeping the current one")
        return
    }
    Purchasely.logLevel = level
}

// 2. The notification observer must survive the port. Register it exactly
//    where PurchaselyRN.m:638 did, inside start's completion.
NotificationCenter.default.addObserver(
    self, selector: #selector(purchasePerformed),
    name: .ply_purchasedSubscription, object: nil
)

// 3. `Int(exactly:)`, never `Int(_:)`. PurchaselyRN.m:740 casts a double after
//    a fmod test that 1e300 passes: in C that is garbage, in Swift Int(1e300)
//    is a fatal error.
if let asInt = Int(exactly: value.doubleValue.rounded()) { … } else { … double path … }
```

`PLYRNLogWarn` does not exist until Task 14. For Tasks 9–13 use `NSLog("[Purchasely] …")` and add a `// TODO(task-14): PLYRNLogWarn` marker; Task 14 Step 6 replaces them all.

### Task 10: `PurchaselyRN+Attributes.swift`

**Files:** Create `packages/purchasely/ios/PurchaselyRN+Attributes.swift`. Test: `packages/purchasely/ios/PurchaselyTests/BridgeAttributesTests.swift`.

**Source ranges:** `PurchaselyRN.m:715-955` — the 20 `setUserAttributeWith*` methods, `incrementUserAttribute`, `decrementUserAttribute`, `userAttribute`, `userAttributes`, `clearUserAttribute`, `clearUserAttributes`, `clearBuiltInAttributes`, `getBuiltInAttributes`, `getBuiltInAttribute`, `setAttribute`, and the legal-basis mapper at `:705`.

**Interfaces produced:** 20 `@objc` exported methods plus `static func legalBasis(fromOrdinal:) -> PLYLegalBasis`.

**The traps:** `incrementUserAttribute` uses 32-bit `intValue` at `:857` — keep that width, do not widen it to `Int`. The array setters take `NSArray`; declare them `[Any]?` per constraint 4. `userAttribute` reads back arrays, and the read path is where the Android bridge needed `Arguments.makeNativeArray` — check what the iOS read path returns and keep it.

### Task 11: `PurchaselyRN+Products.swift`

**Files:** Create `packages/purchasely/ios/PurchaselyRN+Products.swift`. Test: `packages/purchasely/ios/PurchaselyTests/BridgeProductsTests.swift`.

**Source ranges:** `PurchaselyRN.m:1000-1240` — `purchaseWithPlanVendorId`, `restoreAllProducts`, `silentRestoreAllProducts`, `synchronize`, `allProducts`, `productWithIdentifier`, `planWithIdentifier`, `userSubscriptions`, `userSubscriptionsHistory`, `setDynamicOffering`, `getDynamicOfferings`, `removeDynamicOffering`, `clearDynamicOfferings`, `signPromotionalOffer`, `isEligibleForIntroOffer`.

**Interfaces produced:** 15 `@objc` exported methods.

**The traps:**

```swift
// 1. The two selectors that change (constraint 3). Their JS name must not.
@objc(restoreAllProducts:reject:)          // was resolve:reject:
@objc(silentRestoreAllProducts:reject:)    // was silentRestoreWithResolve:reject:

// 2. A nil array coalesces to [], it does not vanish (PurchaselyRN.m:1150).
resolve((subscriptions ?? []).map { $0.asDictionary })

// 3. The billing-plan-type mappers are now on PLYPlan, from phase 1 Task 2.
//    In Swift call them by their Swift names, not the @objc selectors:
//    PLYPlan.billingPlanType(fromRNString: value)
```

### Task 12: `PurchaselyRN+Presentations.swift`

The largest and riskiest extension. **Read the whole range before writing anything.**

**Files:** Create `packages/purchasely/ios/PurchaselyRN+Presentations.swift`. Test: `packages/purchasely/ios/PurchaselyTests/BridgePresentationsTests.swift`.

**Source ranges:** `PurchaselyRN.m:76-320` (the presentation helpers: `stringFromPresentationAction`, `presentationActionFromString`, `stringFromWebCheckoutProvider`, `presentationToMap`, `presentationErrorToMap`, `closeReasonToRNString`, `applyPresentationDisplayOptions`, `plyParseDimensionMap`, `plyTransitionFromMap`), `:206` (`presentationBuilderFor`), `:1296-1450` (the 3 delegate methods and the web-redemption body), `:1489-1516` (`extractPresentationTargets`), `:1517-1900` (`preloadPresentation`, `displayPresentation`, the default dismiss handler, `closePresentation`, `goBackToPreviousScreen`, `closeAllScreens`, the BYOS methods and `loadedClientPresentationForMap`).

**Interfaces produced:**
- 9 `@objc` exported methods
- `static func presentationToMap(_ presentation: any PLYPresentation) -> [String: Any]` — **`internal`, not `private`**: Task 13 calls it. Swift's private-in-extension exception is per file.
- `static func webRedemptionBody(withSuccess:hasContext:subscription:replay:errorCode:errorMessage:) -> [String: Any]` — keep the exact Swift name Task 6's test uses
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

At this point the project has two `PurchaselyRN` classes and **will not compile**. That is expected until Step 4.

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

RCT_EXTERN_METHOD(start:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(userLogin:(NSString *)userId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// … the remaining 61, one per Swift @objc(...) selector.

@end
```

Generate the list rather than typing it. Run this and use its output as the starting point, then align each line with the matching Swift `@objc(...)`:

```bash
cd packages/purchasely/ios
rg -o '@objc\(([^)]+)\)' -r '$1' PurchaselyRN.swift PurchaselyRN+*.swift | sort
```

- [ ] **Step 5: Delete the four obsolete files**

```bash
cd packages/purchasely/ios
git rm PurchaselyRN.h PLYTransitionFactory.swift
git rm -r Purchasely.xcodeproj
```

`PurchaselyRN.h` goes because no host app imports it and the React headers reach Swift through `react-native-purchasely-Bridging-Header.h` (Global Constraint 12 — do **not** delete that file too). `Purchasely.xcodeproj` is read by no CI job and no `pod install`, and it still lists the files this task removes.

- [ ] **Step 6: Replace the `NSLog` markers with `PLYRNLogWarn`**

```bash
rg -n 'TODO\(task-14\)' packages/purchasely/ios
```

Replace each marked `NSLog(...)` with `PLYRNLogWarn("…")` and delete the marker. Swift sees `PLYRNLogWarn` because the shim declares it in a `.m` whose header — none — is not needed: add its declaration to `react-native-purchasely-Bridging-Header.h`:

```objc
/// Non-variadic wrapper around RCTLogWarn, for the Swift side. Defined in
/// PurchaselyRN.m; RCTLogWarn itself is a variadic macro that Swift cannot see.
FOUNDATION_EXPORT void PLYRNLogWarn(NSString *message);
```

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
- Modify: `packages/purchasely/CLAUDE.md` (9 lines) — or `CLAUDE.md` at the repo root, whichever holds them
- Modify: `docs/superpowers/specs/2026-09-08-ios-bridge-swift-migration-design.md` (status line)

**Interfaces:** none.

- [ ] **Step 1: Find every stale reference**

```bash
rg -n 'PurchaselyRN\.m|PurchaselyRN\.h|PurchaselyRNTests\.m|Classes/Hybrid|PLYTransitionFactory|~1500 lines|~330|~265' CLAUDE.md
```

- [ ] **Step 2: Correct them**

Nine lines name the moved files (75, 76, 99, 441, 591, 604, 623, 711, 724). Also fix the two stale test line counts: `CLAUDE.md` says 330 and 265; the real files were 535 and 785 before this work. And the "Modifying Native Bridge / iOS" section must now say: edit the Swift file for the method, **and** add or update its `RCT_EXTERN_METHOD` line in `PurchaselyRN.m`, copying the selector from the Swift `@objc(...)` annotation.

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
| 8.4 per-field absence policy | 1, 3, 6 |
| 8.5 exported signatures | Global Constraints 3 and 4 |
| 9 the contract | 1, 5 |
| 10 tests and CI | 1, 5, 6; 4 step 7; 14 step 8 |
| 12 phase 1 `@objc public`, the 2 C functions | 2 |
| 14 definition of done | 4 step 7; 14 steps 9, 10; 15 step 3 |
