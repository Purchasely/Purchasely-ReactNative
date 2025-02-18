import { NativeModules, NativeEventEmitter } from 'react-native';
import { PLYPresentationViewBeta } from './PLYPresentationView';
//import { PurchaselyView } from './PurchaselyViewManager';

const purchaselyVersion = '5.0.7';

interface Constants {
  logLevelDebug: number;
  logLevelWarn: number;
  logLevelInfo: number;
  logLevelError: number;
  productResultPurchased: number;
  productResultCancelled: number;
  productResultRestored: number;
  sourceAppStore: number;
  sourcePlayStore: number;
  sourceHuaweiAppGallery: number;
  sourceAmazonAppstore: number;
  sourceNone: number;
  firebaseAppInstanceId: number;
  airshipChannelId: number;
  airshipUserId: number;
  batchInstallationId: number;
  adjustId: number;
  appsflyerId: number;
  onesignalPlayerId: number;
  mixpanelDistinctId: number;
  clevertapId: number;
  sendinblueUserEmail: number;
  iterableUserId: number;
  iterableUserEmail: number;
  atInternetIdClient: number;
  amplitudeUserId: number;
  amplitudeDeviceId: number;
  mparticleUserId: number;
  customerIoUserId: number;
  customerIoUserEmail: number;
  branchUserDeveloperIdentity: number;
  moEngageUniqueId: number;
  batchCustomUserId: number;
  consumable: number;
  nonConsumable: number;
  autoRenewingSubscription: number;
  nonRenewingSubscription: number;
  unknown: number;
  runningModeTransactionOnly: number;
  runningModeObserver: number;
  runningModePaywallObserver: number;
  runningModeFull: number;
  presentationTypeNormal: number;
  presentationTypeFallback: number;
  presentationTypeDeactivated: number;
  presentationTypeClient: number;
  themeLight: number;
  themeDark: number;
  themeSystem: number;
  userAttributeSourcePurchasely: number;
  userAttributeSourceClient: number;
  userAttributeString: number;
  userAttributeBoolean: number;
  userAttributeInt: number;
  userAttributeFloat: number;
  userAttributeDate: number;
  userAttributeStringArray: number;
  userAttributeIntArray: number;
  userAttributeFloatArray: number;
  userAttributeBooleanArray: number;
}

const constants = NativeModules.Purchasely.getConstants() as Constants;

export enum ProductResult {
  PRODUCT_RESULT_CANCELLED = constants.productResultCancelled,
  PRODUCT_RESULT_PURCHASED = constants.productResultPurchased,
  PRODUCT_RESULT_RESTORED = constants.productResultRestored,
}

export enum LogLevels {
  DEBUG = constants.logLevelDebug,
  INFO = constants.logLevelInfo,
  WARNING = constants.logLevelWarn,
  ERROR = constants.logLevelError,
}

export enum SubscriptionSource {
  APPLE_APP_STORE = constants.sourceAppStore,
  GOOGLE_PLAY_STORE = constants.sourcePlayStore,
  HUAWEI_APP_GALLERY = constants.sourceHuaweiAppGallery,
  AMAZON_APPSTORE = constants.sourceAmazonAppstore,
}

export enum Attributes {
  FIREBASE_APP_INSTANCE_ID = constants.firebaseAppInstanceId,
  AIRSHIP_CHANNEL_ID = constants.airshipChannelId,
  AIRSHIP_USER_ID = constants.airshipUserId,
  BATCH_INSTALLATION_ID = constants.batchInstallationId,
  ADJUST_ID = constants.adjustId,
  APPSFLYER_ID = constants.appsflyerId,
  ONESIGNAL_PLAYER_ID = constants.onesignalPlayerId,
  MIXPANEL_DISTINCT_ID = constants.mixpanelDistinctId,
  CLEVER_TAP_ID = constants.clevertapId,
  SENDINBLUE_USER_EMAIL = constants.sendinblueUserEmail,
  ITERABLE_USER_ID = constants.iterableUserId,
  ITERABLE_USER_EMAIL = constants.iterableUserEmail,
  AT_INTERNET_ID_CLIENT = constants.atInternetIdClient,
  AMPLITUDE_USER_ID = constants.amplitudeUserId,
  AMPLITUDE_DEVICE_ID = constants.amplitudeDeviceId,
  MPARTICLE_USER_ID = constants.mparticleUserId,
  CUSTOMER_IO_USER_ID = constants.customerIoUserId,
  CUSTOMER_IO_USER_EMAIL = constants.customerIoUserEmail,
  BRANCH_DEVELOPER_IDENTITY = constants.branchUserDeveloperIdentity,
  MOENGAGE_UNIQUE_ID = constants.moEngageUniqueId,
  BATCH_CUSTOM_USER_ID = constants.batchCustomUserId,
}

