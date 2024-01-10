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
} from 'react-native-purchasely';

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

function App(): React.JSX.Element {
  React.useEffect(() => {
    Purchasely.userLogout();

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
        console.log('Purchasely SDK configuration error', e);
      }

      if (!configured) {
        console.log('Purchasely SDK not properly initialized');
      }

      Purchasely.userLogout();

      //setAnonymousUserId(await Purchasely.getAnonymousUserId());

      await Purchasely.isAnonymous().then(isAnonymous => {
        console.log('Anonymous ? ' + isAnonymous);
      });

      /*Purchasely.userLogin("test-user");

      await Purchasely.isAnonymous().then((isAnonymous) => {
        console.log('Anonymous when connected ? ' + isAnonymous);
      });*/

      try {
        const product = await Purchasely.productWithIdentifier(
          'PURCHASELY_PLUS',
        );
        console.log('Product', product);

        const subscriptions = await Purchasely.userSubscriptions();
        console.log('Subscriptions', subscriptions);

        const plan = await Purchasely.planWithIdentifier(
          'PURCHASELY_PLUS_YEARLY',
        );
        console.log('Plan', plan);

        await Purchasely.isEligibleForIntroOffer('PURCHASELY_PLUS_YEARLY').then(
          (isEligible: boolean) => {
            console.log('Is eligible for intro offer ? ' + isEligible);
          },
        );

        Purchasely.userDidConsumeSubscriptionContent();

        const products = await Purchasely.allProducts();
        console.log('Products', products);
      } catch (e) {
        console.log('Purchasely SDK product fetching error', e);
      }

      Purchasely.setLogLevel(LogLevels.DEBUG);

      //indicate to sdk it is safe to launch purchase flow
      Purchasely.readyToOpenDeeplink(true);

      //force your language
      Purchasely.setLanguage('en');

      //Set an attribute for each type
      Purchasely.setUserAttributeWithString('stringKey', 'StringValue');
      Purchasely.setUserAttributeWithNumber('intKey', 3);
      Purchasely.setUserAttributeWithNumber('floatKey', 1.2);
      Purchasely.setUserAttributeWithBoolean('booleanKey', true);
      Purchasely.setUserAttributeWithDate('dateKey', new Date());

      //get all attributes
      const attributes = await Purchasely.userAttributes();
      console.log(attributes);

      //retrive a date attribute
      const dateAttribute = await Purchasely.userAttribute('dateKey');
      console.log(new Date(dateAttribute).getFullYear());

      //remove an attribute
      Purchasely.clearUserAttribute('dateKey');
      console.log(await Purchasely.userAttribute('dateKey'));

      //remove all attributes
      Purchasely.clearUserAttributes();

      Purchasely.setPaywallActionInterceptorCallback(result => {
        console.log('Received action from paywall');
        console.log(result.info);

        switch (result.action) {
          case PLYPaywallAction.NAVIGATE:
            console.log(
              'User wants to navigate to website ' +
                result.parameters.title +
                ' ' +
                result.parameters.url,
            );
            Purchasely.onProcessAction(true);
            break;
          case PLYPaywallAction.LOGIN:
            console.log('User wants to login');
            //Present your own screen for user to log in
            Purchasely.hidePresentation();
            // Call this method to display Purchaely paywall
            // Purchasely.showPresentation()
            // Call this method to update Purchasely Paywall
            // Purchasely.onProcessAction(true);
            break;
          case PLYPaywallAction.PURCHASE:
            console.log('User wants to purchase');
            Purchasely.hidePresentation();

            /**
             * If you want to intercept it, hide presentation and display your screen
             * then call onProcessAction() to continue or stop purchasely purchase action like this
             *
             * First hide presentation to display your own screen
             * Purchasely.hidePresentation()
             *
             * Call this method to display Purchasely paywall
             * Purchasely.showPresentation()
             *
             * Call this method to update Purchasely Paywall
             * Purchasely.onProcessAction(true|false); // true to continue, false to stop
             *
             * Purchasely.closePresentation(); //when you want to close the paywall (after purchase for example)
             *
             **/
            break;
          default:
            Purchasely.onProcessAction(true);
        }
      });

      //Purchasely.addEventListener((event) => {
      //console.log(event.name);
      //console.log(event.properties);
      //});

      Purchasely.addPurchasedListener(() => {
        // User has successfully purchased a product, reload content
        console.log('User has purchased');
      });

      Purchasely.setAttribute(Attributes.FIREBASE_APP_INSTANCE_ID, 'test0');
    }

    setupPurchasely();

    return () => {
      Purchasely.removeEventListener();
    };
  }, []);

  const isDarkMode = useColorScheme() === 'dark';

  const backgroundStyle = {
    backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
  };

  return (
    <SafeAreaView style={backgroundStyle}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={backgroundStyle.backgroundColor}
      />
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        style={backgroundStyle}>
        <Header />
        <View
          style={{
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
          }}>
          <Section title="Step One">
            Edit <Text style={styles.highlight}>App.tsx</Text> to change this
            screen and then come back to see your edits.
          </Section>
          <Section title="See Your Changes">
            <ReloadInstructions />
          </Section>
          <Section title="Debug">
            <DebugInstructions />
          </Section>
          <Section title="Learn More">
            Read the docs to discover what to do next:
          </Section>
          <LearnMoreLinks />
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

export default App;
