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

## T14 — User attributes : types étendus (double / date / arrays)

**Inspiré de :** `dart_ios_bridge_test.dart` T14 (Flutter v6)

**Ce que ça teste :** round-trip `setUserAttributeWithDouble / Date / StringArray / IntArray / BooleanArray` → `userAttribute(key)`.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `setUserAttributeWithDouble('e2e_dbl', 3.14)` | — |
| 2 | `setUserAttributeWithDate('e2e_date', new Date('2024-06-15T12:00:00.000Z'))` | — |
| 3 | `setUserAttributeWithStringArray('e2e_str_arr', ['alpha','beta','gamma'])` | — |
| 4 | `setUserAttributeWithIntArray('e2e_int_arr', [10,20,30])` | — |
| 5 | `setUserAttributeWithBooleanArray('e2e_bool_arr', [true,false,true])` | — |
| 6 | `await sleep(400)` | — |
| 7 | `userAttribute('e2e_dbl')` | `~3.14` |
| 8 | `userAttribute('e2e_date')` | `2024-06-15` |
| 9 | `userAttribute('e2e_str_arr / e2e_int_arr / e2e_bool_arr')` | `length === 3` |
| 10 | `clearUserAttribute` × 5 | — |

**Marqueurs :** `[E2E:T14:PASS]` / `[E2E:T14:FAIL]` — **Driver host :** aucun

---

## T15 — User attributes : opérations bulk

**Inspiré de :** `dart_ios_bridge_test.dart` T15

**Ce que ça teste :** `userAttributes()` retourne une map contenant les attributs, `clearUserAttributes()` vide tout, `clearBuiltInAttributes()` ne throw pas.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `setUserAttributeWithString('bulk_a', 'hello')` | — |
| 2 | `setUserAttributeWithInt('bulk_b', 99)` | — |
| 3 | `await sleep(300)` | — |
| 4 | `userAttributes()` | map contient `bulk_a === 'hello'` |
| 5 | `clearUserAttributes()` | — |
| 6 | `await sleep(300)` | — |
| 7 | `userAttribute('bulk_a')` | `null` |
| 8 | `clearBuiltInAttributes()` | — (no-throw) |

**Marqueurs :** `[E2E:T15:PASS]` / `[E2E:T15:FAIL]` — **Driver host :** aucun

---

## T16 — Increment / decrement

**Inspiré de :** `dart_ios_bridge_test.dart` T16

**Ce que ça teste :** `incrementUserAttribute` / `decrementUserAttribute` modifient un compteur.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `clearUserAttribute('e2e_counter')` | — |
| 2 | `incrementUserAttribute({ key: 'e2e_counter', value: 7 })` | — |
| 3 | `userAttribute('e2e_counter')` → v1 | `typeof v1 === 'number'` |
| 4 | `incrementUserAttribute({ key: 'e2e_counter', value: 3 })` | — |
| 5 | `userAttribute('e2e_counter')` → v2 | `v2 > v1` |
| 6 | `decrementUserAttribute({ key: 'e2e_counter', value: 4 })` | — |
| 7 | `userAttribute('e2e_counter')` → v3 | `v3 < v2` |
| 8 | `clearUserAttribute('e2e_counter')` | — |

**Marqueurs :** `[E2E:T16:PASS]` / `[E2E:T16:FAIL]` — **Driver host :** aucun

---

## T17 — Catalogue : productWithIdentifier / planWithIdentifier / isEligibleForIntroOffer

**Inspiré de :** `dart_ios_bridge_test.dart` T17

**Ce que ça teste :** lookup par `vendorId` + check d'éligibilité intro.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `allProducts()` | tableau non-vide |
| 2 | `productWithIdentifier(product.vendorId)` | `vendorId` + `name` non-vide |
| 3 | `planWithIdentifier(plan.vendorId)` | `vendorId` match |
| 4 | `isEligibleForIntroOffer(plan.vendorId)` | `boolean` |

**Marqueurs :** `[E2E:T17:PASS]` / `[E2E:T17:FAIL]` — **Driver host :** aucun

---

## T18 — Dynamic offerings : CRUD

**Inspiré de :** `dart_ios_bridge_test.dart` T18

