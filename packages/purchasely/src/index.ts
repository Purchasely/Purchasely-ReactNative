import { NativeEventEmitter, NativeModules } from 'react-native';

import { PLYPresentationView } from './components/PLYPresentationView';
import type {
  Constants,
  DynamicOffering,
  FetchPresentationParameters,
  PresentPlanParameters,
  PresentPresentationParameters,
  PresentPresentationPlacementParameters,
  PresentPresentationWithIdentifierParameters,
  PresentProductParameters,
  PurchasePlanParameters,
  SignPromotionalOfferParameters,
  StartParameters,
  UserAttributesParameters,
} from './interfaces';
import { Attributes, LogLevels, PLYDataProcessingLegalBasis, PLYDataProcessingPurpose, PLYThemeMode, RunningMode } from './enums';
import type {
  PaywallActionInterceptorResult,
  PresentPresentationResult,
  PurchaselyEvent,
  PurchaselyPlan,
  PurchaselyPresentation,
  PurchaselyProduct,
  PurchaselyPromotionalOfferSignature,
  PurchaselySubscription,
  PurchaselyUserAttribute,
} from './types';

const purchaselyVersion = '5.5.0';

const constants = NativeModules.Purchasely.getConstants() as Constants;

const PurchaselyEventEmitter = new NativeEventEmitter(NativeModules.Purchasely);

