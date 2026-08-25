import 'react-native-gesture-handler';

import { StatusBar } from 'expo-status-bar';
import { useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Linking,
  SafeAreaView,
  StatusBar as RNStatusBar,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { TrueSheet } from '@lodev09/react-native-true-sheet';
import Purchasely, {
  PLYPresentationBuilder,
  PLYPresentationView,
  type PLYInterceptResult,
  type PLYPresentationOutcome,
} from 'react-native-purchasely';

const API_KEY = 'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d';
const PLACEMENT_ID = 'onboarding';
/** Height of the container that hosts the embedded paywall. */
const BANNER_HEIGHT = 140;

export default function App() {
  const [isConfigured, setIsConfigured] = useState(false);
  const [status, setStatus] = useState('Starting the Purchasely SDK…');
  const sheet = useRef<TrueSheet>(null);

  useEffect(() => {
    let subscription: { remove: () => void } | undefined;

    const start = async () => {
      try {
        const configured = await Purchasely.builder(API_KEY)
          .runningMode('full')
          .logLevel('debug')
          .allowDeeplink(true)
          .allowCampaigns(true)
          .storekitVersion('storeKit2')
          .stores(['google'])
          .start();

        setIsConfigured(configured);
        setStatus(configured ? 'SDK started.' : 'SDK start failed.');
        if (!configured) return;

        registerInterceptors();
        await registerDeeplinks();
      } catch (error) {
        setStatus(`SDK start error: ${String(error)}`);
      }
    };

    // Action interceptors — the host app decides what each paywall action does.
    const registerInterceptors = () => {
      Purchasely.interceptAction('login', async (): Promise<PLYInterceptResult> => {
        // Show your own login screen here, then return 'success'.
        return 'notHandled';
      });
      Purchasely.interceptAction('purchase', async (): Promise<PLYInterceptResult> => {
        // Run your own transaction here, then return 'success' or 'failed'.
        return 'notHandled';
      });
      Purchasely.interceptAction('navigate', async (_info, payload): Promise<PLYInterceptResult> => {
        console.log('navigate action', payload);
        return 'notHandled';
      });
    };

    // Deeplinks — cold start plus every link received while the app runs.
    const registerDeeplinks = async () => {
      const initial = await Linking.getInitialURL();
      if (initial) await Purchasely.handleDeeplink(initial);
      subscription = Linking.addEventListener('url', ({ url }) => {
        Purchasely.handleDeeplink(url);
      });
    };

    start();
    return () => {
      subscription?.remove();
      Purchasely.removeAllActionInterceptors();
    };
  }, []);

  const displayPaywall = async () => {
    const request = PLYPresentationBuilder.placement(PLACEMENT_ID)
      .onDismissed((outcome: PLYPresentationOutcome) => console.log('dismissed', outcome))
      .build();
    const outcome = await request.display();
    console.log('paywall outcome', outcome);
  };

  return (
    <GestureHandlerRootView style={styles.root}>
      <SafeAreaView style={styles.root}>
        <StatusBar style="auto" />
        <Text style={styles.title}>Purchasely Expo test</Text>
        <Text style={styles.status}>{status}</Text>

        {!isConfigured ? (
          <ActivityIndicator style={styles.spinner} />
        ) : (
          <>
            <TouchableOpacity style={styles.button} onPress={displayPaywall}>
              <Text style={styles.buttonText}>Display the paywall</Text>
            </TouchableOpacity>

            <TouchableOpacity style={styles.button} onPress={() => sheet.current?.present()}>
              <Text style={styles.buttonText}>Open a true-sheet</Text>
            </TouchableOpacity>

            {/* Embedded paywall in a fixed-height container. The native view must
                fill the container on Android and on iOS. */}
            <View style={styles.banner}>
              <PLYPresentationView
                flex={1}
                placementId={PLACEMENT_ID}
                onPresentationClosed={(outcome) => console.log('banner closed', outcome)}
              />
            </View>
          </>
        )}

        <TrueSheet ref={sheet} detents={['auto']}>
          <View style={styles.sheet}>
            <Text>A third-party native module renders here.</Text>
          </View>
        </TrueSheet>
      </SafeAreaView>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fff', paddingTop: RNStatusBar.currentHeight ?? 0 },
  title: { fontSize: 22, fontWeight: '600', margin: 16 },
  status: { marginHorizontal: 16, marginBottom: 16, color: '#555' },
  spinner: { marginTop: 24 },
  button: {
    backgroundColor: '#1b1b1b',
    borderRadius: 8,
    marginHorizontal: 16,
    marginBottom: 12,
    padding: 14,
  },
  buttonText: { color: '#fff', textAlign: 'center' },
  banner: { backgroundColor: '#f2f2f2', height: BANNER_HEIGHT, marginHorizontal: 16 },
  sheet: { padding: 24 },
});
