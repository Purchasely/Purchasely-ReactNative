import React, { useEffect, useRef } from 'react';
import {
    findNodeHandle,
    NativeModules,
    Platform,
    requireNativeComponent,
    UIManager,
    type ViewProps,
} from 'react-native';
import type { PresentPresentationResult } from '../';

const PurchaselyNativeView = requireNativeComponent<
    ViewProps & { placementId?: string; presentation?: unknown }
>('PurchaselyView');

// Commands interface for type safety
// Must match COMMAND_CREATE in PurchaselyViewManager.kt
const Commands = {
    create: 1,
};

interface PLYPresentationViewProps {
    placementId?: string;
    presentation?: unknown;
    onPresentationClosed?: (result: PresentPresentationResult) => void;
    flex?: number;
}

export const PLYPresentationView: React.FC<PLYPresentationViewProps> = ({
    placementId,
    presentation,
    onPresentationClosed,
    flex = 1,
}) => {
    const ref = useRef<React.ElementRef<typeof PurchaselyNativeView>>(null);

    useEffect(() => {
        if (!onPresentationClosed) return;

        let cancelled = false;

        const handleClose = async () => {
            try {
                const result: PresentPresentationResult = await NativeModules.PurchaselyView.onPresentationClosed();
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
>>>>>>> 4c5c03e (chore: migrate to React Native 0.83)

    useEffect(() => {
        if (Platform.OS === 'android') {
            const viewId = findNodeHandle(ref.current);
            if (viewId) {
                // Use numeric command ID directly for New Architecture compatibility
                // This pattern works with both Legacy and New Architecture via interop
                UIManager.dispatchViewManagerCommand(
                    viewId,
                    Commands.create,
                    [viewId]
                );
            }
        }
    }, []);

    return (
        <PurchaselyNativeView
            style={{ flex }}
            placementId={placementId}
            presentation={presentation}
            ref={Platform.OS === 'android' ? ref : undefined}
        />
    );
};
