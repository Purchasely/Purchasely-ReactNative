# Purchasely React Native — E2E Test Index

Tests exécutés séquentiellement sur émulateur/simulateur via CI nightly.
Déclenchés par le script hôte → composant `E2ETestRunner.tsx` embarqué dans l'APK/app.

| Platform | Script hôte | CI workflow | Statut |
|----------|-------------|-------------|--------|
| Android | `run_e2e.sh` | `e2e-android.yml` | ✅ Actif |
| iOS | `run_e2e_ios.sh` | `e2e-ios.yml` | ✅ Actif |

---

## T1 — Anonymous user ID (non-empty + UUID format)

**Inspiré de :** INIT-04 + INIT-05 (Android)

**Ce que ça teste :** `getAnonymousUserId()` retourne un identifiant non-vide au format UUID.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `getAnonymousUserId()` | `id.length > 0` |
| 2 | — | `id` matches `/^[0-9a-f]{8}-[0-9a-f]{4}-…/i` |

**Marqueurs :** `[E2E:T1:PASS]` / `[E2E:T1:FAIL]` — **Driver host :** aucun

---

## T2 — Cycle login / logout

**Inspiré de :** INIT-03 + INIT-07 + INIT-08 (Android)

**Ce que ça teste :** `isAnonymous()` passe `true → false → true` autour de `userLogin()` / `userLogout()`.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `isAnonymous()` | `true` |
| 2 | `userLogin('rn_it_user')` | — |
| 3 | `isAnonymous()` | `false` |
| 4 | `userLogout()` | — |
| 5 | `isAnonymous()` | `true` |

**Marqueurs :** `[E2E:T2:PASS]` / `[E2E:T2:FAIL]` — **Driver host :** aucun

---

## T3 — Preload : propriétés de présentation

**Inspiré de :** PRES-01 + PRES-02 + PRES-03 (Android)

**Ce que ça teste :** `presentation.placement(id).build().preload()` retourne un objet `Presentation` complet.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `preload()` | objet non-null |
| 2 | — | `screenId` non-vide |
| 3 | — | `placementId === 'integration_test_audiences'` |
| 4 | — | `type` est `NORMAL` ou `FALLBACK` (jamais null) |
| 5 | — | `plans.length > 0` |
| 6 | — | `plans[0].planVendorId` non-vide |

**Propriétés loguées :** `screenId`, `placementId`, `type`, `audienceId`, `plans.length`, `plans[0].planVendorId`

**Marqueurs :** `[E2E:T3:PASS]` / `[E2E:T3:FAIL]` — **Driver host :** aucun

---

## T4 — Dynamic offerings

**Ce que ça teste :** `getDynamicOfferings()` retourne un tableau (peut être vide sur émulateur).

**Marqueurs :** `[E2E:T4:PASS]` / `[E2E:T4:FAIL]` — **Driver host :** aucun

---

## T5 — All products

**Ce que ça teste :** `allProducts()` retourne un tableau.

**Marqueurs :** `[E2E:T5:PASS]` / `[E2E:T5:FAIL]` — **Driver host :** aucun

---

## T6 — Interceptor cleanup round-trip

**Inspiré de :** ACT (Android) — setup / teardown pattern

**Ce que ça teste :** `interceptAction()` → `removeActionInterceptor()` → `removeAllActionInterceptors()` sans erreur.

**Marqueurs :** `[E2E:T6:PASS]` / `[E2E:T6:FAIL]` — **Driver host :** aucun

---

## T7 — Display drawer + close programmatique → outcome properties

**Inspiré de :** CB-01 (Android) — dismiss callback CANCELLED + PROGRAMMATIC

**Ce que ça teste :** `req.display({ type: 'drawer', height: 60% })` → `req.close()` → outcome vérifié.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `preload()` | — |
| 2 | `req.display({ type: 'drawer', height: 60% })` | — |
| 3 | `await sleep(3000)` | drawer rendu |
| 4 | `req.close()` | — |
| 5 | Await `displayPromise` (timeout 15 s) | outcome reçu |
| 6 | — | `closeReason === 'programmatic'` (épinglé) |
| 7 | — | `purchaseResult === 'cancelled'` (aucun achat) |
| 8 | — | `presentation.screenId` non-vide |
| 9 | — | `presentation.placementId` non-vide |

**Marqueurs :** `[E2E:T7:PASS]` / `[E2E:T7:FAIL]` — **Driver host :** aucun

---

## T8 — Purchase interceptor : plan + offer sur tap réel

