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
} from 'react-native-purchasely';

const App: React.FunctionComponent<{}> = () => {
  const [anonymousUserId, setAnonymousUserId] = React.useState<string>('');
  const [loading, setLoading] = React.useState<boolean>(false);

  Purchasely.startWithAPIKey(
    'afa96c76-1d8e-4e3c-a48f-204a3cd93a15',
    ['Google'],
    null,
    LogLevels.WARNING,
    false
  ).then(
    (configured) => {
      if (!configured) {
        console.log('Purchasely SDK not properly initialized');
        return;
      }

      setupPurchasely();
    },
    (error) => {
      console.log('Purchasely SDK initialization error', error);
    }
  );

  React.useEffect(() => {
    (async () => {
      setAnonymousUserId(await Purchasely.getAnonymousUserId());
      Purchasely.userLogout();

      const product = await Purchasely.productWithIdentifier('PURCHASELY_PLUS');
      console.log('Product', product);
      const plan = await Purchasely.planWithIdentifier(
        'PURCHASELY_PLUS_YEARLY'
      );
      console.log('Plan', plan);

      const products = await Purchasely.allProducts();
      console.log('Products', products);
    })();

    // return Purchasely.removeAllListeners();
  }, []);

  const onPressPresentation = async () => {
    try {
      const result = await Purchasely.presentPresentationWithIdentifier();
      console.log(result);
      console.log('Presentation View Result : ' + ProductResult[result.result]);

      if (result.plan != null) {
        console.log('Plan Vendor ID : ' + result.plan.vendorId);
        console.log('Plan Name : ' + result.plan.name);
      }
    } catch (e) {
      console.error(e);
    }
  };

  const onPressProduct = async () => {
    try {
      const result = await Purchasely.presentProductWithIdentifier(
        'PURCHASELY_PLUS'
      );
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

  const onPressPlan = async () => {
    try {
      const result = await Purchasely.presentPlanWithIdentifier(
        'PURCHASELY_PLUS_WEEKLY',
        null,
        'my_content_id'
      );
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

  function setupPurchasely() {
    Purchasely.userLogin('JEFF');
    Purchasely.setLogLevel(LogLevels.DEBUG);
    Purchasely.isReadyToPurchase(true);

    Purchasely.setDefaultPresentationResultCallback((result) => {
      console.log('Result is ' + result.result);
    });

    Purchasely.setLoginTappedCallback(() => {
      //Present your own screen for user to log in
      console.log('Received callback from user tapped on sign in button');

      //Call this method to update Purchasely Paywall
      Purchasely.onUserLoggedIn(true);
    });

    Purchasely.setPurchaseCompletionCallback(() => {
      //Present your own screen before purchase
      console.log('Received callback from user tapped on purchase button');

      //Call this method to process to payment
      Purchasely.processToPayment(true);
    });

    Purchasely.addEventListener((event) => {
      console.log(event);
    });
    // Purchasely.removeAllListeners();

    Purchasely.addPurchasedListener(() => {
      // User has successfully purchased a product, reload content
      console.log('User has purchased');
    });

    Purchasely.setAttribute(Attributes.FIREBASE_APP_INSTANCE_ID, 'test0');
  }

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
        onPress={onPressPlan}
        disabled={loading}
        style={loading ? styles.buttonDisabled : styles.button}
      >
        <Text style={styles.text}>
          {loading && (
            <ActivityIndicator color="#0000ff" size={styles.text.fontSize} />
          )}{' '}
          Display plan
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