export enum PlanType {
  PLAN_TYPE_CONSUMABLE = constants.consumable,
  PLAN_TYPE_NON_CONSUMABLE = constants.nonConsumable,
  PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION = constants.autoRenewingSubscription,
  PLAN_TYPE_NON_RENEWING_SUBSCRIPTION = constants.nonRenewingSubscription,
  PLAN_TYPE_UNKNOWN = constants.unknown,
}

export enum RunningMode {
  TRANSACTION_ONLY = constants.runningModeTransactionOnly,
  OBSERVER = constants.runningModeObserver,
  PAYWALL_OBSERVER = constants.runningModePaywallObserver,
  FULL = constants.runningModeFull,
}

export enum PLYThemeMode {
  LIGHT = constants.themeLight,
  DARK = constants.themeDark,
  SYSTEM = constants.themeSystem,
}

export enum PLYPaywallAction {
  CLOSE = 'close',
  LOGIN = 'login',
  NAVIGATE = 'navigate',
  PURCHASE = 'purchase',
  RESTORE = 'restore',
  OPEN_PRESENTATION = 'open_presentation',
  PROMO_CODE = 'promo_code',
}

export enum PLYPresentationType {
  NORMAL = constants.presentationTypeNormal,
  FALLBACK = constants.presentationTypeFallback,
  DEACTIVATED = constants.presentationTypeDeactivated,
  CLIENT = constants.presentationTypeClient,
}

export enum PLYUserAttributeSource {
  PURCHASELY = constants.userAttributeSourcePurchasely,
  CLIENT = constants.userAttributeSourceClient
}

export enum PLYUserAttributeType {
  STRING = constants.userAttributeString,
  BOOLEAN = constants.userAttributeBoolean,
  INT = constants.userAttributeInt,
  FLOAT = constants.userAttributeFloat,
  DATE = constants.userAttributeDate,
  STRING_ARRAY = constants.userAttributeStringArray,
  INT_ARRAY = constants.userAttributeIntArray,
  FLOAT_ARRAY = constants.userAttributeFloatArray,
  BOOLEAN_ARRAY = constants.userAttributeBooleanArray,
}

export type PLYPaywallInfo = {
  presentationId?: string;
  placementId?: string;
  contentId?: string;
  abTestId?: string;
  abTestVariantId?: string;
};

export type PurchaselyPlan = {
  vendorId: string;
  productId: string;
  name: string;
  type: PlanType;
  amount: number;
  localizedAmount: string;
  currencyCode: string;
  currencySymbol: string;
  price: string;
  period: string;
  hasIntroductoryPrice: boolean;
  introPrice: string;
  introAmount: number;
  introDuration: string;
  introPeriod: string;
  hasFreeTrial: boolean;
};

export type PurchaselyOffer = {
  vendorId?: string | null;
  storeOfferId?: string | null;
};

export type PurchaselySubscriptionOffer = {
  subscriptionId: string;
  basePlanId?: string | null;
  offerToken?: string | null;
  offerId?: string | null;
};

export type PurchaselyProduct = {
  name: string;
  vendorId: string;
  plans: PurchaselyPlan[];
};

export type PurchaselyPromotionalOfferSignature = {
  planVendorId: String;
  identifier: String;
  signature: String;
  nonce: any;
  keyIdentifier: String;
  timestamp: number;
};

export type PurchaselyUserAttribute = {
  key: string;
  value?: any | null;
  type?: PLYUserAttributeType | null;
  source?: PLYUserAttributeSource | null;
};

export type PurchaselySubscription = {
  purchaseToken: string;
  subscriptionSource: SubscriptionSource;
  nextRenewalDate: string;
  cancelledDate: string;
  plan: PurchaselyPlan;
  product: PurchaselyProduct;
  /*cumulatedRevenuesInUSD: number;
  subscriptionDurationInDays: number;
  subscriptionDurationInWeeks: number;
  subscriptionDurationInMonths: number;*/
};

export type PresentPresentationResult = {
  result: ProductResult;
  plan: PurchaselyPlan;
};

export type FetchPresentationResult = {
  presentation: PurchaselyPresentation;
};

