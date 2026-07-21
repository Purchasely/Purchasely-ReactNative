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

const purchaselyVersion = '6.0.0-rc.3';

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

const restoreAllProducts = (): Promise<boolean> => {
  return NativeModules.Purchasely.restoreAllProducts();
};

const silentRestoreAllProducts = (): Promise<boolean> => {
  return NativeModules.Purchasely.silentRestoreAllProducts();
};

const userSubscriptions = ({ invalidateCache = false }: { invalidateCache?: boolean | null } = {}): Promise<PLYSubscription[]> => {
  return NativeModules.Purchasely.userSubscriptions(invalidateCache);
};

const userSubscriptionsHistory = (): Promise<PLYSubscription[]> => {
  return NativeModules.Purchasely.userSubscriptionsHistory();
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

const setUserAttributeWithInt = setUserAttributeWithNumber;
const setUserAttributeWithDouble = setUserAttributeWithNumber;

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

const setUserAttributeWithIntArray = setUserAttributeWithNumberArray;
const setUserAttributeWithDoubleArray = setUserAttributeWithNumberArray;

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
export type { PLYPresentationViewResult } from './components/PLYPresentationView';

export default Purchasely;
