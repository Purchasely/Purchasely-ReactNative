import React, { useState } from 'react';
import {
  Linking,
  View,
  TouchableHighlight,
  Button,
  Text,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';

import Purchasely, {
  LogLevels,
  Attributes,
  ProductResult,
  RunningMode,
  PLYPaywallAction,
  PLYPresentationType,
} from 'react-native-purchasely';

import { NavigationContainer } from '@react-navigation/native';

import { createNativeStackNavigator } from '@react-navigation/native-stack';

import Modal from 'react-native-modal';



const App: React.FunctionComponent = () => {
  const [anonymousUserId, setAnonymousUserId] = React.useState<string>('');
  const [loading, setLoading] = React.useState<boolean>(false);

  React.useEffect(() => {
    Purchasely.userLogout();

    async function setupPurchasely() {
      var configured = false;
      try {
        configured = await Purchasely.startWithAPIKey(
          '31572cdd-96f3-4d94-b17f-9f2668c07800',//'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d',
          ['Google'],
          null,
          LogLevels.DEBUG,
          RunningMode.FULL
        );
      } catch (e) {
        console.log('Purchasely SDK configuration errror', e);
      }

      if (!configured) {
        console.log('Purchasely SDK not properly initialized');
      }

      setAnonymousUserId(await Purchasely.getAnonymousUserId());

      const product = await Purchasely.productWithIdentifier('PURCHASELY_PLUS');
      console.log('Product', product);

      const subscriptions = await Purchasely.userSubscriptions();
      console.log('Subscriptions', subscriptions);

      const plan = await Purchasely.planWithIdentifier(
        'PURCHASELY_PLUS_YEARLY'
      );
      console.log('Plan', plan);
      console.log(
        'User is eligible for intro offer:' + plan.isEligibleForIntroOffer
      );

      Purchasely.userDidConsumeSubscriptionContent();

      const products = await Purchasely.allProducts();
      console.log('Products', products);

      Purchasely.setLogLevel(LogLevels.DEBUG);

      //indicate to sdk it is safe to launch purchase flow
      Purchasely.isReadyToPurchase(true);

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

      Purchasely.setPaywallActionInterceptorCallback((result) => {
        console.log('Received action from paywall');
        console.log(result.info);

        switch (result.action) {
          case PLYPaywallAction.NAVIGATE:
            console.log(
              'User wants to navigate to website ' +
                result.parameters.title +
                ' ' +
                result.parameters.url
            );
            Purchasely.onProcessAction(true);
            break;
          case PLYPaywallAction.LOGIN:
            console.log('User wants to login');
            //Present your own screen for user to log in
            // Purchasely.onProcessAction(false);
            Purchasely.closePaywall();
            setIsLoginModalVisible(true);

            // Purchasely.onProcessAction(true);
            //Call this method to update Purchasely Paywall
            break;
          case PLYPaywallAction.PURCHASE:
            console.log('User wants to purchase');
            //If you want to intercept it, close paywall and display your screen
            //then call onProcessAction() to continue or stop purchasely purchase action
            // Purchasely.closePaywall();
            Purchasely.onProcessAction(true);
            break;
          default:
            Purchasely.onProcessAction(true);
        }
      });

      Purchasely.addEventListener((event) => {
        console.log(event.name);
        console.log(event.properties);
      });

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

  const onPressPresentation = async () => {
    try {
      const result = await Purchasely.presentPresentationForPlacement({
        placementVendorId: 'paywall_carousel',
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
        placementId: 'RELANCEDM',
        contentId: 'content_id_from_reactnative',
      });

      if (presentation.type === PLYPresentationType.DEACTIVATED) {
        // No paywall to display
        return;
      }

      if (presentation.type === PLYPresentationType.CLIENT) {
        // Display my own paywall
        return;
      }

      //Display Purchasely paywall

      const result = await Purchasely.presentPresentation({
        presentation: presentation,
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
          console.log('User cancelled');
          break;
      }
    } catch (e) {
      console.error(e);
    }
  };

  const onPressPurchase = async () => {
    setLoading(true);
    try {
      const plan = await Purchasely.purchaseWithPlanVendorId(
        'PURCHASELY_PLUS_MONTHLY',
        'my_content_id'
      );
      console.log('Purchased ' + plan);
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

  const onPressContinueAction = () => {
    //Call this method to continue Purchasely action
    Purchasely.onProcessAction(true);
  };

  const [isLoginModalVisible, setIsLoginModalVisible] = useState(false);

  const handleLoginModal = () => {
    Purchasely.userLogin('test-user');
    setIsLoginModalVisible(() => !isLoginModalVisible);
    Purchasely.onProcessAction(true);
  };

  const Stack = createNativeStackNavigator()

  function HomeScreen() {
    return (
      <View style={styles.container}>
        <Text>Anonymous User Id {anonymousUserId}</Text>
        <TouchableHighlight
          onPress={onPressPresentation}
          disabled={loading}
          style={loading ? styles.buttonDisabled : styles.button}
        >
          <Text style={styles.text}>
            {loading && (
              <ActivityIndicator color="#0000ff" size={styles.text.fontSize} />
            )}{' '}
            Display presentation
          </Text>
        </TouchableHighlight>
        <TouchableHighlight
          onPress={onPressFetch}
          disabled={loading}
          style={loading ? styles.buttonDisabled : styles.button}
        >
          <Text style={styles.text}>
            {loading && (
              <ActivityIndicator color="#0000ff" size={styles.text.fontSize} />
            )}{' '}
            Fetch presentation
          </Text>
        </TouchableHighlight>
        <TouchableHighlight
          onPress={onPressPurchase}
          disabled={loading}
          style={loading ? styles.buttonDisabled : styles.button}
        >
          <Text style={styles.text}>
            {loading && (
              <ActivityIndicator color="#0000ff" size={styles.text.fontSize} />
            )}{' '}
            Tap to purchase
          </Text>
        </TouchableHighlight>
        <TouchableHighlight
          onPress={onPressSubscriptions}
          disabled={loading}
          style={loading ? styles.buttonDisabled : styles.button}
        >
          <Text style={styles.text}>
            {loading && (
              <ActivityIndicator color="#0000ff" size={styles.text.fontSize} />
            )}{' '}
            My subscriptions
          </Text>
        </TouchableHighlight>
        <TouchableHighlight
          onPress={onPressRestore}
          disabled={loading}
          style={loading ? styles.buttonDisabled : styles.button}
        >
          <Text style={styles.text}>
            {loading && (
              <ActivityIndicator color="#0000ff" size={styles.text.fontSize} />
            )}{' '}
            Restore purchases
          </Text>
        </TouchableHighlight>

        <TouchableHighlight
          onPress={onPressSilentRestore}
          disabled={loading}
          style={loading ? styles.buttonDisabled : styles.button}
        >
          <Text style={styles.text}>
            {loading && (
              <ActivityIndicator color="#0000ff" size={styles.text.fontSize} />
            )}{' '}
            Silent Restore purchases
          </Text>
        </TouchableHighlight>

        <TouchableHighlight
          onPress={onPressContinueAction}
          disabled={loading}
          style={loading ? styles.buttonDisabled : styles.button}
        >
          <Text style={styles.text}>
            {loading && (
              <ActivityIndicator color="#0000ff" size={styles.text.fontSize} />
            )}{' '}
            Continue action
          </Text>
        </TouchableHighlight>
      </View>
      // <Modal isVisible={isLoginModalVisible}>
      //   <View style={{ flex: 1, backgroundColor: '#FF00FF' }}>
      //     <Text>Login Modal!</Text>
      //     <Button title="Hide modal" onPress={handleLoginModal} />
      //   </View>
      // </Modal>
    );
  }

  return (
    <NavigationContainer linking={linkingConfiguration}>
      <Stack.Navigator>
        <Stack.Screen name="Home" component={HomeScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
};

// purchaselyrn://ply/placements/test
const linkingConfiguration = {
  prefixes: ['purchaselyrn://'],

  // Custom function to get the URL which was used to open the app
  async getInitialURL(): Promise<string | null> {
    const url = await Linking.getInitialURL();
    if (url != null) {
      Purchasely.handle(url);
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
  },
  button: {
    backgroundColor: '#ccc',
    marginVertical: 5,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonDisabled: {
    backgroundColor: '#ccf',
    marginVertical: 5,
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
