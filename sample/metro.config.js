const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');
const path = require('path');
const exclusionList = require('metro-config/src/defaults/exclusionList');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = {
  resolver: {
    extraNodeModules: {
      'react-native-purchasely': path.resolve(__dirname, '../purchasely'),
    },
    blockList: exclusionList([
      /node_modules\/react-native-purchasely\/node_modules\/react-native\/.*/,
    ]),
  },
  watchFolders: [
    path.resolve(__dirname, '../purchasely'),
  ],
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);