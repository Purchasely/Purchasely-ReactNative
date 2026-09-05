import { NativeEventEmitter, NativeModules } from 'react-native';

import { PLYPresentationView } from './components/PLYPresentationView';
import type {
  PLYDynamicOffering,
  PurchasePlanParameters,
  SignPromotionalOfferParameters,
  UserAttributesParameters,
} from './interfaces';
import {
  Attributes,
  LogLevels,
  PLYDataProcessingLegalBasis,
  PLYDataProcessingPurpose,
  PLYThemeMode,
  PLYUserAttributeSource,
  PLYUserAttributeType,
} from './enums';
import type {
  PLYEvent,
  PLYPlan,
  PLYProduct,
  PLYPromotionalOfferSignature,
  PLYSubscription,
  PLYUserAttribute,
  PLYWebRedemptionResult,
} from './types';
import {
  PLYPresentationBuilder,
  setDefaultPresentationDismissHandler,
  removeDefaultPresentationDismissHandler,
} from './presentation';
import { PurchaselyBuilder } from './startBuilder';
import {
  interceptAction,
  removeActionInterceptor,
  removeAllActionInterceptors,
} from './interceptor';
import type {
  PLYPresentation,
  PLYPresentationActionKind,
} from './presentationTypes';

const purchaselyVersion = '6.1.0';

const PurchaselyEventEmitter = new NativeEventEmitter(NativeModules.Purchasely);

/**
 * Cross-platform start builder. Mirrors the iOS/Android contract:
 * `Purchasely.builder('API_KEY').appUserId('u').runningMode('full').start()`.
 *
 * This is the only supported way to initialize the SDK since 6.0.0.
 */
const builder = (apiKey: string): PurchaselyBuilder => {
  // Ensure the bridge version stays in sync with the wrapper version.
  PurchaselyBuilder.bridgeVersion = purchaselyVersion;
  return PurchaselyBuilder.apiKey(apiKey);
};

const apiKey = builder;

function setUserAttributeWithDate(key: string, value: Date, legalBasis?: PLYDataProcessingLegalBasis): void {
  const dateAsString = value.toISOString();
  return NativeModules.Purchasely.setUserAttributeWithDate(key, dateAsString, legalBasis);
}

type EventListenerCallback = (event: PLYEvent) => void;

const addEventListener = (callback: EventListenerCallback) => {
  return PurchaselyEventEmitter.addListener('PURCHASELY_EVENTS', callback);
};

const removeEventListener = () => {
  return PurchaselyEventEmitter.removeAllListeners('PURCHASELY_EVENTS');
};

type PurchaseListenerCallback = () => void;

const addPurchasedListener = (callback: PurchaseListenerCallback) => {
  return PurchaselyEventEmitter.addListener('PURCHASE_LISTENER', callback);
};

const removePurchasedListener = () => {
  return PurchaselyEventEmitter.removeAllListeners('PURCHASE_LISTENER');
};

const listenToEvents = addEventListener;
const stopListeningToEvents = removeEventListener;
const listenToPurchases = addPurchasedListener;
const stopListeningToPurchases = removePurchasedListener;

type UserAttributeSetListenerCallback = (
  userAttribute: PLYUserAttribute
) => void;

const addUserAttributeSetListener = (
  callback: UserAttributeSetListenerCallback
) => {
  return PurchaselyEventEmitter.addListener(
    'USER_ATTRIBUTE_SET_LISTENER',
    callback
  );
};

const removeUserAttributeSetListener = () => {
  return PurchaselyEventEmitter.removeAllListeners(
    'USER_ATTRIBUTE_SET_LISTENER'
  );
};

type UserAttributeRemovedListenerCallback = (
  userAttribute: PLYUserAttribute
) => void;

const addUserAttributeRemovedListener = (
  callback: UserAttributeRemovedListenerCallback
) => {
  return PurchaselyEventEmitter.addListener(
    'USER_ATTRIBUTE_REMOVED_LISTENER',
    callback
  );
};

