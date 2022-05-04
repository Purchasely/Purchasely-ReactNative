import { NativeModules, NativeEventEmitter } from 'react-native';
import { version as purchaselySdkVersion } from '../package.json';

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
  amplitudeSessionId: number;
  firebaseAppInstanceId: number;
  airshipChannelId: number;
  batchInstallationId: number;
  adjustId: number;
  appsflyerId: number;
  onesignalPlayerId: number;
  mixpanelDistinctId: number;
  clevertapId: number;
  consumable: number;
  nonConsumable: number;
  autoRenewingSubscription: number;
  nonRenewingSubscription: number;
  unknown: number;
  runningModeTransactionOnly: number;
  runningModeObserver: number;
  runningModePaywallOnly: number;
  runningModePaywallObserver: number;
  runningModeFull: number;
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
  AMPLITUDE_SESSION_ID = constants.amplitudeSessionId,
  FIREBASE_APP_INSTANCE_ID = constants.firebaseAppInstanceId,
  AIRSHIP_CHANNEL_ID = constants.airshipChannelId,
  BATCH_INSTALLATION_ID = constants.batchInstallationId,
  ADJUST_ID = constants.adjustId,
  APPSFLYER_ID = constants.appsflyerId,
  ONESIGNAL_PLAYER_ID = constants.onesignalPlayerId,
  MIXPANEL_DISTINCT_ID = constants.mixpanelDistinctId,
  CLEVER_TAP_ID = constants.clevertapId,
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
  PAYWALL_ONLY = constants.runningModePaywallOnly,
  PAYWALL_OBSERVER = constants.runningModePaywallObserver,
  FULL = constants.runningModeFull,
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

export type PurchaselyProduct = {
  name: string;
  vendorId: string;
  plans: PurchaselyPlan[];
};

export type PurchaselySubscription = {
  purchaseToken: string;
  subscriptionSource: SubscriptionSource;
  nextRenewalDate: string;
  cancelledDate: string;
  plan: PurchaselyPlan;
  product: PurchaselyProduct;
};

export type PresentPresentationResult = {
  result: ProductResult;
  plan: PurchaselyPlan;
};

export type PaywallActionInterceptorResult = {
  info: PLYPaywallInfo;
  action: PLYPaywallAction;
  parameters: {
    url: String;
    title: String;
    plan: PurchaselyPlan;
    presentation: String;
  };
};

type PurchaselyType = {
  getConstants(): Constants;
  close(): void;
  getAnonymousUserId(): Promise<string>;
  userLogin(userId: string): Promise<boolean>;
  userLogout(): void;
  setLogLevel(logLevel: LogLevels): void;
  isReadyToPurchase(isReadyToPurchase: boolean): void;
  setAttribute(attribute: Attributes, value: string): void;
  allProducts(): Promise<PurchaselyProduct[]>;
  productWithIdentifier(vendorId: string): Promise<PurchaselyProduct>;
  planWithIdentifier(vendorId: string): Promise<PurchaselyPlan>;
  restoreAllProducts(): Promise<boolean>;
  silentRestoreAllProducts(): Promise<boolean>;
  userSubscriptions(): Promise<PurchaselySubscription[]>;
  presentSubscriptions(): void;
  handle(deeplink: string | null): Promise<boolean>;
  synchronize(): void;
  setDefaultPresentationResultHandler(): Promise<PresentPresentationResult>;
  setPaywallActionInterceptor(): Promise<PaywallActionInterceptorResult>;
  onProcessAction(processAction: boolean): void;
  setLanguage(language: string): void;
  closePaywall(): void;
};

const RNPurchasely = NativeModules.Purchasely as PurchaselyType;

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
  | 'PRESENTATION_VIEWED'
  | 'PRESENTATION_OPENED'
  | 'PRESENTATION_SELECTED'
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
  | 'USER_LOGGED_OUT';

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

function startWithAPIKey(
  apiKey: string,
  stores: string[],
  userId: string | null,
  logLevel: number,
  runningMode: number
): Promise<boolean> {
  return NativeModules.Purchasely.startWithAPIKey(
    apiKey,
    stores,
    userId,
    logLevel,
    runningMode,
    purchaselySdkVersion
  );
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

interface PresentPresentationParameters {
  presentationVendorId?: string | null;
  contentId?: string | null;
  isFullscreen?: boolean;
}

const presentPresentationWithIdentifier = ({
  presentationVendorId = null,
  contentId = null,
  isFullscreen = false,
}: PresentPresentationParameters): Promise<PresentPresentationResult> => {
  return NativeModules.Purchasely.presentPresentationWithIdentifier(
    presentationVendorId,
    contentId,
    isFullscreen
  );
};

interface PresentPresentationPlacementParameters {
  placementVendorId?: string | null;
  contentId?: string | null;
  isFullscreen?: boolean;
}

const presentPresentationForPlacement = ({
  placementVendorId = null,
  contentId = null,
  isFullscreen = false,
}: PresentPresentationPlacementParameters): Promise<PresentPresentationResult> => {
  return NativeModules.Purchasely.presentPresentationForPlacement(
    placementVendorId,
    contentId,
    isFullscreen
  );
};

interface PresentProductParameters {
  productVendorId?: string | null;
  presentationVendorId?: string | null;
  contentId?: string | null;
  isFullscreen?: boolean;
}

const presentProductWithIdentifier = ({
  productVendorId = null,
  presentationVendorId = null,
  contentId = null,
  isFullscreen = false,
}: PresentProductParameters): Promise<PresentPresentationResult> => {
  return NativeModules.Purchasely.presentProductWithIdentifier(
    productVendorId,
    presentationVendorId,
    contentId,
    isFullscreen
  );
};
interface PresentPlanParameters {
  planVendorId?: string | null;
  presentationVendorId?: string | null;
  contentId?: string | null;
  isFullscreen?: boolean;
}

const presentPlanWithIdentifier = ({
  planVendorId = null,
  presentationVendorId = null,
  contentId = null,
  isFullscreen = false,
}: PresentPlanParameters): Promise<PresentPresentationResult> => {
  return NativeModules.Purchasely.presentPlanWithIdentifier(
    planVendorId,
    presentationVendorId,
    contentId,
    isFullscreen
  );
};

const purchaseWithPlanVendorId = (
  planVendorId: string,
  contentId: string | null = null
): Promise<PurchaselyPlan> => {
  return NativeModules.Purchasely.purchaseWithPlanVendorId(
    planVendorId,
    contentId
  );
};

const Purchasely = {
  ...RNPurchasely,
  startWithAPIKey,
  addEventListener,
  removeEventListener,
  addPurchasedListener,
  removePurchasedListener,
  setDefaultPresentationResultCallback,
  setPaywallActionInterceptorCallback,
  presentPresentationWithIdentifier,
  presentPresentationForPlacement,
  presentProductWithIdentifier,
  presentPlanWithIdentifier,
  purchaseWithPlanVendorId,
};

export default Purchasely;
