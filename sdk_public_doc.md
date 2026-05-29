# Purchasely React Native SDK Documentation

This document provides comprehensive documentation for integrating and using the Purchasely React Native SDK with JavaScript/TypeScript.

> **Upgrading from v5?** The v5 paywall API has been **removed** in v6 in favour
> of the chainable builder API documented here. See
> [`MIGRATION-v6.md`](./MIGRATION-v6.md) for the complete old→new mapping. The
> Purchasely AI plugin and skills (`purchasely-integrate`, `purchasely-review`,
> `purchasely-debug`) can apply the migration for you.

---

## Table of Contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [SDK Initialization](#sdk-initialization)
4. [Displaying Paywalls](#displaying-paywalls)
5. [Processing Transactions](#processing-transactions)
6. [Action Interceptor](#action-interceptor)
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

### Android Dependencies

> ⚠️ **Important**: The main Purchasely SDK (`react-native-purchasely`) does **NOT** include store implementations by default. This modular architecture allows you to include only the stores you need and avoid dependency conflicts.

With Android, you can choose to use Google Play Store and/or Huawei AppGallery and/or Amazon Appstore. **You must install the corresponding dependency for each store you want to support.**

#### Google Play Billing (Required for Google Play Store)

If your app is distributed on the **Google Play Store**, you **must** install the Google Play Billing dependency:

```shell
npm install @purchasely/react-native-purchasely-google --save
```

**Why is this required?**
- The Purchasely core SDK does not include the Google Play Billing library
- When you specify `androidStores: ['Google']` in initialization, the SDK looks for this dependency at runtime
- Without this dependency, purchases will not work on Android devices using Google Play Store
- The app may crash or fail to initialize properly on Android

#### Video Player (Required for Video Paywalls)

If your paywalls contain videos, you **must** install the Android video player dependency:

```shell
npm install @purchasely/react-native-purchasely-android-player --save
```

**Why is this required?**
- The core SDK does not include a video player to avoid conflicts with other media libraries you may have (e.g., Media3/ExoPlayer)
- Without this dependency, videos in paywalls will not play on Android
- If you already have your own video player that supports HLS, you can provide your own player view instead

#### Version Matching (Critical)

> ⚠️ **All Purchasely packages must be at the exact same version.** Mismatched versions will cause runtime errors or unexpected behavior.

```json
// package.json
"dependencies": {
  "react-native-purchasely": "6.0.0",
  "@purchasely/react-native-purchasely-google": "6.0.0",
  "@purchasely/react-native-purchasely-android-player": "6.0.0"
}
```

#### Complete Android Installation Example

For a typical app distributed on Google Play Store with video paywalls:

```shell
# Install all required dependencies
npm install react-native-purchasely --save
npm install @purchasely/react-native-purchasely-google --save
npm install @purchasely/react-native-purchasely-android-player --save
```

Then initialize with the Google store:

```typescript
await Purchasely.builder('YOUR_API_KEY')
    .stores(['google']) // Requires @purchasely/react-native-purchasely-google
    .storekitVersion('storeKit2')
    .start();
```

---

## SDK Initialization

> **v6 — paywall API only.** Initialization, paywall display, and action
> interception use the chainable builder API below. The v5 paywall methods
> (`Purchasely.start({...})`, `startWithAPIKey`,
> `presentPresentationForPlacement`, `fetchPresentation`,
> `setPaywallActionInterceptorCallback`, `onProcessAction`,
> `setDefaultPresentationResultCallback`, `readyToOpenDeeplink`, …) have been
> **removed**. See [`MIGRATION-v6.md`](./MIGRATION-v6.md) for the complete
> old→new mapping. All **core** methods (user, products, subscriptions,
> attributes, listeners) are unchanged.

Initialize the Purchasely SDK as early as possible in your application lifecycle
using `Purchasely.builder(apiKey)`.

### Full Mode (Recommended)

In `full` mode, Purchasely handles the entire purchase flow including transactions and receipts.

```typescript
import Purchasely from 'react-native-purchasely';

// Only the API key is required; every other option has a sensible default.
try {
    const configured = await Purchasely.builder('YOUR_API_KEY')
        .runningMode('full')           // 'observer' (default) | 'full'
        .logLevel('error')             // 'debug' in development to see logs
        .appUserId(null)               // set your user id here if you know it
        .stores(['google'])            // Android: 'google' | 'huawei' | 'amazon'
        .storekitVersion('storeKit2')  // iOS: 'storeKit2' (recommended) | 'storeKit1'
        .start();

    if (configured) {
        console.log('Purchasely SDK configured successfully');
    }
} catch (e) {
    console.log('Purchasely SDK not configured properly', e);
}
```

### Observer (PaywallObserver) Mode

Use `observer` mode if you have an existing in-app purchase infrastructure and want to use Purchasely only for paywall display and analytics. **This is the default in v6.**

```typescript
import Purchasely from 'react-native-purchasely';

try {
    const configured = await Purchasely.builder('YOUR_API_KEY')
        .runningMode('observer')
        .logLevel('error')
        .stores(['google'])
        .storekitVersion('storeKit2')
        .start();
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

`Purchasely.presentation.placement(id).build()` returns a `PresentationRequest`.
Calling `display()` shows the paywall and resolves at **dismiss** with a
`PresentationOutcome`.

```typescript
import Purchasely from 'react-native-purchasely';

try {
    const outcome = await Purchasely.presentation
        .placement('ONBOARDING')
        .contentId('my_content_id') // optional: associate content with the purchase
        .build()
        .display();

    // outcome: { presentation, purchaseResult, plan, closeReason, error }
    if (outcome.error) {
        console.error(outcome.error.message);
    } else if (
        outcome.purchaseResult === 'purchased' ||
        outcome.purchaseResult === 'restored'
    ) {
        console.log('User purchased ' + outcome.plan?.name);
        // Update entitlements to unlock content
    } else {
        console.log('User dismissed: ' + outcome.closeReason);
    }
} catch (e) {
    console.error(e);
}
```

You can also target a specific screen, product, or plan:

```typescript
// Specific presentation by screen id
await Purchasely.presentation.screen('SCREEN_ID').build().display();

// Specific product (content) inside a screen
await Purchasely.presentation.screen('SCREEN_ID').contentId('CONTENT_ID').build().display();
```

### Display Results

`display()` resolves with a `PresentationOutcome`:

| Field | Description |
|-------|-------------|
| `presentation` | The displayed presentation (or `null`) |
| `purchaseResult` | `'purchased'` \| `'restored'` \| `'cancelled'` \| `null` |
| `plan` | The purchased plan (when `purchaseResult` is `'purchased'`/`'restored'`) |
| `closeReason` | `'button'` \| `'backSystem'` \| `'programmatic'` (when no purchase) |
| `error` | Error object, mutually exclusive with `closeReason` |

---

## Processing Transactions

### Full Mode

In `full` mode, the Purchasely SDK automatically launches the native in-app purchase flow when a user clicks on a purchase button and handles the transaction. You only need to update entitlements once you have confirmation that the purchase was processed.

```typescript
try {
    const outcome = await Purchasely.presentation
        .placement('onboarding')
        .build()
        .display();

    if (
        outcome.purchaseResult === 'purchased' ||
        outcome.purchaseResult === 'restored'
    ) {
        console.log('User purchased ' + outcome.plan?.name);
        // Update entitlements to unlock the access to the contents
    }
} catch (e) {
    console.error(e);
}
```

### Observer Mode with Action Interceptor

In `observer` mode, you handle purchases with your own infrastructure while using Purchasely for paywall display. Use `Purchasely.interceptAction(kind, handler)` — the handler returns `'success' | 'failed' | 'notHandled'` (there is no more `onProcessAction`).

```typescript
import { Platform } from 'react-native';

Purchasely.interceptAction('purchase', async (info, payload) => {
    if (payload?.kind !== 'purchase') {
        return 'notHandled';
    }
    try {
        // The store product id (sku) the user clicked on in the paywall
        const storeProductId = payload.plan.productId;

        if (Platform.OS === 'android') {
            // Only for Android you can retrieve other information
            const basePlanId = payload.subscriptionOffer?.basePlanId;
            const offerId = payload.subscriptionOffer?.offerId;
            const offerToken = payload.subscriptionOffer?.offerToken;
        }

        const success = await MyPurchaseSystem.purchase(storeProductId);
        if (success) {
            Purchasely.synchronize(); // Synchronize all purchases with Purchasely
            return 'success';
        }
        return 'failed';
    } catch (e) {
        console.log(e);
        return 'failed';
    }
});

Purchasely.interceptAction('restore', async () => {
    try {
        await MyPurchaseSystem.restorePurchases();
        Purchasely.synchronize();
        return 'success';
    } catch (e) {
        return 'failed';
    }
});
```

---

## Action Interceptor

The action interceptor lets you intercept and handle user actions on the paywall. Register **one handler per action kind** with `Purchasely.interceptAction(kind, handler)`. The handler returns a result string that tells the SDK how the action was handled:

- `'success'` — you handled the action successfully
- `'failed'` — you tried to handle it but it failed
- `'notHandled'` — let the SDK perform its default behaviour

### Available Action Kinds

| Kind | Description |
|------|-------------|
| `purchase` | User tapped a purchase button |
| `restore` | User tapped the restore button |
| `login` | User tapped the login button |
| `close` / `closeAll` | User tapped the close button |
| `navigate` | User wants to navigate to an external URL |
| `openPresentation` | User wants to open another presentation |
| `openPlacement` | User wants to open another placement |
| `promoCode` | User wants to enter a promo code |
| `webCheckout` | User wants to start a web checkout |

### Implementation

```typescript
import Purchasely from 'react-native-purchasely';
import { Linking } from 'react-native';

Purchasely.interceptAction('navigate', async (info, payload) => {
    if (payload?.kind === 'navigate') {
        console.log('User wants to navigate to ' + payload.url);
        Linking.openURL(payload.url);
        return 'success';
    }
    return 'notHandled';
});

Purchasely.interceptAction('login', async () => {
    console.log('User wants to login');
    // Present your own screen for the user to log in
    Purchasely.userLogin('MY_USER_ID');
    return 'success';
});

Purchasely.interceptAction('purchase', async (info, payload) => {
    if (payload?.kind === 'purchase') {
        // If you want to handle the purchase yourself
        return 'notHandled';
    }
    return 'notHandled';
});
```

### Removing interceptors

```typescript
Purchasely.removeActionInterceptor('navigate');
Purchasely.removeAllActionInterceptors();
```

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

To handle the login button on the paywall, intercept the `login` action:

```typescript
Purchasely.interceptAction('login', async () => {
    console.log('User wants to login');
    // Present your own screen for the user to log in
    Purchasely.userLogin('MY_USER_ID');
    return 'success';
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

Build a `PresentationRequest`, `preload()` it to fetch the screen from the
network, then `display()` the same request when you are ready to show it.

```typescript
import Purchasely, { PLYPresentationType } from 'react-native-purchasely';

try {
    const request = Purchasely.presentation.placement('ONBOARDING').build();

    // Preload resolves once the screen is loaded
    const presentation = await request.preload();

    if (presentation.type == PLYPresentationType.DEACTIVATED) {
        // No paywall to display
        return;
    }

    if (presentation.type == PLYPresentationType.CLIENT) {
        // Display your own paywall (BYOS)
        const planIds = presentation.plans;
        return;
    }

    // Display the preloaded Purchasely paywall; resolves at dismiss
    const outcome = await request.display();

    if (
        outcome.purchaseResult === 'purchased' ||
        outcome.purchaseResult === 'restored'
    ) {
        console.log('User purchased ' + outcome.plan?.name);
    } else {
        console.log('Dismissed: ' + outcome.closeReason);
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

Deeplink display is now allowed via the start builder (replaces
`readyToOpenDeeplink(true)`):

```typescript
await Purchasely.builder('YOUR_API_KEY')
    .allowDeeplink(true)
    .start();
```

### Setting the Default Presentation Handler

Retrieve the result of user actions on paywalls opened via deeplinks by
attaching `onDismissed` to a default presentation request (replaces
`setDefaultPresentationResultCallback`):

```typescript
Purchasely.presentation
    .default()
    .onDismissed((outcome) => {
        console.log('Presentation dismissed: ' + outcome.purchaseResult);

        if (outcome.plan != null) {
            console.log('Plan Vendor ID: ' + outcome.plan.vendorId);
            console.log('Plan Name: ' + outcome.plan.name);
        }
    })
    .build()
    .display();
```

---

## Platform-Specific Features

### StoreKit Selection (iOS)

Choose between StoreKit 1 and StoreKit 2 for iOS:

```typescript
await Purchasely.builder('YOUR_API_KEY')
    .storekitVersion('storeKit2') // 'storeKit2' = StoreKit 2, 'storeKit1' = StoreKit 1
    .start();
```

> **Recommendation**: Use StoreKit 2 (`storekitVersion('storeKit2')`) for new integrations.

### Android Stores

Purchasely supports multiple Android stores:

```typescript
await Purchasely.builder('YOUR_API_KEY')
    .stores(['google']) // Options: 'google', 'huawei', 'amazon'
    .start();
```

To use multiple stores:

```typescript
.stores(['google', 'huawei'])
```

> **Note**: Install the corresponding dependencies for each store you want to support.

### Android-Specific Purchase Parameters

When intercepting purchases on Android, you can access additional parameters from the typed `purchase` payload:

```typescript
Purchasely.interceptAction('purchase', async (info, payload) => {
    if (payload?.kind === 'purchase' && Platform.OS === 'android') {
        const basePlanId = payload.subscriptionOffer?.basePlanId;
        const offerId = payload.subscriptionOffer?.offerId;
        const offerToken = payload.subscriptionOffer?.offerToken;
    }
    return 'notHandled';
});
```

---

## Troubleshooting

### Common Issues

1. **SDK not configured**: Ensure you call `Purchasely.builder(apiKey)....start()` before any other SDK methods.

2. **Purchases not working**: Verify that you've added the correct store dependencies and they're all at the same version.

3. **Paywall not displaying**: Check that:
   - The placement exists in your Purchasely Console
   - The SDK is properly initialized
   - You have an active internet connection

4. **StoreKit issues on iOS**: Ensure your iOS deployment target is set to at least 11.0.

### Debug Mode

Enable debug logging during development:

```typescript
await Purchasely.builder('YOUR_API_KEY')
    .logLevel('debug') // Use 'error' in production
    .start();
```

---

## Additional Resources

- [Purchasely Console](https://console.purchasely.io)
- [NPM Package](https://www.npmjs.com/package/react-native-purchasely)
- [Purchasely Documentation](https://docs.purchasely.com)