**Ce que ça teste :** `setDynamicOffering` → `getDynamicOfferings` → `removeDynamicOffering` → `clearDynamicOfferings`.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `presentation.placement(...).preload()` | `plans[0].planVendorId` |
| 2 | `setDynamicOffering({ reference, planVendorId })` | `boolean` |
| 3 | `getDynamicOfferings()` | tableau |
| 4 | `removeDynamicOffering(reference)` | — |
| 5 | `clearDynamicOfferings()` | — |

**Marqueurs :** `[E2E:T18:PASS]` / `[E2E:T18:FAIL]` — **Driver host :** aucun

---

## T19 — Builder `screen(id)` + transitions modal / popin

**Inspiré de :** `dart_ios_bridge_test.dart` T19

**Ce que ça teste :** `PLYPresentationBuilder.screen(id).build().preload().display(transition)` puis close programmatique.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `placement(...).preload()` → récupère `screenId` | non-vide |
| 2 | `screen(screenId).build().preload()` | `screenId` non-vide |
| 3 | `display({ type: 'modal' })` puis `close()` | `outcome.presentation.screenId` non-vide |
| 4 | `display({ type: 'popin', width, height })` puis `close()` | `outcome.presentation.screenId` non-vide |

**Marqueurs :** `[E2E:T19:PASS]` / `[E2E:T19:FAIL]` — **Driver host :** aucun

---

## T20 — Config setters : smoke test

**Inspiré de :** `dart_ios_bridge_test.dart` T20

**Ce que ça teste :** `allowDeeplink` / `allowCampaigns` / `setLanguage` / `setThemeMode` / `setLogLevel` / `setDebugMode` / `revokeDataProcessingConsent` ne throw pas.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `allowDeeplink(true)` puis `false` | — (no-throw) |
| 2 | `allowCampaigns(true)` puis `false` | — (no-throw) |
| 3 | `setLanguage('en')` | — (no-throw) |
| 4 | `setThemeMode(PLYThemeMode.SYSTEM)` | — (no-throw) |
| 5 | `setLogLevel(LogLevels.DEBUG)` | — (no-throw) |
| 6 | `setDebugMode(false)` | — (no-throw) |
| 7 | `revokeDataProcessingConsent([...])` | — (no-throw) |

**Marqueurs :** `[E2E:T20:PASS]` / `[E2E:T20:FAIL]` — **Driver host :** aucun

---

## T21 — synchronize() résout OU rejette proprement (pas de hang)

**Inspiré de :** Flutter catalog **T6** (`dart_android_bridge_test.dart` / `dart_ios_bridge_test.dart`)

**Ce que ça teste :** contrat v6 de `synchronize()` : la promesse **résout** (`true` en succès) **ou rejette** avec l'erreur store native. Sur émulateur sans Play billing, elle rejette avec `BillingUnavailable` — les deux issues passent ; seul un **hang** (jamais réglée) échoue.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `Promise.race([synchronize(), timeout(20 s)])` | règle sous 20 s |
| 2 | résolution | PASS (`result` loggé) |
| 3 | rejet ≠ timeout | PASS (erreur store loggée) |
| 4 | timeout 20 s atteint | FAIL (hang) |

**Marqueurs :** `[E2E:T21:PASS]` / `[E2E:T21:FAIL]` — **Driver host :** aucun

