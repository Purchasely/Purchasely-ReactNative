import React from 'react';
import {
  Linking,
  TouchableHighlight,
  ActivityIndicator,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
} from 'react-native';

import {Colors} from 'react-native/Libraries/NewAppScreen';

import Purchasely, {
  LogLevels,
  Attributes,
  ProductResult,
  RunningMode,
  PLYPaywallAction,
  PLYPresentationType,
  type PurchaselyPresentation,
  type PresentPresentationResult,
} from 'react-native-purchasely';

import {type NavigationProp} from '@react-navigation/native';

import {NavigationContainer} from '@react-navigation/native';
import {createNativeStackNavigator} from '@react-navigation/native-stack';

import {PLYPresentationView} from './PLYPresentationView';
//import {PLYPresentationViewBeta} from 'react-native-purchasely';

const Stack = createNativeStackNavigator();

var presentationForComponent: PurchaselyPresentation | null = null;

const fetchPresentation = async () => {
  try {
    presentationForComponent = await Purchasely.fetchPresentation({
      placementId: 'ONBOARDING',
      contentId: null,
    });
    console.log('presentation fetched is %s', presentationForComponent?.id);
  } catch (e) {
    console.error(e);
  }
};

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

      fetchPresentation();

      Purchasely.userLogout();

      //setAnonymousUserId(await Purchasely.getAnonymousUserId());

      await Purchasely.isAnonymous().then(isAnonymous => {
        console.log('Anonymous ? ' + isAnonymous);
      });

      Purchasely.userLogin("test-user");

      await Purchasely.isAnonymous().then((isAnonymous) => {
        console.log('Anonymous when connected ? ' + isAnonymous);
      });

      try {
        const product = await Purchasely.productWithIdentifier(
          'PURCHASELY_PLUS',
        );
        console.log('Product', product);

        const subscriptions = await Purchasely.userSubscriptions();
        console.log('Active Subscriptions:', subscriptions);

        const expiredSubscriptions = await Purchasely.userSubscriptionsHistory();
        console.log('Expired Subscriptions:', expiredSubscriptions);
        if(expiredSubscriptions.length > 0) {
          console.log('cancelled date:', expiredSubscriptions[0].cancelledDate);
          console.log('subscription source:', expiredSubscriptions[0].subscriptionSource);
          console.log('productId:', expiredSubscriptions[0].plan.productId);
          console.log('vendorId:', expiredSubscriptions[0].plan.vendorId);
          console.log('vendorId:', expiredSubscriptions[0].plan.vendorId);
          console.log('amount:', expiredSubscriptions[0].plan.amount);
          console.log('period:', expiredSubscriptions[0].plan.period);
          console.log('localizedAmount:', expiredSubscriptions[0].plan.localizedAmount);
          console.log('type:', expiredSubscriptions[0].plan.type);
          console.log('hasFreeTrial:', expiredSubscriptions[0].plan.hasFreeTrial);
        }

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

      Purchasely.incrementUserAttribute({key: 'sessions', value: 1});
      Purchasely.incrementUserAttribute({key: 'sessions'});
      Purchasely.incrementUserAttribute({key: 'sessions', value: null});
      Purchasely.decrementUserAttribute({key: 'sessions'});

      Purchasely.incrementUserAttribute({key: 'app_views', value: 8.4}); // will be rounded to 8

      //get all attributes
      const attributes = await Purchasely.userAttributes();
      console.log('Attributes');
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
            Purchasely.onProcessAction(true);
            //Purchasely.hidePresentation();

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

      Purchasely.addPurchasedListener(() => {
        // User has successfully purchased a product, reload content
        console.log('User has purchased');
      });

      Purchasely.setAttribute(Attributes.FIREBASE_APP_INSTANCE_ID, 'test0');
    }

    Purchasely.addEventListener(event => {
      console.log('Event received');
      console.log(event.name);
      console.log(event.properties);
    });

    setupPurchasely();

    return () => {
      Purchasely.removeEventListener();
    };
  }, []);

  return (
    <NavigationContainer>
      <Stack.Navigator>
        <Stack.Screen
          name="Home"
          component={HomeScreen}
          options={{title: 'Welcome'}}
        />
        <Stack.Screen name="Paywall" component={PaywallScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}

const HomeScreen = ({navigation}) => {
  const onPressPresentation = async () => {
    try {
      const result = await Purchasely.presentPresentationForPlacement({
        placementVendorId: 'steps',
        isFullscreen: true,
        loadingBackgroundColor: '#FFFFFFFF',
      });

      console.log('Result is ' + result.result);

      switch (result.result) {
        case ProductResult.PRODUCT_RESULT_PURCHASED:
        case ProductResult.PRODUCT_RESULT_RESTORED:
          if (result.plan != null) {
            console.log('User purchased ' + result.plan.name);
          }

          break;
        case ProductResult.PRODUCT_RESULT_CANCELLED:
          break;
      }
    } catch (e) {
      console.error(e);
    }
  };

  const onPressFetch = async () => {
    try {
      const presentation = await Purchasely.fetchPresentation({
        placementId: 'ONBOARDING',
        contentId: null,
      });

      console.log('Type = ' + presentation.type);
      console.log('Plans = ' + JSON.stringify(presentation.plans, null, 2));
      if (presentation.type === PLYPresentationType.DEACTIVATED) {
        // No paywall to display
        return;
      }

      if (presentation.type === PLYPresentationType.CLIENT) {
        // Display my own paywall
        console.log(
          'metadata: ' + JSON.stringify(presentation.metadata, null, 2),
        );
        return;
      }

      //Display Purchasely paywall
      const result = await Purchasely.presentPresentation({
        presentation: presentation,
      });

      console.log('---- Paywall Closed ----');
      console.log('Result is ' + result.result);

      switch (result.result) {
        case ProductResult.PRODUCT_RESULT_PURCHASED:
        case ProductResult.PRODUCT_RESULT_RESTORED:
          if (result.plan != null) {
            console.log('User purchased ' + result.plan.name);
          }

          break;
        case ProductResult.PRODUCT_RESULT_CANCELLED:
          console.log('User cancelled');
          break;
      }
    } catch (e) {
      console.error(e);
    }
  };

  const onPressShowPresentation = () => {
    Purchasely.showPresentation();
  };

  const onPressHidePresentation = () => {
    Purchasely.hidePresentation();
  };

  const onPressClosePresentation = () => {
    Purchasely.closePresentation();
  };

  const onPressContinueAction = () => {
    //Call this method to continue Purchasely action
    Purchasely.showPresentation();
    Purchasely.onProcessAction(true);
  };

  const onPressPurchase = async () => {
    setLoading(true);
    try {
      const plan = await Purchasely.purchaseWithPlanVendorId({
        planVendorId: 'PURCHASELY_PLUS_MONTHLY',
        offerId: null,
        contentId: 'my_content_id',
      });
      console.log('Purchased ' + plan);
    } catch (e) {
      console.error(e);
    }
    setLoading(false);
  };

  const onPressPurchaseWithPromotionalOffer = async () => {
    setLoading(true);
    try {
      const plan = await Purchasely.purchaseWithPlanVendorId({
        planVendorId: 'PURCHASELY_PLUS_YEARLY',
        offerId: 'com.purchasely.plus.yearly.promo',
        contentId: 'my_content_id',
      });
      console.log('Purchased ' + plan);
    } catch (e) {
      console.error(e);
    }
    setLoading(false);
  };

  const onPressSignPromotionalOffer = async () => {
    setLoading(true);
    try {
      const signature = await Purchasely.signPromotionalOffer({
        storeProductId: 'com.purchasely.plus.yearly',
        storeOfferId: 'com.purchasely.plus.yearly.winback.test',
      });

      console.log('Signature timestamp: ' + signature.timestamp);
      console.log('Signature planVendorId: ' + signature.planVendorId);
      console.log('Signature identifier: ' + signature.identifier);
      console.log('Signature signature: ' + signature.signature);
      console.log('Signature nonce: ' + signature.nonce);
      console.log('Signature keyIdentifier: ' + signature.keyIdentifier);
    } catch (e) {
      console.error(e);
    }
    setLoading(false);
  };

  const onPressSubscriptions = () => {
    Purchasely.presentSubscriptions();
  };

  const onPressRestore = async () => {
    setLoading(true);
    try {
      const restored = await Purchasely.restoreAllProducts();
      console.log('Restoration success ? ' + restored);
    } catch (e) {
      console.error(e);
    }
    setLoading(false);
  };

  const onPressSilentRestore = async () => {
    setLoading(true);
    try {
      const restored = await Purchasely.silentRestoreAllProducts();
      console.log('Silent Restoration success ? ' + restored);
    } catch (e) {
      console.error(e);
    }
    setLoading(false);
  };

  const onPressSynchronize = async () => {
    Purchasely.synchronize();
    console.log('Synchronize done');
  };

  const isDarkMode = useColorScheme() === 'dark';
  const [] = React.useState<string>('');
  const [loading, setLoading] = React.useState<boolean>(false);
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
        <View
          style={{backgroundColor: isDarkMode ? Colors.black : Colors.white}}>
          <TouchableHighlight
            onPress={() => navigation.navigate('Paywall')}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>Open Paywall Component</Text>
          </TouchableHighlight>

          <TouchableHighlight
            onPress={onPressPresentation}
            disabled={loading}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>
              {loading && (
                <ActivityIndicator
                  color="#0000ff"
                  size={styles.text.fontSize}
                />
              )}{' '}
              Display presentation
            </Text>
          </TouchableHighlight>

          <TouchableHighlight
            onPress={onPressFetch}
            disabled={loading}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>
              {loading && (
                <ActivityIndicator
                  color="#0000ff"
                  size={styles.text.fontSize}
                />
              )}{' '}
              Fetch presentation
            </Text>
          </TouchableHighlight>

          <TouchableHighlight
            onPress={onPressShowPresentation}
            disabled={loading}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>
              {loading && (
                <ActivityIndicator
                  color="#0000ff"
                  size={styles.text.fontSize}
                />
              )}{' '}
              Show presentation
            </Text>
          </TouchableHighlight>

          <TouchableHighlight
            onPress={onPressHidePresentation}
            disabled={loading}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>
              {loading && (
                <ActivityIndicator
                  color="#0000ff"
                  size={styles.text.fontSize}
                />
              )}{' '}
              Hide presentation
            </Text>
          </TouchableHighlight>

          <TouchableHighlight
            onPress={onPressClosePresentation}
            disabled={loading}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>
              {loading && (
                <ActivityIndicator
                  color="#0000ff"
                  size={styles.text.fontSize}
                />
              )}{' '}
              Close presentation
            </Text>
          </TouchableHighlight>

          <TouchableHighlight
            onPress={onPressContinueAction}
            disabled={loading}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>
              {loading && (
                <ActivityIndicator
                  color="#0000ff"
                  size={styles.text.fontSize}
                />
              )}{' '}
              Continue action
            </Text>
          </TouchableHighlight>

          <TouchableHighlight
            onPress={onPressPurchase}
            disabled={loading}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>
              {loading && (
                <ActivityIndicator
                  color="#0000ff"
                  size={styles.text.fontSize}
                />
              )}{' '}
              Tap to purchase
            </Text>
          </TouchableHighlight>

          <TouchableHighlight
            onPress={onPressPurchaseWithPromotionalOffer}
            disabled={loading}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>
              {loading && (
                <ActivityIndicator
                  color="#0000ff"
                  size={styles.text.fontSize}
                />
              )}{' '}
              Tap to purchase with promo offer
            </Text>
          </TouchableHighlight>

          <TouchableHighlight
            onPress={onPressSignPromotionalOffer}
            disabled={loading}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>
              {loading && (
                <ActivityIndicator
                  color="#0000ff"
                  size={styles.text.fontSize}
                />
              )}{' '}
              Sign promo offer
            </Text>
          </TouchableHighlight>
          <TouchableHighlight
            onPress={onPressSubscriptions}
            disabled={loading}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>
              {loading && (
                <ActivityIndicator
                  color="#0000ff"
                  size={styles.text.fontSize}
                />
              )}{' '}
              My subscriptions
            </Text>
          </TouchableHighlight>

          <TouchableHighlight
            onPress={onPressRestore}
            disabled={loading}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>
              {loading && (
                <ActivityIndicator
                  color="#0000ff"
                  size={styles.text.fontSize}
                />
              )}{' '}
              Restore purchases
            </Text>
          </TouchableHighlight>

          <TouchableHighlight
            onPress={onPressSilentRestore}
            disabled={loading}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>
              {loading && (
                <ActivityIndicator
                  color="#0000ff"
                  size={styles.text.fontSize}
                />
              )}{' '}
              Silent Restore purchases
            </Text>
          </TouchableHighlight>

          <TouchableHighlight
            onPress={onPressSynchronize}
            disabled={loading}
            style={loading ? styles.buttonDisabled : styles.button}>
            <Text style={styles.text}>
              {loading && (
                <ActivityIndicator
                  color="#0000ff"
                  size={styles.text.fontSize}
                />
              )}{' '}
              Synchronize
            </Text>
          </TouchableHighlight>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

var PaywallScreen = ({
  navigation,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  route,
}: {
  navigation: NavigationProp<any>;
  route: any;
}) => {
  fetchPresentation();

  const callback = (result: PresentPresentationResult) => {
    console.log('### Paywall closed');
    console.log('### Result is ' + result.result);
    switch (result.result) {
      case ProductResult.PRODUCT_RESULT_PURCHASED:
      case ProductResult.PRODUCT_RESULT_RESTORED:
        if (result.plan != null) {
          console.log('User purchased ' + result.plan.name);
        }

        break;
      case ProductResult.PRODUCT_RESULT_CANCELLED:
        console.log('User cancelled');
        break;
    }
    navigation.goBack();
  };

  console.log(
    'presentation already fetched is %s',
    presentationForComponent?.id,
  );

  return (
    <View style={{flex: 1}}>
      <PLYPresentationView
        //placementId="ACCOUNT"
        flex={7}
        presentation={presentationForComponent}
        onPresentationClosed={callback}
      />
      <View style={{flex: 3, justifyContent: 'center', alignItems: 'center'}}>
        <TouchableHighlight>
          <Text>Your own React Native content</Text>
        </TouchableHighlight>
      </View>
    </View>
  );
};

// purchaselyrn://ply/placements/test
const linkingConfiguration = {
  prefixes: ['purchaselyrn://'],

  // Custom function to get the URL which was used to open the app
  async getInitialURL(): Promise<string | null> {
    const url = await Linking.getInitialURL();
    if (url != null) {
      Purchasely.isDeeplinkHandled(url);
    }
    return url;
  },

  // Custom function to subscribe to incoming links
  /*subscribe(listener) {

  // Listen to incoming links from deep linking
  const linkingSubscription = Linking.addEventListener('url', ({ url }) => {
    Purchasely.handle(url);
  });

  return () => {
    linkingSubscription.remove();
  };
}*/
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5FCFF',
    marginTop: 30,
  },
  button: {
    backgroundColor: '#ccc',
    marginVertical: 5,
    marginHorizontal: 30,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonDisabled: {
    backgroundColor: '#ccf',
    marginVertical: 5,
    marginHorizontal: 30,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  center: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  block: {
    borderColor: '#000',
    borderWidth: 1,
    paddingBottom: 5,
  },
  text: {
    lineHeight: 30,
    fontSize: 20,
    textAlign: 'center',
    margin: 10,
  },
  title: {
    fontSize: 30,
    margin: 10,
  },
  subtitle: {
    fontSize: 25,
    margin: 10,
  },
});

export default App;
