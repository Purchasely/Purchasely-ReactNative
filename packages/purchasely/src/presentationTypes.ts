/**
 * cross-platform bridge contract types.
 * See: the cross-platform bridge contract
 *
 * These types are exposed by the builder API
 * (`PLYPresentationBuilder`, `Purchasely.interceptAction`, `Purchasely.builder()`).
 *
 * The legacy v5 types in `types.ts` remain for backward compatibility.
 */

import { PlanType, ProductResult } from './enums';
import type {
    PLYPresentationType,
    PLYWebCheckoutProvider,
} from './enums';
import type {
    PLYBillingPlanType,
    PLYPlan,
    PLYPromoOffer,
    PLYSubscriptionOffer,
    PLYPresentationPlan,
    PLYPresentationMetadata,
} from './types';

/**
 * Reason a PLYPresentation was dismissed.
 *
 * - `button` — the user tapped a close button inside the paywall.
 * - `backSystem` — system back: the Android back gesture/button, or the iOS
 *   interactive dismiss (swipe-down / nav pop), which both map here.
 * - `programmatic` — closed via `request.close()`.
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
    plan?: PLYPlan | null;
    closeReason?: PLYCloseReason | null;
    error?: PLYPresentationError | null;
}

/**
 * Cross-platform PLYPresentation. The public identifier is `screenId`
 * (mapped from iOS `presentation.screenId`). `id` is kept as an alias for
 * compatibility but is deprecated.
 */
export interface PLYPresentation {
    /** Stable identifier of the screen. Maps to `presentation.screenId` on iOS. */
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

/**
 * A {@link PLYPresentation} that has been preloaded and can drive its own
 * lifecycle. Returned by `PLYPresentationRequest.preload()`. In addition to the
 * data fields of {@link PLYPresentation}, it exposes {@link display},
 * {@link close} and {@link back}, which delegate to the originating
 * `PLYPresentationRequest`. Mirrors the Flutter SDK, where the object resolved
 * by `preload()` carries the presentation lifecycle methods.
 */
export interface PLYLoadedPresentation extends PLYPresentation {
    /**
     * Display this preloaded presentation. Resolves at dismiss with a
     * {@link PLYPresentationOutcome}. Optionally takes a {@link PLYTransition}.
     */
    display(transition?: PLYTransition | null): Promise<PLYPresentationOutcome>;
    /** Programmatically close the presentation if it is currently visible. */
    close(): void;
    /** Navigate back inside a multi-step (Flow) presentation. */
    back(): void;
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
    /**
     * Plan being purchased. On Apple (iOS 26.4+) with a multi-period commitment
     * this carries `plan.commitmentInfo` (see {@link PLYPlan}).
     */
    plan: PLYPlan;
    subscriptionOffer?: PLYSubscriptionOffer | null;
    offer?: PLYPromoOffer | null;
    /**
     * Billing plan the paywall resolved for this purchase. `'monthly'` means
     * the paywall intended Apple's monthly-billing commitment (iOS 26.4+).
     *
     * Returning `'notHandled'` from the interceptor lets the native SDK
     * complete the purchase and apply this billing plan itself. If you handle
     * the purchase yourself and return `'success'`, be aware that
     * `purchaseWithPlanVendorId` cannot carry the billing plan today, so the
     * purchase is made up-front rather than in monthly instalments.
     *
     * Always `'unspecified'` on Android. See {@link PLYBillingPlanType}.
     */
    billingPlanType?: PLYBillingPlanType;
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
 *
 * @internal Not part of the public API — importable from within the package
 * (e.g. `presentation.ts`) but intentionally excluded from the `index.ts`
 * barrel export (see the `export type *` re-export there).
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

/**
 * Android's DistributionType member names, shared 1:1 with iOS's native
 * PLYPlanType case names, mapped to the cross-platform {@link PlanType}
 * ordinal.
 *
 * @internal
 */
const PLAN_TYPE_NAME_MAP: Record<string, PlanType> = {
    CONSUMABLE: PlanType.PLAN_TYPE_CONSUMABLE,
    NON_CONSUMABLE: PlanType.PLAN_TYPE_NON_CONSUMABLE,
    RENEWING_SUBSCRIPTION: PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION,
    NON_RENEWING_SUBSCRIPTION: PlanType.PLAN_TYPE_NON_RENEWING_SUBSCRIPTION,
    UNKNOWN: PlanType.PLAN_TYPE_UNKNOWN,
};

/**
 * [rc.4 hardening] Normalize a `PLYPlan.type` value that may arrive as
 * either the numeric ordinal every platform emits today, or the Android
 * native SDK's upcoming DistributionType **string** name (e.g.
 * `"RENEWING_SUBSCRIPTION"`) — a planned rc.4 change on the Android side
 * only. Returns the value unchanged when it's already a number; maps a known
 * string name to its ordinal; returns `null` for anything unrecognized.
 *
 * @internal
 */
export function normalizePlanType(
    value: PlanType | string | null | undefined
): PlanType | null {
    if (value === null || value === undefined) {
        return null;
    }
    if (typeof value === 'number') {
        return value;
    }
    if (typeof value !== 'string') {
        return null;
    }
    return Object.hasOwn(PLAN_TYPE_NAME_MAP, value)
        ? PLAN_TYPE_NAME_MAP[value]!
        : null;
}

/**
 * [rc.4 hardening] Apply {@link normalizePlanType} to a raw native plan
 * payload's `type` field, leaving every other field untouched. Returns the
 * input unchanged when it isn't a plan-shaped object or has no `type`; an
 * unrecognized string is normalized to `PLAN_TYPE_UNKNOWN` so the public
 * `PLYPlan.type` contract remains numeric.
 *
 * @internal
 */
export function normalizePlan<T>(raw: T): T {
    if (!raw || typeof raw !== 'object' || !('type' in raw)) {
        return raw;
    }
    const type = (raw as { type: unknown }).type;
    const normalized = normalizePlanType(type as PlanType | string);
    if (normalized === null) {
        return typeof type === 'string'
            ? { ...raw, type: PlanType.PLAN_TYPE_UNKNOWN }
            : raw;
    }
    return { ...raw, type: normalized };
}
