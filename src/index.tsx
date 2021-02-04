import { NativeModules, NativeEventEmitter } from 'react-native';

interface ConstantsIOS {
  logLevelDebug: number;
  logLevelWarn: number;
  logLevelInfo: number;
  logLevelError: number;
  productResultPurchased: number;
  productResultCancelled: number;
  productResultRestored: number;
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
    logLevel: number
  ): void;
  close(): void;
  getAnonymousUserId(): Promise<string>;
  userLogin(userId: string): void;
  userLogout(): void;
  setLogLevel(logLevel: LogLevels): void;
  isReadyToPurchase(isReadyToPurchase: boolean): void;
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
};

const RNPurchasely = NativeModules.Purchasely as PurchaselyType;

const PurchaselyEventEmitter = new NativeEventEmitter(NativeModules.Purchasely);

type PurchaselyEventsNames =
  | 'APP_INSTALLED'
  | 'APP_UPDATED'
  | 'APP_STARTED'
  | 'DEEPLINK_OPENED'
  | 'PRESENTATION_VIEWED'
  | 'LOGIN_TAPPED'
  | 'PURCHASE_FROM_STORE_TAPPED'
  | 'PURCHASE_TAPPED'
  | 'PURCHASE_CANCELLED'
  | 'IN_APP_PURCHASING'
  | 'IN_APP_PURCHASED'
  | 'IN_APP_RENEWED'
  | 'RECEIPT_CREATED'
  | 'RECEIPT_VALIDATED'
  | 'RECEIPT_FAILED'
  | 'RESTORE_STARTED'
  | 'IN_APP_RESTORED'
  | 'RESTORE_SUCCEEDED'
  | 'RESTORE_FAILED'
  | 'IN_APP_DEFERRED'
  | 'IN_APP_PURCHASE_FAILED'
  | 'LINK_OPENED'
  | 'SUBSCRIPTIONS_LIST_VIEWED'
  | 'SUBSCRIPTION_DETAILS_VIEWED'
  | 'SUBSCRIPTION_CANCEL_TAPPED'
  | 'SUBSCRIPTION_PLAN_TAPPED'
  | 'CANCELLATION_REASON_PUBLISHED';

type PurchaselyEventMap = {
  error?: { message?: string };
  transaction?: {
    originalTransactionIdentifier?: string;
    payment?: { productIdentifier?: string; quantity: number };
  };
  url?: { absoluteUrl?: string };
  payment?: { productIdentifier?: string; quantity: number };
  product?: {
    amount?: number;
    android_product_id?: string;
    currency?: string;
    vendorId?: string;
  };
  displayedPresentation?: string;
  plan?: { vendorId?: string };
  cancellationReason?: { code: string; currentLocale: string };
  deeplink?: { description?: string; url?: string };
};

type EventListenerCallback = (event: PurchaselyEventMap | '') => void;

const addListener = (
  event: PurchaselyEventsNames,
  callback: EventListenerCallback
) => {
  return PurchaselyEventEmitter.addListener(event, callback);
};

const removeListener = (
  event: PurchaselyEventsNames,
  callback: EventListenerCallback
) => {
  return PurchaselyEventEmitter.removeListener(event, callback);
};

const removeAllListeners = () => {
  PurchaselyEventEmitter.removeAllListeners('APP_INSTALLED');
  PurchaselyEventEmitter.removeAllListeners('APP_UPDATED');
  PurchaselyEventEmitter.removeAllListeners('APP_STARTED');
  PurchaselyEventEmitter.removeAllListeners('DEEPLINK_OPENED');
  PurchaselyEventEmitter.removeAllListeners('PRESENTATION_VIEWED');
  PurchaselyEventEmitter.removeAllListeners('LOGIN_TAPPED');
  PurchaselyEventEmitter.removeAllListeners('PURCHASE_FROM_STORE_TAPPED');
  PurchaselyEventEmitter.removeAllListeners('PURCHASE_TAPPED');
  PurchaselyEventEmitter.removeAllListeners('PURCHASE_CANCELLED');
  PurchaselyEventEmitter.removeAllListeners('IN_APP_PURCHASING');
  PurchaselyEventEmitter.removeAllListeners('IN_APP_PURCHASED');
  PurchaselyEventEmitter.removeAllListeners('IN_APP_RENEWED');
  PurchaselyEventEmitter.removeAllListeners('RECEIPT_CREATED');
  PurchaselyEventEmitter.removeAllListeners('RECEIPT_VALIDATED');
  PurchaselyEventEmitter.removeAllListeners('RECEIPT_FAILED');
  PurchaselyEventEmitter.removeAllListeners('RESTORE_STARTED');
  PurchaselyEventEmitter.removeAllListeners('IN_APP_RESTORED');
  PurchaselyEventEmitter.removeAllListeners('RESTORE_SUCCEEDED');
  PurchaselyEventEmitter.removeAllListeners('RESTORE_FAILED');
  PurchaselyEventEmitter.removeAllListeners('IN_APP_DEFERRED');
  PurchaselyEventEmitter.removeAllListeners('IN_APP_PURCHASE_FAILED');
  PurchaselyEventEmitter.removeAllListeners('LINK_OPENED');
  PurchaselyEventEmitter.removeAllListeners('SUBSCRIPTIONS_LIST_VIEWED');
  PurchaselyEventEmitter.removeAllListeners('SUBSCRIPTION_DETAILS_VIEWED');
  PurchaselyEventEmitter.removeAllListeners('SUBSCRIPTION_CANCEL_TAPPED');
  PurchaselyEventEmitter.removeAllListeners('SUBSCRIPTION_PLAN_TAPPED');
  PurchaselyEventEmitter.removeAllListeners('CANCELLATION_REASON_PUBLISHED');
};

const Purchasely = {
  ...RNPurchasely,
  addListener,
  removeListener,
  removeAllListeners,
};

export default Purchasely;
