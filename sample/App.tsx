/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

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
  ProductResult,
  RunningMode,
  PLYPaywallAction,
  PLYPresentationType,
  type PurchaselyPresentation,
  type PresentPresentationResult,
  PurchaselyUserAttribute,
} from 'react-native-purchasely';

import {type NavigationProp} from '@react-navigation/native';

import {NavigationContainer} from '@react-navigation/native';
import {createNativeStackNavigator} from '@react-navigation/native-stack';

import {PLYPresentationView} from './PLYPresentationView';
//import {PLYPresentationViewBeta} from 'react-native-purchasely';

const Stack = createNativeStackNavigator();

var presentationForComponent: PurchaselyPresentation | null = null;

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
      });
    } catch (e) {
      console.log('Purchasely SDK configuration error:', e);
    }

    fetchPresentation();

    if (!configured) {
      console.error('Purchasely SDK initialization failed.');
    } else {
      console.info('Purchasely SDK initialized successfully.');
    }

    // logout the user
    Purchasely.userLogout();

   //indicate to sdk it is safe to launch purchase flow
    Purchasely.readyToOpenDeeplink(true);

    //force your language
    Purchasely.setLanguage('en');

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

    // Fetch the product with the identifier 'PURCHASELY_PLUS'
    const product = await Purchasely.productWithIdentifier('PURCHASELY_PLUS');
    console.log('Product', product);

    // Fetch the plan with the identifier 'PURCHASELY_PLUS_YEARLY'
    const plan = await Purchasely.planWithIdentifier('PURCHASELY_PLUS_YEARLY');
    console.log('Plan', plan);

    // Check whether the user is eligible for the intro offer 'PURCHASELY_PLUS_YEARLY'
    await Purchasely.isEligibleForIntroOffer('PURCHASELY_PLUS_YEARLY').then(
      (isEligible: boolean) => {
        console.log('Is eligible for intro offer ? ' + isEligible);
      },
    );

    // Fetch user's active subscriptions
    const subscriptions = await Purchasely.userSubscriptions();
    console.log('Active Subscriptions:', subscriptions.length, 'subscriptions');

    // Fetch user's expired subscriptions
    const expiredSubscriptions = await Purchasely.userSubscriptionsHistory();
    console.log('Expired Subscriptions:', expiredSubscriptions.length, 'subscriptions');

    if(expiredSubscriptions.length > 0) {
      console.log('\t- cancelled date:', expiredSubscriptions[0].cancelledDate);
      console.log('\t- subscription source:', expiredSubscriptions[0].subscriptionSource);
      console.log('\t- productId:', expiredSubscriptions[0].plan.productId);
      console.log('\t- vendorId:', expiredSubscriptions[0].plan.vendorId);
      console.log('\t- endorId:', expiredSubscriptions[0].plan.vendorId);
      console.log('\t- amount:', expiredSubscriptions[0].plan.amount);
      console.log('\t- period:', expiredSubscriptions[0].plan.period);
      console.log('\t- localizedAmount:', expiredSubscriptions[0].plan.localizedAmount);
      console.log('\t- type:', expiredSubscriptions[0].plan.type);
      console.log('\t- hasFreeTrial:', expiredSubscriptions[0].plan.hasFreeTrial);
    }

    Purchasely.addUserAttributeSetListener((attribute: PurchaselyUserAttribute) => {
      console.log('Attribute set:', attribute);
    });

    Purchasely.addUserAttributeRemovedListener(attribute => {
      console.log('Attribute removed:', attribute);
    });

    //Set an attribute for each type
    Purchasely.setUserAttributeWithString('stringKey', 'StringValue');
    Purchasely.setUserAttributeWithNumber('intKey', 3);
    Purchasely.setUserAttributeWithNumber('floatKey', 1.2);
    Purchasely.setUserAttributeWithBoolean('booleanKey', true);
    Purchasely.setUserAttributeWithDate('dateKey', new Date());

    Purchasely.setUserAttributeWithStringArray('stringArrayKey', ['StringValue', 'Test']);
    Purchasely.setUserAttributeWithNumberArray('intArrayKey', [3, 42]);
    Purchasely.setUserAttributeWithNumberArray('floatArrayKey', [1.2, 23.23]);
    Purchasely.setUserAttributeWithBooleanArray('booleanArrayKey', [true, false, true]);

    Purchasely.incrementUserAttribute({key: 'sessions', value: 1});
    Purchasely.incrementUserAttribute({key: 'sessions'});
    Purchasely.incrementUserAttribute({key: 'sessions', value: null});
    Purchasely.decrementUserAttribute({key: 'sessions'});

    Purchasely.incrementUserAttribute({key: 'app_views', value: 8.4}); // will be rounded to 8

    //get all attributes
    const attributes = await Purchasely.userAttributes();
    console.log('Attributes:', attributes);

    //retrive a date attribute
    const dateAttribute = await Purchasely.userAttribute('dateKey');
    console.log('dateKey =', new Date(dateAttribute).getFullYear());

    //remove an attribute
    Purchasely.clearUserAttribute('dateKey');
    console.log('dateKey =', await Purchasely.userAttribute('dateKey'));

    //remove all attributes
    Purchasely.clearUserAttributes();

    // Set paywall action interceptor callback
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

    // Set events listener
    /**
     * Purchasely devs only
     * It's possible that to make it work with this sample project you need to change the import in index.ts to the following:
     * import { NativeModules, NativeEventEmitter } from '../../react-native';
   */
    Purchasely.addEventListener(event => {
      console.info('Event received:', event.name);
      //console.log(event.properties);
    });

    console.log("Add purchase listener");
    Purchasely.addPurchasedListener(() => {
      console.log('Purchase successful');
    });

  } // end of setupPurchasely()

  setupPurchasely();

  return (
    <NavigationContainer>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
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

const styles = StyleSheet.create({
  sectionContainer: {
    marginTop: 12,
    paddingHorizontal: 24,
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


function Section({children}: SectionProps): React.JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';
  return (
    <View style={styles.sectionContainer}>
      {children}
    </View>
  );
}


// ---------------------------------------------------
// ----------     Home Screen     --------------------
// ---------------------------------------------------

const HomeScreen = ({navigation}) => {
  const isDarkMode = useColorScheme() === 'dark';
  const backgroundStyle = {
    backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
  };

  return (
    <SafeAreaView style={{ flex: 1 }}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={backgroundStyle.backgroundColor}
      />
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        style={backgroundStyle}
        contentContainerStyle={{ flexGrow: 1 }} >

        <Header />

        <View
          style={{
            flex: 1,
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
          }}>
          <Section>
            <Button
               onPress={ () => onPressPresentation() }
              title="Display Presentation"
            />
          </Section>

          <Section>
            <Button
               onPress={() => onPressFetch() }
              title="Fetch Presentation"
            />
          </Section>

          <Section>
            <Button
               onPress={() => onPressNestedView(navigation) }
              title="Display Nested View"
            />
          </Section>

          <Section>
            <Button
               onPress={() => onPressShowPresentation() }
              title="Show Presentation"
            />
          </Section>

          <Section>
            <Button
               onPress={() => onPressHidePresentation() }
              title="Hide Presentation"
            />
          </Section>

          <Section>
            <Button
               onPress={() => onPressClosePresentation() }
              title="Close Presentation"
            />
          </Section>

          <Section>
            <Button
               onPress={() => onPressContinueAction() }
              title="Continue Action"
            />
          </Section>

          <Section>
            <Button
               onPress={() => onPressPurchase() }
              title="Purchase"
            />
          </Section>

          <Section>
            <Button
               onPress={() => onPressPurchaseWithPromotionalOffer() }
              title="Purchase With Promotional Offer"
            />
          </Section>

          <Section>
            <Button
               onPress={() => onPressSignPromotionalOffer() }
              title="Sign Promotional Offer"
            />
          </Section>

          <Section>
            <Button
               onPress={() => onPressSubscriptions() }
              title="Display Subscriptions"
            />
          </Section>

          <Section>
            <Button
               onPress={() => onPressRestore() }
              title="Restore"
            />
          </Section>

          <Section>
            <Button
               onPress={() => onPressSilentRestore() }
              title="Silent Restore"
            />
          </Section>

          <Section>
            <Button
               onPress={() => onPressSynchronize() }
              title="Synchronize"
            />
          </Section>

        </View>
      </ScrollView>
    </SafeAreaView>
  );
}






// ---------------------------------------------------
// ----------     Paywall Screen     -----------------
// ---------------------------------------------------

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
        placementId="ACCOUNT"
        flex={7}
        presentation={presentationForComponent}
        onPresentationClosed={(res) => callback(res)}
      />
      <View style={{flex: 3, justifyContent: 'center', alignItems: 'center'}}>
        <Section>
          <Text>Your own React Native content</Text>
        </Section>
      </View>
    </View>
  );
};


// ---------------------------------------------------
// ----------     Button's onPress methods     -------
// ---------------------------------------------------

const onPressNestedView = (navigation: { navigate: (arg0: string) => void; }) => {
  navigation.navigate('Paywall')
}


const onPressPresentation = async () => {
  try {
    const result = await Purchasely.presentPresentationForPlacement({
      placementVendorId: 'composer',
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

    console.log(presentation.placementId)
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



export default App;
