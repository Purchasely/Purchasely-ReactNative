# Rapport de migration React Native → Purchasely SDK natif 6.0

> Session du 2026-06-16 sur la branche `feat/sdk-v6-migration`.
> Ce document récapitule **tout ce qui a été fait** pour finaliser la migration
> du SDK React Native vers les SDK natifs Purchasely 6.0, et sert de source pour
> mettre à jour `../Documentation` (docs publiques) et `../purchasely-ai-skill`
> (références `react-native/`), comme cela a été fait pour Android, iOS et Flutter.

---

## 1. Contexte et principe

Le SDK React Native Purchasely est un **bridge JS/TS ↔ natif** (`NativeModules` /
`NativeEventEmitter`) vers les SDK natifs iOS (`Purchasely`) et Android
(`io.purchasely:core`). Cette migration **adapte le bridge aux SDK natifs 6.0**.

Principe directeur (identique à la migration Flutter, validé avec le demandeur) :

- **Pas de nommage « v6 » dans l'API publique TS.** Les nouvelles méthodes
  **remplacent** l'existant. Quand il n'y a pas de nouvelle méthode native (ex.
  `setUserAttribute*`), on **laisse en l'état**.
- Trois zones sont des breaking changes : **démarrage du SDK** (`builder`),
  **affichage / preload / fermeture d'une présentation** (`PresentationBuilder`
  → `PresentationRequest`), et **l'action interceptor** (`interceptAction` par
  action retournant `'success' | 'failed' | 'notHandled'`). Le reste de la
  surface `Purchasely.*` reste source-compatible.

