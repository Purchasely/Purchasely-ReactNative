import React from 'react';
import {
  View,
  TouchableHighlight,
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
} from 'react-native-purchasely';

const App: React.FunctionComponent = () => {
  const [anonymousUserId, setAnonymousUserId] = React.useState<string>('');
  const [loading, setLoading] = React.useState<boolean>(false);

  React.useEffect(() => {
    async function setupPurchasely() {
      try {
        const configured = await Purchasely.startWithAPIKey(
          'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d',
          ['Google'],
          null,
          LogLevels.DEBUG,
          RunningMode.FULL
        );

        if (!configured) {
          console.log('Purchasely SDK not properly initialized');
          return;
        }

        setAnonymousUserId(await Purchasely.getAnonymousUserId());

        const product = await Purchasely.productWithIdentifier(
          'PURCHASELY_PLUS'
        );
        console.log('Product', product);

        const subscriptions = await Purchasely.userSubscriptions();
        console.log('Subscriptions', subscriptions);

        const plan = await Purchasely.planWithIdentifier(
          'PURCHASELY_PLUS_YEARLY'
        );
        console.log('Plan', plan);

        const products = await Purchasely.allProducts();
        console.log('Products', products);

        Purchasely.setLogLevel(LogLevels.DEBUG);

        //indicate to sdk it is safe to launch purchase flow
        Purchasely.isReadyToPurchase(true);

        //force your language
        Purchasely.setLanguage('en');

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
              Purchasely.closePaywall();
              Purchasely.userLogin('MY_USER_ID');
              //Call this method to update Purchasely Paywall
              break;
            case PLYPaywallAction.PURCHASE:
              console.log('User wants to purchase');
              //If you want to intercept it, close paywall and display your screen
              //then call onProcessAction() to continue or stop purchasely purchase action
              Purchasely.closePaywall();
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
      } catch (e) {
        console.log('Purchasely SDK initialization error', e);
      }
    }

    setupPurchasely();

    return () => {
      Purchasely.removeEventListener();
    };
  }, []);

  const onPressPresentation = async () => {
    try {
      const result = await Purchasely.presentPresentationForPlacement({
        placementVendorId: 'onboarding',
        isFullscreen: true,
      });

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

  const onPressProduct = async () => {
    try {
      const result = await Purchasely.presentProductWithIdentifier({
        productVendorId: 'PURCHASELY_PLUS',
        contentId: 'my_content_id',
      });
      console.log(result);
      console.log('Presentation View Result : ' + result.result);

      if (result.plan != null) {
        console.log('Plan Vendor ID : ' + result.plan.vendorId);
        console.log('Plan Name : ' + result.plan.name);
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

  const onPressContinuePayment = () => {
    //Call this method to process to payment
    Purchasely.onProcessAction(true);
  };

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
        onPress={onPressProduct}
        disabled={loading}
        style={loading ? styles.buttonDisabled : styles.button}
      >
        <Text style={styles.text}>
          {loading && (
            <ActivityIndicator color="#0000ff" size={styles.text.fontSize} />
          )}{' '}
          Display product
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
        onPress={onPressContinuePayment}
        disabled={loading}
        style={loading ? styles.buttonDisabled : styles.button}
      >
        <Text style={styles.text}>
          {loading && (
            <ActivityIndicator color="#0000ff" size={styles.text.fontSize} />
          )}{' '}
          Continue payment
        </Text>
      </TouchableHighlight>
    </View>
  );
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
