/**
 * cross-platform bridge contract types.
 * See: the cross-platform bridge contract
 *
 * These types are exposed by the builder API
 * (`PLYPresentationBuilder`, `Purchasely.interceptAction`, `Purchasely.builder()`).
 *
 * The legacy v5 types in `types.ts` remain for backward compatibility.
 */

import { ProductResult } from './enums';
import type {
    PLYPresentationType,
    PLYWebCheckoutProvider,
} from './enums';
import type {
    PurchaselyPlan,
    PurchaselyOffer,
    PurchaselySubscriptionOffer,
    PLYPresentationPlan,
    PLYPresentationMetadata,
} from './types';

/**
 * Reason a PLYPresentation was dismissed.
 *
 * - `button` — the user tapped a close button inside the paywall.
 * - `backSystem` — system back: the Android back gesture/button, or the iOS
 *   interactive dismiss (swipe-down / nav pop), which both map here.
 * - `programmatic` — closed via `request.close()` / `Purchasely.close()`.
 *
 * Mirrors the native `PLYCloseReason` (`button` / `back_system` /
 * `programmatic`). Nullable in the outcome: when the native SDK does not report
 * a reason, `closeReason` is `null`.
 */
export type PLYCloseReason = 'button' | 'backSystem' | 'programmatic';

/** Outcome of `purchaseResult` in {@link PLYPresentationOutcome}. */
export type PLYPurchaseResult = 'purchased' | 'cancelled' | 'restored';

/** Error returned by the presentation lifecycle. */
export interface PLYPresentationError {
    code?: string | number | null;
    message: string;
    domain?: string | null;
}

/** Unit of a {@link PLYTransitionDimension}. */
export type PLYDimensionType = 'pixel' | 'percentage';

/**
 * A transition dimension (width / height), mirroring the native
 * `PLYTransitionDimension`. `value` is in pixels when `type` is `'pixel'`, or a
 * 0–1 fraction when `type` is `'percentage'`.
 */
export interface PLYTransitionDimension {
    type: PLYDimensionType;
    value: number;
}

/**
 * PLYPresentation transition mode.
 *
 * `inlinePaywall` is not supported by the legacy `PLYPresentationView` and is
 * exposed only for cross-platform parity.
 *
 * `width` / `height` mirror the native `PLYTransition` dimensions. The legacy
 * `heightPercentage` field was removed in v6 — use `height` with a
 * `{ type: 'percentage', value }` dimension instead.
 */
export interface PLYTransition {
    type:
        | 'fullScreen'
        | 'push'
        | 'modal'
        | 'drawer'
        | 'popin'
        | 'inlinePaywall';
    width?: PLYTransitionDimension | null;
    height?: PLYTransitionDimension | null;
    dismissible?: boolean | null;
    backgroundColors?: {
        light?: string | null;
        dark?: string | null;
    } | null;
}

/**
 * Outcome of a {@link PLYPresentation} display, resolved when the presentation is
 * dismissed. Mirrors the native `PLYPresentationOutcome`: five fields, mutually
 * exclusive between `error` and `closeReason`.
 */
export interface PLYPresentationOutcome {
    presentation?: PLYPresentation | null;
    purchaseResult?: PLYPurchaseResult | null;
    plan?: PurchaselyPlan | null;
    closeReason?: PLYCloseReason | null;
    error?: PLYPresentationError | null;
}

/**
 * Cross-platform PLYPresentation. The public identifier is `screenId`
 * (mapped from iOS `presentation.id`). `id` is kept as an alias for
 * compatibility but is deprecated.
 */
export interface PLYPresentation {
    /** Stable identifier of the screen. Maps to `presentation.id` on iOS. */
    screenId: string;
    /** @deprecated use {@link PLYPresentation.screenId}. Kept for compat. */
    id?: string;
    placementId?: string | null;
    contentId?: string | null;
    audienceId?: string | null;
    abTestId?: string | null;
    abTestVariantId?: string | null;
    campaignId?: string | null;
    flowId?: string | null;
    language?: string | null;
    type?: PLYPresentationType | null;
    plans?: PLYPresentationPlan[] | null;
    metadata?: PLYPresentationMetadata | null;
    height?: number | null;
}

/** Information surfaced when an interceptor is triggered. */
export interface PLYInterceptorInfo {
    contentId?: string | null;
    presentation?: PLYPresentation | null;
}

/** Result of running a custom interceptor block. */
export type PLYInterceptResult = 'success' | 'failed' | 'notHandled';

/** Known action kinds the interceptor can subscribe to. */
export type PLYPresentationActionKind =
    | 'close'
    | 'closeAll'
    | 'login'
    | 'navigate'
    | 'purchase'
    | 'restore'
    | 'openPresentation'
    | 'openPlacement'
    | 'promoCode'
    | 'webCheckout';

/** Typed payload for the navigate action. */
export interface PLYNavigatePayload {
    kind: 'navigate';
    url: string;
    title?: string | null;
}

/** Typed payload for the purchase action. */
export interface PLYPurchasePayload {
    kind: 'purchase';
    plan: PurchaselyPlan;
    subscriptionOffer?: PurchaselySubscriptionOffer | null;
    offer?: PurchaselyOffer | null;
}

/** Typed payload for close / closeAll actions. */
export interface PLYClosePayload {
    kind: 'close' | 'closeAll';
    closeReason: PLYCloseReason;
}

/** Typed payload for the openPresentation action. */
export interface PLYOpenPresentationPayload {
    kind: 'openPresentation';
    presentationId: string;
}

/** Typed payload for the openPlacement action. */
export interface PLYOpenPlacementPayload {
    kind: 'openPlacement';
    placementId: string;
}

/** Typed payload for the webCheckout action. */
export interface PLYWebCheckoutPayload {
    kind: 'webCheckout';
    url: string;
    clientReferenceId: string;
    queryParameterKey: string;
    webCheckoutProvider: PLYWebCheckoutProvider | string;
}

/** Union of every known interceptor payload. */
export type PLYActionPayload =
    | PLYNavigatePayload
    | PLYPurchasePayload
    | PLYClosePayload
    | PLYOpenPresentationPayload
    | PLYOpenPlacementPayload
    | PLYWebCheckoutPayload;

/** Handler signature for action interception. */
export type PLYActionInterceptorHandler = (
    info: PLYInterceptorInfo,
    payload: PLYActionPayload | null
) => Promise<PLYInterceptResult> | PLYInterceptResult;

/**
 * Internal helper — convert the legacy v5 `ProductResult` ordinal to the
 * string form for the {@link PLYPresentationOutcome.purchaseResult}.
 */
export function purchaseResultFromOrdinal(
    value: ProductResult | number | null | undefined
): PLYPurchaseResult | null {
    if (value === null || value === undefined) {
        return null;
    }
    switch (value) {
        case ProductResult.PRODUCT_RESULT_PURCHASED:
            return 'purchased';
        case ProductResult.PRODUCT_RESULT_RESTORED:
            return 'restored';
        case ProductResult.PRODUCT_RESULT_CANCELLED:
            return 'cancelled';
        default:
            return null;
    }
}