**L'essentiel de la couche TS, du bridge Android et du bridge iOS existait déjà**
sur la branche au début de la session (façade `builder`/`PresentationBuilder`/
`interceptAction`, `PresentationOutcome` à 5 champs, vue inline `PLYPresentationView`,
bridges natifs réécrits, tests d'intégration, `MIGRATION-v6.md`, exemple). Le
travail de cette session a consisté à : **vérifier la compilation/le runtime
contre les vrais SDK natifs v6**, **ajouter le callback à `synchronize`**,
**corriger un test natif Android cassé**, **aligner les versions natives sur
l'artefact publié `6.0.0-rc.1`**, et **valider sur simulateur/émulateur**.

---

## 2. Changements effectués cette session

### 2.1 `synchronize()` — ajout du callback (TS + Android ; iOS déjà câblé)

Les SDK natifs 6.0 exposent désormais des callbacks succès/erreur sur
`synchronize()`. Le bridge en profite :

- **TS** (`packages/purchasely/src/index.ts`) : `synchronize()` passe de
  `(): void` à **`(): Promise<boolean>`**. La promesse résout à la fin de la
  synchronisation et rejette en cas d'échec. **Source-compatible** : les appels
  fire-and-forget existants (sans `await`) continuent de marcher.
- **Android** (`PurchaselyModule.kt`) : `synchronize(promise: Promise)` appelle
  `Purchasely.synchronize(onSuccess = { promise.resolve(true) }, onError = { e -> … })`.
  Signature native confirmée dans la source :
  `fun synchronize(onSuccess: PLYPurchaseResultHandler? = null, onError: PLYErrorHandler? = null)`
  (`@JvmOverloads`, chemin sans store → `onError(PLYError.NoStoreConfigured)`).
  Avant : `fun synchronize() { Purchasely.synchronize() }` (fire-and-forget).
- **iOS** (`PurchaselyRN.m`) : **déjà câblé** sur la branche —
  `RCT_EXPORT_METHOD(synchronize:reject:)` appelle déjà
  `[Purchasely synchronizeWithSuccess:^{ resolve(@YES); } failure:^(NSError*e){ … }]`.
  Aucune modification iOS nécessaire.

### 2.2 Correction d'un test natif Android cassé (pré-existant)

`PurchaselyModuleTest.kt` ne compilait plus contre `io.purchasely:core:6.0.0-rc.1` :
`Unresolved reference 'PLYPresentationType'` (l'enum a migré du package
`io.purchasely.ext` vers `io.purchasely.ext.presentation` en v6). Ajout de
`import io.purchasely.ext.presentation.PLYPresentationType` (le module
`PurchaselyModule.kt` l'importait déjà correctement). Débloque toute la suite de
tests natifs Android.

### 2.3 Alignement des versions natives sur l'artefact **publié** `6.0.0-rc.1`

Les pins étaient sur `6.0.0` (artefact non publié). Après vérification, la
version **réellement publiée** du milestone rc1 est `6.0.0-rc.1` (avec point)
sur **Maven Central** (Android) **et** sur le **trunk CocoaPods** (iOS) :

| Réf | Avant | Après | Source de résolution |
|---|---|---|---|
| `packages/purchasely/android/build.gradle` (`core`) | `6.0.0` | `6.0.0-rc.1` | Maven Central |
| `packages/google/android/build.gradle` (`google-play`) | `6.0.0` | `6.0.0-rc.1` | Maven Central |
| `packages/android-player/android/build.gradle` (`player`) | `6.0.0` | `6.0.0-rc.1` | Maven Central |
| `packages/amazon/android/build.gradle` (`amazon`) | `6.0.0` | `6.0.0-rc.1` | Maven Central |
| `packages/huawei/android/build.gradle` (`huawei-services`) | `6.0.0` | `6.0.0-rc.1` | Maven Central |
| `packages/purchasely/react-native-purchasely.podspec` (`Purchasely`) | `6.0.0` | `6.0.0-rc.1` | CocoaPods trunk |

> **iOS ET Android utilisent la MÊME chaîne `6.0.0-rc.1` (avec point).** C'est
> différent de la note de convention du rapport Flutter (qui annonçait Android
> `6.0.0-rc1` sans point) : pour React Native, les deux artefacts publiés
> portent `6.0.0-rc.1`. Le `6.0.0-rc1` (sans point) présent dans le `mavenLocal`
> de la machine était un build local périmé, **absent de Maven Central** (HTTP
> 404), à ne pas utiliser.

> ⚠️ **Piège Gradle (leçon Flutter, vérifiée ici).** Gradle classe `6.0.0`
> (release) au-dessus de `6.0.0-rc.1` (pré-release) : une seule réf `io.purchasely:*`
> laissée en `6.0.0` (ou un `mavenLocal` contaminé) remonterait silencieusement
> le `core` → `NoSuchMethodError` au runtime. **Vérifié** : la résolution du
> `debugRuntimeClasspath` ne montre QUE `6.0.0-rc.1` (cf. §5). L'app exemple
> Android n'a aucune réf `io.purchasely:*` directe (héritage transitif des
> packages), donc aligner les 5 `build.gradle` suffit.

> ✅ **Conséquence CI.** Les deux artefacts `6.0.0-rc.1` étant publiés (Maven
> Central + trunk CocoaPods), le CI natif ne dépend plus d'un `mavenLocal` /
> dev-pod local — ce qui devrait **débloquer les jobs `build-android` /
> `build-ios`** (voir §7, doute n°2).

### 2.4 Tests TS ajoutés / mis à jour (`synchronize`)

- `__mocks__/testUtils.ts` : mock `synchronize: jest.fn().mockResolvedValue(true)`.
- `__tests__/index.test.ts` : 2 tests ajoutés — résolution (`await … resolves true`)
  et propagation d'erreur (`await … rejects`).

### 2.5 Exemple

- `example/src/Home.tsx` : `onPressSynchronize` illustre la nouvelle sémantique
  (`await Purchasely.synchronize()` + `try/catch`).

### 2.6 Documentation

- `MIGRATION-v6.md` : section « Synchronize (now awaitable) » ajoutée + note
  dans « What's UNCHANGED ».
- Ce rapport (`V6_MIGRATION_REPORT.md`).

---

## 3. API TS v6 finale (référence pour `../Documentation` + `../purchasely-ai-skill`)

### Initialisation (builder)

```typescript
const configured = await Purchasely.builder('YOUR_API_KEY')
  .appUserId('user_id')          // optionnel
  .runningMode('full')           // 'observer' (défaut) | 'full'
  .logLevel('error')             // 'debug' | 'info' | 'warn' | 'error'
  .allowDeeplink(true)           // remplace readyToOpenDeeplink(true)
  .allowCampaigns(true)          // optionnel
  .stores(['google'])            // Android : 'google' | 'huawei' | 'amazon'
  .storekitVersion('storeKit2')  // iOS : 'storeKit1' | 'storeKit2'
  .start()
```

> **Mode par défaut = `observer`** en v6. Passer `.runningMode('full')` si
> Purchasely doit gérer/valider les achats.

### Affichage d'une présentation

```typescript
const outcome = await Purchasely.presentation
  .placement('ONBOARDING')        // ou .screen('SCREEN_ID') / .default()
  .contentId('content_id')        // optionnel
  .build()
  .display({ type: 'fullScreen' })

// PresentationOutcome (5 champs) :
//   presentation, purchaseResult, plan, closeReason, error
```

Cycle de vie : `const req = Purchasely.presentation.placement(id).build()` →
`req.preload()` → `req.display()` / `req.close()` / `req.back()`.

### Action interceptor

```typescript
Purchasely.interceptAction('purchase', async (info, payload) => {
  if (payload?.kind === 'purchase') { /* … */ return 'success' }
  return 'notHandled' // 'success' | 'failed' | 'notHandled'
})
Purchasely.removeActionInterceptor('purchase')
Purchasely.removeAllActionInterceptors()
```

Kinds : `close, closeAll, login, navigate, purchase, restore, openPresentation,
openPlacement, promoCode, webCheckout`.

### Inline (embarqué)

```tsx
<PLYPresentationView placementId="ONBOARDING" flex={1}
  onPresentationClosed={(result) => { /* … */ }} />
```

### Synchronize (nouveau comportement)

```typescript
try {
  await Purchasely.synchronize() // résout à la fin ; rejette en cas d'échec
} catch (e) { /* PLYError.NoStoreConfigured, … */ }
```

### Inchangé (source-compatible)

`purchaseWithPlanVendorId`, `signPromotionalOffer`, `restoreAllProducts`,
`silentRestoreAllProducts`, `userLogin`/`userLogout`, `isAnonymous`,
`getAnonymousUserId`, `allProducts`, `productWithIdentifier`, `planWithIdentifier`,
`isEligibleForIntroOffer`, `userSubscriptions`/`userSubscriptionsHistory`,
`setUserAttribute*` (+ increment/decrement/clear), `userAttributes`/`userAttribute`,
`addEventListener`/`addPurchasedListener`/`addUserAttribute*Listener`,
`setDynamicOffering`/`getDynamicOfferings`/`removeDynamicOffering`/`clearDynamicOfferings`,
`clientPresentationDisplayed`/`clientPresentationClosed`, `revokeDataProcessingConsent`,
`setLanguage`, `setThemeMode`, `setLogLevel`, `setDebugMode`, `isDeeplinkHandled`,
`userDidConsumeSubscriptionContent`, `presentSubscriptions` (Android : no-op + warning,
UI native d'abonnements retirée en v6).

---

## 4. Fichiers modifiés (cette session)

- `packages/purchasely/src/index.ts` — `synchronize` → `Promise<boolean>`.
- `packages/purchasely/android/.../PurchaselyModule.kt` — `synchronize(promise)` +
  callbacks `onSuccess`/`onError`.
- `packages/purchasely/android/.../test/.../PurchaselyModuleTest.kt` — import
  `PLYPresentationType` (package `presentation`).
- `packages/purchasely/android/build.gradle`, `packages/google/…`,
  `packages/android-player/…`, `packages/amazon/…`, `packages/huawei/…` — pins
  `6.0.0-rc.1`.
- `packages/purchasely/react-native-purchasely.podspec` — pin `Purchasely '6.0.0-rc.1'`.
- `packages/purchasely/src/__mocks__/testUtils.ts`,
  `packages/purchasely/src/__tests__/index.test.ts` — tests `synchronize`.
- `example/src/Home.tsx` — exemple `synchronize` awaitable.
- `MIGRATION-v6.md`, `V6_MIGRATION_REPORT.md` — docs.

**Non commité / local-machine :**
- `example/ios/Podfile.lock` (untracked) : régénéré, `Purchasely (6.0.0-rc.1)`
  résolu depuis le trunk CocoaPods.

**Éditions cross-repo (à NE PAS committer ici) :**
- `/Users/kevin/Purchasely/iOS/Purchasely.podspec` : version bumpée en `6.0.0-rc.1`
  (édition antérieure). **N'est plus nécessaire** pour ce repo : le pod est
  désormais résolu depuis le trunk CocoaPods, pas depuis un dev-pod local.
  Peut être reverté.

---

## 5. Vérifications exécutées (preuves)

| Vérification | Commande | Résultat |
|---|---|---|
| TS typecheck | `yarn typecheck` | ✅ exit 0 |
| TS lint | `yarn lint` | ✅ exit 0 |
| TS tests (Jest) | `yarn test --maxWorkers=2` | ✅ **5 suites, 136 tests** (dont nouveaux `synchronize` + `presentation.integration`) |
| Build Android | `cd example/android && ./gradlew :app:assembleDebug` | ✅ BUILD SUCCESSFUL, `app-debug.apk` |
| Résolution Android | `./gradlew :app:dependencies --configuration debugRuntimeClasspath` | ✅ `io.purchasely:core|google-play:6.0.0-rc.1` **uniquement** (aucun `6.0.0`) |
| Tests natifs Android | `./gradlew :react-native-purchasely:testDebugUnitTest` | ✅ **41 tests, 0 échec** (PurchaselyModuleTest 32 + EnumOrdinalConsistencyTest 9) |
| Smoke Android (réel, Pixel_Tablet) | install APK + launch | ✅ `Init SDK (v.6.0.0-rc.1)`, `isSdkStarted=true`, `sdkVersion=6.0.0-rc.1`, `initialized successfully`, login/logout/anonymous |
| **Présentation v6 de bout en bout (Android)** | tap « Display Presentation » | ✅ `PRESENTATION_LOADED` → `PRESENTATION_VIEWED` → **paywall « PURCHASELY MUSIC » affiché plein écran** (rendu 2,6 s, 0 crash) |
| **`synchronize()` awaitable (Android, réel)** | tap « Synchronize » | ✅ `Synchronize purchases` → JS `Synchronize done` (la Promise résout) |
| pod install iOS | `cd example/ios && pod update Purchasely` | ✅ `Purchasely (6.0.0-rc.1)` intégré **depuis le trunk CocoaPods** |
| Build iOS (exemple) | `xcodebuild build -workspace example.xcworkspace -scheme example` | ⚠️ Collision d'assets **résolue** par le pod du trunk ; le build progresse jusqu'à la compilation et échoue **uniquement** sur `fmt` consteval dans `Pods/fmt/src/format.cc` (React Native core sous Xcode 26.5). 3 contournements tentés (2 CLI + 1 `post_install FMT_USE_CONSTEVAL=0`) sans effet : le `fmt` de RN 0.79 ignore le flag (clé sur `__cpp_consteval`). Fix réel = Xcode 16.x. Blocage **environnement RN/Xcode**, sans rapport avec Purchasely — cf. §7 doute n°2. |

> Le backend est **réel** (clé API de l'exemple) : plans `PURCHASELY_PLUS_YEARLY/MONTHLY`,
> dynamic offerings, validation d'offre côté serveur, audience `play_store` — tout
> remonte du vrai backend Purchasely.

---

## 6. Contrat de bridge (JS ↔ natif)

- **NativeModules.Purchasely** : `start` (via builder), `preload`, `display`,
  `closePresentation`/`hidePresentation`/`back`, `registerInterceptor`/
  `removeActionInterceptor`/`removeAllActionInterceptors`, `synchronize`
  (Promise), + toute la surface conservée.
- **NativeEventEmitter** : `PURCHASELY_EVENTS`, `PURCHASE_LISTENER`,
  `USER_ATTRIBUTE_SET_LISTENER`, `USER_ATTRIBUTE_REMOVED_LISTENER`, +
  événements de présentation (`PURCHASELY_PRESENTATION_EVENTS`).

---

## 7. Doutes / points à reviewer (À LIRE)

1. **Convention de version (important, divergence avec Flutter).** Pour React
   Native, l'artefact publié des deux côtés est **`6.0.0-rc.1`** (avec point) :
   Maven Central (Android) ET trunk CocoaPods (iOS). Le rapport Flutter annonçait
   Android `6.0.0-rc1` (sans point) ; ce n'est PAS le cas ici (le `6.0.0-rc1`
   sans point n'existe qu'en `mavenLocal` local et renvoie 404 sur Maven Central).
   **À confirmer** : la chaîne de version finale lors de la release (rc → final).
   Mettre à jour les 6 pins en conséquence avant merge/release.

2. **Build iOS local bloqué par React Native core (`fmt`/Xcode 26.5), PAS par
   Purchasely.** L'intégration Purchasely iOS est prouvée propre : le pod
   `6.0.0-rc.1` se résout depuis le trunk, s'intègre, et la collision d'assets
   (`Assets.car`) — présente avec le dev-pod local de la branche `develop` — a
   **disparu** avec le pod publié. Le seul échec restant est
   `fmt::basic_format_string … is not a constant expression` dans `Pods/fmt`
   (toolchain C++ de React Native 0.79 sous Xcode 26.5) — il toucherait
   n'importe quelle app RN 0.79, indépendamment de Purchasely. 3 contournements
   tentés sans succès : `-DFMT_CONSTEVAL=` et `-DFMT_USE_CONSTEVAL=0` en CLI (non
   propagés à la cible `fmt`), puis un `post_install` posant `FMT_USE_CONSTEVAL=0`
   par target — vérifié : le define **atteint** la compilation de `format.cc`
   (`-DFMT_USE_CONSTEVAL=0` dans la commande clang) mais le `fmt` embarqué par RN
   0.79 **l'ignore** pour ce chemin (il clé `FMT_CONSTEVAL` sur `__cpp_consteval`).
   ⇒ **pas de switch préprocesseur propre** ; il faut soit **builder avec un Xcode
   compatible RN 0.79 (Xcode 16.x)**, soit upgrader React Native, soit patcher la
   source `Pods/fmt` (fragile). Le `post_install` inefficace a été retiré.
   Le CI (`macos-latest`, Xcode compatible) devrait builder normalement maintenant
   que le pod est sur le trunk. **À reviewer** : la version d'Xcode du runner CI.

3. **Le dev-pod iOS local n'est plus nécessaire.** La branche avait été testée
   avec `pod 'Purchasely', :path => '/Users/kevin/Purchasely/iOS'`. Le pod étant
   désormais sur le trunk, le Podfile de l'exemple est **inchangé** (pas de chemin
   machine-spécifique committé) et l'édition de version du podspec iOS local peut
   être revertée.

4. **`synchronize()` rejette le chemin « no store ».** Sans store configuré, le
   natif appelle `onError(PLYError.NoStoreConfigured)` → la Promise **rejette**.
   Les appelants qui `await` doivent `catch` (l'exemple le fait). Les appels
   fire-and-forget restent inoffensifs.

5. **Pas de test unitaire natif `synchronize` ajouté côté Android.** Le chemin
   no-store passe par `PLYLogger.w` → `PLYDiagnosticManager.addLog` (non gardé),
   risqué en JUnit pur sans Robolectric ; et `Promise.reject` + null-safety
   Kotlin/Mockito est fragile. Le bridge `synchronize` est couvert par : compile
   contre `6.0.0-rc.1` (assembleDebug), tests JS resolve/reject, et test
   fonctionnel réel (`Synchronize done`). À renforcer par un test natif si une
   infra Robolectric est ajoutée (comme l'a fait Flutter).

6. **Version du package RN → `6.0.0-rc.1`.** Alignée sur les natifs (iOS +
   Android) : `purchaselyVersion` (`index.ts`), les 5 `package.json`, le test du
   bridge (`index.test.ts`), `VERSIONS.md`, `sdk_public_doc.md`, `CLAUDE.md`.
   Release prévue après review (les 5 packages npm doivent rester à la **même**
   version). `CHANGELOG.md` garde son entête `6.0.0-beta.0` — à renommer au
   moment de la release.

7. **Validation fonctionnelle iOS.** Réalisée seulement sur Android faute de
   build iOS local (cf. doute n°2). La couche JS/TS étant commune aux deux
   plateformes et le bridge iOS `synchronize` étant déjà câblé (inchangé cette
   session), le risque iOS spécifique est faible. À refaire sur un runner Xcode
   compatible.

---

## 8. Pour mettre à jour `../Documentation` et `../purchasely-ai-skill`

- `purchasely-ai-skill/references/react-native/integration.md` : encore en **v5**
  (`Purchasely.start({...})`, `fetchPresentation`/`presentPresentation`,
  `setPaywallActionInterceptor` + `onProcessAction`). À remplacer par l'API v6
  (§3) : `builder`, `presentation`/`PresentationRequest`, `interceptAction`,
  `PLYPresentationView`, `synchronize` awaitable.
- Créer `purchasely-ai-skill/references/react-native/migration-v6.md` (analogue
  Android/iOS/Flutter) à partir de `MIGRATION-v6.md`.
- `purchasely-ai-skill/references/sdk-versions.md` : React Native passe de `5.7.3`
  à la version v6 du package (cf. doute n°6), natifs `6.0.0-rc.1` (Android Maven
  Central + iOS trunk CocoaPods).
- Docs publiques (`../Documentation`) : guide d'intégration RN + guide de
  migration 5→6 RN, en miroir des guides Android/iOS/Flutter.
