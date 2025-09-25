import { NativeModules } from 'react-native';
import type { Constants } from './interfaces';

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
  CLOSE_ALL = 'closeAll',
  LOGIN = 'login',
  NAVIGATE = 'navigate',
  PURCHASE = 'purchase',
  RESTORE = 'restore',
  OPEN_PRESENTATION = 'open_presentation',
  OPEN_PLACEMENT = 'open_placement',
  PROMO_CODE = 'promo_code',
  OPEN_FLOW_STEP = 'open_flow_step',
  WEB_CHECKOUT = 'web_checkout',
}

export enum PLYDataProcessingLegalBasis {
  ESSENTIAL = 'ESSENTIAL',
  OPTIONAL = 'OPTIONAL'
}

export enum PLYDataProcessingPurpose {
  ANALYTICS = 'analytics',
  IDENTIFIED_ANALYTICS = 'identified-analytics',
  CAMPAIGNS = 'campaigns',
  PERSONALIZATION = 'persnalization',
  THIRD_PARTY_INTEGRATION = 'third-party-integration'
}

export enum PLYPresentationType {
  NORMAL = constants.presentationTypeNormal,
  FALLBACK = constants.presentationTypeFallback,
  DEACTIVATED = constants.presentationTypeDeactivated,
  CLIENT = constants.presentationTypeClient,
}

export enum PLYUserAttributeSource {
  PURCHASELY = constants.userAttributeSourcePurchasely,
  CLIENT = constants.userAttributeSourceClient,
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

export enum PLYWebCheckoutProvider {
  STRIPE = 'stripe',
  OTHER = 'other'
}
