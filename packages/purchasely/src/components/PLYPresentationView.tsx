import React, {useEffect, useRef } from 'react';
import {
  findNodeHandle,
  NativeModules,
  Platform,
  requireNativeComponent,
  UIManager,
} from 'react-native';

import type { PLYPresentationRequest } from '../presentation';
import type { ProductResult } from '../enums';
import type { PurchaselyPlan } from '../types';

const PurchaselyView = requireNativeComponent('PurchaselyView');

/**
 * Result delivered to {@link PLYPresentationViewProps.onPresentationClosed}
 * when the embedded paywall is dismissed. Mirrors what the native iOS/Android
 * embedded views emit: the {@link ProductResult} of the purchase flow and the
 * purchased/restored plan (or `null` when the user simply closed the paywall).
 */
export interface PLYPresentationViewResult {
  result: ProductResult;
  plan: PurchaselyPlan | null;
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
  onPresentationClosed?: (result: PLYPresentationViewResult) => void;
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

  useEffect(() => {
    if (!onPresentationClosed) return;

    let cancelled = false;

    const handleClose = async () => {
      try {
        const result = await NativeModules.PurchaselyView.onPresentationClosed();
        if (!cancelled) {
          onPresentationClosed(result);
        }
      } catch (e) {
        // Only log unexpected errors — ignore if the effect was cancelled
        if (!cancelled) {
          console.warn('[PLYPresentationView] onPresentationClosed error:', e)
        }
      }
    };

    handleClose();

    return () => {
      cancelled = true;
    };
  }, [onPresentationClosed]);

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
       console.log('### viewId', viewId);
       if (viewId) {
         console.log('### creating Fragment');
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
      {...(Platform.OS === 'android' && { ref: ref })}
    />
  );
};
