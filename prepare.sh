#!/bin/bash

VERSION=$1

#replace version number in json files
sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" packages/purchasely/package.json

sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" packages/google/package.json
sed -i '' "s/^.*\"react-native-purchasely\":.*$/\t\t\"react-native-purchasely\": \"${VERSION}\"/" packages/google/package.json

sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" packages/huawei/package.json
sed -i '' "s/^.*\"react-native-purchasely\":.*$/\t\t\"react-native-purchasely\": \"${VERSION}\"/" packages/huawei/package.json

sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" packages/amazon/package.json
sed -i '' "s/^.*\"react-native-purchasely\":.*$/\t\t\"react-native-purchasely\": \"${VERSION}\"/" packages/amazon/package.json

sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" packages/android-player/package.json

#replace version number in index.ts
sed -i '' "s/^.*const purchaselyVersion.*$/const purchaselyVersion = '${VERSION}';/" packages/purchasely/src/index.ts

#publish
yarn all:prepare