const start = ({
  apiKey,
  androidStores = ['Google'],
  storeKit1,
  userId = null,
  logLevel = LogLevels.ERROR,
  runningMode = RunningMode.FULL,
}: StartParameters): Promise<boolean> => {
  return NativeModules.Purchasely.start(
    apiKey,
    androidStores,
    storeKit1,
    userId,
    logLevel,
    runningMode,
    purchaselyVersion
  );
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

type DefaultPresentationResultCallback = (
  result: PresentPresentationResult
) => void;

const setDefaultPresentationResultCallback = (
  callback: DefaultPresentationResultCallback
) => {
  Purchasely.setDefaultPresentationResultHandler().then((result) => {
    setDefaultPresentationResultCallback(callback);
    try {
      callback(result);
    } catch (e) {
      console.warn(
        '[Purchasely] Error with callback for default presentation result',
        e
      );
    }
  });
};

type PaywallActionInterceptorCallback = (
  result: PaywallActionInterceptorResult
) => void;

const setPaywallActionInterceptorCallback = (
  callback: PaywallActionInterceptorCallback
) => {
  Purchasely.setPaywallActionInterceptor().then((result) => {
    setPaywallActionInterceptorCallback(callback);
    try {
      callback(result);
    } catch (e) {
      console.warn('[Purchasely] Error with paywall interceptor callback', e);
    }
  });
};

const fetchPresentation = ({
  placementId = null,
  presentationId = null,
  contentId = null,
}: FetchPresentationParameters): Promise<PurchaselyPresentation> => {
  return NativeModules.Purchasely.fetchPresentation(
    placementId,
    presentationId,
    contentId
  );
};

const presentPresentation = ({
  presentation = null,
  isFullscreen = false,
  loadingBackgroundColor = null,
}: PresentPresentationParameters): Promise<PresentPresentationResult> => {
  return NativeModules.Purchasely.presentPresentation(
    presentation,
    isFullscreen,
    loadingBackgroundColor
  );
};

const presentPresentationWithIdentifier = ({
  presentationVendorId = null,
  contentId = null,
  isFullscreen = false,
  loadingBackgroundColor = null,
}: PresentPresentationWithIdentifierParameters): Promise<PresentPresentationResult> => {
  return NativeModules.Purchasely.presentPresentationWithIdentifier(
    presentationVendorId,
    contentId,
    isFullscreen,
    loadingBackgroundColor
  );
};

const presentPresentationForPlacement = ({
  placementVendorId = null,
  contentId = null,
  isFullscreen = false,
  loadingBackgroundColor = null,
}: PresentPresentationPlacementParameters): Promise<PresentPresentationResult> => {
  return NativeModules.Purchasely.presentPresentationForPlacement(
    placementVendorId,
    contentId,
    isFullscreen,
    loadingBackgroundColor
  );
};

const presentProductWithIdentifier = ({
  productVendorId = null,
  presentationVendorId = null,
  contentId = null,
  isFullscreen = false,
  loadingBackgroundColor = null,
}: PresentProductParameters): Promise<PresentPresentationResult> => {
  return NativeModules.Purchasely.presentProductWithIdentifier(
    productVendorId,
    presentationVendorId,
    contentId,
    isFullscreen,
    loadingBackgroundColor
  );
};
const presentPlanWithIdentifier = ({
  planVendorId = null,
  presentationVendorId = null,
  contentId = null,
  isFullscreen = false,
  loadingBackgroundColor = null,
}: PresentPlanParameters): Promise<PresentPresentationResult> => {
  return NativeModules.Purchasely.presentPlanWithIdentifier(
    planVendorId,
    presentationVendorId,
    contentId,
    isFullscreen,
    loadingBackgroundColor
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

const closePresentation = () => {
  return NativeModules.Purchasely.closePresentation();
};

const hidePresentation = () => {
  return NativeModules.Purchasely.hidePresentation();
};

const showPresentation = () => {
  return NativeModules.Purchasely.showPresentation();
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

const readyToOpenDeeplink = (ready: boolean): void => {
  return NativeModules.Purchasely.readyToOpenDeeplink(ready);
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

const presentSubscriptions = (): void => {
  return NativeModules.Purchasely.presentSubscriptions();
};

const isDeeplinkHandled = (deeplink: string | null): Promise<boolean> => {
  return NativeModules.Purchasely.isDeeplinkHandled(deeplink);
};

const synchronize = (): void => {
  return NativeModules.Purchasely.synchronize();
};

const setDefaultPresentationResultHandler =
  (): Promise<PresentPresentationResult> => {
    return NativeModules.Purchasely.setDefaultPresentationResultHandler();
  };

const setPaywallActionInterceptor =
  (): Promise<PaywallActionInterceptorResult> => {
    return NativeModules.Purchasely.setPaywallActionInterceptor();
  };

const onProcessAction = (processAction: boolean): void => {
  return NativeModules.Purchasely.onProcessAction(processAction);
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

const isEligibleForIntroOffer = (planVendorId: String): Promise<boolean> => {
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

const Purchasely = {
  start,
  addEventListener,
  removeEventListener,
  addPurchasedListener,
  removePurchasedListener,
  addUserAttributeSetListener,
  removeUserAttributeSetListener,
  addUserAttributeRemovedListener,
  removeUserAttributeRemovedListener,
  setDefaultPresentationResultCallback,
  setPaywallActionInterceptorCallback,
  fetchPresentation,
  presentPresentation,
  presentPresentationWithIdentifier,
  presentPresentationForPlacement,
  presentProductWithIdentifier,
  presentPlanWithIdentifier,
  purchaseWithPlanVendorId,
  setUserAttributeWithDate,
  showPresentation,
  closePresentation,
  hidePresentation,
  signPromotionalOffer,
  incrementUserAttribute,
  decrementUserAttribute,
  getConstants,
  close,
  getAnonymousUserId,
  userLogin,
  userLogout,
  setLogLevel,
  readyToOpenDeeplink,
  setAttribute,
  allProducts,
  productWithIdentifier,
  planWithIdentifier,
  restoreAllProducts,
  silentRestoreAllProducts,
  userSubscriptions,
  userSubscriptionsHistory,
  presentSubscriptions,
  isDeeplinkHandled,
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
  setDefaultPresentationResultHandler,
  setPaywallActionInterceptor,
  onProcessAction,
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
  revokeDataProcessingConsent
};

export * from './types';
export * from './enums';
export * from './interfaces';
export { PLYPresentationView };

export default Purchasely;
