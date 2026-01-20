
# Purchasely React Native SDK Documentation

This document provides comprehensive documentation for integrating and using the Purchasely React Native SDK with JavaScript/TypeScript.

---

## Table of Contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [SDK Initialization](#sdk-initialization)
4. [Displaying Paywalls](#displaying-paywalls)
5. [Processing Transactions](#processing-transactions)
6. [Paywall Action Interceptor](#paywall-action-interceptor)
7. [User Identification](#user-identification)
8. [Subscription Status & Entitlements](#subscription-status--entitlements)
9. [Custom User Attributes](#custom-user-attributes)
10. [Event Listeners](#event-listeners)
11. [Pre-fetching Screens](#pre-fetching-screens)
12. [Deeplinks Management](#deeplinks-management)
13. [Platform-Specific Features](#platform-specific-features)

---

## Requirements

| Requirement | iOS | Android |
|-------------|-----|---------|
| Minimum OS Version | 11.0 | 21 |
| compileSdkVersion | - | 33 |
| targetSdkVersion | - | 33 |

---

## Installation

### Main Dependency

Install the Purchasely React Native SDK via NPM:

```shell
npm install react-native-purchasely --save
```

### iOS Setup

Update your Podfile to set the minimum iOS version:

```yaml
// Podfile

...

platform :ios, '11.0'

...
```

Then run:

```shell
cd ios && pod install
```

### Android Setup

Update your `android/build.gradle` file:

```groovy
// Edit file android/build.gradle
buildscript {
    ext {
        minSdkVersion = 21 //min version must not be below 21
        compileSdkVersion = 33
        targetSdkVersion = 33
    }
}

allprojects {
    repositories {
        mavenCentral()
    }
}
```

### Google Play Billing (Android)

To add Google as a store, install the Google dependency:

```shell
npm install @purchasely/react-native-purchasely-google --save
```

### Video Player (Android)

For video support in paywalls, add the player dependency:

```shell
npm install @purchasely/react-native-purchasely-android-player --save
```

> **Note**: All your Purchasely dependencies **must** always be at the **same version**:
>
> ```json
> // package.json
> "dependencies": {
>   "react-native-purchasely": "5.0.0",
>   "@purchasely/react-native-purchasely-google": "5.0.0",
>   "@purchasely/react-native-purchasely-android-player": "5.0.0"
> }
> ```

---

## SDK Initialization

Initialize the Purchasely SDK as early as possible in your application lifecycle.

### Full Mode (Recommended)

In `full` mode, Purchasely handles the entire purchase flow including transactions and receipts.

```typescript
import Purchasely, { LogLevels, RunningMode } from 'react-native-purchasely';

// Everything is optional except apiKey and storeKit1
// Example with default values
try {
    const configured = await Purchasely.start({
        apiKey: 'YOUR_API_KEY',
        storeKit1: false, // set to false to use StoreKit2, true to use StoreKit1
        logLevel: LogLevels.ERROR, // set to DEBUG in development mode to see logs
        userId: null, // if you know your user id, set it here
        runningMode: RunningMode.Full, // select between Full and PaywallObserver
        androidStores: ['Google'] // default is Google, don't forget to add the dependency
    });

    if (configured) {
        console.log('Purchasely SDK configured successfully');
    }
} catch (e) {
    console.log('Purchasely SDK not configured properly', e);
}
```

### PaywallObserver Mode

Use `paywallObserver` mode if you have an existing in-app purchase infrastructure and want to use Purchasely only for paywall display and analytics.

```typescript
import Purchasely, { LogLevels, RunningMode } from 'react-native-purchasely';

try {
    const configured = await Purchasely.start({
        apiKey: 'YOUR_API_KEY',
        storeKit1: false,
        logLevel: LogLevels.ERROR,
        userId: null,
        runningMode: RunningMode.PaywallObserver,
        androidStores: ['Google']
    });
} catch (e) {
    console.log('Purchasely SDK not configured properly');
}
```

### API Key

You can find your API Key in the Purchasely Console under **App settings > Backend & SDK configuration**.

---

## Displaying Paywalls

Purchasely paywalls are displayed using **placements**. A placement is a specific location in your app where you want to display a paywall (e.g., onboarding, settings, premium feature).

### Display a Placement

```typescript
import Purchasely, { ProductResult } from 'react-native-purchasely';

try {
    const result = await Purchasely.presentPresentationForPlacement({
        placementVendorId: 'ONBOARDING',
        contentId: 'my_content_id', // optional: associate content with the purchase
        isFullscreen: true,
    });

    switch (result.result) {
        case ProductResult.PRODUCT_RESULT_PURCHASED:
        case ProductResult.PRODUCT_RESULT_RESTORED:
            if (result.plan != null) {
                console.log('User purchased ' + result.plan.name);
                // Update entitlements to unlock content
            }
            break;
        case ProductResult.PRODUCT_RESULT_CANCELLED:
            console.log('User cancelled');
            break;
    }
} catch (e) {
    console.error(e);
}
```

### Display Results

After displaying a placement, you receive a result indicating the user's action:

- `PRODUCT_RESULT_PURCHASED`: User purchased a plan
- `PRODUCT_RESULT_RESTORED`: User restored a previous purchase
- `PRODUCT_RESULT_CANCELLED`: User did not complete a purchase

---

## Processing Transactions

### Full Mode

In `full` mode, the Purchasely SDK automatically launches the native in-app purchase flow when a user clicks on a purchase button and handles the transaction. You only need to update entitlements once you have confirmation that the purchase was processed.

```typescript
try {
    const result = await Purchasely.presentPresentationForPlacement({
        placementVendorId: 'onboarding',
        isFullscreen: true,
    });

    switch (result.result) {
        case ProductResult.PRODUCT_RESULT_PURCHASED:
        case ProductResult.PRODUCT_RESULT_RESTORED:
            if (result.plan != null) {
                console.log('User purchased ' + result.plan.name);
                // Update entitlements to unlock the access to the contents
            }
            break;
        case ProductResult.PRODUCT_RESULT_CANCELLED:
            break;
    }
} catch (e) {
    console.error(e);
}
```

### PaywallObserver Mode with Paywall Action Interceptor

In `paywallObserver` mode, you handle purchases with your own infrastructure while using Purchasely for paywall display.

```typescript
Purchasely.setPaywallActionInterceptorCallback((result) => {
    if (result.action === PLYPaywallAction.PURCHASE) {
        try {
            // The store product id (sku) the user clicked on in the paywall
            const storeProductId = result.parameters.plan.productId;

            if (Platform.OS === 'android') {
                // Only for Android you can retrieve other information
                const basePlanId = result.parameters.subscriptionOffer?.basePlanId;
                const offerId = result.parameters.subscriptionOffer?.offerId;
                const offerToken = result.parameters.subscriptionOffer?.offerToken;
            }

            const success = await MyPurchaseSystem.purchase(storeProductId);
            if (success) {
                Purchasely.synchronize(); // Synchronize all purchases with Purchasely
                Purchasely.onProcessAction(false); // Stop processing action
            }
        } catch (e) {
            console.log(e);
            Purchasely.onProcessAction(false);
        }
    } else if (result.action === PLYPaywallAction.RESTORE) {
        try {
            await MyPurchaseSystem.restorePurchases();
            Purchasely.synchronize();
            Purchasely.onProcessAction(false);
        } catch (e) {
            Purchasely.onProcessAction(false);
        }
    } else {
        Purchasely.onProcessAction(true); // Continue other actions
    }
});
```

---

## Paywall Action Interceptor

The Paywall Action Interceptor allows you to intercept and handle user actions on the paywall.

### Available Actions

| Action | Description |
|--------|-------------|
| `PURCHASE` | User tapped a purchase button |
| `RESTORE` | User tapped the restore button |
| `LOGIN` | User tapped the login button |
| `CLOSE` | User tapped the close button |
| `NAVIGATE` | User wants to navigate to an external URL |
| `OPEN_PRESENTATION` | User wants to open another presentation |

### Implementation

```typescript
import Purchasely, { PLYPaywallAction } from 'react-native-purchasely';

Purchasely.setPaywallActionInterceptorCallback((result) => {
    console.log('Received action from paywall ' + result.info.presentationId);

    if (result.action === PLYPaywallAction.NAVIGATE) {
        console.log('User wants to navigate to ' + result.parameters.url);
        Purchasely.onProcessAction(true);
    } else if (result.action === PLYPaywallAction.CLOSE) {
        console.log('User wants to close paywall');
        Purchasely.onProcessAction(true);
    } else if (result.action === PLYPaywallAction.LOGIN) {
        console.log('User wants to login');
        // Present your own screen for user to log in
        Purchasely.closePresentation();
        Purchasely.userLogin('MY_USER_ID');
        // Call this method to update Purchasely Paywall
        Purchasely.onProcessAction(true);
    } else if (result.action === PLYPaywallAction.OPEN_PRESENTATION) {
        console.log('User wants to open a new paywall');
        Purchasely.onProcessAction(true);
    } else if (result.action === PLYPaywallAction.PURCHASE) {
        console.log('User wants to purchase');
        // If you want to intercept it, close presentation and handle yourself
        Purchasely.closePresentation();
    } else if (result.action === PLYPaywallAction.RESTORE) {
        console.log('User wants to restore purchases');
        Purchasely.onProcessAction(true);
    } else {
        console.log('Action unknown ' + result.action);
        Purchasely.onProcessAction(true);
    }
});
```

> **Important**: Always call `Purchasely.onProcessAction(true/false)` to notify the SDK whether to continue processing the action.

---

## User Identification

### Anonymous Users

The Purchasely SDK automatically generates and assigns an `anonymous_user_id` to each user, maintaining consistency as long as the app remains installed on the device.

```typescript
// Get the anonymous user ID
const anonymousId = await Purchasely.getAnonymousUserId();
console.log('Anonymous User ID: ' + anonymousId);
```

### User Login

To authenticate users and associate purchases with their account:

```typescript
// Login with user ID
Purchasely.userLogin('123456789').then((refresh) => {
    if (refresh) {
        // You should call your backend to refresh user entitlements
        console.log('User logged in, refresh entitlements');
    }
});
```

### User Logout

To sign out a user:

```typescript
// Logout user (clears user ID and custom attributes)
Purchasely.userLogout();
```

### Login from Paywall

To handle the login button on the paywall:

```typescript
Purchasely.setPaywallActionInterceptorCallback((result) => {
    if (result.action === PLYPaywallAction.LOGIN) {
        console.log('User wants to login');
        // Present your own screen for user to log in
        Purchasely.closePresentation();
        Purchasely.userLogin('MY_USER_ID');
        // Call this method to update Purchasely Paywall
        Purchasely.onProcessAction(true);
    } else {
        Purchasely.onProcessAction(true);
    }
});
```

---

## Subscription Status & Entitlements

### Retrieve User Subscriptions

Purchasely offers a way to retrieve active subscriptions directly from your mobile app:

```typescript
try {
    const subscriptions = await Purchasely.userSubscriptions();
    console.log('==> Subscriptions');
    if (subscriptions[0] !== undefined) {
        console.log(subscriptions[0].plan);
        console.log(subscriptions[0].subscriptionSource);
        console.log(subscriptions[0].nextRenewalDate);
        console.log(subscriptions[0].cancelledDate);
    }
} catch (e) {
    console.log(e);
}
```

> **Note**: There is a **few seconds delay** for `Purchasely.userSubscriptions()` to be updated after a purchase or restoration. If you rely on this method to get the current subscription status right after a purchase, you should **wait for 3 seconds** before calling this method.

---

## Custom User Attributes

Custom User Attributes allow you to segment users and personalize their journey.

### Supported Types

- `String`
- `Int` (Number)
- `Float` (Number)
- `Bool` (Boolean)
- `Date`
- `Array of Strings`

### Setting Attributes

```typescript
// Set individual attributes
Purchasely.setUserAttributeWithString('gender', 'man');
Purchasely.setUserAttributeWithNumber('age', 21);
Purchasely.setUserAttributeWithNumber('weight', 78.2);
Purchasely.setUserAttributeWithBoolean('premium', true);
Purchasely.setUserAttributeWithDate('subscription_date', new Date());
```

### Retrieving Attributes

```typescript
// Get all attributes
const attributes = await Purchasely.userAttributes();
console.log(attributes); // Returns a PurchaselyUserAttribute object with key and value

// Retrieve a specific attribute
const dateAttribute = await Purchasely.userAttribute('subscription_date');
// For dates, parse the ISO 8601 string to retrieve the Date object
console.log(new Date(dateAttribute).getFullYear());
```

### Incrementing / Decrementing Counters

```typescript
// Increment a user attribute
Purchasely.incrementUserAttribute({ key: 'viewed_articles' });
// Increment by a specific number
Purchasely.incrementUserAttribute({ key: 'viewed_articles', value: 3 });

// Decrement a user attribute
Purchasely.decrementUserAttribute({ key: 'viewed_articles' });
// Decrement by a specific number
Purchasely.decrementUserAttribute({ key: 'viewed_articles', value: 7 });
```

### Clearing Attributes

```typescript
// Remove one attribute
Purchasely.clearUserAttribute('size');

// Remove all attributes
Purchasely.clearUserAttributes();
```

> **Note**: `Purchasely.userLogout()` will automatically clear all custom user attributes unless you call `Purchasely.userLogout(false)`.

---

## Event Listeners

### UI / SDK Events Listener

When users interact with Purchasely Screens, the SDK triggers events. Implement an event listener to forward these events to analytics platforms.

```typescript
Purchasely.addEventListener((event) => {
    console.log('Event received: ' + event.name);
    console.log('Event properties: ' + JSON.stringify(event.properties));

    // Forward to your analytics platform
    // Analytics.track(event.name, event.properties);
});
```

### Custom User Attributes Listener

When a user submits answers to a survey, custom user attributes can be set automatically by the SDK:

```typescript
Purchasely.setUserAttributeListener((attribute) => {
    console.log('Attribute key: ' + attribute.key);
    console.log('Attribute value: ' + attribute.value);
    console.log('Attribute type: ' + attribute.type);
    console.log('Attribute source: ' + attribute.source);

    // Ignore if source is CLIENT (set by your app)
    if (attribute.source === PLYUserAttributeSource.PURCHASELY) {
        // Process attribute set by Purchasely (e.g., from surveys)
    }
});
```

---

## Pre-fetching Screens

Pre-fetch paywalls from the network before displaying them for a better user experience.

### Benefits

- Display the Screen only after it has been loaded
- Handle network errors gracefully
- Show a custom loading screen
- Pre-load during app navigation

### Implementation

```typescript
import Purchasely, { PLYPresentationType, ProductResult } from 'react-native-purchasely';

try {
    // Fetch presentation to display
    const presentation = await Purchasely.fetchPresentation({
        placementId: 'ONBOARDING'
    });

    if (presentation.type == PLYPresentationType.DEACTIVATED) {
        // No paywall to display
        return;
    }

    if (presentation.type == PLYPresentationType.CLIENT) {
        // Display your own paywall
        const planIds = presentation.plans;
        return;
    }

    // Display Purchasely paywall
    const result = await Purchasely.presentPresentation({
        presentation: presentation
    });

    switch (result.result) {
        case ProductResult.PRODUCT_RESULT_PURCHASED:
        case ProductResult.PRODUCT_RESULT_RESTORED:
            if (result.plan != null) {
                console.log('User purchased ' + result.plan.name);
            }
            break;
        case ProductResult.PRODUCT_RESULT_CANCELLED:
            console.log('User cancelled');
            break;
    }
} catch (e) {
    console.error(e);
}
```

### Presentation Types

| Type | Description |
|------|-------------|
| `NORMAL` | Default Purchasely paywall |
| `FALLBACK` | Fallback paywall (requested one not found) |
| `DEACTIVATED` | No paywall for this placement |
| `CLIENT` | Your own paywall (BYOS) |

---

## Deeplinks Management

To enable Purchasely to display screens via deeplinks, you need to:

1. Pass the deeplink to the Purchasely SDK
2. Allow the display when your app is ready
3. Set a default presentation handler

### Passing the Deeplink

```typescript
Purchasely.isDeeplinkHandled('app://ply/presentations/')
    .then((value) => console.log('Deeplink handled by Purchasely? ' + value));
```

### Allowing the Display

Once your app is ready (after splash screen, onboarding, login, etc.):

```typescript
Purchasely.readyToOpenDeeplink(true);
```

### Setting the Default Presentation Handler

Retrieve the result of user actions on paywalls opened via deeplinks:

```typescript
Purchasely.setDefaultPresentationResultCallback((result) => {
    console.log('Presentation View Result: ' + result.result);

    if (result.plan != null) {
        console.log('Plan Vendor ID: ' + result.plan.vendorId);
        console.log('Plan Name: ' + result.plan.name);
    }
});
```

---

## Platform-Specific Features

### StoreKit Selection (iOS)

Choose between StoreKit 1 and StoreKit 2 for iOS:

```typescript
await Purchasely.start({
    apiKey: 'YOUR_API_KEY',
    storeKit1: false, // false = StoreKit 2, true = StoreKit 1
    // ...
});
```

> **Recommendation**: Use StoreKit 2 (`storeKit1: false`) for new integrations.

### Android Stores

Purchasely supports multiple Android stores:

```typescript
await Purchasely.start({
    apiKey: 'YOUR_API_KEY',
    androidStores: ['Google'], // Options: 'Google', 'Huawei', 'Amazon'
    // ...
});
```

To use multiple stores:

```typescript
androidStores: ['Google', 'Huawei']
```

> **Note**: Install the corresponding dependencies for each store you want to support.

### Android-Specific Purchase Parameters

When intercepting purchases on Android, you can access additional parameters:

```typescript
if (Platform.OS === 'android') {
    const basePlanId = result.parameters.subscriptionOffer?.basePlanId;
    const offerId = result.parameters.subscriptionOffer?.offerId;
    const offerToken = result.parameters.subscriptionOffer?.offerToken;
}
```

---

## Troubleshooting

### Common Issues

1. **SDK not configured**: Ensure you call `Purchasely.start()` before any other SDK methods.

2. **Purchases not working**: Verify that you've added the correct store dependencies and they're all at the same version.

3. **Paywall not displaying**: Check that:
   - The placement exists in your Purchasely Console
   - The SDK is properly initialized
   - You have an active internet connection

4. **StoreKit issues on iOS**: Ensure your iOS deployment target is set to at least 11.0.

### Debug Mode

Enable debug logging during development:

```typescript
await Purchasely.start({
    apiKey: 'YOUR_API_KEY',
    logLevel: LogLevels.DEBUG, // Use ERROR in production
    // ...
});
```

---

## Additional Resources

- [Purchasely Console](https://console.purchasely.io)
- [NPM Package](https://www.npmjs.com/package/react-native-purchasely)
- [Purchasely Documentation](https://docs.purchasely.com)
