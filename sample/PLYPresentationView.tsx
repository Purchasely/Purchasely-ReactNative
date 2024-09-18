import {useEffect, useRef, useCallback} from 'react';
import {Platform, UIManager, findNodeHandle, NativeModules, requireNativeComponent} from 'react-native';

import {
  type PresentPresentationResult,
  //PurchaselyView,
} from 'react-native-purchasely';

export const PurchaselyView = requireNativeComponent('PurchaselyView');
  // Hold the ref for the native view
const ref = useRef(null);

//import {PurchaselyView} from './PurchaselyViewManager';

interface PLYPresentationViewProps {
  placementId?: string; // Made optional
  presentation?: any; // Made optional
  onPresentationClosed: (result: PresentPresentationResult) => void;
  flex?: number;
}

const PLYPresentationView: React.FC<PLYPresentationViewProps> = ({
  placementId,
  presentation,
  onPresentationClosed,
  flex = 1,
}) => {

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
      handlePresentationClosed(result);
    },
  );

  if (Platform.OS === 'android') {
    const createFragment = (viewId: number) =>
      UIManager.dispatchViewManagerCommand(
        viewId,
        // @ts-ignore
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
      // @ts-ignore
      style={{flex}}
      placementId={placementId}
      presentation={presentation}
      ref={ref} // Attach the ref to PurchaselyView
      {...(Platform.OS === 'android' && {ref: ref})}
    />
  );
};

export { PLYPresentationView };
