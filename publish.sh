#!/bin/bash

VERSION=$1

#replace version number in json file
sed -i '' "s/^.*\"version\":.*$/  \"version\": \"${VERSION}\",/" package.json

#replace version number in index.ts
sed -i '' "s/^.*const purchaselyVersion.*$/const purchaselyVersion = '${VERSION}';/" src/index.ts

#publish
if [[ $2 = true ]]
then
    npm publish --access public
else
    yarn prepare
fi