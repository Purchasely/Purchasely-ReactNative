/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import React from 'react';
import type {PropsWithChildren} from 'react';
import {
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  Button,
  Alert,
  useColorScheme,
  View,
} from 'react-native';

import {
  Colors,
  DebugInstructions,
  Header,
  LearnMoreLinks,
  ReloadInstructions,
} from 'react-native/Libraries/NewAppScreen';

import Purchasely, {
  LogLevels,
  Attributes,
  ProductResult,
  RunningMode,
  PLYPaywallAction,
  PLYPresentationType,
  type PurchaselyPresentation,
  type PresentPresentationResult,
} from 'purchasely';


function App(): React.JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';

  const backgroundStyle = {
    backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
  };

  async function setupPurchasely() {
    var configured = false;
    try {
      // ApiKey and StoreKit1 attributes are mandatory
      configured = await Purchasely.start({
        apiKey: 'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d',
        storeKit1: false, // false to use StoreKit 2 and true to use StoreKit 1
        logLevel: LogLevels.DEBUG, // to force log level for debug
        userId: 'test-user', // if you know your user id
        runningMode: RunningMode.FULL, // to set mode manually
        androidStores: ['Google', 'Huawei'], // Google is already set by default
      });
    } catch (e) {
      console.log('Purchasely SDK configuration error:', e);
    }

    if (!configured) {
      console.error('Purchasely SDK initialization failed.');
    } else {
      console.info('Purchasely SDK initialized successfully.');
    }

    // logout the user
    Purchasely.userLogout();

    // check that the user is anonymous
    await Purchasely.isAnonymous().then(isAnonymous => {
      console.log('Is anonymous ? ' + isAnonymous);
    });

    // login the user
    Purchasely.userLogin("test-user");

    // check that the user is not anonymous anymore
    await Purchasely.isAnonymous().then((isAnonymous) => {
      console.log('User still anonymous ? ' + isAnonymous);
    });
  }

  setupPurchasely();

  return (
    <SafeAreaView style={[backgroundStyle, { flex: 1 }]}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={backgroundStyle.backgroundColor}
      />
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        style={backgroundStyle}
        contentContainerStyle={{ flexGrow: 1 }}
      >

        <Header />

        <View
          style={{
            flex: 1,
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
          }}>
          <Section title="Display Presentation">
            <Button
               onPress={() => Alert.alert('Button pressed')}
              title="Presentation"
            />
          </Section>

          <Section title="Fetch Presentation">
            <Button
               onPress={() => Alert.alert('Button pressed')}
              title="Presentation"
            />
          </Section>

          <Section title="Display Nested View">
            <Button
               onPress={() => Alert.alert('Button pressed')}
              title="Nested View"
            />
          </Section>

        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  sectionContainer: {
    marginTop: 32,
    paddingHorizontal: 24,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '600',
  },
  sectionDescription: {
    marginTop: 8,
    fontSize: 18,
    fontWeight: '400',
  },
  highlight: {
    fontWeight: '700',
  },
});

type SectionProps = PropsWithChildren<{
  title: string;
}>;

function Section({children, title}: SectionProps): React.JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';
  return (
    <View style={styles.sectionContainer}>
      <Text
        style={[
          styles.sectionTitle,
          {
            color: isDarkMode ? Colors.white : Colors.black,
          },
        ]}>
        {title}
      </Text>
      <Text
        style={[
          styles.sectionDescription,
          {
            color: isDarkMode ? Colors.light : Colors.dark,
          },
        ]}>
        {children}
      </Text>
    </View>
  );
}

export default App;