**Divergence vs Flutter :** Flutter attend `Future<bool>` et `expect` résout `true` OU `throws PlatformException`. RN ajoute un timeout de 20 s côté test pour transformer un hang en FAIL explicite plutôt que de bloquer toute la suite (Flutter s'appuie sur le timeout global du runner).

---

## T22 — Default dismiss handler attrape un display() fire-and-forget

**Inspiré de :** `default_dismiss_via_display_test.dart` + `default_dismiss_via_display_ios_test.dart` (Flutter catalog **T11**)

**Ce que ça teste :** un `display()` **ouvert par l'app**, **non-awaité** et **sans `onDismissed` local**, route sa fermeture vers le handler global `setDefaultPresentationDismissHandler`. (Test écrit contre le comportement cible du routing local→default.)

| Step | Action | Assert |
|------|--------|--------|
| 1 | `setDefaultPresentationDismissHandler(cb)` | — |
| 2 | `req = presentation.placement(...).build()` (sans `onDismissed`) | — |
| 3 | `req.display()` (fire-and-forget, pas d'`await`) | — |
| 4 | `await sleep(3000)` | paywall rendu |
| 5 | `req.close()` | fermeture programmatique |
| 6 | `waitFor(() => defaultOutcome, 15000)` | handler global appelé |
| 7 | — | `closeReason === 'programmatic'` (épinglé) |
| 8 | — | `presentation.screenId` non-vide |

**Marqueurs :** `[E2E:T22:PASS]` / `[E2E:T22:FAIL]` — **Driver host :** aucun

**Divergence vs Flutter :** le test Flutter dismisse via un driver hôte (BACK Android → `backSystem` / tap close iOS → `button`) et accepte `anyOf`. La version RN dismisse via `req.close()` (programmatique) — pas de driver — donc `closeReason` est épinglé à `'programmatic'`, assertion plus stricte que l'`anyOf` Flutter.

---

## T23 — onDismissed local gagne sur le default handler

**Inspiré de :** `local_dismiss_handler_test.dart` (+ `_ios`) (Flutter catalog **T12**)

**Ce que ça teste :** default handler ET `onDismissed` local posés → seul le local (et le futur `display()` awaité) reçoivent l'outcome ; le default reste **silencieux**.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `setDefaultPresentationDismissHandler(cb)` | — |
| 2 | `req = placement(...).onDismissed(local).build()` | — |
| 3 | `p = req.display()` (awaité via `Promise.race`) | — |
| 4 | `await sleep(3000)` puis `req.close()` | — |
| 5 | `await p` (timeout 15 s) | outcome awaité reçu |
| 6 | — | `localOutcome` reçu (non-null) |
| 7 | — | `outcome.closeReason === 'programmatic'` |
| 8 | `await sleep(1000)` | — |
| 9 | — | `defaultOutcome === null` (default silencieux) |

**Marqueurs :** `[E2E:T23:PASS]` / `[E2E:T23:FAIL]` — **Driver host :** aucun

**Divergence vs Flutter :** dismiss programmatique (`req.close()`) au lieu du BACK/tap piloté → `closeReason` épinglé `'programmatic'` (Flutter : `anyOf`).

---

## T24 — User attribute listener : événements set + removed

**Inspiré de :** `user_attribute_listener_test.dart` (Flutter — plateforme-agnostique)

**Ce que ça teste :** `setUserAttributeListener({onUserAttributeSet, onUserAttributeRemoved})` reçoit un événement **set** (key/type/value/source) quand on pose un attribut, puis un événement **removed** (key) quand on le clear. Chaîne complète JS → EventEmitter natif → callback.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `setUserAttributeListener({...})` | — |
| 2 | `await sleep(1000)` | handshake EventChannel |
| 3 | `setUserAttributeWithString('e2e_listener_attr', 'hello_listener')` | — |
| 4 | `waitFor(() => lastSet, 15000)` | set reçu |
| 5 | — | `lastSet.value === 'hello_listener'` |
| 6 | `clearUserAttribute('e2e_listener_attr')` | — |
| 7 | `waitFor(() => lastRemovedKey, 15000)` | removed reçu |
| 8 | cleanup : `attrListener.remove()` + `clearUserAttribute` | — |

**Marqueurs :** `[E2E:T24:PASS]` / `[E2E:T24:FAIL]` — **Driver host :** aucun

**Note API RN :** `setUserAttributeListener` (index.ts, lecture seule) enveloppe `addUserAttributeSetListener` / `addUserAttributeRemovedListener` et renvoie `{ remove }`. Callback set = `(key, type, value, source)` ; callback removed = `(key, source)`.

---

## T25 — Vue embarquée `<PLYPresentationView request={…}>` : rendu + fermeture pilotée

**Inspiré de :** `inline_paywall_test.dart` + `INLINE_PAYWALL_CLOSE.md` (Flutter — Android + iOS)

**Ce que ça teste :** on précharge un `request`, on **monte** la vue embarquée dans le runner via la prop `request` (le natif résout la présentation préchargée par `requestId`, pas de second preload), on **attend le rendu** (event `PRESENTATION_VIEWED`), puis un **driver hôte tape réellement un bouton de fermeture natif** de la vue embarquée et on **asserte** l'outcome reçu (échec dur si absent).

> **Divergence Android/iOS (constatée, pas un choix) :** l'écran E2E (`nr011`, placement `integration_test_audiences`) rend un vrai bouton de fermeture (✕) côté Android — driven réellement par `tools/tap_close_inline.sh` → `closeReason === 'button'`. Côté iOS, ce même écran ne rend **aucun** bouton de fermeture, en plein écran comme en vue embarquée (confirmé par un dump `idb ui describe-all` pendant `READY_FOR_INLINE_CLOSE` : zéro élément de taille bouton avec un label de fermeture — et par le driver de repli de T9, `swipe_dismiss_ios.sh`, qui avec la même logique de matching ne trouve rien non plus en plein écran et bascule sur un swipe). C'est une différence de contenu de l'écran de test entre plateformes, pas un bug de bridge/SDK. Le driver iOS tape donc à la place un **bouton de repli E2E-only, réel et toujours affiché**, rendu par `E2ETestRunner.tsx` par-dessus la vue embarquée (label "Close", 90×36pt), câblé sur `request.close()` — le tap OS traverse quand même tout le pont RN réellement, seule la cible diffère. `closeReason` attendu : `'button'` sur Android, `'programmatic'` sur iOS.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `addEventListener(...)` (capture `PRESENTATION_VIEWED`) | — |
| 2 | `req = placement(...).build()` ; `await req.preload()` | — |
| 3 | `setInlineRequest(req)` → monte `<PLYPresentationView request={req}>` (+ bouton de repli E2E-only sur iOS) | — |
| 4 | `waitFor(() => viewedEvent, 30000)` | vue embarquée rendue |
| 5 | Émet `[E2E:READY_FOR_INLINE_CLOSE]` | — |
| 6 | Driver hôte tape le bouton natif (Android : ✕ SDK) ou le bouton de repli (iOS) | `onPresentationClosed` déclenché |
| 7 | `waitFor(() => inlineClosedRef.current, 100000)` | outcome reçu (**FAIL** si absent) |
| 8 | — | `closeReason === 'button'` (Android) / `'programmatic'` (iOS) |
| 9 | — | `presentation.screenId` non-vide |
| 10 | cleanup : `setInlineRequest(null)` + `listener.remove()` | — |

**Marqueurs :**
- `[E2E:READY_FOR_INLINE_CLOSE]` — signal driver
- `[E2E:T25:PASS]` / `[E2E:T25:FAIL]`

**Driver host Android :** `tools/tap_close_inline.sh` (UIAutomator → content-desc="action:close", vrai bouton SDK)
**Driver host iOS :** `tools/tap_close_inline_ios.sh` (idb `ui describe-all` → tap du bouton de repli E2E-only "Close" en points, sans repli swipe)
**Timeout waitFor :** 100 s

**Pourquoi c'est drivable en RN (contrairement à Flutter, voir `INLINE_PAYWALL_CLOSE.md`) :** le harness Flutter `integration_test` route les pointeurs via le binding de test de sa propre fenêtre, donc un tap `adb`/`idb` n'atteint jamais la platform view embarquée sous instrumentation. Le harness RN pilote en revanche l'app réellement lancée via `adb`/`idb` (pas de binding de test in-process), et la vue embarquée est un vrai `Fragment` Android (`PurchaselyViewManager.createFragment`, ajouté à la hiérarchie réelle) / une vraie `UIView` iOS (`PurchaselyView.attachController` → `addSubview`) — un tap au niveau OS l'atteint donc comme n'importe quel contrôle à l'écran, que la cible soit le bouton SDK (Android) ou le bouton de repli RN (iOS).

**Bug Android résolu (bridge, pas SDK) :** le tap réel sur le ✕ atteignait bien le SDK et déclenchait `PLYPresentationViewController.selfClose()` (confirmé en local via logcat), mais `PLYPresentationView.close()` ne détruisait jamais la vue : `preloadPresentation` (`PurchaselyModule.wirePresentationCallbacks`) câble **toujours** `onCloseRequested` pour relayer l'événement JS `PRESENTATION_CLOSE_REQUESTED` — utile pour un modal plein écran non-dismissible où l'app décide de la fermeture. Pour une vue plein écran/flow ce câblage est sans effet (`PLYFlowListener.onCloseRequested` est consulté en premier par le SDK et absorbe le close). Une vue **embarquée** n'a pas de `PLYFlowListener` : `close()` retombe directement sur `callbackPaywallCloseRequested`, le trouve non-null, et l'**invoke** au lieu de retirer la vue (`removeView`) — le tap ✕ ne faisait donc plus jamais rien, sans erreur ni log, jusqu'au timeout dur de 100 s. Fix : `PurchaselyViewManager.PurchaselyFragment.attachPurchaselyView` met `onCloseRequested = null` sur la présentation préchargée juste avant `buildView(...)`, uniquement pour le chemin embarqué par `requestId` — le close natif retombe alors sur le comportement par défaut du SDK (`removeView` → `onDetachedFromWindow` → outcome). Le dismiss handler qui délivre l'outcome ensuite (fix lot 1, commits `c15ca72`/`cd6f42e`/`fa147a8`/`e00bed6`) est bien générique au niveau SDK une fois cette fuite de câblage supprimée : le tap piloté produit le même `PLYPresentationOutcome` 5-champs que les tests programmatiques (T7/T22/T23/T26).

---

## T26 — Lifecycle `PLYLoadedPresentation` : display / close → outcome

**Inspiré de :** nouvelle API v6 du jour (`preload()` renvoie un objet pilotant son propre cycle de vie ; parité Flutter)

**Ce que ça teste :** `const loaded = await req.preload()` → `loaded.display({type:'modal'})` → `loaded.close()` → l'outcome arrive via la promesse de `display`, `closeReason 'programmatic'`. Les méthodes `display/close/back` de l'objet préchargé délèguent au `PLYPresentationRequest` d'origine.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `loaded = await req.preload()` | `loaded.screenId` non-vide |
| 2 | `p = loaded.display({ type:'modal', dismissible:true })` | — |
| 3 | `await sleep(2500)` puis `loaded.close()` | — |
| 4 | `await p` (timeout 15 s) | outcome reçu |
| 5 | — | `closeReason === 'programmatic'` |
| 6 | — | `outcome.presentation.screenId` non-vide |

**Marqueurs :** `[E2E:T26:PASS]` / `[E2E:T26:FAIL]` — **Driver host :** aucun

---

## T27 — Deeplink cold-start via `builder.handleDeeplink()` avant `start()`

**Inspiré de :** `deeplink_cold_start_test.dart` (Flutter — plateforme-agnostique)

**Ce que ça teste :** le modifieur builder `.handleDeeplink(url)` **avant** `.start()` : le SDK rejoue le deeplink après configuration et **auto-ouvre** le paywall, émettant `DEEPLINK_OPENED → PRESENTATION_LOADED → PRESENTATION_VIEWED`. Aucun `Purchasely.handleDeeplink(...)` manuel (ça, c'est T9).

**Contrainte :** modifier le builder d'init **avant** `start()` exige un **process neuf** → T27 tourne dans une **phase dédiée** (pas en cours de session). On s'abonne aux events **avant** `start()` pour ne pas rater la rafale de démarrage ; le process est détruit à la fin (pas de dismiss/driver nécessaire).

| Step | Action | Assert |
|------|--------|--------|
| 1 | `addEventListener(...)` (avant start, capture les 3 events) | — |
| 2 | `builder(API_KEY).…handleDeeplink(DEEPLINK_AUDIENCES).start()` | `true` |
| 3 | `waitFor(() => DEEPLINK_OPENED && PRESENTATION_VIEWED, 60000)` | rafale reçue |
| 4 | — | `DEEPLINK_OPENED.properties.deeplink_identifier` contient le placement |
| 5 | — | `indexOf(DEEPLINK_OPENED) < indexOf(PRESENTATION_VIEWED)` |
| 6 | — | `PRESENTATION_VIEWED.properties.sdk_version` non-vide |

**Marqueurs :** phase dédiée `E2E_PHASE=deeplink_coldstart` sur **les deux plateformes** → `[E2E:T27:PASS]` / `[E2E:T27:FAIL]`. Dans la suite principale (T1-T26), T27 émet `[E2E:T27:SKIP]` (déféré à la phase) — même message côté Android et iOS.

**Driver host :** aucun (le cold-start s'auto-ouvre, pas de tap).
**Phase host Android :** `run_e2e.sh` relance l'app avec `am start --es E2E_PHASE deeplink_coldstart` après la suite principale et surveille `[E2E:T27:PASS|FAIL]`.
**Phase host iOS :** `run_e2e_ios.sh` relance l'app avec `SIMCTL_CHILD_E2E_PHASE=deeplink_coldstart xcrun simctl launch` (simctl transmet la variable d'environnement au process lancé en retirant le préfixe `SIMCTL_CHILD_`) ; `AppDelegate.swift` lit `ProcessInfo.processInfo.environment["E2E_PHASE"]` et la transmet comme initial prop `phase` (miroir de `MainActivity` lisant l'intent extra `E2E_PHASE`).

**Divergence vs Flutter :** Flutter teste dans un `testWidgets` isolé (chaque test Flutter démarre son propre process/binding) — le cold-start y est naturel. RN partage une seule session pour T1-T26, d'où la **phase dédiée** (2ᵉ launch, Android et iOS). Assertions allégées vs Flutter : on exige `DEEPLINK_OPENED` + `PRESENTATION_VIEWED` (invariants cross-platform robustes) et on capture `PRESENTATION_LOADED` sans le rendre obligatoire.

---

## T28 — Vue embarquée imbriquée dans un écran `react-native-screens`

**Ce que ça teste :** une `PLYPresentationView` montée **à l'intérieur** d'un `ScreenStack` / `ScreenStackItem` de `react-native-screens`, c'est-à-dire la hiérarchie que produit tout écran de `@react-navigation/native-stack`.

**Le bug gardé (iOS) :** `PurchaselyView.attachController` déclarait le contrôleur embarqué enfant du **root** view controller de l'app, alors que sa vue vit sous un `RNSScreen`. UIKit lève `UIViewControllerHierarchyInconsistency` dès que les deux divergent et **l'app meurt**. Sur un build non corrigé ce test n'échoue donc pas : plus aucun marqueur n'est émis, et la suite tombe sur son propre filet.

**Pourquoi T25 ne le voyait pas :** T25 monte la vue dans un overlay absolu, où le vrai ancêtre EST le root VC. C'est l'imbrication qui fait tout le test.

Android n'a jamais eu le bug (il attend `isAttachedToWindow` avant de créer son fragment) mais fait tourner le même test en parité.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `presentation.placement(...).build().preload()` | — |
| 2 | monter la vue dans `<ScreenStack><ScreenStackItem>` | — |
| 3 | `waitFor(PRESENTATION_VIEWED, 30000)` | event reçu, app vivante |
| 4 | `[E2E:READY_FOR_NESTED_SHOT]` → capture hôte | screenshot non vide |

**Marqueurs :** `[E2E:T28:PASS]` / `[E2E:T28:FAIL]`, plus `[E2E:READY_FOR_NESTED_SHOT]`
**Driver host :** `capture_nested_inline.sh` (Android) / `capture_nested_inline_ios.sh` (iOS) — capture seule, l'assertion dure est le marqueur lui-même.
**Artefact :** `integration_test/artifacts/e2e_t28_nested_inline_{android,ios}.png`

---

## T29 — Deux vues embarquées montées en même temps gardent leur propre hauteur

**Ce que ça teste :** deux `PLYPresentationView` montées simultanément dans des containers de hauteurs différentes (260dp et 110dp). Chacune doit rendre à **sa** taille.

**Le bug gardé (Android) :** React Native réutilise **un seul** view manager pour toutes les `<PLYPresentationView />`. `PurchaselyViewManager` gardait `propWidth` / `propHeight` sur le manager lui-même : la dernière vue à recevoir son style imposait ses dimensions aux deux, et une bannière rendait rognée.

**Pourquoi l'assertion est côté hôte :** les tailles qui dérapent sont celles des **enfants natifs**. JS ne les voit pas — les containers RN gardent la hauteur que le test leur a donnée quoi qu'il arrive. Le driver lit donc les bounds réels dans l'arbre de vues (`uiautomator dump` sur Android, `idb ui describe-all` sur iOS) et vérifie qu'ils diffèrent et suivent chacun son container. La capture d'écran est l'artefact que lit un humain, pas ce en quoi le test a confiance.

**Note fixture :** l'app de test n'a qu'un placement, et deux `preload()` du même placement coup sur coup sont rejetés par le SDK. La seconde requête passe donc par `screen(id)` — même contenu, chemin embarqué identique. Une intégration réelle monte deux bannières depuis deux placements.

| Step | Action | Assert |
|------|--------|--------|
| 1 | `placement(...).build().preload()` | `screenId` non-vide |
| 2 | `screen(screenId).build().preload()` | — |
| 3 | monter les deux vues (containers 260dp / 110dp) | — |
| 4 | `waitFor(2 × PRESENTATION_VIEWED, 30000)` | les deux ont rendu |
| 5 | `[E2E:DUAL_INLINE_DP:260:110]` + `[E2E:READY_FOR_DUAL_INLINE]` | — |
| 6 | driver hôte : bounds natifs | hauteurs distinctes, chacune ≈ son container |

**Marqueurs :** `[E2E:T29:PASS]` / `[E2E:T29:FAIL]`, plus `[E2E:DUAL_INLINE_DP:tall:short]` et `[E2E:READY_FOR_DUAL_INLINE]`
**Driver host Android :** `assert_dual_inline.sh` — **verdict bloquant** : son échec fait échouer le run, indépendamment du marqueur JS qui, lui, ne dit que « les deux ont chargé ».
**Driver host iOS :** `capture_dual_inline_ios.sh` — **capture seule, pas d'assertion**. `idb ui describe-all` rend l'arbre d'**accessibilité** : des labels et des contrôles, pas les `UIView` conteneurs dans lesquelles vivent les paywalls. Aucun élément ne porte la frame du slot, donc toute assertion de hauteur y serait une heuristique déguisée en mesure. iOS garde donc ce qu'il peut affirmer honnêtement : les deux vues se sont déclarées rendues (assertion JS de T29), et voici l'image. Le bug gardé est de toute façon un bug Android.
**Artefact :** `integration_test/artifacts/e2e_t29_dual_inline_{android,ios}.png` + le dump de hiérarchie.

---

## Architecture du runner

```
CI (ubuntu-latest + KVM)
  └── reactivecircus/android-emulator-runner
        └── run_e2e.sh
              ├── installe l'APK (mode E2E_MODE=true, échec install = abort immédiat)
              ├── lance logcat en background
              ├── surveille [E2E:READY_FOR_TAP]          → tap_purchase.sh       (T8)
              ├── surveille [E2E:READY_FOR_BACK]         → press_back.sh         (T9)
              ├── surveille [E2E:READY_FOR_INLINE_CLOSE] → tap_close_inline.sh   (T25)
              ├── surveille [E2E:READY_FOR_NESTED_SHOT]   → capture_nested_inline.sh (T28)
              ├── surveille [E2E:READY_FOR_DUAL_INLINE]   → assert_dual_inline.sh    (T29, verdict bloquant)
              ├── surveille [E2E:SUITE:PASS|FAIL] (suite principale T1-T26 + T28-T29)
              ├── si PASS → relaunch --es E2E_PHASE deeplink_coldstart (process neuf)
              │              └── surveille [E2E:T27:PASS|FAIL]          (T27 cold-start)
              ├── chaque driver hôte est `wait`é : code retour non-nul → warning visible
              ├── tout id T1-T29 sans AUCUN marqueur PASS/FAIL/SKIP → échec (filet authoritatif)
              └── exit 0 si (suite PASS ET T27 ≠ FAIL ET aucun marqueur manquant), sinon 1

CI (macos-15 + simulateur iOS)
  └── run_e2e_ios.sh
        ├── build Release (bundle JS embarqué, pas de Metro)
        ├── xcrun simctl install (échec = abort immédiat) + launch --console (capture console.log)
        ├── xcrun simctl spawn log stream (capture secondaire)
        ├── surveille [E2E:READY_FOR_TAP]          → tap_purchase_ios.sh      (idb ui tap, T8)
        ├── surveille [E2E:READY_FOR_BACK]         → swipe_dismiss_ios.sh     (idb close/swipe, T9)
        ├── surveille [E2E:READY_FOR_INLINE_CLOSE] → tap_close_inline_ios.sh  (idb ui tap, T25)
        ├── surveille [E2E:READY_FOR_NESTED_SHOT]   → capture_nested_inline_ios.sh (T28)
        ├── surveille [E2E:READY_FOR_DUAL_INLINE]   → capture_dual_inline_ios.sh   (T29, capture seule)
        ├── surveille [E2E:SUITE:PASS|FAIL] (suite principale T1-T26 + T28-T29)
        ├── si PASS → relaunch SIMCTL_CHILD_E2E_PHASE=deeplink_coldstart (process neuf)
        │              └── surveille [E2E:T27:PASS|FAIL]          (T27 cold-start)
        ├── chaque driver hôte est `wait`é : code retour non-nul → warning visible
        ├── tout id T1-T29 sans AUCUN marqueur PASS/FAIL/SKIP → échec (filet authoritatif)
        └── exit 0 si (suite PASS ET T27 ≠ FAIL ET aucun marqueur manquant), sinon 1
```

## Marqueurs émis par E2ETestRunner.tsx

| Marqueur | Signification |
|----------|---------------|
| `[E2E:SUITE:START]` | début de la suite (peut porter `phase=deeplink_coldstart`) |
| `[E2E:Tn:PASS] <détails>` | test Tn réussi |
| `[E2E:Tn:FAIL] <message>` | test Tn échoué |
| `[E2E:Tn:SKIP] <raison>` | test Tn sauté (ex. T27 déféré à sa phase cold-start dédiée) |
| `[E2E:READY_FOR_TAP]` | paywall T8 affiché, driver peut taper |
| `[E2E:READY_FOR_BACK]` | paywall T9 affiché, driver peut dismisser |
| `[E2E:READY_FOR_INLINE_CLOSE]` | vue embarquée T25 rendue, driver peut taper le ✕ |
| `[E2E:SUITE:PASS]` | tous les tests de la phase sont passés |
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
| T14 | T14 (Flutter v6) |
| T15 | T15 (Flutter v6) |
| T16 | T16 (Flutter v6) |
| T17 | T17 (Flutter v6) |
| T18 | T18 (Flutter v6) |
| T19 | T19 (Flutter v6) |
| T20 | T20 (Flutter v6) |

## Mapping avec le catalogue cross-wrapper Flutter (T21-T27)

| Test RN | Réf Flutter catalog | Fichier(s) de test Flutter | Plateformes RN |
|---------|---------------------|----------------------------|----------------|
| T21 | catalog **T6** (`synchronize()`) | `dart_android_bridge_test.dart`, `dart_ios_bridge_test.dart` | Android + iOS |
| T22 | catalog **T11** (default dismiss via display) | `default_dismiss_via_display_test.dart`, `default_dismiss_via_display_ios_test.dart` | Android + iOS |
| T23 | catalog **T12** (local wins over default) | `local_dismiss_handler_test.dart`, `local_dismiss_handler_ios_test.dart` | Android + iOS |
| T24 | — (listener utilitaire) | `user_attribute_listener_test.dart` | Android + iOS |
| T25 | — (vue embarquée, close pilotée) | `inline_paywall_test.dart` + `INLINE_PAYWALL_CLOSE.md` | Android + iOS (rendu ET close réellement pilotés — voir note ci-dessous) |
| T26 | — (lifecycle preload, parité Flutter) | `dart_android_bridge_test.dart` (T8 display path) | Android + iOS |
| T27 | — (deeplink cold-start builder) | `deeplink_cold_start_test.dart` | Android + iOS, chacun en phase process-neuf dédiée |

> Divergences notables vs Flutter : T22/T23 utilisent une fermeture **programmatique** (`req.close()`) au lieu d'un driver hôte → `closeReason` épinglé `'programmatic'` (Flutter accepte `anyOf`). T25 **diverge positivement** de Flutter : là où `INLINE_PAYWALL_CLOSE.md` documente que le harness `integration_test` de Flutter ne peut pas délivrer de tap à la platform view embarquée, le harness RN pilote l'app réellement lancée via adb/idb (pas de binding de test in-process) et la vue embarquée y est un vrai `Fragment`/`UIView` — le tap est donc réellement piloté et asserté en dur, pas seulement le rendu. **Android** tape le vrai bouton ✕ du SDK (`closeReason === 'button'`). **iOS** tape un bouton de repli E2E-only (`request.close()`) car l'écran de test n'y rend aucun bouton de fermeture, en plein écran comme en vue embarquée (`closeReason === 'programmatic'`) — voir la note dans la section T25. T27 tourne désormais en **phase process-neuf sur les deux plateformes** (une seule session RN pour T1-T26 par plateforme).