export type PaywallActionInterceptorResult = {
  info: PLYPaywallInfo;
  action: PLYPaywallAction;
  parameters: {
    url: String;
    title: String;
    plan: PurchaselyPlan;
    offer: PurchaselyOffer | null;
    subscriptionOffer: PurchaselySubscriptionOffer | null;
    presentation: String;
  };
};

const PurchaselyEventEmitter = new NativeEventEmitter(NativeModules.Purchasely);

type PurchaselyEventsNames =
  | 'APP_INSTALLED'
  | 'APP_CONFIGURED'
  | 'APP_UPDATED'
  | 'APP_STARTED'
  | 'CANCELLATION_REASON_PUBLISHED'
  | 'IN_APP_PURCHASING'
  | 'IN_APP_PURCHASED'
  | 'IN_APP_RESTORED'
  | 'IN_APP_DEFERRED'
  | 'IN_APP_PURCHASE_FAILED'
  | 'IN_APP_NOT_AVAILABLE'
  | 'PURCHASE_CANCELLED_BY_APP'
  | 'CAROUSEL_SLIDE_SWIPED'
  | 'DEEPLINK_OPENED'
  | 'LINK_OPENED'
  | 'LOGIN_TAPPED'
  | 'PLAN_SELECTED'
  | 'OPTIONS_SELECTED'
  | 'OPTIONS_VALIDATED'
  | 'PRESENTATION_VIEWED'
  | 'PRESENTATION_OPENED'
  | 'PRESENTATION_SELECTED'
  | 'PRESENTATION_LOADED'
  | 'PRESENTATION_CLOSED'
  | 'PROMO_CODE_TAPPED'
  | 'PURCHASE_CANCELLED'
  | 'PURCHASE_TAPPED'
  | 'RESTORE_TAPPED'
  | 'RECEIPT_CREATED'
  | 'RECEIPT_VALIDATED'
  | 'RECEIPT_FAILED'
  | 'RESTORE_STARTED'
  | 'RESTORE_SUCCEEDED'
  | 'RESTORE_FAILED'
  | 'SUBSCRIPTIONS_LIST_VIEWED'
  | 'SUBSCRIPTION_DETAILS_VIEWED'
  | 'SUBSCRIPTION_CANCEL_TAPPED'
  | 'SUBSCRIPTION_PLAN_TAPPED'
  | 'SUBSCRIPTIONS_TRANSFERRED'
  | 'USER_LOGGED_IN'
  | 'USER_LOGGED_OUT'
  | 'SUBSCRIPTION_CONTENT_USED';

type PurchaselyEventPropertyPlan = {
  type?: string;
  purchasely_plan_id?: string;
  store?: string;
  store_country?: string;
  store_product_id?: string;
  price_in_customer_currency?: number;
  customer_currency?: string;
  period?: string;
  duration?: number;
  intro_price_in_customer_currency?: number;
  intro_period?: string;
  intro_duration?: string;
  has_free_trial?: boolean;
  free_trial_period?: string;
  free_trial_duration?: number;
  discount_referent?: string;
  discount_percentage_comparison_to_referent?: string;
  discount_price_comparison_to_referent?: number;
  is_default: boolean;
};

type PurchaselyEventPropertyCarousel = {
  selected_slide?: number;
  number_of_slides?: number;
  is_carousel_auto_playing: boolean;
  default_slide?: number;
  previous_slide?: number;
};

type PurchaselyEventPropertySubscription = {
  plan?: String;
  product?: String;
};

type PurchaselyEvent = {
  name: PurchaselyEventsNames;
  properties: PurchaselyEventProperties;
};

type PurchaselyEventProperties = {
  sdk_version: string;
  event_name: PurchaselyEventsNames;
  event_created_at_ms: number;
  event_created_at: string;
  displayed_presentation?: string;
  user_id?: string;
  anonymous_user_id?: string;
  purchasable_plans?: PurchaselyEventPropertyPlan[];
  deeplink_identifier?: string;
  source_identifier?: string;
  selected_plan?: string;
  previous_selected_plan?: string;
  selected_presentation?: string;
  previous_selected_presentation?: string;
  link_identifier?: string;
  carousels?: PurchaselyEventPropertyCarousel[];
  language?: string;
  device?: string;
  os_version?: string;
  device_type?: string;
  error_message?: string;
  cancellation_reason_id?: string;
  cancellation_reason?: string;
  plan?: string;
  selected_product?: string;
  plan_change_type?: string;
  running_subscriptions?: PurchaselyEventPropertySubscription[];
};

export type PLYPresentationPlan = {
  planVendorId: string | null;
  storeProductId?: string | null;
  basePlanId?: string | null;
  offerId?: string | null;
};

