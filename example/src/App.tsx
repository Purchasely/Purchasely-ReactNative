import React from 'react';
import {
  View,
  TouchableHighlight,
  Text,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import Purchasely, { LogLevels, Attributes } from 'react-native-purchasely';

const App: React.FunctionComponent<{}> = () => {
  const [anonymousUserId, setAnonymousUserId] = React.useState<string>('');
  const [loading, setLoading] = React.useState<boolean>(false);

  Purchasely.startWithAPIKey(
    'afa96c76-1d8e-4e3c-a48f-204a3cd93a15',
    ['Google'],
    null,
    LogLevels.WARNING,
    false
  );
  Purchasely.setLogLevel(LogLevels.DEBUG);
  Purchasely.isReadyToPurchase(true);

  Purchasely.setDefaultPresentationResultCallback((result) => {
    console.log('Result is ' + result.result);
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

  React.useEffect(() => {
    (async () => {
      setAnonymousUserId(await Purchasely.getAnonymousUserId());
      Purchasely.userLogin('DEMO_USER').then((refresh) => {
        if (refresh) {
          // Call your backend to refresh user information
        }
      });
      const product = await Purchasely.productWithIdentifier('PURCHASELY_PLUS');
      console.log('Product', product);
      const plan = await Purchasely.planWithIdentifier(
        'PURCHASELY_PLUS_YEARLY'
      );
      console.log('Plan', plan);
      const subscriptions = await Purchasely.userSubscriptions();
      console.log('Subscriptions', subscriptions);
    })();

    // return Purchasely.removeAllListeners();
  }, []);

  const onPressPresentation = async () => {
    try {
      const result = await Purchasely.presentPresentationWithIdentifier(null);
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

  const onPressProduct = async () => {
    try {
      const result = await Purchasely.presentProductWithIdentifier(
        'PURCHASELY_PLUS',
        null
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
        null
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
        'PURCHASELY_PLUS_MONTHLY'
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
