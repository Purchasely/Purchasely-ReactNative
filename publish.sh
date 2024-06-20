#!/bin/bash

VERSION=$1

#replace version number in json files
sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" purchasely/package.json

sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" purchasely-google/package.json
sed -i '' "s/^.*\"react-native-purchasely\":.*$/\t\t\"react-native-purchasely\": \"${VERSION}\"/" purchasely-google/package.json

sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" purchasely-huawei/package.json
sed -i '' "s/^.*\"react-native-purchasely\":.*$/\t\t\"react-native-purchasely\": \"${VERSION}\",/" purchasely-huawei/package.json

sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" purchasely-amazon/package.json
sed -i '' "s/^.*\"react-native-purchasely\":.*$/\t\t\"react-native-purchasely\": \"${VERSION}\",/" purchasely-amazon/package.json

sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" purchasely-android-player/package.json

#replace version number in index.ts
sed -i '' "s/^.*const purchaselyVersion.*$/const purchaselyVersion = '${VERSION}';/" purchasely/src/index.ts

#publish
if [[ $2 = true ]]
then
    cd purchasely && npm publish --access public
    cd ../purchasely-google && npm publish --access public
    cd ../purchasely-huawei && npm publish --access public
    cd ../purchasely-amazon && npm publish --access public
    cd ../purchasely-android-player && npm publish --access public
else
    cd purchasely && yarn && yarn prepare
    cd ../purchasely-google && yarn install && yarn prepare
    cd ../purchasely-huawei && yarn install && yarn prepare
    cd ../purchasely-amazon && yarn install && yarn prepare
    cd ../purchasely-android-player && yarn install && yarn prepare
fi