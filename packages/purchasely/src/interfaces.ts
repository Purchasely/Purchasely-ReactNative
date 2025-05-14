import type { PurchaselyPresentation } from './types';

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

export interface StartParameters {
  apiKey: string;
  androidStores?: string[] | null;
  storeKit1: boolean;
  userId?: string | null;
  logLevel: number;
  runningMode: number;
}

export interface FetchPresentationParameters {
  placementId?: string | null;
  presentationId?: string | null;
  contentId?: string | null;
}

export interface PresentPresentationParameters {
  presentation?: PurchaselyPresentation | null;
  isFullscreen?: boolean;
  loadingBackgroundColor?: string | null;
}

export interface PresentPresentationWithIdentifierParameters {
  presentationVendorId?: string | null;
  contentId?: string | null;
  isFullscreen?: boolean;
  loadingBackgroundColor?: string | null;
}

export interface PresentPresentationPlacementParameters {
  placementVendorId?: string | null;
  contentId?: string | null;
  isFullscreen?: boolean;
  loadingBackgroundColor?: string | null;
}

export interface PresentProductParameters {
  productVendorId?: string | null;
  presentationVendorId?: string | null;
  contentId?: string | null;
  isFullscreen?: boolean;
  loadingBackgroundColor?: string | null;
}

export interface PresentPlanParameters {
  planVendorId?: string | null;
  presentationVendorId?: string | null;
  contentId?: string | null;
  isFullscreen?: boolean;
  loadingBackgroundColor?: string | null;
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
}
