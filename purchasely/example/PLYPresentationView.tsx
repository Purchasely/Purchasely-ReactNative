import React, {useEffect, useRef, useCallback} from 'react';
import {
  View,
  Platform,
  UIManager,
  findNodeHandle,
  requireNativeComponent,
  NativeModules,
} from 'react-native';
import {PresentPresentationResult} from 'react-native-purchasely';

export const PurchaselyView = requireNativeComponent('PurchaselyView');

interface PLYPresentationViewProps {
  placementId?: string; // Made optional
  presentation?: any; // Made optional
  onPresentationClosed: (result: PresentPresentationResult) => void;
}

const PLYPresentationView: React.FC<PLYPresentationViewProps> = ({
  placementId,
  presentation,
  onPresentationClosed,
  flex = 1,
}) => {
  const ref = useRef<any>(null);

  const handlePresentationClosed = useCallback(
    (result: PresentPresentationResult) => {
      if (onPresentationClosed) {
        onPresentationClosed(result);
      }
    },
    [onPresentationClosed],
  );

  NativeModules.PurchaselyView.onPresentationClosed().then(
    (result: PresentPresentationResult) => {
      console.log('### Paywall closed callback');
      handlePresentationClosed(result);
    },
  );

  if (Platform.OS === 'android') {
    const createFragment = (viewId: number) =>
      UIManager.dispatchViewManagerCommand(
        viewId,
        UIManager.PurchaselyView.Commands.create.toString(),
        [viewId],
      );

    useEffect(() => {
      const viewId = findNodeHandle(ref.current);
      if (viewId) {
        createFragment(viewId);
      }

      // Assuming you're setting up an event listener or similar for onPresentationClosed
      // Ensure the implementation here matches how your native module expects to handle this callback

      return () => {
        // Clean up any event listeners or other resources
      };
    }, []);
  }

  return (
    <PurchaselyView
      style={{flex}}
      placementId={placementId}
      presentation={presentation}
      {...(Platform.OS === 'android' && {ref: ref})}
    />
  );
};

export default PLYPresentationView;
