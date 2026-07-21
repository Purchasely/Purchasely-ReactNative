import type { PLYDataProcessingLegalBasis } from './enums';
import type { PLYBillingPlanType } from './types';

export interface Constants {
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
  oneSignalExternalId: number;
  oneSignalUserId: number;
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
  runningModeObserver: number;
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

export interface StartParameters {
  apiKey: string;
  androidStores?: string[] | null;
  storeKit1: boolean;
  userId?: string | null;
  logLevel: number;
  runningMode: number;
}

export interface PurchasePlanParameters {
  planVendorId: string;
  offerId?: string | null;
  contentId?: string | null;
}

export interface SignPromotionalOfferParameters {
  storeProductId: string;
  storeOfferId: string;
}

export interface UserAttributesParameters {
  key: string;
  value?: number | null;
  legalBasis?: PLYDataProcessingLegalBasis
}

export interface PLYDynamicOffering {
  reference: string;
  planVendorId: string;
  offerVendorId?: string | null;
  /**
   * Billing plan type to force for this offering. Apple-only (iOS 26.4+);
   * ignored on Android. Defaults to `'unspecified'` (native picks the default).
   */
  billingPlanType?: PLYBillingPlanType | null;
}
