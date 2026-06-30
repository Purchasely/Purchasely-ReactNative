import {
  type PlanType,
  PLYPresentationType,
  PLYUserAttributeSource,
  PLYUserAttributeType,
  SubscriptionSource,
  PLYWebCheckoutProvider,
  PLYDataProcessingLegalBasis
} from './enums';

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
  planVendorId: string;
  identifier: string;
  signature: string;
  nonce: any;
  keyIdentifier: string;
  timestamp: number;
};

export type PurchaselyUserAttribute = {
  key: string;
  value?: any | null;
  type?: PLYUserAttributeType | null;
  source?: PLYUserAttributeSource | null;
  legalBasis?: PLYDataProcessingLegalBasis;
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

export type PurchaselyEventsNames =
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

export type PurchaselyEventPropertyPlan = {
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

export type PurchaselyEventPropertyCarousel = {
  selected_slide?: number;
  number_of_slides?: number;
  is_carousel_auto_playing: boolean;
  default_slide?: number;
  previous_slide?: number;
};

export type PurchaselyEventPropertySubscription = {
  plan?: string;
  product?: string;
};

export type PurchaselyEvent = {
  name: PurchaselyEventsNames;
  properties: PurchaselyEventProperties;
};

export type PurchaselyEventProperties = {
  sdk_version: string;
  event_name: PurchaselyEventsNames;
  event_created_at_ms: number;
  event_created_at: string;
  displayed_presentation?: string;
  placement_id?: string;
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
  event_created_at_ms_original?: number;
  event_created_at_original?: string;
  is_fallback_presentation?: boolean;
  presentation_type?: string;
  audience_id?: string;
  ab_test_id?: string;
  ab_test_variant_id?: string;
  content_id?: string;
  campaign_id?: string;
  flow_id?: string;
  step_id?: string;
  flow_version?: string;
  flow_session_id?: string;
  from_action_id?: string;
  from_step_id?: string;
  display_mode?: string;
  display_method?: string;
  method_to_display?: string;
  orientation?: string;
  paywall_request_duration_in_ms?: number;
  paywall_display_time_in_ms?: number;
  paywall_rendering_time_in_ms?: number;
  promo_offer?: string;
  eligible_to_intro_offer?: boolean;
  eligible_to_intro_offer_sk2?: boolean;
  eligible_to_promo_offer?: boolean;
  eligible_to_promo_offer_sk2?: boolean;
  billing_plan_type?: string;
  commitment?: string;
  commitment_progress?: string;
  storekit_version?: string;
  selected_option_id?: string;
  selected_options?: string[];
  displayed_options?: string[];
  session_id?: string;
  session_duration?: number;
  session_count?: number;
  app_installed_at?: string;
  app_installed_at_ms?: number;
  screen_duration?: number;
  screen_displayed_at?: string;
  screen_displayed_at_ms?: number;
  is_sdk_started?: boolean;
  sdk_start_error?: string;
  sdk_start_duration_in_ms?: number;
  error_code?: string;
  web_checkout_provider?: PLYWebCheckoutProvider;
  web_checkout_url?: string;
  client_reference_id?: string;
  stripe_checkout_session_id?: string;
  stripe_purchase_id?: string;
};

export type PLYPresentationPlan = {
  planVendorId: string | null;
  storeProductId?: string | null;
  basePlanId?: string | null;
  offerId?: string | null;
  storeOfferId?: string | null;
  offerVendorId?: string | null;
  default?: boolean | null;
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
  height: number | null;
};
