import React, { Component } from 'react';

import {
  StyleSheet,
  View,
  Text,
  TouchableHighlight,
  NativeModules,
  NativeEventEmitter,
} from 'react-native';

import Purchasely from 'react-native-purchasely';

const eventEmitter = new NativeEventEmitter(NativeModules.Purchasely);
eventEmitter.addListener('Purchasely-Events', (data) => console.log(data));

async function startPurchasely() {
  Purchasely.startWithAPIKey(
    'afa96c76-1d8e-4e3c-a48f-204a3cd93a15',
    ['Google'],
    null,
    Purchasely.logLevelDebug
  );
  Purchasely.setLogLevel(Purchasely.logLevelDebug);
  Purchasely.setAppUserId('DEMO_USER');
  Purchasely.isReadyToPurchase(true);

  const anonymousUserId = await Purchasely.getAnonymousUserId();
  console.log('Anonymous userId: ' + anonymousUserId);

  try {
    const product = await Purchasely.productWithIdentifier('PURCHASELY_PLUS');
    console.log(' ==> Product');
    console.log(product.vendorId);
    console.log(product.name);
    console.log(product.plans);
  } catch (e) {
    console.log(e);
  }

  try {
    const plan = await Purchasely.planWithIdentifier('PURCHASELY_PLUS_YEARLY');
    console.log(' ==> Plan');
    console.log(plan.vendorId);
    console.log(plan.name);
    console.log(plan.price);
    console.log(plan.amount);
    console.log(plan.period);
    console.log(plan.hasIntroductoryPrice);
    console.log(plan.introPrice);
    console.log(plan.introAmount);
    console.log(plan.introDuration);
  } catch (e) {
    console.log(e);
  }

  try {
    const subscriptions = await Purchasely.userSubscriptions();
    console.log(' ==> Subscriptions');
    if (subscriptions[0] !== undefined) {
      console.log(subscriptions[0].plan);
      console.log(subscriptions[0].subscriptionSource);
      console.log(subscriptions[0].nextRenewalDate);
      console.log(subscriptions[0].cancelledDate);
    }
  } catch (e) {
    console.log(e);
  }
}

startPurchasely();

function onPressProduct() {
  Purchasely.presentProductWithIdentifier('PURCHASELY_PLUS', null, (data) => {
    console.log('Product View Result : ' + data['result']);
    console.log('Plan Vendor ID : ' + data['plan']['vendorId']);
    console.log('Plan Name : ' + data['plan']['name']);
  });
}

async function onPressPurchase() {
  try {
    const plan = await Purchasely.purchaseWithPlanVendorId(
      'PURCHASELY_PLUS_MONTHLY'
    );
    console.log('Purchased ' + plan);
  } catch (e) {
    console.log(e);
  }
}

async function onPressSubscriptions() {
  Purchasely.presentSubscriptions();
}

async function onPressRestore() {
  try {
    const restored = await Purchasely.restoreAllProducts();
    console.log('Restoration success ? ' + restored);
  } catch (e) {
    console.log(e);
  }
}

class App extends Component {
  render() {
    return (
      <View style={styles.container}>
        <TouchableHighlight onPress={onPressProduct}>
          <Text style={styles.text}>Display product</Text>
        </TouchableHighlight>
        <TouchableHighlight onPress={onPressPurchase}>
          <Text style={styles.text}>Tap to purchase</Text>
        </TouchableHighlight>
        <TouchableHighlight onPress={onPressSubscriptions}>
          <Text style={styles.text}>My subscriptions</Text>
        </TouchableHighlight>
        <TouchableHighlight onPress={onPressRestore}>
          <Text style={styles.text}>Restore purchases</Text>
        </TouchableHighlight>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5FCFF',
  },
  text: {
    fontSize: 20,
    textAlign: 'center',
    margin: 10,
  },
});

export default App;
