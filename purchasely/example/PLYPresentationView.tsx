import React, { useEffect, useRef } from 'react';
import { View, Platform, UIManager, findNodeHandle, requireNativeComponent } from 'react-native';

export const PurchaselyView = requireNativeComponent('PurchaselyView');

const PLYPresentationView: React.FC<PLYPresentationViewProps> = ({ placementId, presentation }) => {
  const ref = useRef<any>(null);

  if (Platform.OS === 'android') {
    const createFragment = (viewId: number) =>
      UIManager.dispatchViewManagerCommand(
        viewId,
        // we are calling the 'create' command
        UIManager.PurchaselyView.Commands.create.toString(),
        [viewId],
      );

    useEffect(() => {
      const viewId = findNodeHandle(ref.current);
      createFragment(viewId);
    }, []);
  }

  return (
    <View style={{ flex: 1 }}>
      <PurchaselyView
        style={{ flex: 1 }}
        placementId={placementId}
        presentation={presentation}
        {...(Platform.OS === 'android' && { ref: ref })}
      />
    </View>
  );
};

interface PLYPresentationViewProps {
  placementId: string | null;
  presentation: any | null;
}

export default PLYPresentationView;