import React, {useEffect, useRef } from 'react';
import {
  findNodeHandle,
  NativeModules,
  Platform,
  requireNativeComponent,
  UIManager,
} from 'react-native';
import type { PresentPresentationResult } from '../';

const PurchaselyView = requireNativeComponent('PurchaselyView');

interface PLYPresentationViewProps {
  placementId?: string; // Made optional
  presentation?: any; // Made optional
  onPresentationClosed?: (result: PresentPresentationResult) => void;
  flex?: number;
}

export const PLYPresentationView: React.FC<PLYPresentationViewProps> = ({
  placementId,
  presentation,
  onPresentationClosed,
  flex = 1, // Default to 1 if not provided
}) => {
  const ref = useRef<any>(null);

  useEffect(() => {
    if (!onPresentationClosed) return;

    let cancelled = false;

    const handleClose = async () => {
      try {
        const result: PresentPresentationResult = await NativeModules.PurchaselyView.onPresentationClosed();
        if (!cancelled) {
          onPresentationClosed(result);
        }
      } catch (_) {
        // Ignore errors when the effect is cancelled (component unmounted or prop changed)
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
      {...(Platform.OS === 'android' && { ref: ref })}
    />
  );
};