const removeUserAttributeRemovedListener = () => {
  return PurchaselyEventEmitter.removeAllListeners(
    'USER_ATTRIBUTE_REMOVED_LISTENER'
  );
};

type WebRedemptionListenerCallback = (
  result: PLYWebRedemptionResult
) => void;

/**
 * Listen to the outcome of a Web2App redemption
 * (`{scheme}://ply/redeem/{token}`).
 *
 * **Add the listener before `Purchasely.builder(...).start()`.** A redemption
 * can settle during `start()`, from a cold start that the link itself
 * triggered, or from a token that a previous launch left pending. A listener
 * that you add after `start()` misses exactly the case it is most needed for.
 *
 * The SDK calls the listener on the main thread, exactly once per settled
 * redemption, on success and on failure alike.
 *
 * The `appHandlesRedemptionAlert` start option decides *when*:
 *
 * - `false` (the default): the SDK shows its own popin and calls the listener
 *   after the user acknowledges it, so the app acts on a screen that the user
 *   already dismissed.
 * - `true`: the SDK shows nothing and calls the listener as soon as the
 *   redemption settles. The app must then show its own result screen.
 *
 * Two more behaviours to know:
 *
 * - `result.replay` is `true` when the **server** reports that the token was
 *   redeemed before. The SDK keeps no cache and calls the server every time,
 *   so this is a verdict about the token, not an observation of the user.
 * - A redemption deeplink is **not** subject to `allowDeeplink`. The native
 *   SDK intercepts `ply/redeem` out of band, before the routing branch that
 *   the gate sits behind. A redemption still completes with
 *   `allowDeeplink(false)`.
 * - **On iOS only**, `result.errorMessage` for an expired link can contain a
 *   masked email address, so the app can tell the user where the fresh link
 *   went. The analytics event drops it. Show that text to the user. Do not
 *   forward it to an analytics stack or to a crash reporter.
 *
 * @example
 * ```ts
 * Purchasely.addWebRedemptionListener((result) => {
 *   if (result.isSuccess) {
 *     unlock(result.context?.subscription)
 *   } else {
 *     showError(result.errorCode, result.errorMessage)
 *   }
 * })
 * await Purchasely.builder('API_KEY').appHandlesRedemptionAlert(true).start()
 * ```
 */
const addWebRedemptionListener = (
  callback: WebRedemptionListenerCallback
) => {
  return PurchaselyEventEmitter.addListener(
    'WEB_REDEMPTION_LISTENER',
    callback
  );
};

/** Remove every listener added with {@link addWebRedemptionListener}. */
const removeWebRedemptionListener = () => {
  return PurchaselyEventEmitter.removeAllListeners('WEB_REDEMPTION_LISTENER');
};

export interface UserAttributeListener {
  onUserAttributeSet?: (
    key: string,
    type: PLYUserAttributeType | null | undefined,
    value: any,
    source: PLYUserAttributeSource | null | undefined
  ) => void;
  onUserAttributeRemoved?: (
    key: string,
    source: PLYUserAttributeSource | null | undefined
  ) => void;
}

const setUserAttributeListener = (listener: UserAttributeListener) => {
  const setSubscription = addUserAttributeSetListener((attribute) => {
    listener.onUserAttributeSet?.(
      attribute.key,
      attribute.type,
      attribute.value,
      attribute.source
    );
  });
  const removedSubscription = addUserAttributeRemovedListener((attribute) => {
    listener.onUserAttributeRemoved?.(
      attribute.key,
      attribute.source
    );
  });
  return {
    remove: () => {
      setSubscription.remove();
      removedSubscription.remove();
    },
  };
};

const clearUserAttributeListener = () => {
  removeUserAttributeSetListener();
  removeUserAttributeRemovedListener();
};

const purchaseWithPlanVendorId = ({
  planVendorId,
  offerId = null,
  contentId = null,
}: PurchasePlanParameters): Promise<PLYPlan> => {
  return NativeModules.Purchasely.purchaseWithPlanVendorId(
    planVendorId,
    offerId,
    contentId
  );
};