**Inspiré de :** ACT-01 + ACT-08 (Android)

**Ce que ça teste :** L'interceptor `'purchase'` se déclenche quand l'utilisateur tape le bouton d'achat. On vérifie les paramètres de l'action.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `interceptAction('purchase', handler)` | — |
| 2 | `req.display()` | paywall affiché |
| 3 | `await sleep(3000)` | — |
| 4 | Émet `[E2E:READY_FOR_TAP]` | — |
| 5 | Driver hôte tape `action:purchase` | interceptor déclenché |
| 6 | `waitFor(() => capturedPayload, 40000)` | payload reçu |
| 7 | — | `payload.plan.vendorId` non-vide |
| 8 | — | `payload.offer` (promo offer — null si pas configuré) |
| 9 | — | `info.contentId` présent |
| 10 | `req.close()` + cleanup | — |

**Handler retourne `'success'`** — pas d'achat natif déclenché.

**Marqueurs :**
- `[E2E:READY_FOR_TAP]` — signal driver
- `[E2E:T8:PASS]` / `[E2E:T8:FAIL]`

**Driver host Android :** `tools/tap_purchase.sh` (UIAutomator → content-desc="action:purchase")
**Driver host iOS :** `tools/tap_purchase_ios.sh` (idb `ui describe-all` → tap du CTA en points)
**Timeout waitFor :** 40 s

---

## T9 — Default dismiss handler + deeplink + BACK → outcome properties

**Inspiré de :** CB-04 (Android) + PRES propriétés

**Ce que ça teste :** `setDefaultPresentationDismissHandler()` reçoit l'outcome (avec `presentation.screenId` et `placementId`) quand un paywall ouvert via `handleDeeplink()` est fermé par BACK / swipe-dismiss.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `setDefaultPresentationDismissHandler(cb)` | — |
| 2 | `handleDeeplink(ply://ply/placements/...)` | `true` retourné |
| 3 | `await sleep(2000)` | paywall rendu |
| 4 | Émet `[E2E:READY_FOR_BACK]` | — |
| 5 | Driver hôte presse BACK (Android) / swipe-dismiss (iOS) | handler appelé |
| 6 | `waitFor(() => globalOutcome, 40000)` | outcome reçu |
| 7 | — | `closeReason === 'backSystem'` (épinglé — BACK Android / swipe iOS) |
| 8 | — | `presentation.screenId` non-vide |
| 9 | — | `presentation.placementId` non-vide |

**Marqueurs :**
- `[E2E:READY_FOR_BACK]` — signal driver
- `[E2E:T9:PASS]` / `[E2E:T9:FAIL]`

**Driver host Android :** `tools/press_back.sh`
**Driver host iOS :** `tools/swipe_dismiss_ios.sh` (idb : bouton fermer sinon swipe-down)
**Timeout waitFor :** 40 s

---

## T10 — addEventListener → PRESENTATION_VIEWED

**Inspiré de :** PRES-04 + PRES-07 (Android)

**Ce que ça teste :** L'événement `PRESENTATION_VIEWED` est émis quand une présentation est affichée, avec ses propriétés.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `addEventListener(listener)` | — |
| 2 | `req.display()` | — |
| 3 | `waitFor(() => viewedEvent, 15000)` | événement reçu |
| 4 | — | `event.name === 'PRESENTATION_VIEWED'` |
| 5 | — | `event.properties.placement_id` non-vide |
| 6 | — | `event.properties.sdk_version` non-vide |
| 7 | `req.close()` + `listener.remove()` | — |

**Marqueurs :** `[E2E:T10:PASS]` / `[E2E:T10:FAIL]` — **Driver host :** aucun

---

## T11 — PRESENTATION_CLOSED → placement_id + displayed_presentation

**Inspiré de :** PRES-08 + PRES-10 (Android)

**Ce que ça teste :** L'événement `PRESENTATION_CLOSED` est émis avec `placement_id` et `displayed_presentation` quand on ferme une présentation programmatiquement.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `addEventListener(listener)` | — |
| 2 | `req.display()` | — |
| 3 | `waitFor(() => viewedEvent, 15000)` | PRESENTATION_VIEWED reçu |
| 4 | `req.close()` | — |
| 5 | `waitFor(() => closedEvent, 10000)` | PRESENTATION_CLOSED reçu |
| 6 | — | `event.properties.placement_id` non-vide |
| 7 | — | `event.properties.displayed_presentation` non-vide |

**Marqueurs :** `[E2E:T11:PASS]` / `[E2E:T11:FAIL]` — **Driver host :** aucun

