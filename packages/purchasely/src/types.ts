import {
  type PlanType,
  PLYUserAttributeSource,
  PLYUserAttributeType,
  SubscriptionSource,
  PLYWebCheckoutProvider,
  PLYDataProcessingLegalBasis
} from './enums';

/**
 * Billing plan of a commitment installment. Apple-only (iOS 26.4+).
 * Mirrors the native `PLYBillingPlanType` façade.
 */
export type PLYBillingPlanType = 'unspecified' | 'upFront' | 'monthly';

/**
 * Billing information for a subscription with a multi-period commitment
 * (Apple-only, iOS 26.4+ "monthly subscription with 12-month commitment").
 * Mirrors the native `PLYCommitmentInfo`. Empty/absent on Android and on Apple
 * plans without a commitment.
 */
export type PLYCommitmentInfo = {
  billingPlanType: PLYBillingPlanType;
  /** Per-billing-cycle price (e.g. 9.99 for a monthly billed plan). */
  billingPrice: number;
  /** ISO 8601 duration of each billing cycle, e.g. 'P1M'. */
  billingPeriod: string;
  /** Total price over the full commitment period (e.g. 119.88 for 12 x 9.99). */
  totalPrice: number;
  /** ISO 8601 duration of the full commitment, e.g. 'P1Y'. */
  totalPeriod: string;
  /** Number of billing cycles in the commitment (1 for upFront, 12 for 12-month monthly). */
  totalDuration: number;
};

/**
 * A subscriber's progress through a multi-period commitment (Apple-only,
 * iOS 26.4+). Mirrors the native `PLYCommitmentProgress`. `null`/absent on
 * Android and on subscriptions without a commitment.
 */
export type PLYCommitmentProgress = {
  /** Current billing period number within the commitment (1-based). */
  billingPeriodNumber: number;
  /** Total number of billing periods in the commitment. */
  totalBillingPeriods: number;
  /** Date when the commitment expires, ISO 8601. */
  commitmentExpiresDate: string;
  /** Price charged for this billing period. */
  commitmentPrice: number;
};

export type PLYPlan = {
  vendorId: string;
  productId: string;
  /** Google Play base plan id. `null` on the App Store (no base-plan concept). */
  basePlanId?: string | null;
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
  /** Whether the plan carries a promotional offer price. */
  hasOfferPrice: boolean;
  /** Localized promotional offer price (empty when {@link hasOfferPrice} is false). */
  offerPrice: string;
  /** Raw promotional offer amount. */
  offerAmount: number;
  /** Promotional offer duration (ISO-8601, e.g. `P1M`). */
  offerDuration: string;
  /** Promotional offer period (ISO-8601). */
  offerPeriod: string;
  /**
   * Commitment installment details (Apple-only, iOS 26.4+). Absent on Android
   * and on plans without a multi-period commitment.
   */
  commitmentInfo?: PLYCommitmentInfo[];
};

export type PLYPromoOffer = {
  vendorId?: string | null;
  storeOfferId?: string | null;
  publicId?: string | null;
};

export type PLYSubscriptionOffer = {
  subscriptionId: string;
  basePlanId?: string | null;
  offerToken?: string | null;
  offerId?: string | null;
};

export type PLYProduct = {
  name: string;
  vendorId: string;
  plans: PLYPlan[];
};

export type PLYPromotionalOfferSignature = {
  planVendorId: string;
  identifier: string;
  signature: string;
  nonce: any;
  keyIdentifier: string;
  timestamp: number;
};

export type PLYUserAttribute = {
  key: string;
  value?: any | null;
  type?: PLYUserAttributeType | null;
  source?: PLYUserAttributeSource | null;
  legalBasis?: PLYDataProcessingLegalBasis;
};