/**
 * Sign a StoreKit promotional offer so it can be redeemed in a subsequent
 * purchase.
 *
 * **iOS only.** There is no Android equivalent (Google Play has no
 * promotional-offer-signing primitive), so the Android native bridge is a
 * no-op that resolves `null` instead of rejecting.
 */
const signPromotionalOffer = ({
  storeProductId,
  storeOfferId,
}: SignPromotionalOfferParameters): Promise<PLYPromotionalOfferSignature | null> => {
  return NativeModules.Purchasely.signPromotionalOffer(
    storeProductId,
    storeOfferId
  );
};

const incrementUserAttribute = ({
  key,
  value,
  legalBasis
}: UserAttributesParameters): void => {
  const nonNullValue = value ?? 1;
  return NativeModules.Purchasely.incrementUserAttribute(key, nonNullValue, legalBasis);
};
const decrementUserAttribute = ({
  key,
  value,
  legalBasis
}: UserAttributesParameters): void => {
  const nonNullValue = value ?? 1;
  return NativeModules.Purchasely.decrementUserAttribute(key, nonNullValue, legalBasis);
};

const getAnonymousUserId = (): Promise<string> => {
  return NativeModules.Purchasely.getAnonymousUserId();
};

const userLogin = (userId: string): Promise<boolean> => {
  return NativeModules.Purchasely.userLogin(userId);
};

/**
 * Log the current user out.
 *
 * @param clearUserAttributes Whether to also clear locally-stored user
 * attributes. Defaults to `true`, matching both native SDKs' own default.
 */
const userLogout = (clearUserAttributes: boolean = true): void => {
  return NativeModules.Purchasely.userLogout(clearUserAttributes);
};

const setLogLevel = (logLevel: LogLevels): void => {
  return NativeModules.Purchasely.setLogLevel(logLevel);
};

const setAttribute = (attribute: Attributes, value: string): void => {
  return NativeModules.Purchasely.setAttribute(attribute, value);
};

const allProducts = (): Promise<PLYProduct[]> => {
  return NativeModules.Purchasely.allProducts();
};

const productWithIdentifier = (
  vendorId: string
): Promise<PLYProduct> => {
  return NativeModules.Purchasely.productWithIdentifier(vendorId);
};

const planWithIdentifier = (vendorId: string): Promise<PLYPlan> => {
  return NativeModules.Purchasely.planWithIdentifier(vendorId);
};

// Client-side timeout: the native restore call has no timeout of its own, so
// (matching Flutter) we race it against a rejection. If the store never
// resolves — a known StoreKit / Play Billing failure mode — the promise fails
// instead of hanging forever. `timeout` is in milliseconds; omit it to wait
// indefinitely.
const withTimeout = <T>(
  promise: Promise<T>,
  timeout?: number | null,
  label = 'restoreAllProducts'
): Promise<T> => {
  if (timeout == null) return promise;
  let timer: ReturnType<typeof setTimeout>;
  const guard = new Promise<T>((_resolve, reject) => {
    timer = setTimeout(
      () => reject(new Error(`Purchasely.${label} timed out after ${timeout}ms`)),
      timeout
    );
  });
  return Promise.race([promise, guard]).finally(() => clearTimeout(timer)) as Promise<T>;
};

const restoreAllProducts = ({
  timeout,
}: { timeout?: number | null } = {}): Promise<boolean> => {
  return withTimeout(
    NativeModules.Purchasely.restoreAllProducts(),
    timeout,
    'restoreAllProducts'
  );
};

const silentRestoreAllProducts = ({
  timeout,
}: { timeout?: number | null } = {}): Promise<boolean> => {
  return withTimeout(
    NativeModules.Purchasely.silentRestoreAllProducts(),
    timeout,
    'silentRestoreAllProducts'
  );
};

