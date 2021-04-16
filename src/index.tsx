import { NativeModules, NativeEventEmitter } from 'react-native';

interface ConstantsIOS {
  logLevelDebug: number;
  logLevelWarn: number;
  logLevelInfo: number;
  logLevelError: number;
  productResultPurchased: number;
  productResultCancelled: number;
  productResultRestored: number;
  amplitudeSessionId: number;
  firebaseAppInstanceId: number;
  airshipChannelId: number;
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
  amplitudeSessionId: number;
  firebaseAppInstanceId: number;
  airshipChannelId: number;
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

export enum Attributes {
  AMPLITUDE_SESSION_ID = constants.amplitudeSessionId,
  FIREBASE_APP_INSTANCE_ID = constants.firebaseAppInstanceId,
  AIRSHIP_CHANNEL_ID = constants.airshipChannelId,
}

export type PurchaselyPlan = {
  vendorId: number;
  name: number;
  distributionType: number;
  amount: number;
  priceCurrency: number;
  price: number;
  period: number;
  hasIntroductoryPrice: number;
  introPrice: number;
  introAmount: number;
  introDuration: number;
  introPeriod: number;
  hasFreeTrial: number;
};

export type PurchaselyProduct = {
  id: number;
  name: string;
  vendorId: number;
  plans: { [name: string]: PurchaselyPlan };
};

export type PurchaselySubscription = {
  id: number;
  purchaseToken: string;
  subscriptionSource: number;
  nextRenewalDate: number;
  cancelledDate: number;
  plan: PurchaselyPlan;
  product: PurchaselyProduct;
};

export type PresentPresentationResult = {
  result: ProductResult;
  plan: PurchaselyPlan;
};

type PurchaselyType = {
  getConstants(): ConstantsIOS | ConstantsAndroid;
  startWithAPIKey(
    apiKey: string,
    stores: string[],
    userId: string | null,
    logLevel: number,
    observerMode: boolean | false
  ): void;
  close(): void;
  getAnonymousUserId(): Promise<string>;
  userLogin(userId: string): Promise<boolean>;
  userLogout(): void;
  setLogLevel(logLevel: LogLevels): void;
  isReadyToPurchase(isReadyToPurchase: boolean): void;
  setAttribute(attribute: Attributes, value: string): void;
  presentPresentationWithIdentifier(
    presentationVendorId: string | null
  ): Promise<PresentPresentationResult>;
  presentProductWithIdentifier(
    productVendorId: string,
    presentationVendorId: string | null
  ): Promise<PresentPresentationResult>;
  presentPlanWithIdentifier(
    planVendorId: string,
    presentationVendorId: string | null
  ): Promise<PresentPresentationResult>;
  productWithIdentifier(vendorId: string): Promise<PurchaselyProduct>;
  planWithIdentifier(vendorId: string): Promise<PurchaselyPlan>;
  purchaseWithPlanVendorId(planVendorId: string): Promise<PurchaselyPlan>;
  restoreAllProducts(): Promise<boolean>;
  displaySubscriptionCancellationInstruction(): void;
  userSubscriptions(): Promise<PurchaselySubscription[]>;
  presentSubscriptions(): void;
  handle(deeplink: string | null): Promise<boolean>;
  synchronize(): void;
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

const Purchasely = {
  ...RNPurchasely,
  addEventListener,
  removeEventListener,
  addPurchasedListener,
  removePurchasedListener,
};

export default Purchasely;
