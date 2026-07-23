import React, { useEffect, useRef } from 'react';
import {
  findNodeHandle,
  Platform,
  requireNativeComponent,
  UIManager,
} from 'react-native';

import type { PLYPresentationRequest } from '../presentation';
import type {
  PLYPresentation,
  PLYPresentationOutcome,
} from '../presentationTypes';
import { normalizePlan, purchaseResultFromOrdinal } from '../presentationTypes';
import { PURCHASELY_PRESENTATION_EVENTS, presentationEventEmitter } from '../events';
import type { PLYPresentationLifecycleEvent } from '../events';

const PurchaselyView = requireNativeComponent('PurchaselyView');

/** Counter for generating a routing id for views that have no preloaded
 * `request` (the `presentation` prop and fresh `placementId` paths have no
 * bridge `requestId` of their own). */
let nextViewId = 0;
const generateViewId = (): string => {
  nextViewId += 1;
  return `ply_view_${Date.now()}_${nextViewId}`;
};

/** Normalize the raw `presentation` field of a native lifecycle event to the
 * {@link PLYPresentation} shape (mirrors `presentation.ts#normalizePresentation`,
 * duplicated here rather than imported — that helper isn't exported). */
function normalizeEventPresentation(raw: any): PLYPresentation | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const screenId = raw.screenId ?? raw.id;
  if (!screenId) {
    return null;
  }
  return {
    screenId,
    id: screenId,
    placementId: raw.placementId ?? null,
    contentId: raw.contentId ?? null,
    audienceId: raw.audienceId ?? null,
    abTestId: raw.abTestId ?? null,
    abTestVariantId: raw.abTestVariantId ?? null,
    campaignId: raw.campaignId ?? null,
    flowId: raw.flowId ?? null,
    language: raw.language ?? null,
    type: raw.type ?? null,
    plans: raw.plans ?? null,
    metadata: raw.metadata ?? null,
    height: raw.height ?? null,
  };
}

/** Convert a native `PURCHASELY_PRESENTATION_DISMISSED` event into the
 * 5-field {@link PLYPresentationOutcome}, identical to the full-screen
 * `request.display()` contract. */
function eventToOutcome(
  event: PLYPresentationLifecycleEvent
): PLYPresentationOutcome {
  const rawError = event.error;
  const error = rawError
    ? {
          code: rawError.code ?? null,
          message: rawError.message ?? 'Unknown error',
          domain: rawError.domain ?? null,
      }
    : null;
  return {
    presentation: normalizeEventPresentation(event.presentation),
    purchaseResult: purchaseResultFromOrdinal(event.purchaseResult),
    plan: normalizePlan(event.plan) ?? null,
    // Exclusion rule (cf. contract): error != null ⇒ closeReason == null.
    closeReason: error ? null : event.closeReason ?? null,
    error,
  };
}

interface PLYPresentationViewProps {
  placementId?: string; // Made optional
  presentation?: any; // Made optional
  /**
   * A presentation request that was already preloaded via `request.preload()`.
   * The native view resolves the loaded presentation by the request's
   * `requestId` (no second preload) — mirrors the full-screen builder flow and
   * the native iOS/Android/Flutter SDKs. Preload before rendering; otherwise
   * `requestId` is null and the view falls back to `placementId` /
   * `presentation`.
   */
  request?: PLYPresentationRequest;
  /**
   * Called once when the embedded presentation is dismissed, with the same
   * 5-field {@link PLYPresentationOutcome} the full-screen `request.display()`
   * promise resolves with.
   */
  onPresentationClosed?: (outcome: PLYPresentationOutcome) => void;
  flex?: number;
}

export const PLYPresentationView: React.FC<PLYPresentationViewProps> = ({
  placementId,
  presentation,
  request,
  onPresentationClosed,
  flex = 1, // Default to 1 if not provided
}) => {
  const ref = useRef<any>(null);

  // Stable per-mount id used to route the dismiss event when there is no
  // preloaded `request` — lazily generated once, not on every render.
  const fallbackViewIdRef = useRef<string | null>(null);
  if (fallbackViewIdRef.current === null) {
    fallbackViewIdRef.current = generateViewId();
  }
  const fallbackViewId = fallbackViewIdRef.current;

  // The id this instance listens for on `PURCHASELY_PRESENTATION_DISMISSED`:
  // the bridge `requestId` once the `request` prop has been preloaded,
  // otherwise the generated fallback (routed by the native `viewId` prop).
  const routingId = request?.requestId ?? fallbackViewId;

  useEffect(() => {
    if (!onPresentationClosed) return;

    const subscription = presentationEventEmitter.addListener(
      PURCHASELY_PRESENTATION_EVENTS.DISMISSED,
      (event: PLYPresentationLifecycleEvent) => {
        if (event.requestId !== routingId) {
          return;
        }
        onPresentationClosed(eventToOutcome(event));
      }
    );

    return () => {
      subscription.remove();
    };
  }, [onPresentationClosed, routingId]);

  useEffect(() => {
    if (Platform.OS === 'android') {
      const createFragment = (viewId: number) =>
        UIManager.dispatchViewManagerCommand(
          viewId,
          // @ts-ignore
          UIManager.PurchaselyView.Commands.create.toString(),
          [viewId]
        );

       const viewId = findNodeHandle(ref.current);
       if (viewId) {
         createFragment(viewId);
       }
     }
   }, []);

  return (
    <PurchaselyView
      // @ts-ignore
      style={{ flex }}
      placementId={placementId}
      presentation={presentation}
      requestId={request?.requestId ?? undefined}
      viewId={fallbackViewId}
      {...(Platform.OS === 'android' && { ref: ref })}
    />
  );
};
