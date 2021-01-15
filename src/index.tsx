import { NativeModules, NativeEventEmitter } from 'react-native';
interface Constants {
  logLevelDebug: number;
  logLevelWarning: number;
  logLevelInfo: number;
  logLevelVerbose: number;
  logLevelError: number;
  productResultPurchased: number;
  productResultCancelled: number;
  productResultRestored: number;
}

const constants = NativeModules.Purchasely.getConstants() as Constants;

export enum ProductResult {
  PRODUCT_RESULT_CANCELLED = constants.productResultCancelled,
  PRODUCT_RESULT_PURCHASED = constants.productResultPurchased,
  PRODUCT_RESULT_RESTORED = constants.productResultRestored,
}

export enum LogLevels {
  DEBUG = constants.logLevelDebug,
  VERBOSE = constants.logLevelVerbose,
  INFO = constants.logLevelInfo,
  WARNING = constants.logLevelWarning,
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

type presentProductWithIdentifierCallback = (res: {
  result: ProductResult;
  plan: PurchaselyPlan;
}) => void;

type PurchaselyType = {
  getConstants(): Constants;
  startWithAPIKey(
    apiKey: string,
    stores: string[],
    userId: string | null,
    logLevel: number
  ): void;
  close(): void;
  getAnonymousUserId(): Promise<string>;
  setAppUserId(userId: string | null): void;
  setLogLevel(logLevel: LogLevels): void;
  isReadyToPurchase(isReadyToPurchase: boolean): void;
  presentProductWithIdentifier(
    productVendorId: string,
    presentationVendorId: string | null,
    callback: presentProductWithIdentifierCallback
  ): void;
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

type EventListenerCallback = (event: {
  [name: string]: PurchaselyEventMap | '';
}) => void;

const addListener = (callback: EventListenerCallback) => {
  return PurchaselyEventEmitter.addListener('Purchasely-Events', callback);
};

const removeListener = (callback: EventListenerCallback) => {
  return PurchaselyEventEmitter.removeListener('Purchasely-Events', callback);
};

const removeAllListeners = () => {
  return PurchaselyEventEmitter.removeAllListeners('Purchasely-Events');
};

const Purchasely = {
  ...RNPurchasely,
  addListener,
  removeListener,
  removeAllListeners,
};

export default Purchasely;
