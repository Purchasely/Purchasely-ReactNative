import { NativeModules, NativeEventEmitter } from 'react-native';

interface ConstantsIOS {
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
interface ConstantsAndroid {
  logLevelDebug: number;
  logLevelWarn: number;
  logLevelInfo: number;
  logLevelError: number;
  logLevelVerbose: number;
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

const constants = NativeModules.Purchasely.getConstants() as
  | ConstantsIOS
  | ConstantsAndroid;

export function isConstantAndroid(
  c: ConstantsIOS | ConstantsAndroid
): c is ConstantsAndroid {
  return (c as ConstantsAndroid).logLevelWarn !== undefined;
}

export function isConstantIOS(
  c: ConstantsIOS | ConstantsAndroid
): c is ConstantsIOS {
  return (c as ConstantsIOS).logLevelWarn !== undefined;
}

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

export type PurchaselyPlan = {
  vendorId: string;
  name: string;
  type: PlanType;
  amount: number;
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
  plans: { [name: string]: PurchaselyPlan };
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
  action: PLYPaywallAction;
  parameters: {
    url: String;
    title: String;
    plan: String;
    presentation: String;
  };
};

type PurchaselyType = {
  getConstants(): ConstantsIOS | ConstantsAndroid;
  startWithAPIKey(
    apiKey: string,
    stores: string[],
    userId: string | null,
    logLevel: number,
    runningMode: number
  ): Promise<boolean>;
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
  | 'DEEPLINK_OPENED'
  | 'IN_APP_PURCHASING'
  | 'IN_APP_PURCHASED'
  | 'IN_APP_RENEWED'
  | 'IN_APP_RESTORED'
  | 'IN_APP_DEFERRED'
  | 'IN_APP_PURCHASE_FAILED'
  | 'LINK_OPENED'
  | 'LOGIN_TAPPED'
  | 'PLAN_SELECTED'
  | 'PRESENTATION_OPENED'
  | 'PRESENTATION_SELECTED'
  | 'PRESENTATION_VIEWED'
  | 'PURCHASE_FROM_STORE_TAPPED'
  | 'PURCHASE_TAPPED'
  | 'PURCHASE_CANCELLED'
  | 'PURCHASE_CANCELLED_BY_APP'
  | 'RECEIPT_CREATED'
  | 'RECEIPT_VALIDATED'
  | 'RECEIPT_FAILED'
  | 'RESTORE_STARTED'
  | 'RESTORE_SUCCEEDED'
  | 'RESTORE_FAILED'
  | 'STORE_PRODUCT_FETCH_FAILED'
  | 'SUBSCRIPTIONS_LIST_VIEWED'
  | 'SUBSCRIPTION_DETAILS_VIEWED'
  | 'SUBSCRIPTION_CANCEL_TAPPED'
  | 'SUBSCRIPTION_PLAN_TAPPED'
  | 'SUBSCRIPTIONS_TRANSFERRED'
  | 'USER_LOGGED_IN'
  | 'USER_LOGGED_OUT';

type PurchaselyEventMap = {
  name: PurchaselyEventsNames;
  properties?: {
    error?: { message?: string };
    transaction?: {
      transaction_identifier?: string;
      original_transaction_identifier?: string;
      payment?: { product_identifier?: string; quantity: number };
    };
    url?: { absolute_url?: string };
    payment?: { product_identifier?: string; quantity: number };
    product?: {
      amount?: number;
      currency?: string;
      intro_amount?: number;
      intro_period?: string;
      intro_duration?: number;
      intro_cycles?: number;
      apple_product_id?: string;
      android_product_id?: string;
      vendor_id?: string;
    };
    displayed_presentation?: string;
    plan?: { vendor_id?: string };
    presentation?: { vendor_id?: string };
    reason?: { code: string; current_locale: string };
    deeplink?: { description?: string; url?: string };
  };
};

type EventListenerCallback = (event: PurchaselyEventMap) => void;

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

const presentPresentationWithIdentifier = (
  presentationVendorId: string | null = null,
  contentId: string | null = null
): Promise<PresentPresentationResult> => {
  return NativeModules.Purchasely.presentPresentationWithIdentifier(
    presentationVendorId,
    contentId
  );
};

const presentProductWithIdentifier = (
  productVendorId: string,
  presentationVendorId: string | null = null,
  contentId: string | null = null
): Promise<PresentPresentationResult> => {
  return NativeModules.Purchasely.presentProductWithIdentifier(
    productVendorId,
    presentationVendorId,
    contentId
  );
};

const presentPlanWithIdentifier = (
  planVendorId: string,
  presentationVendorId: string | null = null,
  contentId: string | null = null
): Promise<PresentPresentationResult> => {
  return NativeModules.Purchasely.presentPlanWithIdentifier(
    planVendorId,
    presentationVendorId,
    contentId
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
  addEventListener,
  removeEventListener,
  addPurchasedListener,
  removePurchasedListener,
  setDefaultPresentationResultCallback,
  setPaywallActionInterceptorCallback,
  presentPresentationWithIdentifier,
  presentProductWithIdentifier,
  presentPlanWithIdentifier,
  purchaseWithPlanVendorId,
};

export default Purchasely;
