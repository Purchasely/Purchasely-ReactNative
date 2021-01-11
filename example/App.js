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

Purchasely.startWithAPIKey(
  'afa96c76-1d8e-4e3c-a48f-204a3cd93a15',
  ['Google'],
  null,
  Purchasely.logLevelDebug
);
Purchasely.setLogLevel(Purchasely.logLevelDebug);
Purchasely.setAppUserId('DEMO_USER');
Purchasely.isReadyToPurchase(true);
Purchasely.getAnonymousUserId((anonymousUserId) => {
  console.log('Anonymous User Id is ' + anonymousUserId);
});

Purchasely.productWithIdentifier(
  'PURCHASELY_PLUS',
  (errorMsg) => {
    console.error(errorMsg);
  },
  (product) => {
    console.log(' ==> Product');
    console.log(product.vendorId);
    console.log(product.name);
    console.log(product.plans);
  }
);

Purchasely.planWithIdentifier(
  'PURCHASELY_PLUS_YEARLY',
  (errorMsg) => {
    console.error(errorMsg);
  },
  (plan) => {
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
  }
);

Purchasely.userSubscriptions(
  (errorMsg) => {
    console.error(errorMsg);
  },
  (subscriptions) => {
    console.log(' ==> Subscriptions');
    if (subscriptions[0] !== undefined) {
      console.log(subscriptions[0].plan);
      console.log(subscriptions[0].subscriptionSource);
      console.log(subscriptions[0].nextRenewalDate);
      console.log(subscriptions[0].cancelledDate);
    }
  }
);

console.log(' ==> Restorations');
Purchasely.restoreAllProducts(
  (errorMsg) => {
    console.log('Restoration error');
    console.error(errorMsg);
  },
  (restored) => {
    console.log(' ==> Restored');
  }
);

Purchasely.handle(
  'ply://products/PURCHASELY_PLUS/default',
  (errorMsg) => {
    console.log('Deeplink error');
    console.error(errorMsg);
  },
  (handled) => {
    console.log(' ==> Deeplink handled');
  }
);

class App extends Component {
  _onPressProduct() {
    Purchasely.presentProductWithIdentifier(
      'PURCHASELY_PLUS',
      null,
      (msg) => {
        console.error(msg);
      },
      (someData) => {
        console.log(someData);
      }
    );
  }

  _onPressPurchase() {
    Purchasely.purchaseWithPlanVendorId(
      'PURCHASELY_PLUS_MONTHLY',
      (msg) => {
        console.error(msg);
      },
      (someData) => {
        console.log(someData);
      }
    );
  }

  _onPressSubscriptions() {
    Purchasely.presentSubscriptions();
  }

  render() {
    return (
      <View style={styles.container}>
        <TouchableHighlight onPress={this._onPressProduct}>
          <Text style={styles.text}>Display product</Text>
        </TouchableHighlight>
        <TouchableHighlight onPress={this._onPressPurchase}>
          <Text style={styles.text}>Tap to purchase</Text>
        </TouchableHighlight>
        <TouchableHighlight onPress={this._onPressSubscriptions}>
          <Text style={styles.text}>My subscriptions</Text>
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