---

## T12 — Fermeture programmatique ne déclenche pas l'interceptor

**Inspiré de :** ACT-07 (Android)

**Ce que ça teste :** `req.close()` (fermeture programmatique) ne passe pas par l'interceptor `'close'` / `'closeAll'`.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `interceptAction('close', flagFn)` | — |
| 2 | `interceptAction('closeAll', flagFn)` | — |
| 3 | `req.display()` | — |
| 4 | `await sleep(3000)` | paywall rendu |
| 5 | `req.close()` | — |
| 6 | `await sleep(2000)` | — |
| 7 | — | `interceptorCalled === false` |

**Marqueurs :** `[E2E:T12:PASS]` / `[E2E:T12:FAIL]` — **Driver host :** aucun

---

## T13 — User attributes : set / get / clear

**Inspiré de :** USER_ATTRIBUTES (Android)

**Ce que ça teste :** `setUserAttributeWith*` + `userAttribute(key)` + `clearUserAttribute(key)`.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `setUserAttributeWithString('e2e_str', 'hello_rn')` | — |
| 2 | `setUserAttributeWithNumber('e2e_num', 42)` | — |
| 3 | `setUserAttributeWithBoolean('e2e_bool', true)` | — |
| 4 | `await sleep(300)` | — |
| 5 | `userAttribute('e2e_str')` | `=== 'hello_rn'` |
| 6 | `userAttribute('e2e_num')` | `=== 42` |
| 7 | `userAttribute('e2e_bool')` | `=== true` |
| 8 | `clearUserAttribute('e2e_str/num/bool')` | — |
| 9 | `await sleep(300)` | — |
| 10 | `userAttribute('e2e_str')` | `null` |
| 11 | `userAttribute('e2e_num')` | `null` |

**Marqueurs :** `[E2E:T13:PASS]` / `[E2E:T13:FAIL]` — **Driver host :** aucun

---

## Architecture du runner

```
CI (ubuntu-latest + KVM)
  └── reactivecircus/android-emulator-runner
        └── run_e2e.sh
              ├── installe l'APK (mode E2E_MODE=true)
              ├── lance logcat en background
              ├── surveille [E2E:READY_FOR_TAP]  → tap_purchase.sh    (T8)
              ├── surveille [E2E:READY_FOR_BACK] → press_back.sh      (T9)
              └── surveille [E2E:SUITE:PASS|FAIL] → exit 0|1

CI (macos-14 + simulateur iOS)
  └── run_e2e_ios.sh
        ├── build Release (bundle JS embarqué, pas de Metro)
        ├── xcrun simctl install + launch --console (capture console.log)
        ├── xcrun simctl spawn log stream (capture secondaire)
        ├── surveille [E2E:READY_FOR_TAP]  → tap_purchase_ios.sh  (idb ui tap, points)
        ├── surveille [E2E:READY_FOR_BACK] → swipe_dismiss_ios.sh (idb close/swipe)
        └── surveille [E2E:SUITE:PASS|FAIL] → exit 0|1
```

## Marqueurs émis par E2ETestRunner.tsx

| Marqueur | Signification |
|----------|---------------|
| `[E2E:SUITE:START]` | début de la suite |
| `[E2E:Tn:PASS] <détails>` | test Tn réussi |
| `[E2E:Tn:FAIL] <message>` | test Tn échoué |
| `[E2E:READY_FOR_TAP]` | paywall T8 affiché, driver peut taper |
| `[E2E:READY_FOR_BACK]` | paywall T9 affiché, driver peut dismisser |
| `[E2E:SUITE:PASS]` | tous les tests sont passés |
| `[E2E:SUITE:FAIL]` | au moins un test a échoué |

## Mapping avec les scénarios Android

| Test RN | Scénario(s) Android |
|---------|---------------------|
| T1 | INIT-04, INIT-05 |
| T2 | INIT-03, INIT-07, INIT-08 |
| T3 | PRES-01, PRES-02, PRES-03 |
| T4 | — (RN-spécifique) |
| T5 | — (RN-spécifique) |
| T6 | ACT setup/teardown |
| T7 | CB-01 (CANCELLED + PROGRAMMATIC) |
| T8 | ACT-01, ACT-08 |
| T9 | CB-04 (BACK_SYSTEM) |
| T10 | PRES-04, PRES-07 |
| T11 | PRES-08, PRES-10 |
| T12 | ACT-07 |
| T13 | USER_ATTRIBUTES |
