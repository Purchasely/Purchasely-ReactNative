import { NativeEventEmitter, NativeModules } from 'react-native';

import { PLYPresentationView } from './components/PLYPresentationView';
import type {
  Constants,
  DynamicOffering,
  PurchasePlanParameters,
  SignPromotionalOfferParameters,
  UserAttributesParameters,
} from './interfaces';
import { Attributes, LogLevels, PLYDataProcessingLegalBasis, PLYDataProcessingPurpose, PLYThemeMode } from './enums';
import type {
  PurchaselyEvent,
  PurchaselyPlan,
  PurchaselyPresentation,
  PurchaselyProduct,
  PurchaselyPromotionalOfferSignature,
  PurchaselySubscription,
  PurchaselyUserAttribute,
} from './types';
import {
  PresentationBuilder,
  setDefaultPresentationDismissHandler,
  removeDefaultPresentationDismissHandler,
} from './presentation';
import { PurchaselyBuilder } from './startBuilder';
import {
  interceptAction,
  removeActionInterceptor,
  removeAllActionInterceptors,
} from './interceptor';
import type { PresentationActionKind } from './presentationTypes';

const purchaselyVersion = '6.0.0-rc.1';

const constants = NativeModules.Purchasely.getConstants() as Constants;

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

function setUserAttributeWithDate(key: string, value: Date, legalBasis?: PLYDataProcessingLegalBasis): void {
  const dateAsString = value.toISOString();
  return NativeModules.Purchasely.setUserAttributeWithDate(key, dateAsString, legalBasis);
}

type EventListenerCallback = (event: PurchaselyEvent) => void;

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

type UserAttributeSetListenerCallback = (
  userAttribute: PurchaselyUserAttribute
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
  userAttribute: PurchaselyUserAttribute
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

const purchaseWithPlanVendorId = ({
  planVendorId,
  offerId = null,
  contentId = null,
}: PurchasePlanParameters): Promise<PurchaselyPlan> => {
  return NativeModules.Purchasely.purchaseWithPlanVendorId(
    planVendorId,
    offerId,
    contentId
  );
};

const signPromotionalOffer = ({
  storeProductId,
  storeOfferId,
}: SignPromotionalOfferParameters): Promise<PurchaselyPromotionalOfferSignature> => {
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

const getConstants = (): Constants => {
  return constants;
};

const close = (): void => {
  return NativeModules.Purchasely.close();
};

const getAnonymousUserId = (): Promise<string> => {
  return NativeModules.Purchasely.getAnonymousUserId();
};

const userLogin = (userId: string): Promise<boolean> => {
  return NativeModules.Purchasely.userLogin(userId);
};

const userLogout = (): void => {
  return NativeModules.Purchasely.userLogout();
};

const setLogLevel = (logLevel: LogLevels): void => {
  return NativeModules.Purchasely.setLogLevel(logLevel);
};

const setAttribute = (attribute: Attributes, value: string): void => {
  return NativeModules.Purchasely.setAttribute(attribute, value);
};

const allProducts = (): Promise<PurchaselyProduct[]> => {
  return NativeModules.Purchasely.allProducts();
};

const productWithIdentifier = (
  vendorId: string
): Promise<PurchaselyProduct> => {
  return NativeModules.Purchasely.productWithIdentifier(vendorId);
};

const planWithIdentifier = (vendorId: string): Promise<PurchaselyPlan> => {
  return NativeModules.Purchasely.planWithIdentifier(vendorId);
};

const restoreAllProducts = (): Promise<boolean> => {
  return NativeModules.Purchasely.restoreAllProducts();
};

const silentRestoreAllProducts = (): Promise<boolean> => {
  return NativeModules.Purchasely.silentRestoreAllProducts();
};

const userSubscriptions = ({ invalidateCache = false }: { invalidateCache?: boolean | null } = {}): Promise<PurchaselySubscription[]> => {
  return NativeModules.Purchasely.userSubscriptions(invalidateCache);
};

const userSubscriptionsHistory = (): Promise<PurchaselySubscription[]> => {
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

const userAttributes = (): Promise<PurchaselyUserAttribute> => {
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

const clientPresentationDisplayed = (
  presentation: PurchaselyPresentation
): void => {
  return NativeModules.Purchasely.clientPresentationDisplayed(presentation);
};

const clientPresentationClosed = (
  presentation: PurchaselyPresentation
): void => {
  return NativeModules.Purchasely.clientPresentationClosed(presentation);
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

const setDynamicOffering = (offering: DynamicOffering): Promise<boolean> => {
  return NativeModules.Purchasely.setDynamicOffering(offering.reference, offering.planVendorId, offering.offerVendorId);
};

const getDynamicOfferings = (): Promise<DynamicOffering[]> => {
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

const Purchasely = {
  // paywall API — the only supported way to display & intercept paywalls.
  builder,
  presentation: PresentationBuilder,
  interceptAction: (
    kind: PresentationActionKind,
    handler: Parameters<typeof interceptAction>[1]
  ) => interceptAction(kind, handler),
  removeActionInterceptor,
  removeAllActionInterceptors,
  // Global handler for presentations the app did not instantiate itself
  // (campaigns, deeplinks, Promoted In-App Purchases).
  setDefaultPresentationDismissHandler,
  removeDefaultPresentationDismissHandler,
  // Core SDK — version-agnostic (user, products, subscriptions, attributes…).
  addEventListener,
  removeEventListener,
  addPurchasedListener,
  removePurchasedListener,
  addUserAttributeSetListener,
  removeUserAttributeSetListener,
  addUserAttributeRemovedListener,
  removeUserAttributeRemovedListener,
  purchaseWithPlanVendorId,
  setUserAttributeWithDate,
  signPromotionalOffer,
  incrementUserAttribute,
  decrementUserAttribute,
  getConstants,
  close,
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
  setLanguage,
  userDidConsumeSubscriptionContent,
  setUserAttributeWithString,
  setUserAttributeWithNumber,
  setUserAttributeWithBoolean,
  setUserAttributeWithStringArray,
  setUserAttributeWithNumberArray,
  setUserAttributeWithBooleanArray,
  userAttributes,
  userAttribute,
  clearUserAttribute,
  clearUserAttributes,
  clientPresentationDisplayed,
  clientPresentationClosed,
  isAnonymous,
  isEligibleForIntroOffer,
  setThemeMode,
  clearBuiltInAttributes,
  setDynamicOffering,
  getDynamicOfferings,
  removeDynamicOffering,
  clearDynamicOfferings,
  revokeDataProcessingConsent,
  setDebugMode
};

export * from './types';
export * from './enums';
export * from './interfaces';
export * from './presentationTypes';
export { PURCHASELY_PRESENTATION_EVENTS } from './events';
export {
  PresentationBuilder,
  PresentationRequest,
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