export type PLYSubscription = {
  purchaseToken: string;
  subscriptionSource: SubscriptionSource;
  nextRenewalDate: string;
  cancelledDate: string;
  plan: PLYPlan;
  product: PLYProduct;
  /**
   * [PAR-24] Android-only. The native `PLYSubscription.toMap()` (Android)
   * includes total revenue attributed to this subscription, in USD; the iOS
   * bridge's `PLYSubscription+Hybrid.m asDictionary` never emits it. Optional
   * so iOS callers see `undefined` instead of a silently-missing required
   * field.
   */
  cumulatedRevenuesInUSD?: number;
  /** Android-only — see {@link cumulatedRevenuesInUSD}. */
  subscriptionDurationInDays?: number;
  /** Android-only — see {@link cumulatedRevenuesInUSD}. */
  subscriptionDurationInWeeks?: number;
  /** Android-only — see {@link cumulatedRevenuesInUSD}. */
  subscriptionDurationInMonths?: number;
  /**
   * Progress through a multi-period commitment (Apple-only, iOS 26.4+).
   * `null`/absent on Android and on subscriptions without a commitment.
   */
  commitmentProgress?: PLYCommitmentProgress | null;
};

export type PLYEventName =
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
  | 'SUBSCRIPTION_CONTENT_USED'
  | 'IN_APP_RENEWED'
  | 'PLACEMENT_OPENED'
  | 'PURCHASE_FROM_STORE_TAPPED'
  | 'STORE_PRODUCT_FETCH_FAILED'
  | 'WEB_CHECKOUT_OPENED_IN_WEB_BROWSER'
  | 'WEB_CHECKOUT_ERROR'
  | 'WEB_CHECKOUT_TAPPED'
  | 'WEB_CHECKOUT_TIMED_OUT';

export type PLYEventPropertyPlan = {
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

export type PLYEventPropertyCarousel = {
  selected_slide?: number;
  number_of_slides?: number;
  is_carousel_auto_playing: boolean;
  default_slide?: number;
  previous_slide?: number;
};

export type PLYEventPropertySubscription = {
  plan?: string;
  product?: string;
};

export type PLYEvent = {
  name: PLYEventName;
  properties: PLYEventProperties;
};

export type PLYEventProperties = {
  sdk_version: string;
  event_name: PLYEventName;
  event_created_at_ms: number;
  event_created_at: string;
  displayed_presentation?: string;
  placement_id?: string;
  user_id?: string;
  anonymous_user_id?: string;
  purchasable_plans?: PLYEventPropertyPlan[];
  deeplink_identifier?: string;
  source_identifier?: string;
  selected_plan?: string;
  previous_selected_plan?: string;
  selected_presentation?: string;
  previous_selected_presentation?: string;
  link_identifier?: string;
  carousels?: PLYEventPropertyCarousel[];
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
  running_subscriptions?: PLYEventPropertySubscription[];
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

/**
 * A plan attached to a `PLYPresentation` (`presentation.plans[]`).
 *
 * [RN-W-06] Field availability is **not symmetric** across platforms — it
 * mirrors real differences between the native plan models (Apple vs. Google
 * Play offer concepts aren't identical), not a bridge bug:
 * - `basePlanId` / `storeOfferId` — **Android-only**. The native iOS
 *   `PLYPresentationPlan` has no equivalent properties, so both are always
 *   `undefined` on iOS.
 * - `offerId` — present on **both** platforms, but from different identifier
 *   spaces. On iOS it holds Apple's own distinct promotional-offer
 *   identifier. On Android there is no separate native `offerId`, so the
 *   bridge duplicates `storeOfferId`'s value under this key.
 * - `planVendorId`, `storeProductId`, `offerVendorId`, `default` — genuinely
 *   cross-platform; both native models expose all four.
 */
export type PLYPresentationPlan = {
  planVendorId: string | null;
  storeProductId?: string | null;
  /** Android-only. Always `undefined` on iOS. */
  basePlanId?: string | null;
  /** Cross-platform, but see the type-level doc — not the same id space on both platforms. */
  offerId?: string | null;
  /** Android-only. Always `undefined` on iOS. */
  storeOfferId?: string | null;
  offerVendorId?: string | null;
  default?: boolean | null;
};

export type PLYPresentationMetadata = {
  [key: string]: string | number | boolean;
};