const userSubscriptions = ({ invalidateCache = false }: { invalidateCache?: boolean | null } = {}): Promise<PLYSubscription[]> => {
  return NativeModules.Purchasely.userSubscriptions(invalidateCache);
};

const userSubscriptionsHistory = ({
  invalidateCache = false,
}: { invalidateCache?: boolean | null } = {}): Promise<PLYSubscription[]> => {
  return NativeModules.Purchasely.userSubscriptionsHistory(invalidateCache);
};

const handleDeeplink = (deeplink: string | null): Promise<boolean> => {
  return NativeModules.Purchasely.handleDeeplink(deeplink);
};

const synchronize = (): Promise<boolean> => {
  // v6: the native SDKs (iOS success/failure, Android onSuccess/onError) now
  // report completion. The returned promise resolves when the receipt sync
  // finishes and rejects on failure. Awaiting is optional — fire-and-forget
  // callers stay source-compatible with the previous `void` signature.
  return NativeModules.Purchasely.synchronize();
};

const allowDeeplink = (allow: boolean): void => {
  return NativeModules.Purchasely.allowDeeplink(allow);
};

const allowCampaigns = (allow: boolean): void => {
  return NativeModules.Purchasely.allowCampaigns(allow);
};

const setLanguage = (language: string): void => {
  return NativeModules.Purchasely.setLanguage(language);
};

const userDidConsumeSubscriptionContent = (): void => {
  return NativeModules.Purchasely.userDidConsumeSubscriptionContent();
};

const setUserAttributeWithString = (key: string, value: string, legalBasis?: PLYDataProcessingLegalBasis): void => {
  return NativeModules.Purchasely.setUserAttributeWithString(key, value, legalBasis);
};

const setUserAttributeWithNumber = (key: string, value: number, legalBasis?: PLYDataProcessingLegalBasis): void => {
  return NativeModules.Purchasely.setUserAttributeWithNumber(key, value, legalBasis);
};

const setUserAttributeWithInt = (key: string, value: number, legalBasis?: PLYDataProcessingLegalBasis): void => {
  return NativeModules.Purchasely.setUserAttributeWithInt(key, value, legalBasis);
};

const setUserAttributeWithDouble = (key: string, value: number, legalBasis?: PLYDataProcessingLegalBasis): void => {
  return NativeModules.Purchasely.setUserAttributeWithDouble(key, value, legalBasis);
};

const setUserAttributeWithBoolean = (key: string, value: boolean, legalBasis?: PLYDataProcessingLegalBasis): void => {
  return NativeModules.Purchasely.setUserAttributeWithBoolean(key, value, legalBasis);
};

const setUserAttributeWithStringArray = (
  key: string,
  value: string[],
  legalBasis?: PLYDataProcessingLegalBasis
): void => {
  return NativeModules.Purchasely.setUserAttributeWithStringArray(key, value, legalBasis);
};

const setUserAttributeWithNumberArray = (
  key: string,
  value: number[],
  legalBasis?: PLYDataProcessingLegalBasis
): void => {
  return NativeModules.Purchasely.setUserAttributeWithNumberArray(key, value, legalBasis);
};

const setUserAttributeWithBooleanArray = (
  key: string,
  value: boolean[],
  legalBasis?: PLYDataProcessingLegalBasis
): void => {
  return NativeModules.Purchasely.setUserAttributeWithBooleanArray(key, value, legalBasis);
};

const setUserAttributeWithIntArray = (
  key: string,
  value: number[],
  legalBasis?: PLYDataProcessingLegalBasis
): void => {
  return NativeModules.Purchasely.setUserAttributeWithIntArray(key, value, legalBasis);
};

const setUserAttributeWithDoubleArray = (
  key: string,
  value: number[],
  legalBasis?: PLYDataProcessingLegalBasis
): void => {
  return NativeModules.Purchasely.setUserAttributeWithDoubleArray(key, value, legalBasis);
};

