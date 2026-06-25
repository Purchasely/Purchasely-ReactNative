# Purchasely React Native — E2E Test Index

Tests exécutés séquentiellement sur émulateur Android (API 34, ubuntu+KVM) via CI nightly.
Déclenchés par `run_e2e.sh` → composant `E2ETestRunner.tsx` embarqué dans l'APK.

---

## T1 — Anonymous user ID

**Ce que ça teste :** `getAnonymousUserId()` retourne un identifiant non-vide.  
**Marqueurs LogCat :** `[E2E:T1:PASS]` / `[E2E:T1:FAIL]`  
**Driver host :** aucun  

---

## T2 — Cycle login / logout

**Ce que ça teste :** `isAnonymous()` passe `true → false → true` autour de `userLogin()` / `userLogout()`.  
**Marqueurs LogCat :** `[E2E:T2:PASS]` / `[E2E:T2:FAIL]`  
**Driver host :** aucun  

---

## T3 — Preload d'un placement

**Ce que ça teste :** `presentation.placement(id).build().preload()` retourne un objet `Presentation` avec un `screenId` valide.  
**Marqueurs LogCat :** `[E2E:T3:PASS]` / `[E2E:T3:FAIL]`  
**Driver host :** aucun  

---

## T4 — Dynamic offerings

**Ce que ça teste :** `getDynamicOfferings()` retourne un tableau (peut être vide sur émulateur).  
**Marqueurs LogCat :** `[E2E:T4:PASS]` / `[E2E:T4:FAIL]`  
**Driver host :** aucun  

---

## T5 — All products

**Ce que ça teste :** `allProducts()` retourne un tableau.  
**Marqueurs LogCat :** `[E2E:T5:PASS]` / `[E2E:T5:FAIL]`  
**Driver host :** aucun  

---

## T6 — Interceptor cleanup round-trip

**Ce que ça teste :** `interceptAction()` → `removeActionInterceptor()` → `removeAllActionInterceptors()` sans erreur.  
**Marqueurs LogCat :** `[E2E:T6:PASS]` / `[E2E:T6:FAIL]`  
**Driver host :** aucun  

---

## T7 — Display drawer + close programmatique

**Ce que ça teste :** affichage d'un paywall en drawer (60 %), attente 3 s, `req.close()` programmatique, vérification que `closeReason` est `"programmatic"` (ou `"button"` / `"backSystem"`).  
**Marqueurs LogCat :** `[E2E:T7:PASS]` / `[E2E:T7:FAIL]`  
**Driver host :** aucun — fermeture purement programmatique  
**Timeout interne :** 15 s sur `displayPromise`  

---

## T8 — Purchase interceptor (tap réel)

**Ce que ça teste :** l'interceptor `'purchase'` se déclenche quand l'utilisateur tape le bouton d'achat sur le paywall natif. On vérifie :
- `payload.plan.vendorId` non vide
- `payload.plan.productId` présent
- `payload.plan.promoOffer` (null si pas d'offre promo configurée)
- `info.contentId`

L'interceptor retourne `'success'` (pas d'achat natif effectué). Le paywall est ensuite fermé via `req.close()`.

**Marqueurs LogCat :**
- `[E2E:READY_FOR_TAP]` — émis quand le paywall est affiché (signal pour le driver)
- `[E2E:T8:PASS]` / `[E2E:T8:FAIL]`

**Driver host :** `integration_test/tools/tap_purchase.sh`  
→ dump UIAutomator → cherche `content-desc="action:purchase"` → extrait les coordonnées via Python → tap  
**Timeout waitFor :** 40 s pour que l'interceptor se déclenche  

---

## T9 — Default dismiss handler via deeplink + BACK

**Ce que ça teste :** `setDefaultPresentationDismissHandler()` reçoit l'outcome quand un paywall ouvert via `handleDeeplink()` est fermé par la touche BACK système.  
On vérifie que `closeReason` est `"backSystem"` (ou `"button"` / `"programmatic"`).

**Marqueurs LogCat :**
- `[E2E:READY_FOR_BACK]` — émis quand le paywall est affiché (signal pour le driver)
- `[E2E:T9:PASS]` / `[E2E:T9:FAIL]`

**Driver host :** `integration_test/tools/press_back.sh`  
→ dump UIAutomator → détecte un élément avec `action:` dans `content-desc` → `adb shell input keyevent KEYCODE_BACK`  
**Timeout waitFor :** 40 s pour que le dismiss handler soit appelé  

---

## Architecture du runner

```
CI (ubuntu-latest + KVM)
  └── reactivecircus/android-emulator-runner
        └── run_e2e.sh
              ├── installe l'APK (mode E2E_MODE=true)
              ├── lance logcat en background
              ├── surveille [E2E:READY_FOR_TAP]  → tap_purchase.sh (T8)
              ├── surveille [E2E:READY_FOR_BACK] → press_back.sh  (T9)
              └── surveille [E2E:SUITE:PASS|FAIL] → exit 0|1
```

## Marqueurs émis par E2ETestRunner.tsx

| Marqueur | Signification |
|----------|---------------|
| `[E2E:SUITE:START]` | début de la suite |
| `[E2E:Tn:PASS] <détails>` | test Tn réussi |
| `[E2E:Tn:FAIL] <message>` | test Tn échoué |
| `[E2E:READY_FOR_TAP]` | paywall T8 affiché, driver peut taper |
| `[E2E:READY_FOR_BACK]` | paywall T9 affiché, driver peut presser BACK |
| `[E2E:SUITE:PASS]` | tous les tests sont passés |
| `[E2E:SUITE:FAIL]` | au moins un test a échoué |
