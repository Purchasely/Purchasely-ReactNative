import React, { useEffect, useState } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  ActivityIndicator,
  SafeAreaView,
  StatusBar,
  Alert,
  ScrollView,
} from 'react-native';
import Purchasely, {
  LogLevels,
  RunningMode,
  PLYPresentationType,
  ProductResult,
  PurchaselyPresentation,
} from 'react-native-purchasely';

function App(): React.JSX.Element {
  const [isConfigured, setIsConfigured] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [presentation, setPresentation] = useState<PurchaselyPresentation | null>(null);
  const [statusMessage, setStatusMessage] = useState('Initializing Purchasely SDK...');

  useEffect(() => {
    initializePurchasely();
  }, []);

  const initializePurchasely = async () => {
    try {
      setStatusMessage('Starting Purchasely SDK...');

      // Initialize the SDK with start method
      const configured = await Purchasely.start({
        apiKey: 'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d', // Demo API key
        storeKit1: false, // Use StoreKit 2 on iOS
        logLevel: LogLevels.DEBUG,
        runningMode: RunningMode.FULL,
        androidStores: ['Google'],
      });

      if (configured) {
        setIsConfigured(true);
        setStatusMessage('SDK initialized successfully!');
        console.log('Purchasely SDK initialized successfully');

        // Set language
        Purchasely.setLanguage('en');

        // Ready to open deeplinks
        Purchasely.readyToOpenDeeplink(true);

        // Fetch presentation after SDK is configured
        await fetchPresentationData();
      } else {
        setStatusMessage('SDK initialization failed');
        console.error('Purchasely SDK initialization failed');
      }
    } catch (error) {
      setStatusMessage(`SDK Error: ${error}`);
      console.error('Purchasely SDK initialization error:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const fetchPresentationData = async () => {
    try {
      setStatusMessage('Fetching presentation...');

      // Fetch presentation using fetchPresentation method
      const fetchedPresentation = await Purchasely.fetchPresentation({
        placementId: 'ONBOARDING', // Use a placement ID from your Purchasely console
        contentId: null,
      });

      setPresentation(fetchedPresentation);
      setStatusMessage('Presentation fetched successfully!');
      console.log('Presentation fetched:', fetchedPresentation);
    } catch (error) {
      setStatusMessage(`Fetch error: ${error}`);
      console.error('Error fetching presentation:', error);
    }
  };

  const showPresentation = async () => {
    if (!presentation) {
      Alert.alert('Error', 'No presentation available. Please fetch first.');
      return;
    }

    try {
      // Check presentation type
      if (presentation.type === PLYPresentationType.DEACTIVATED) {
        Alert.alert('Info', 'This presentation is deactivated');
        return;
      }

      if (presentation.type === PLYPresentationType.CLIENT) {
        Alert.alert('Info', 'This is a client-side presentation');
        return;
      }

      // Present the presentation using presentPresentation method
      const result = await Purchasely.presentPresentation({
        presentation: presentation,
        isFullscreen: true,
      });

      // Handle the result
      switch (result.result) {
        case ProductResult.PRODUCT_RESULT_PURCHASED:
          Alert.alert('Success', `Purchased: ${result.plan?.name || 'Unknown plan'}`);
          break;
        case ProductResult.PRODUCT_RESULT_RESTORED:
          Alert.alert('Success', `Restored: ${result.plan?.name || 'Unknown plan'}`);
          break;
        case ProductResult.PRODUCT_RESULT_CANCELLED:
          console.log('User cancelled');
          break;
        default:
          console.log('Presentation closed with result:', result.result);
      }
    } catch (error) {
      Alert.alert('Error', `Failed to show presentation: ${error}`);
      console.error('Error presenting:', error);
    }
  };

  const presentDirectly = async () => {
    try {
      // Alternative: Present directly without fetching first
      const result = await Purchasely.presentPresentationForPlacement({
        placementVendorId: 'ONBOARDING',
        isFullscreen: true,
      });

      switch (result.result) {
        case ProductResult.PRODUCT_RESULT_PURCHASED:
          Alert.alert('Success', `Purchased: ${result.plan?.name || 'Unknown plan'}`);
          break;
        case ProductResult.PRODUCT_RESULT_RESTORED:
          Alert.alert('Success', `Restored: ${result.plan?.name || 'Unknown plan'}`);
          break;
        case ProductResult.PRODUCT_RESULT_CANCELLED:
          console.log('User cancelled');
          break;
      }
    } catch (error) {
      Alert.alert('Error', `Failed to present: ${error}`);
      console.error('Error presenting directly:', error);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#f5f5f5" />

      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.header}>
          <Text style={styles.title}>Purchasely RN CLI Test</Text>
          <Text style={styles.subtitle}>SDK Integration Demo</Text>
        </View>

        <View style={styles.statusContainer}>
          <Text style={styles.statusLabel}>Status:</Text>
          <Text style={styles.statusText}>{statusMessage}</Text>
          {isLoading && <ActivityIndicator style={styles.loader} color="#007AFF" />}
        </View>

        <View style={styles.infoContainer}>
          <Text style={styles.infoTitle}>SDK Configuration</Text>
          <Text style={styles.infoText}>
            Configured: {isConfigured ? 'Yes' : 'No'}
          </Text>
          <Text style={styles.infoText}>
            Presentation: {presentation ? 'Loaded' : 'Not loaded'}
          </Text>
          {presentation && (
            <>
              <Text style={styles.infoText}>Type: {presentation.type}</Text>
              <Text style={styles.infoText}>ID: {presentation.id || 'N/A'}</Text>
            </>
          )}
        </View>

        <View style={styles.buttonContainer}>
          <TouchableOpacity
            style={[styles.button, !isConfigured && styles.buttonDisabled]}
            onPress={fetchPresentationData}
            disabled={!isConfigured}
          >
            <Text style={styles.buttonText}>Fetch Presentation</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.button, styles.buttonPrimary, !presentation && styles.buttonDisabled]}
            onPress={showPresentation}
            disabled={!presentation}
          >
            <Text style={styles.buttonText}>Show Presentation</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.button, styles.buttonSecondary, !isConfigured && styles.buttonDisabled]}
            onPress={presentDirectly}
            disabled={!isConfigured}
          >
            <Text style={styles.buttonText}>Present Directly</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.footer}>
          <Text style={styles.footerText}>
            This app demonstrates the Purchasely React Native SDK
          </Text>
          <Text style={styles.footerText}>
            with React Native CLI
          </Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollContent: {
    flexGrow: 1,
  },
  header: {
    padding: 20,
    alignItems: 'center',
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  subtitle: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
  statusContainer: {
    padding: 16,
    backgroundColor: '#fff',
    margin: 16,
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  statusLabel: {
    fontSize: 12,
    color: '#666',
    fontWeight: '600',
  },
  statusText: {
    fontSize: 14,
    color: '#333',
    marginTop: 4,
  },
  loader: {
    marginTop: 8,
  },
  infoContainer: {
    padding: 16,
    backgroundColor: '#fff',
    marginHorizontal: 16,
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  infoTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  infoText: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
  buttonContainer: {
    padding: 16,
    gap: 12,
  },
  button: {
    backgroundColor: '#007AFF',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  buttonPrimary: {
    backgroundColor: '#34C759',
  },
  buttonSecondary: {
    backgroundColor: '#FF9500',
  },
  buttonDisabled: {
    backgroundColor: '#ccc',
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  footer: {
    padding: 16,
    alignItems: 'center',
    marginTop: 'auto',
  },
  footerText: {
    fontSize: 12,
    color: '#999',
    textAlign: 'center',
  },
});

export default App;