const userAttributes = (): Promise<Record<string, any>> => {
  return NativeModules.Purchasely.userAttributes();
};

const userAttribute = (key: string): Promise<any> => {
  return NativeModules.Purchasely.userAttribute(key);
};

const clearUserAttribute = (key: string): void => {
  return NativeModules.Purchasely.clearUserAttribute(key);
};

const clearUserAttributes = (): void => {
  return NativeModules.Purchasely.clearUserAttributes();
};

/**
 * Reduce a presentation to the identifiers the native bridges use to look up
 * the loaded native presentation. A `PLYLoadedPresentation` also carries
 * functions (`display` / `close` / `back`) which the RN bridge cannot
 * serialize, so only plain fields are sent.
 */
const clientPresentationPayload = (presentation: PLYPresentation) => ({
  screenId: presentation.screenId ?? presentation.id ?? null,
  placementId: presentation.placementId ?? null,
});

/**
 * Notify Purchasely that a client (BYOS) paywall built from a preloaded
 * `PLYPresentationType.CLIENT` presentation is now displayed.
 *
 * Pass the presentation obtained from
 * `Purchasely.presentation…build().preload()`.
 */
const clientPresentationDisplayed = (presentation: PLYPresentation): void => {
  return NativeModules.Purchasely.clientPresentationDisplayed(
    clientPresentationPayload(presentation)
  );
};

/**
 * Notify Purchasely that a client (BYOS) paywall previously reported through
 * {@link clientPresentationDisplayed} has been closed.
 */
const clientPresentationClosed = (presentation: PLYPresentation): void => {
  return NativeModules.Purchasely.clientPresentationClosed(
    clientPresentationPayload(presentation)
  );
};

const isAnonymous = (): Promise<boolean> => {
  return NativeModules.Purchasely.isAnonymous();
};

const isEligibleForIntroOffer = (planVendorId: string): Promise<boolean> => {
  return NativeModules.Purchasely.isEligibleForIntroOffer(planVendorId);
};

const setThemeMode = (theme: PLYThemeMode): void => {
  return NativeModules.Purchasely.setThemeMode(theme);
};

const clearBuiltInAttributes = (): void => {
  return NativeModules.Purchasely.clearBuiltInAttributes();
};

/** [PAR-07] Read every built-in (SDK-computed) user attribute. */
const getBuiltInAttributes = (): Promise<Record<string, any>> => {
  return NativeModules.Purchasely.getBuiltInAttributes();
};

/** [PAR-07] Read a single built-in (SDK-computed) user attribute by key. */
const getBuiltInAttribute = (key: string): Promise<any> => {
  return NativeModules.Purchasely.getBuiltInAttribute(key);
};

const setDynamicOffering = (offering: PLYDynamicOffering): Promise<boolean> => {
  return NativeModules.Purchasely.setDynamicOffering(
    offering.reference,
    offering.planVendorId,
    offering.offerVendorId,
    offering.billingPlanType ?? 'unspecified'
  );
};

const getDynamicOfferings = (): Promise<PLYDynamicOffering[]> => {
  return NativeModules.Purchasely.getDynamicOfferings();
};

const removeDynamicOffering = (reference: string): void => {
  return NativeModules.Purchasely.removeDynamicOffering(reference);
};

const clearDynamicOfferings = (): void => {
  return NativeModules.Purchasely.clearDynamicOfferings();
};

const revokeDataProcessingConsent = (purposes: PLYDataProcessingPurpose[]): void => {
  const stringPurposes = purposes.map(p => p as string);
  return NativeModules.Purchasely.revokeDataProcessingConsent(stringPurposes);
}

const setDebugMode = (debugMode: boolean): void => {
  return NativeModules.Purchasely.setDebugMode(debugMode);
};

/**
 * Close every Purchasely screen currently displayed, regardless of which
 * request opened them. Unlike `PLYPresentationRequest#close()` (scoped to a
 * single request on iOS; dismisses everything on Android — see its
 * doc-comment), this is an explicit, cross-platform "close everything" call.
 */
