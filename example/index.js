/**
 * @format
 */

import React from 'react';
import {AppRegistry} from 'react-native';
import App from './src/App';
import {name as appName} from './app.json';
import E2ETestRunner from './src/E2ETestRunner';

// When launched with E2E_MODE intent extra, MainActivity passes e2eMode=true
// as an initial prop, which routes to the test runner component.
const RootComponent = (props) => {
  if (props.e2eMode) {
    return React.createElement(E2ETestRunner, props);
  }
  return React.createElement(App, props);
};

AppRegistry.registerComponent(appName, () => RootComponent);
