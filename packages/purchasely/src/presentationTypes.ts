/**
 * cross-platform bridge contract types.
 * See: the cross-platform bridge contract
 *
 * These types are exposed by the builder API
 * (`PresentationBuilder`, `Purchasely.interceptAction`, `Purchasely.builder()`).
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
 * Reason a Presentation was dismissed.
 * Always `null` on iOS until native exposes the value (see contract P0.2).
 */
export type CloseReason = 'button' | 'backSystem' | 'programmatic';

/** Outcome of `purchaseResult` in {@link PresentationOutcome}. */
export type PurchaseResultKind = 'purchased' | 'cancelled' | 'restored';

/** Error returned by the presentation lifecycle. */
export interface PresentationError {
    code?: string | number | null;
    message: string;
    domain?: string | null;
}

/**
 * Presentation transition mode.
 *
 * `inlinePaywall` is not supported by the legacy `PLYPresentationView` and is
 * exposed only for cross-platform parity.
 */
export interface Transition {
    type:
        | 'fullScreen'
        | 'push'
        | 'modal'
        | 'drawer'
        | 'popin'
        | 'inlinePaywall';
    heightPercentage?: number | null;
    dismissible?: boolean | null;
    backgroundColors?: {
        light?: string | null;
        dark?: string | null;
    } | null;
}

/**
 * Outcome of a {@link Presentation} display, resolved when the presentation is
 * dismissed (Android-style). Five fields, mutually exclusive between
 * `error` and `closeReason`.
 */
export interface PresentationOutcome {
    presentation?: Presentation | null;
    purchaseResult?: PurchaseResultKind | null;
    plan?: PurchaselyPlan | null;
    closeReason?: CloseReason | null;
    error?: PresentationError | null;
}

/**
 * Cross-platform Presentation. The public identifier is `screenId`
 * (mapped from iOS `presentation.id`). `id` is kept as an alias for
 * compatibility but is deprecated.
 */
export interface Presentation {
    /** Stable identifier of the screen. Maps to `presentation.id` on iOS. */
    screenId: string;
    /** @deprecated use {@link Presentation.screenId}. Kept for compat. */
    id?: string;
    placementId?: string | null;
    contentId?: string | null;
    audienceId?: string | null;
    abTestId?: string | null;
    abTestVariantId?: string | null;
    language?: string | null;
    type?: PLYPresentationType | null;
    plans?: PLYPresentationPlan[] | null;
    metadata?: PLYPresentationMetadata | null;
    height?: number | null;
}

/** Information surfaced when an interceptor is triggered. */
export interface InterceptorInfo {
    contentId?: string | null;
    presentation?: Presentation | null;
}

/** Result of running a custom interceptor block. */
export type InterceptResult = 'success' | 'failed' | 'notHandled';

/** Known action kinds the interceptor can subscribe to. */
export type PresentationActionKind =
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
export interface NavigatePayload {
    kind: 'navigate';
    url: string;
    title?: string | null;
}

/** Typed payload for the purchase action. */
export interface PurchasePayload {
    kind: 'purchase';
    plan: PurchaselyPlan;
    subscriptionOffer?: PurchaselySubscriptionOffer | null;
    offer?: PurchaselyOffer | null;
}

/** Typed payload for close / closeAll actions. */
export interface ClosePayload {
    kind: 'close' | 'closeAll';
    closeReason: CloseReason;
}

/** Typed payload for the openPresentation action. */
export interface OpenPresentationPayload {
    kind: 'openPresentation';
    presentationId: string;
}

/** Typed payload for the openPlacement action. */
export interface OpenPlacementPayload {
    kind: 'openPlacement';
    placementId: string;
}

/** Typed payload for the webCheckout action. */
export interface WebCheckoutPayload {
    kind: 'webCheckout';
    url: string;
    clientReferenceId: string;
    queryParameterKey: string;
    webCheckoutProvider: PLYWebCheckoutProvider | string;
}

/** Union of every known interceptor payload. */
export type ActionPayload =
    | NavigatePayload
    | PurchasePayload
    | ClosePayload
    | OpenPresentationPayload
    | OpenPlacementPayload
    | WebCheckoutPayload;

/** Handler signature for action interception. */
export type InterceptorHandler = (
    info: InterceptorInfo,
    payload: ActionPayload | null
) => Promise<InterceptResult> | InterceptResult;

/**
 * Internal helper — convert the legacy v5 `ProductResult` ordinal to the
 * string form for the {@link PresentationOutcome.purchaseResult}.
 */
export function purchaseResultFromOrdinal(
    value: ProductResult | number | null | undefined
): PurchaseResultKind | null {
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