const closeAllScreens = (): void => {
  return NativeModules.Purchasely.closeAllScreens();
};

const Purchasely = {
  // paywall API — the only supported way to display & intercept paywalls.
  builder,
  apiKey,
  presentation: PLYPresentationBuilder,
  interceptAction: (
    kind: PLYPresentationActionKind,
    handler: Parameters<typeof interceptAction>[1]
  ) => interceptAction(kind, handler),
  removeActionInterceptor,
  removeAllActionInterceptors,
  // Global handler for presentations the app did not instantiate itself
  // (campaigns, deeplinks, Promoted In-App Purchases).
  setDefaultPresentationDismissHandler,
  removeDefaultPresentationDismissHandler,
  // Client (BYOS) presentations — notify Purchasely when your own paywall UI
  // (built from a preloaded CLIENT presentation) is shown / closed.
  clientPresentationDisplayed,
  clientPresentationClosed,
  // Core SDK — version-agnostic (user, products, subscriptions, attributes…).
  addEventListener,
  removeEventListener,
  listenToEvents,
  stopListeningToEvents,
  addPurchasedListener,
  removePurchasedListener,
  listenToPurchases,
  stopListeningToPurchases,
  addUserAttributeSetListener,
  removeUserAttributeSetListener,
  addUserAttributeRemovedListener,
  removeUserAttributeRemovedListener,
  setUserAttributeListener,
  clearUserAttributeListener,
  addWebRedemptionListener,
  removeWebRedemptionListener,
  purchaseWithPlanVendorId,
  setUserAttributeWithDate,
  signPromotionalOffer,
  incrementUserAttribute,
  decrementUserAttribute,
  getAnonymousUserId,
  userLogin,
  userLogout,
  setLogLevel,
  setAttribute,
  allProducts,
  productWithIdentifier,
  planWithIdentifier,
  restoreAllProducts,
  silentRestoreAllProducts,
  userSubscriptions,
  userSubscriptionsHistory,
  handleDeeplink,
  synchronize,
  allowDeeplink,
  allowCampaigns,
  setLanguage,
  userDidConsumeSubscriptionContent,
  setUserAttributeWithString,
  setUserAttributeWithNumber,
  setUserAttributeWithInt,
  setUserAttributeWithDouble,
  setUserAttributeWithBoolean,
  setUserAttributeWithStringArray,
  setUserAttributeWithNumberArray,
  setUserAttributeWithIntArray,
  setUserAttributeWithDoubleArray,
  setUserAttributeWithBooleanArray,
  userAttributes,
  userAttribute,
  clearUserAttribute,
  clearUserAttributes,
  isAnonymous,
  isEligibleForIntroOffer,
  setThemeMode,
  clearBuiltInAttributes,
  getBuiltInAttributes,
  getBuiltInAttribute,
  setDynamicOffering,
  getDynamicOfferings,
  removeDynamicOffering,
  clearDynamicOfferings,
  revokeDataProcessingConsent,
  setDebugMode,
  closeAllScreens
};

export * from './types';
export * from './enums';
export * from './interfaces';
// [PAR-14 / REC-17] `export type *` re-exports every type/interface from
// presentationTypes.ts but excludes its one runtime value export,
// `purchaseResultFromOrdinal` — documented `@internal`, used by presentation.ts
// (which imports it directly from './presentationTypes', unaffected by this
// barrel export), but never meant to be public API.
export type * from './presentationTypes';
export { PURCHASELY_PRESENTATION_EVENTS } from './events';
export {
  PLYPresentationBuilder,
  PLYPresentationRequest,
  setDefaultPresentationDismissHandler,
  removeDefaultPresentationDismissHandler,
} from './presentation';
export {
  interceptAction,
  removeActionInterceptor,
  removeAllActionInterceptors,
} from './interceptor';
export { PurchaselyBuilder } from './startBuilder';
export { PLYPresentationView };

export default Purchasely;
