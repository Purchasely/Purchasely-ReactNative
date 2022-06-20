#!/bin/bash

VERSION=$1

#replace version number in json files
sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" purchasely/package.json

sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" purchasely-google/package.json
sed -i '' "s/^.*\"react-native-purchasely\":.*$/\t\t\"react-native-purchasely\": \"${VERSION}\",/" purchasely-google/package.json

sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" purchasely-huawei/package.json
sed -i '' "s/^.*\"react-native-purchasely\":.*$/\t\t\"react-native-purchasely\": \"${VERSION}\",/" purchasely-huawei/package.json

sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" purchasely-amazon/package.json
sed -i '' "s/^.*\"react-native-purchasely\":.*$/\t\t\"react-native-purchasely\": \"${VERSION}\",/" purchasely-amazon/package.json

#replace version number in index.ts
sed -i '' "s/^.*const purchaselyVersion.*$/const purchaselyVersion = '${VERSION}';/" purchasely/src/index.ts

#publish
if [[ $2 = true ]]
then
    cd purchasely && npm publish --access public
    cd ../purchasely-google && npm publish --access public
    cd ../purchasely-huawei && npm publish --access public
    cd ../purchasely-amazon && npm publish --access public
else
    cd purchasely && yarn prepare
    cd ../purchasely-google && yarn prepare
    cd ../purchasely-huawei && yarn prepare
    cd ../purchasely-amazon && yarn prepare
fi