export type PLYPresentationMetadata = {
  [key: string]: string | number | boolean;
};

export type PurchaselyPresentation = {
  id: string;
  placementId?: string | null;
  audienceId?: string | null;
  abTestId?: string | null;
  abTestVariantId?: string | null;
  language?: string | null;
  type?: PLYPresentationType | null;
  plans?: PLYPresentationPlan[] | null;
  metadata: PLYPresentationMetadata;
};

interface StartParameters {
  apiKey: string;
  androidStores?: string[] | null;
  storeKit1: boolean;
  userId?: string | null;
  logLevel?: number | null;
  runningMode?: number | null;
}

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

function setUserAttributeWithDate(key: string, value: Date): void {
  const dateAsString = value.toISOString();
  return NativeModules.Purchasely.setUserAttributeWithDate(key, dateAsString);
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

type UserAttributeSetListenerCallback = (userAttribute: PurchaselyUserAttribute) => void;

const addUserAttributeSetListener = (callback: UserAttributeSetListenerCallback) => {
  return PurchaselyEventEmitter.addListener('USER_ATTRIBUTE_SET_LISTENER', callback);
};

const removeUserAttributeSetListener = () => {
  return PurchaselyEventEmitter.removeAllListeners('USER_ATTRIBUTE_SET_LISTENER');
};

type UserAttributeRemovedListenerCallback = (userAttribute: PurchaselyUserAttribute) => void;

const addUserAttributeRemovedListener = (callback: UserAttributeRemovedListenerCallback) => {
  return PurchaselyEventEmitter.addListener('USER_ATTRIBUTE_REMOVED_LISTENER', callback);
};

const removeUserAttributeRemovedListener = () => {
  return PurchaselyEventEmitter.removeAllListeners('USER_ATTRIBUTE_REMOVED_LISTENER');
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

interface FetchPresentationParameters {
  placementId?: string | null;
  presentationId?: string | null;
  contentId?: string | null;
}

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

interface PresentPresentationParameters {
  presentation?: PurchaselyPresentation | null;
  isFullscreen?: boolean;
  loadingBackgroundColor?: string | null;
}

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

interface PresentPresentationWithIdentifierParameters {
  presentationVendorId?: string | null;
  contentId?: string | null;
  isFullscreen?: boolean;
  loadingBackgroundColor?: string | null;
}

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

interface PresentPresentationPlacementParameters {
  placementVendorId?: string | null;
  contentId?: string | null;
  isFullscreen?: boolean;
  loadingBackgroundColor?: string | null;
}

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

interface PresentProductParameters {
  productVendorId?: string | null;
  presentationVendorId?: string | null;
  contentId?: string | null;
  isFullscreen?: boolean;
  loadingBackgroundColor?: string | null;
}

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
interface PresentPlanParameters {
  planVendorId?: string | null;
  presentationVendorId?: string | null;
  contentId?: string | null;
  isFullscreen?: boolean;
  loadingBackgroundColor?: string | null;
}

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

interface PurchasePlanParameters {
  planVendorId: string;
  offerId?: string | null;
  contentId?: string | null;
}
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

interface SignPromotionalOfferParameters {
  storeProductId: string;
  storeOfferId: string;
}
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

interface UserAttributesParameters {
  key: string;
  value?: number | null;
}
const incrementUserAttribute = ({
  key,
  value,
}: UserAttributesParameters):void => {
  const nonNullValue = value ?? 1;
  return NativeModules.Purchasely.incrementUserAttribute(
    key,
    nonNullValue
  );
};
const decrementUserAttribute = ({
  key,
  value,
}: UserAttributesParameters):void => {
  const nonNullValue = value ?? 1;
  return NativeModules.Purchasely.decrementUserAttribute(
    key,
    nonNullValue
  );
};

const getConstants = (): Constants => {
  return constants;
}

const close = (): void => {
  return NativeModules.Purchasely.close();
}

const getAnonymousUserId = (): Promise<string> => {
  return NativeModules.Purchasely.getAnonymousUserId();
}

const userLogin = (userId: string): Promise<boolean> => {
  return NativeModules.Purchasely.userLogin(userId);
}

const userLogout = (): void => {
  return NativeModules.Purchasely.userLogout();
}

const setLogLevel = (logLevel: LogLevels): void => {
  return NativeModules.Purchasely.setLogLevel(logLevel);
}

const readyToOpenDeeplink = (ready: boolean): void => {
  return NativeModules.Purchasely.readyToOpenDeeplink(ready);
}

const setAttribute = (attribute: Attributes, value: string): void => {
  return NativeModules.Purchasely.setAttribute(attribute, value);
}

const allProducts = (): Promise<PurchaselyProduct[]> => {
  return NativeModules.Purchasely.allProducts();
}

const productWithIdentifier = (vendorId: string): Promise<PurchaselyProduct> => {
  return NativeModules.Purchasely.productWithIdentifier(vendorId);
}

const planWithIdentifier = (vendorId: string): Promise<PurchaselyPlan> => {
  return NativeModules.Purchasely.planWithIdentifier(vendorId);
}

const restoreAllProducts = (): Promise<boolean> => {
  return NativeModules.Purchasely.restoreAllProducts();
}

const silentRestoreAllProducts = (): Promise<boolean> => {
  return NativeModules.Purchasely.silentRestoreAllProducts();
}

const userSubscriptions = (): Promise<PurchaselySubscription[]> => {
  return NativeModules.Purchasely.userSubscriptions();
}

const userSubscriptionsHistory = (): Promise<PurchaselySubscription[]> => {
  return NativeModules.Purchasely.userSubscriptionsHistory();
}

const presentSubscriptions = (): void => {
  return NativeModules.Purchasely.presentSubscriptions();
}

const isDeeplinkHandled = (deeplink: string | null): Promise<boolean> => {
  return NativeModules.Purchasely.isDeeplinkHandled(deeplink);
}

const synchronize = (): void => {
  return NativeModules.Purchasely.synchronize();
}

const setDefaultPresentationResultHandler = (): Promise<PresentPresentationResult> => {
  return NativeModules.Purchasely.setDefaultPresentationResultHandler();
}

const setPaywallActionInterceptor = (): Promise<PaywallActionInterceptorResult> => {
  return NativeModules.Purchasely.setPaywallActionInterceptor();
}

const onProcessAction = (processAction: boolean): void => {
  return NativeModules.Purchasely.onProcessAction(processAction);
}

const setLanguage = (language: string): void => {
  return NativeModules.Purchasely.setLanguage(language);
}

const userDidConsumeSubscriptionContent = (): void => {
  return NativeModules.Purchasely.userDidConsumeSubscriptionContent();
}

const setUserAttributeWithString = (key: string, value: string): void => {
  return NativeModules.Purchasely.setUserAttributeWithString(key, value);
}

const setUserAttributeWithNumber = (key: string, value: number): void => {
  return NativeModules.Purchasely.setUserAttributeWithNumber(key, value);
}

const setUserAttributeWithBoolean = (key: string, value: boolean): void => {
  return NativeModules.Purchasely.setUserAttributeWithBoolean(key, value);
}

const setUserAttributeWithStringArray = (key: string, value: string[]): void => {
  return NativeModules.Purchasely.setUserAttributeWithStringArray(key, value);
}

const setUserAttributeWithNumberArray = (key: string, value: number[]): void => {
  return NativeModules.Purchasely.setUserAttributeWithNumberArray(key, value);
}

const setUserAttributeWithBooleanArray = (key: string, value: boolean[]): void => {
  return NativeModules.Purchasely.setUserAttributeWithBooleanArray(key, value);
}

const userAttributes = (): Promise<PurchaselyUserAttribute> => {
  return NativeModules.Purchasely.userAttributes();
}

const userAttribute = (key: string): Promise<any> => {
  return NativeModules.Purchasely.userAttribute(key);
}

const clearUserAttribute = (key: string): void => {
  return NativeModules.Purchasely.clearUserAttribute(key);
}

const clearUserAttributes = (): void => {
  return NativeModules.Purchasely.clearUserAttributes();
}

const clientPresentationDisplayed = (presentation: PurchaselyPresentation): void => {
  return NativeModules.Purchasely.clientPresentationDisplayed(presentation);
}

const clientPresentationClosed = (presentation: PurchaselyPresentation): void => {
  return NativeModules.Purchasely.clientPresentationClosed(presentation);
}

const isAnonymous = (): Promise<boolean> => {
  return NativeModules.Purchasely.isAnonymous();
}

const isEligibleForIntroOffer = (planVendorId: String): Promise<boolean> => {
  return NativeModules.Purchasely.isEligibleForIntroOffer(planVendorId);
}

const setThemeMode = (theme: PLYThemeMode): void => {
  return NativeModules.Purchasely.setThemeMode(theme);
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

};

export default Purchasely;

export { PLYPresentationViewBeta };

//export { PurchaselyView };
