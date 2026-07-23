# Custom Screens (BYOS) — React Native SDK Plan

**Created:** 2026-07-17
**Status:** Draft — awaiting review
**Tickets:** [MOB-204](https://linear.app/purchasely/issue/MOB-204) (React Native), parent [MOB-200](https://linear.app/purchasely/issue/MOB-200) "Pause/Resume flow → BYOS Bridges"
**Base branch:** `feat/sdk-v6-migration` (`react-native-purchasely@6.0.0-rc.3`, native SDKs 6.0.0-rc.3)
**Native references:** Purchasely-Android-Sources (v6, shipped), Purchasely-iOS-Sources (shipped since 5.6.2)

> Naming note: "BYOS" was the internal codename on iOS and was scrubbed from all public
> symbols before release. The public feature name is **Custom Screen** on both native SDKs.
> This plan uses "Custom Screen" for all public API and reserves "BYOS" for internal docs.

---

## 1. Context & Goal

A **Custom Screen** is a screen inside a Purchasely presentation/flow whose UI is authored by
the host app instead of the Screen Composer. The console marks such a screen `is_client: true`
and gives it a `connections` array (named exit paths, each with a `vendor_id`, a `default`
flag, and actions). When the SDK reaches a client screen it asks the app for UI, embeds the
returned UI **inside its own flow container** (inheriting the step's transition —
fullscreen/push/modal/drawer/popin), and the app drives navigation by executing connections.

This is shipped on both native SDKs:

| | Android | iOS |
|---|---|---|
| Registration | `Purchasely.setCustomScreenProvider(PLYCustomScreenProvider?)` | `Purchasely.setCustomScreenViewControllerDelegate(_:)` (UIKit, `@objc`) + SwiftUI variant, UIKit tried first |
| Provider callback | `onCustomScreenRequested(presentation: PLYPresentation): PLYCustomScreen?` — synchronous, main thread | `viewController(for: PLYPresentation) -> UIViewController?` — synchronous, main thread |
| Return type | `PLYCustomScreen.View(android.view.View)` / `.Fragment(Fragment)` | `UIViewController?` |
| Hosting | View `addView`'d / Fragment committed into the current flow fragment's container (`PLYFlowParentFragment.onCustomScreenLoaded`) | Child-VC containment inside the same `PLYProductViewController` used for normal paywalls |
| No provider / null | Warn log; container left empty; display still recorded | Warn log; presentation **self-closes** with `.cancelled` |
| Navigation | `presentation.execute(connection?)` (null → default), `presentation.back()`, `presentation.close()` | `presentation.executeConnection(connection?)` (nil → default), `presentation.close()` |
| Data handed over | Full `PLYPresentation` incl. `connections: List<PLYConnection>` (`id`, `default` public) | Full `PLYPresentation` incl. `connections: Set<PLYConnection>` (only `id` public) |
| Auto events | `clientPresentationDisplayed` fired automatically on mount (`PRESENTATION_VIEWED`) | Standard presentation lifecycle events |
| Applies to | Flow steps **and** standalone presentations | Any `isClient` presentation, flow or standalone |

The RN bridge already has three relevant building blocks (none of which is the provider):

- `PLYPresentationType.CLIENT` surfaced to TS (`src/enums.ts`, from native constants).
- `Purchasely.clientPresentationDisplayed/Closed` notification pair (`src/index.ts:358-384`,
  contract locked by `src/__tests__/index.test.ts`) — for app-managed *standalone* client
  presentations only.
- The **action-interceptor round trip** (`registerActionInterceptor` → native emits
  `PURCHASELY_ACTION_INTERCEPTED` with `callbackId` → JS resolves via
  `completeActionInterceptor`, native `CompletableDeferred`/stored-block + 30s timeout) —
  the plumbing template for any "native waits on JS" handshake.
- `requestId`-keyed native registries of loaded presentations
  (`activeLoadedPresentations` / `kPresentationsByRequest`).

**Goal:** mirror the native Custom Screen feature in React Native — a React component
rendered *inside* the native flow container for `CLIENT` steps, with connection-based
navigation, API names aligned with Android's neutral `setCustomScreenProvider`.

---

## 2. The Core Problem & Chosen Architecture

The native provider callback is **synchronous on the main thread** and must return native UI.
JS cannot answer synchronously — but unlike Flutter, React Native has a first-class mechanism
for rendering a JS-authored component into an arbitrary native container: **root views**
(`ReactRootView`/surfaces on Android, `RCTRootView`/`RCTSurfaceHostingProxyRootView` on iOS)
running on the **same JS runtime as the app** (shared state, same Redux/Context/queryClient).

> The 2025 Notion feasibility note rated RN "très compliqué" — that assessment targeted the
> old *pause/hide-the-flow* model (hiding the flow window destroys the RN controller and flow
> context). The **shipped** native design (child containment inside the flow container) makes
> the root-view approach the natural fit and requires **no native SDK changes**.

### Option A — App-registered component mounted in a native root view ✅ **chosen**

The app registers a root component once (`AppRegistry.registerComponent`) and tells the SDK
its name. The bridge's native provider synchronously returns a host Fragment/VC, then mounts
a root view for that component with `initialProps = { presentation }` (including
`connections` and a `customScreenId` correlation key). The component drives the flow via
`executeConnection`/`back`/`close` module methods.

- ✔ Same JS context as the app — custom login/onboarding steps can use app state directly.
- ✔ Matches native design exactly: transitions, back stack, standalone + flow, `display()` +
  embedded `PLYPresentationView` all work unchanged.
- ✔ Synchronous native contract satisfied without any JS round trip on the hot path — the
  component name is known upfront; only rendering is async (root view fills in when React
  commits, exactly like any RN screen).
- ✖ Root-view creation differs across old arch / new arch (bridgeless) — the main
  implementation risk (see §5 and Risks).

### Option B — Per-request JS round trip choosing a component name ❌ rejected for v1

An `interceptAction`-style handshake (`CUSTOM_SCREEN_REQUESTED` event + `callbackId` →
JS returns a component name or null) adds latency and a timeout failure mode on a UI-blocking
path, for little gain: a single root component can switch on `presentation.id` in render —
the same pattern native samples use (one delegate switching on the presentation id). Can be
added later without breaking the v1 API.

### Option C — Pause/hide the flow (MOB-200 model) ❌ deferred

Requires new native pause/resume APIs (MOB-201/MOB-205, Backlog) and has the documented
context-destruction problem. Revisit only if a customer needs full-app-navigation custom
steps that can't live in a hosted root view.

---

## 3. Public TS API (spec)

```ts
export interface PLYConnection {
  id: string | null;        // console vendor_id
  isDefault: boolean;
}

// PLYPresentation gains:
//   connections?: PLYConnection[];
//   customScreenId?: string;   // set only when delivered through the provider

export interface PLYCustomScreenProviderOptions {
  /** Name registered via AppRegistry.registerComponent(...) */
  componentName: string;
}

/** Register/replace the custom screen provider. Call after Purchasely.start(). */
Purchasely.setCustomScreenProvider(options: PLYCustomScreenProviderOptions): void;
Purchasely.removeCustomScreenProvider(): void;

/** Navigation from a custom screen (or a standalone CLIENT presentation). */
Purchasely.executeConnection(presentation: PLYPresentation, connectionId?: string): void;
Purchasely.customScreenBack(presentation: PLYPresentation): void;
Purchasely.customScreenClose(presentation: PLYPresentation): void;
```

Component contract + convenience hook:

```tsx
export interface PLYCustomScreenProps {
  presentation: PLYPresentation;   // arrives as initialProps
}

// Optional sugar shipping with the SDK:
export function usePurchaselyCustomScreen(props: PLYCustomScreenProps): {
  presentation: PLYPresentation;
  executeConnection: (connectionId?: string) => void;  // undefined → default connection
  back: () => void;
  close: () => void;
};
```

App usage:

```tsx
// index.js
AppRegistry.registerComponent('PurchaselyCustomScreen', () => PurchaselyCustomScreen);

// after Purchasely.start(...)
Purchasely.setCustomScreenProvider({ componentName: 'PurchaselyCustomScreen' });

// PurchaselyCustomScreen.tsx — one component, switch on presentation id (native-sample pattern)
function PurchaselyCustomScreen(props: PLYCustomScreenProps) {
  const { presentation, executeConnection, back } = usePurchaselyCustomScreen(props);
  switch (presentation.id) {
    case 'onboarding_custom_step': return <OnboardingStep onDone={() => executeConnection()} />;
    default: return (
      <View>
        {presentation.connections?.map(c => (
          <Button key={c.id} title={c.id ?? ''} onPress={() => executeConnection(c.id ?? undefined)} />
        ))}
        <Button title="Back" onPress={back} />
      </View>
    );
  }
}
```

`executeConnection` must operate on the **presentation instance delivered to the custom
screen** (via its `customScreenId`), never a previously fetched one — mirrors the documented
native pitfall (Android `FlowTests.kt:576`: connections differ per flow instance). For
standalone CLIENT presentations preloaded by the app, `executeConnection` falls back to the
`requestId`-keyed registry.

---

## 4. Bridge Contract

New native module methods (both platforms, names identical):

| Method | Args | Notes |
|---|---|---|
| `setCustomScreenProvider` | `componentName: string` | Registers the native provider/delegate; last call wins (matches native) |
| `removeCustomScreenProvider` | — | Android `setCustomScreenProvider(null)`; iOS `removeCustomScreenViewControllerDelegate()` |
| `executeConnection` | `presentationKey: string, connectionId: string?` | `presentationKey` = `customScreenId` (provider path) or `requestId` (standalone path); `connectionId == null` → default connection |
| `customScreenBack` | `presentationKey: string` | Android `presentation.back()`; iOS: same call the existing `goBackToPreviousScreen` path uses |
| `customScreenClose` | `presentationKey: string` | `presentation.close()` |

Marshalling additions (`PLYPresentation.toRNMap()` / `presentationToMap`):

```
connections: [ { id, isDefault } ],
customScreenId: string?        // only on provider-delivered presentations
```

`customScreenId` format `ply_cs_<uuid>`, keyed into a static `ConcurrentHashMap` (Android) /
`@synchronized` dictionary (iOS) of native `PLYPresentation` instances — same discipline as
`pendingActionInterceptors`/`kInterceptorCallbacks`; entry removed on host teardown. Note:
Android `initialProps` is a `Bundle` → convert via `Arguments.toBundle(...)`.

---

## 5. Native Implementation

### 5.1 Android (`packages/purchasely/android/.../PurchaselyModule.kt` + new files)

1. **Provider registration**:
   ```kotlin
   @ReactMethod
   fun setCustomScreenProvider(componentName: String) {
     Purchasely.setCustomScreenProvider(object : PLYCustomScreenProvider {
       override fun onCustomScreenRequested(presentation: PLYPresentation): PLYCustomScreen? {
         val id = registerCustomScreenPresentation(presentation)
         return PLYCustomScreen.Fragment(
           PurchaselyCustomScreenFragment.newInstance(componentName, id)
         )
       }
     })
   }
   ```
   Return a **Fragment** (not View) for lifecycle-driven unmount; the flow machinery commits
   it into the step container via `childFragmentManager.replace(...)`.
2. **New `PurchaselyCustomScreenFragment`** — hosts the React surface, arch-aware:
   - **Bridgeless/new arch** (RN ≥ 0.74; example app runs `newArchEnabled=true`):
     `reactHost.createSurface(context, componentName, initialPropsBundle)` → `surface.start()`
     → attach `surface.view`; `onDestroyView` → `surface.stop()`.
   - **Old arch**: `ReactRootView(context).startReactApplication(reactNativeHost.reactInstanceManager,
     componentName, initialPropsBundle)`; `onDestroyView` → `unmountReactApplication()`.
   - Host discovery: `activity.application as ReactApplication` → `.reactHost` (new) /
     `.reactNativeHost` (old); precedent for arch detection exists in RN's own
     `ReactDelegate`. Wrap in try/catch and warn-log per the SDK no-crash rule.
   - `onDestroyView` also removes the registry entry.
3. **Module methods** `executeConnection`/`customScreenBack`/`customScreenClose`: resolve the
   presentation from the custom-screen registry, falling back to `activeLoadedPresentations`
   by `requestId`; run `presentation.execute(connections.firstOrNull { it.id == connectionId })`
   (null-id → `execute(null)` = default) on the main thread. Missing entry → warn log, no-op.
4. **`toRNMap` additions**: `connections` (`PLYConnection.id`/`.default` are public) and
   `customScreenId`.

### 5.2 iOS (`packages/purchasely/ios/PurchaselyRN.m` + new files)

1. **Delegate**: `PLYRNCustomScreenDelegate: NSObject <PLYCustomScreenViewControllerDelegate>`,
   registered via `[Purchasely setCustomScreenViewControllerDelegate:]` **only** when JS calls
   `setCustomScreenProvider` (preserving iOS's no-delegate self-close default otherwise).
2. **`viewControllerForPresentation:`**:
   - Register the presentation → `customScreenId`.
   - Build the root view, arch-aware:
     - Preferred (RN ≥ 0.74, covers both archs): `RCTRootViewFactory` /
       `RCTAppDelegate.rootViewFactory` → `viewWithModuleName:initialProperties:`.
     - Old-arch fallback: `[[RCTRootView alloc] initWithBridge:self.bridge
       moduleName:componentName initialProperties:props]` (module already holds `self.bridge`
       via `RCTEventEmitter`).
   - Return `PLYRNCustomScreenViewController` (plain `UIViewController` whose `view` is the
     root view; cleans registry + tears the surface down on `didMoveToParentViewController:nil`
     / `dealloc`).
3. **Module methods** mirror Android: match `connectionId` in `presentation.connections`,
   `executeConnection:` (nil → default), back, close — dispatched to main queue.
4. **`presentationToMap` additions**: `connections` — iOS `PLYConnection` publicly exposes
   only `id`; the `default` flag is internal. → **Native iOS SDK prerequisite (tiny):**
   expose `isDefault` on `PLYConnection` (Purchasely-iOS-Sources PR). Interim: bridge
   `isDefault: false` and rely on `executeConnection(nil)` for default behavior.
5. SwiftUI delegate is **not** bridged — irrelevant from JS.

### 5.3 Event parity

Android auto-fires `clientPresentationDisplayed` on mount; closed is not auto-fired by flow
fragments. iOS shares normal presentation lifecycle events. → Verify
`PRESENTATION_VIEWED`/`PRESENTATION_CLOSED` parity in M5; if needed, call
`clientPresentationClosed` from the host teardown (aligned with what native does for normal
steps popped from a flow).

---

## 6. Milestones

Branch off `feat/sdk-v6-migration`; atomic commits per milestone; jest suite green throughout.

| # | Milestone | Contents | Est. |
|---|---|---|---|
| M1 | **Models + standalone support** | `PLYConnection` TS type; `connections`/`customScreenId` in `presentationTypes.ts` + `normalizePresentation`; native map additions (both platforms); `executeConnection` for requestId-held presentations; jest contract tests | 1–1.5 d |
| M2 | **Android provider + root-view host** | Provider registration, `PurchaselyCustomScreenFragment` (both archs), registry, module methods | 2–3 d |
| M3 | **iOS delegate + root-view host** | Delegate, `PLYRNCustomScreenViewController` (both archs), registry, module methods; iOS-Sources PR for `PLYConnection.isDefault` | 2–3 d |
| M4 | **JS API layer** | `setCustomScreenProvider/remove`, `executeConnection/back/close`, `usePurchaselyCustomScreen` hook, exports; jest tests (mirroring the existing "keep the client (BYOS) presentation API" contract test) | 1–1.5 d |
| M5 | **Example + E2E validation** | Example-app registered component (per-connection buttons, native-sample pattern); `E2ETestRunner` T-scenario for a flow with a CLIENT step; validate: all 5 transition types, pushed-inside-container steps, back navigation, event parity, unmount (no leaked surfaces), old-arch + new-arch example runs, touch handling inside modal/drawer | 2–3 d |
| M6 | **Docs + release** | README + `sdk_public_doc.md` section, arch-support matrix, CHANGELOG/RELEASE_NOTES; fold into next 6.0.0-rc / 6.1.0 | 0.5–1 d |

Total ≈ 9–13 dev-days. M2/M3 parallelizable once M1 locks the wire contract.

---

## 7. Testing Strategy

- **Jest** (`packages/purchasely/src/__tests__/`): provider registration calls the native
  method; `executeConnection` payloads (`customScreenId` vs `requestId` fallback,
  undefined → null connectionId); `normalizePresentation` with/without `connections`;
  hook behavior; API-surface contract test (extend the existing BYOS test).
- **Native units**: extract and test the connection-lookup + registry helpers (plain
  JUnit/XCTest where practical; module classes stay thin).
- **E2E**: `E2ETestRunner` scenario driving a console flow with a CLIENT step — asserts the
  registered component mounts, a connection tap advances the flow, `back()` returns, and
  `PRESENTATION_VIEWED` fires for the custom step. Needs a console flow on the example API
  key (open question OQ-1; Android integration tests use `integration_test_my_own_screen`).
- **Arch matrix**: run the example app with `newArchEnabled=true` (current default) **and**
  old arch on Android; bridgeless and legacy on iOS. This is the highest-risk axis.
- **Regression**: full jest suite + example builds — the presentation map change touches all
  presentation events.

---

## 8. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Root-view creation across old arch / new arch / bridgeless variants (`ReactHost` vs `ReactInstanceManager`, `RCTRootViewFactory` availability) | Feature broken on some RN setups | Arch-aware host classes (M2/M3); explicit arch test matrix (M5); document minimum supported RN version (repo targets 0.86; verify floor — likely ≥ 0.74 for the factory path, older versions get the legacy path) |
| First React commit latency → briefly empty container during step transition | Visible flash | JS runtime is already warm (same app instance); measure in M5; optional loading background color from `presentation.backgroundColor` |
| Touch/gesture conflicts inside modal/drawer bottom-sheets (scrim, drag-to-dismiss vs inner scroll) | Interaction bugs | Explicit M5 test matrix over all 5 transitions incl. pushed-inside-container |
| Surface/root-view leak per step | Memory growth over long flows | Lifecycle-bound teardown (Fragment `onDestroyView` / VC teardown); leak check in M5 |
| Android `null` (blank) vs iOS `nil` (self-close) asymmetry | Behavior divergence | Bridge always returns a host once registered; unregistered → native defaults apply unchanged (documented) |
| iOS `PLYConnection.isDefault` not public | `isDefault` wrong on iOS | Tiny iOS-Sources PR (M3); interim fallback documented in §5.2 |
| Custom screen rendering a `PLYPresentationView` RN component inside itself | Recursive/undefined behavior | Document as unsupported in v1 |
| Headless/JS-not-ready edge (client step reached before React context is initialized, e.g. cold-start deeplink into a flow) | Blank step | Register provider right after `Purchasely.start()`; host waits for React context readiness (`addReactInstanceEventListener`) before mounting; warn-log timeout |

---

## 9. Open Questions

- **OQ-1**: Which console placement/flow (example app's API key) will carry a CLIENT step for
  demos/E2E? (Android: `integration_test_my_own_screen`; iOS: `cm_flow_byos`.)
- **OQ-2**: Confirm iOS flow-step-back parity — reuse whatever the existing
  `goBackToPreviousScreen` iOS implementation calls; verify identical behavior from a custom
  step during M3.
- **OQ-3**: Expose connection `actions` metadata to JS? **Out of scope v1** — iOS keeps them
  opaque; parity = `id` + `isDefault` only.
- **OQ-4**: Add the per-request dynamic decision path (Option B: event + callbackId, e.g. to
  let JS decline per screen)? Deferred; additive later without breaking v1.
- **OQ-5**: Minimum RN version officially supported for this feature (drives which root-view
  code paths we must maintain).

---

## 10. Key Source References

**Native contract** (source of truth for parity):
- Android: `core/src/main/java/io/purchasely/ext/PLYCustomScreen.kt`,
  `ext/interfaces.kt:147` (`PLYCustomScreenProvider`), `ext/Purchasely.kt:1115`
  (`setCustomScreenProvider`), `ext/PLYConnection.kt`,
  `ext/presentation/PLYPresentationBase.kt:351-385` (`execute`/`back`/`close`),
  `views/flows/PLYFlowManager.kt:333` (`requestCustomScreen`),
  `views/flows/fragments/PLYFlowParentFragment.kt:468` (`onCustomScreenLoaded`),
  sample: `samplev2/.../SampleV2Application.kt:235`, tests:
  `integration-tests/.../CustomScreenProviderTests.kt`, `FlowTests.kt:124,588`.
- iOS: `Purchasely/Classes/common/Purchasely+CustomScreen.swift`,
  `Purchasely+PublicInterface.swift:813-857`,
  `Model/UI/PLYPresentation+CustomScreen.swift` (`executeConnection`),
  `Model/UI/PLYConnection.swift`,
  `specific/uikit/Controller/PLYProductViewController+Configure.swift:142-297`,
  sample: `Example/PurchaselySampleV2/.../Helpers/CustomScreens.swift`.

**RN bridge precedents** (this repo, `packages/purchasely/`):
- Interceptor round trip: `src/interceptor.ts`, `android/.../PurchaselyModule.kt`
  (`registerActionInterceptor`/`completeActionInterceptor`, `pendingActionInterceptors`),
  `ios/PurchaselyRN.m` (`kInterceptorCallbacks`, 30s timeout).
- Registries & marshalling: `PLYPresentation.toRNMap()` (Android),
  `presentationToMap` (iOS), `activeLoadedPresentations` / `kPresentationsByRequest`,
  `clientPresentationDisplayed/Closed` (`src/index.ts:358-384`, locked by
  `src/__tests__/index.test.ts:171`).
- Native-view embedding (reverse-direction precedent only):
  `src/components/PLYPresentationView.tsx`, `PurchaselyViewManager.kt`,
  `PurchaselyViewManager.swift` / `PurchaselyView.swift`.
