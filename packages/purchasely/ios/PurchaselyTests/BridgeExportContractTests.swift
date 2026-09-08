//
//  BridgeExportContractTests.swift
//  The parity gate for the Objective-C → Swift port of the bridge module.
//
//  The export shim is parsed as TEXT at registration, not linked: a Swift
//  @objc signature that disagrees with its RCT_EXTERN_METHOD line produces no
//  compile error and fails at run time in a client app with "method not
//  found". This file locks the 63 JS names, the module name, the 60 constant
//  keys with their numeric values, the 11 event names, AND (below) the exact
//  Objective-C selector behind each of the 63 exports — pinning the argument
//  count along with it, since the selector's colon count IS its argument
//  count.
//
//  It does NOT yet turn a selector mismatch during the Swift port into a CI
//  failure — that is a different, not-yet-existing test, Task 14's
//  BridgeSelectorResolutionTests. What this file's selector assertion does is
//  snapshot the Objective-C selectors NOW, against the still-Objective-C
//  module, so Task 14 has a before-image of the 63 selectors to diff its
//  after-image against.
//
//  It reads the same table React Native reads. RCTMethodInfo comes from
//  RCTBridgeModule.h, which the pod's umbrella already exposes, so this file
//  needs no import beyond the pod itself.
//

import XCTest
import ObjectiveC
@testable import react_native_purchasely

final class BridgeExportContractTests: XCTestCase {

    // MARK: - the contract

    /// The 63 JS method names `src/` calls on `NativeModules.Purchasely`.
    /// This is the client contract. Adding a name here is a feature; losing
    /// one is a breaking change. Generated with:
    ///   rg -o 'RCT_(EXPORT|REMAP)_METHOD\((\w+)' -r '$2' ios/PurchaselyRN.m
    static let expectedJSNames: Set<String> = [
        "start", "isEligibleForIntroOffer", "setLogLevel", "userLogin",
        "handleDeeplink", "userLogout", "isAnonymous", "setThemeMode",
        "setAttribute", "setUserAttributeWithString",
        "setUserAttributeWithBoolean", "setUserAttributeWithNumber",
        "setUserAttributeWithInt", "setUserAttributeWithDouble",
        "setUserAttributeWithDate", "setUserAttributeWithStringArray",
        "setUserAttributeWithBooleanArray", "setUserAttributeWithNumberArray",
        "setUserAttributeWithIntArray", "setUserAttributeWithDoubleArray",
        "incrementUserAttribute", "decrementUserAttribute", "userAttribute",
        "userAttributes", "clearUserAttribute", "clearUserAttributes",
        "clearBuiltInAttributes", "getBuiltInAttributes", "getBuiltInAttribute",
        "setLanguage", "userDidConsumeSubscriptionContent",
        "getAnonymousUserId", "readyToOpenDeeplink", "allowDeeplink",
        "allowCampaigns", "signPromotionalOffer", "purchaseWithPlanVendorId",
        "restoreAllProducts", "silentRestoreAllProducts", "synchronize",
        "allProducts", "productWithIdentifier", "planWithIdentifier",
        "userSubscriptions", "userSubscriptionsHistory", "setDynamicOffering",
        "getDynamicOfferings", "removeDynamicOffering", "clearDynamicOfferings",
        "revokeDataProcessingConsent", "setDebugMode", "closeAllScreens",
        "preloadPresentation", "displayPresentation",
        "setDefaultPresentationDismissHandler",
        "removeDefaultPresentationDismissHandler", "closePresentation",
        "goBackToPreviousScreen", "clientPresentationDisplayed",
        "clientPresentationClosed", "registerActionInterceptor",
        "unregisterActionInterceptor", "completeActionInterceptor",
    ]

    /// The 11 event names. `src/` subscribes to these by string.
    static let expectedEvents: [String] = [
        "PURCHASELY_EVENTS",
        "PURCHASE_LISTENER",
        "USER_ATTRIBUTE_SET_LISTENER",
        "USER_ATTRIBUTE_REMOVED_LISTENER",
        "WEB_REDEMPTION_LISTENER",
        "PURCHASELY_PRESENTATION_LOADED",
        "PURCHASELY_PRESENTATION_PRESENTED",
        "PURCHASELY_PRESENTATION_CLOSE_REQUESTED",
        "PURCHASELY_PRESENTATION_DISMISSED",
        "PURCHASELY_DEFAULT_PRESENTATION_DISMISSED",
        "PURCHASELY_ACTION_INTERCEPTED",
    ]

    /// The 60 constant keys. `enums.ts:4` builds the JS enums from them, so a
    /// lost key is a `undefined` enum member in a client app.
    static let expectedConstantKeys: Set<String> = [
        "logLevelDebug", "logLevelInfo", "logLevelWarn", "logLevelError",
        "productResultPurchased", "productResultCancelled",
        "productResultRestored", "sourceAppStore", "sourcePlayStore",
        "sourceHuaweiAppGallery", "sourceAmazonAppstore", "sourceStripe",
        "sourceNone", "firebaseAppInstanceId", "airshipChannelId",
        "airshipUserId", "batchInstallationId", "adjustId", "appsflyerId",
        "oneSignalExternalId", "oneSignalUserId", "mixpanelDistinctId",
        "clevertapId", "sendinblueUserEmail", "iterableUserId",
        "iterableUserEmail", "atInternetIdClient", "amplitudeUserId",
        "amplitudeDeviceId", "mparticleUserId", "customerIoUserId",
        "customerIoUserEmail", "branchUserDeveloperIdentity",
        "moEngageUniqueId", "batchCustomUserId", "consumable",
        "nonConsumable", "autoRenewingSubscription", "nonRenewingSubscription",
        "unknown", "runningModeObserver", "runningModeFull",
        "presentationTypeNormal", "presentationTypeFallback",
        "presentationTypeDeactivated", "presentationTypeClient",
        "themeLight", "themeDark", "themeSystem",
        "userAttributeSourcePurchasely", "userAttributeSourceClient",
        "userAttributeString", "userAttributeBoolean", "userAttributeInt",
        "userAttributeFloat", "userAttributeDate",
        "userAttributeStringArray", "userAttributeIntArray",
        "userAttributeFloatArray", "userAttributeBooleanArray",
    ]

    // MARK: - the tests

    func testModuleIsExportedAsPurchasely() {
        // RCT_EXPORT_MODULE_NO_LOAD defines +moduleName (RCTBridgeModule.h:100).
        // The plain RCT_EXTERN_MODULE form would make this "PurchaselyRN" and
        // break every JS call.
        XCTAssertEqual(PurchaselyRN.moduleName(), "Purchasely")
    }

    func testExportedJSNamesAreExactlyTheContract() {
        let actual = Self.exportedJSNames()
        XCTAssertEqual(
            actual, Self.expectedJSNames,
            """
            Exported JS names drifted.
              missing: \(Self.expectedJSNames.subtracting(actual).sorted())
              extra:   \(actual.subtracting(Self.expectedJSNames).sorted())
            A missing name is a breaking change for client apps.
            """
        )
    }

    /// The `objcName` React Native's own export table carries for each of
    /// the 63 JS exports, snapshotted from `PurchaselyRN.m` while it is still
    /// the live Objective-C module. It is the macro's raw method-declaration
    /// text (types, argument names and all), not a bare compiled selector —
    /// but the selector IS embedded in it as the sequence of `label:` heads,
    /// so this still pins the selector, and therefore the argument count
    /// (the selector's colon count), along with everything else.
    /// `exportedEntries()` already collects `objcName` from `RCTMethodInfo`
    /// and nothing asserted it before this test — so a selector could gain
    /// or lose an argument (e.g. `closePresentation:` silently becoming
    /// `closePresentation` or `closePresentation:force:`) and the
    /// JS-name-only gate above would not notice, because the JS name is only
    /// the selector's head up to its first colon.
    ///
    /// This is a before-image, not Task 14's BridgeSelectorResolutionTests:
    /// it snapshots what the Objective-C module exports today so a later
    /// task has something to diff its Swift-shim after-image against.
    ///
    /// Generated by a throwaway test that printed `Self.exportedEntries()`
    /// sorted by JS name, pasted here, then deleted (mirrors the
    /// constants-capture step in Task 5 Step 2) — never hand-write these,
    /// `PurchaselyRN.m`'s multi-line macro arguments collapse to single
    /// spaces in ways that are easy to get wrong by eye.
    static let expectedSelectors: [String: String] = [
        "allProducts": "allProducts:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "allowCampaigns": "allowCampaigns:(BOOL)allow",
        "allowDeeplink": "allowDeeplink:(BOOL)allow",
        "clearBuiltInAttributes": "clearBuiltInAttributes",
        "clearDynamicOfferings": "clearDynamicOfferings",
        "clearUserAttribute": "clearUserAttribute:(NSString * _Nonnull)key",
        "clearUserAttributes": "clearUserAttributes",
        "clientPresentationClosed": "clientPresentationClosed:(NSDictionary<NSString *, id> * _Nullable)presentationMap",
        "clientPresentationDisplayed": "clientPresentationDisplayed:(NSDictionary<NSString *, id> * _Nullable)presentationMap",
        "closeAllScreens": "closeAllScreens",
        "closePresentation": "closePresentation:(NSString *)requestId",
        "completeActionInterceptor": "completeActionInterceptor:(NSString *)callbackId result:(NSString *)result",
        "decrementUserAttribute": "decrementUserAttribute:(NSString * _Nonnull)key value:(NSNumber * _Nonnull)value legalBasis:(NSString * _Nullable)legalBasis",
        "displayPresentation": "displayPresentation:(NSString *)requestId payload:(NSDictionary *)payload transition:(NSDictionary *)transition resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "getAnonymousUserId": "getAnonymousUserId:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "getBuiltInAttribute": "getBuiltInAttribute:(NSString * _Nonnull)key resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "getBuiltInAttributes": "getBuiltInAttributes:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "getDynamicOfferings": "getDynamicOfferings:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "goBackToPreviousScreen": "goBackToPreviousScreen:(NSString *)requestId",
        "handleDeeplink": "handleDeeplink:(NSString * _Nullable) deeplink resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "incrementUserAttribute": "incrementUserAttribute:(NSString * _Nonnull)key value:(NSNumber * _Nonnull)value legalBasis:(NSString * _Nullable)legalBasis",
        "isAnonymous": "isAnonymous:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "isEligibleForIntroOffer": "isEligibleForIntroOffer:(NSString * _Nonnull)planVendorId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "planWithIdentifier": "planWithIdentifier:(NSString * _Nonnull)planVendorId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "preloadPresentation": "preloadPresentation:(NSString *)requestId payload:(NSDictionary *)payload resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "productWithIdentifier": "productWithIdentifier:(NSString * _Nonnull)productVendorId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "purchaseWithPlanVendorId": "purchaseWithPlanVendorId:(NSString * _Nonnull)planVendorId offerId:(NSString * _Nullable)offerId contentId:(NSString * _Nullable)contentId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "readyToOpenDeeplink": "readyToOpenDeeplink:(BOOL)ready",
        "registerActionInterceptor": "registerActionInterceptor:(NSString *)kind",
        "removeDefaultPresentationDismissHandler": "removeDefaultPresentationDismissHandler",
        "removeDynamicOffering": "removeDynamicOffering:(NSString *)reference",
        "restoreAllProducts": "resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "revokeDataProcessingConsent": "revokeDataProcessingConsent:(NSArray<NSString *> * _Nonnull)purposes",
        "setAttribute": "setAttribute:(NSInteger)attribute value:(NSString * _Nonnull)value",
        "setDebugMode": "setDebugMode:(BOOL)enabled",
        "setDefaultPresentationDismissHandler": "setDefaultPresentationDismissHandler",
        "setDynamicOffering": "setDynamicOffering:(NSString *)reference planVendorId:(NSString *)planVendorId offerId:(nullable NSString *)offerId billingPlanType:(nullable NSString *)billingPlanType resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "setLanguage": "setLanguage:(NSString * _Nonnull) language",
        "setLogLevel": "setLogLevel:(NSInteger)logLevel",
        "setThemeMode": "setThemeMode:(NSInteger)mode",
        "setUserAttributeWithBoolean": "setUserAttributeWithBoolean:(NSString * _Nonnull)key value:(BOOL)value legalBasis:(NSString * _Nullable)legalBasis",
        "setUserAttributeWithBooleanArray": "setUserAttributeWithBooleanArray:(NSString * _Nonnull)key value:(NSArray<NSNumber *> * _Nonnull)value legalBasis:(NSString * _Nullable)legalBasis",
        "setUserAttributeWithDate": "setUserAttributeWithDate:(NSString * _Nonnull)key value:(NSString * _Nonnull)value legalBasis:(NSString * _Nullable)legalBasis",
        "setUserAttributeWithDouble": "setUserAttributeWithDouble:(NSString * _Nonnull)key value:(double)value legalBasis:(NSString * _Nullable)legalBasis",
        "setUserAttributeWithDoubleArray": "setUserAttributeWithDoubleArray:(NSString * _Nonnull)key value:(NSArray<NSNumber *> * _Nonnull)value legalBasis:(NSString * _Nullable)legalBasis",
        "setUserAttributeWithInt": "setUserAttributeWithInt:(NSString * _Nonnull)key value:(NSInteger)value legalBasis:(NSString * _Nullable)legalBasis",
        "setUserAttributeWithIntArray": "setUserAttributeWithIntArray:(NSString * _Nonnull)key value:(NSArray<NSNumber *> * _Nonnull)value legalBasis:(NSString * _Nullable)legalBasis",
        "setUserAttributeWithNumber": "setUserAttributeWithNumber:(NSString * _Nonnull)key value:(double)value legalBasis:(NSString * _Nullable)legalBasis",
        "setUserAttributeWithNumberArray": "setUserAttributeWithNumberArray:(NSString * _Nonnull)key value:(NSArray<NSNumber *> * _Nonnull)value legalBasis:(NSString * _Nullable)legalBasis",
        "setUserAttributeWithString": "setUserAttributeWithString:(NSString * _Nonnull)key value:(NSString * _Nonnull)value legalBasis:(NSString * _Nullable)legalBasis",
        "setUserAttributeWithStringArray": "setUserAttributeWithStringArray:(NSString * _Nonnull)key value:(NSArray<NSString *> * _Nonnull)value legalBasis:(NSString * _Nullable)legalBasis",
        "signPromotionalOffer": "signPromotionalOffer:(NSString * )storeProductId storeOfferId:(NSString * )storeOfferId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "silentRestoreAllProducts": "silentRestoreWithResolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "start": "start:(NSString * _Nonnull)apiKey stores:(NSArray * _Nullable)stores storeKit1:(BOOL)storeKit1 userId:(NSString * _Nullable)userId logLevel:(NSInteger)logLevel runningMode:(NSInteger)runningMode purchaselySdkVersion:(NSString * _Nullable)purchaselySdkVersion startOptions:(NSDictionary * _Nullable)startOptions initialized:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "synchronize": "synchronize:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "unregisterActionInterceptor": "unregisterActionInterceptor:(NSString *)kind",
        "userAttribute": "userAttribute:(NSString * _Nonnull)key resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "userAttributes": "userAttributes:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "userDidConsumeSubscriptionContent": "userDidConsumeSubscriptionContent",
        "userLogin": "userLogin:(NSString * _Nonnull)userId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "userLogout": "userLogout:(BOOL)clearUserAttributes",
        "userSubscriptions": "userSubscriptions:(BOOL) invalidate resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
        "userSubscriptionsHistory": "userSubscriptionsHistory:(BOOL)invalidateCache resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject",
    ]

    func testExportedSelectorsMatchTheContract() {
        let actual = Dictionary(uniqueKeysWithValues: Self.exportedEntries())
        XCTAssertEqual(
            actual, Self.expectedSelectors,
            "an exported selector's argument labels or argument count changed"
        )
    }

    func testExportedMethodCountMatches() {
        // Self.expectedJSNames.count, not a hardcoded 63: a hardcoded literal
        // here and the literal list above could drift apart in opposite
        // directions (one edited, the other forgotten) and still agree with
        // each other while disagreeing with reality.
        XCTAssertEqual(Self.exportedEntries().count, Self.expectedJSNames.count)
    }

    func testConstantsToExportKeepsAllSixtyKeys() {
        let constants = PurchaselyRN().constantsToExport() as? [String: Any] ?? [:]
        let actual = Set(constants.keys)
        XCTAssertEqual(
            actual, Self.expectedConstantKeys,
            """
            constantsToExport drifted.
              missing: \(Self.expectedConstantKeys.subtracting(actual).sorted())
              extra:   \(actual.subtracting(Self.expectedConstantKeys).sorted())
            enums.ts builds the JS enums from these keys.
            """
        )
    }

    func testEveryConstantIsANumberNotAnOpaqueEnumBox() {
        // Global constraint 5. Every one of the 60 values is a numeric ordinal
        // today. A Swift enum written without .rawValue would arrive undefined.
        for (key, value) in Self.liveConstants() {
            XCTAssertTrue(
                value is NSNumber,
                "constant '\(key)' is \(type(of: value)), expected NSNumber — write .rawValue"
            )
        }
    }

    /// The 60 constants with their exact numeric values, captured from the
    /// Objective-C module before the port.
    ///
    /// The key set alone is not enough: an ordinal can change without any key
    /// changing, and `enums.ts` maps these numbers straight into the JS enums,
    /// so a shifted value silently mislabels every event a client receives.
    /// Generate this dictionary ONCE, in Step 2, by printing the live values,
    /// then paste it here as a literal and never regenerate it.
    static let expectedConstants: [String: Int] = [
        "adjustId": 4,
        "airshipChannelId": 1,
        "airshipUserId": 2,
        "amplitudeDeviceId": 17,
        "amplitudeUserId": 16,
        "appsflyerId": 5,
        "atInternetIdClient": 11,
        "autoRenewingSubscription": 2,
        "batchCustomUserId": 20,
        "batchInstallationId": 3,
        "branchUserDeveloperIdentity": 15,
        "clevertapId": 7,
        "consumable": 0,
        "customerIoUserEmail": 14,
        "customerIoUserId": 13,
        "firebaseAppInstanceId": 0,
        "iterableUserEmail": 9,
        "iterableUserId": 10,
        "logLevelDebug": 0,
        "logLevelError": 3,
        "logLevelInfo": 1,
        "logLevelWarn": 2,
        "mixpanelDistinctId": 6,
        "moEngageUniqueId": 18,
        "mparticleUserId": 12,
        "nonConsumable": 1,
        "nonRenewingSubscription": 3,
        "oneSignalExternalId": 19,
        "oneSignalUserId": 21,
        "presentationTypeClient": 3,
        "presentationTypeDeactivated": 2,
        "presentationTypeFallback": 1,
        "presentationTypeNormal": 0,
        "productResultCancelled": 1,
        "productResultPurchased": 0,
        "productResultRestored": 2,
        "runningModeFull": 4,
        "runningModeObserver": 1,
        "sendinblueUserEmail": 8,
        "sourceAmazonAppstore": 2,
        "sourceAppStore": 0,
        "sourceHuaweiAppGallery": 3,
        "sourceNone": 5,
        "sourcePlayStore": 1,
        "sourceStripe": 4,
        "themeDark": 1,
        "themeLight": 0,
        "themeSystem": 2,
        "unknown": 4,
        "userAttributeBoolean": 1,
        "userAttributeBooleanArray": 8,
        "userAttributeDate": 4,
        "userAttributeFloat": 3,
        "userAttributeFloatArray": 7,
        "userAttributeInt": 2,
        "userAttributeIntArray": 6,
        "userAttributeSourceClient": 1,
        "userAttributeSourcePurchasely": 0,
        "userAttributeString": 0,
        "userAttributeStringArray": 5,
    ]

    func testConstantValuesAreUnchanged() {
        let live = Self.liveConstants().compactMapValues { ($0 as? NSNumber)?.intValue }
        XCTAssertEqual(
            live, Self.expectedConstants,
            "a constant's numeric value changed; enums.ts maps these into the JS enums"
        )
    }

    /// `constantsToExport` is an optional protocol requirement, not a member of
    /// `PurchaselyRN.h`, so reach it through the protocol rather than calling it
    /// directly on the concrete type. It is an INSTANCE method in
    /// `RCTBridgeModule.h:358` (`@optional`, above `- (NSDictionary *)constantsToExport;`),
    /// not a class method — the plan's snippet had it wrong; the interface wins.
    static func liveConstants() -> [String: Any] {
        let module = PurchaselyRN()
        guard let bridgeModule = module as? RCTBridgeModule,
              let constants = bridgeModule.constantsToExport?() else {
            XCTFail("PurchaselyRN does not export constants")
            return [:]
        }
        return constants as? [String: Any] ?? [:]
    }

    func testSupportedEventsKeepsItsOrderAndContent() {
        let actual = PurchaselyRN().supportedEvents() as? [String] ?? []
        XCTAssertEqual(actual, Self.expectedEvents)
    }

    // MARK: - reading React Native's export table

    private typealias RCTExportFn =
        @convention(c) (AnyObject, Selector) -> UnsafePointer<RCTMethodInfo>

    /// Every (jsName, objcName) pair the module exports.
    ///
    /// Reads the metaclass method list, NOT the superclass chain: RCTEventEmitter
    /// exports addListener: and removeListeners: of its own
    /// (RCTEventEmitter.m:96,115), which would make the count 65.
    static func exportedEntries() -> [(jsName: String, objcName: String)] {
        // Labelled, matching the return type: Swift does not convert between
        // arrays of differently labelled tuples.
        var entries: [(jsName: String, objcName: String)] = []
        var count: UInt32 = 0
        guard let metaclass = object_getClass(PurchaselyRN.self),
              let methods = class_copyMethodList(metaclass, &count) else {
            return entries
        }
        defer { free(methods) }

        for index in 0..<Int(count) {
            let selector = method_getName(methods[index])
            guard NSStringFromSelector(selector).hasPrefix("__rct_export__") else {
                continue
            }
            let fn = unsafeBitCast(method_getImplementation(methods[index]), to: RCTExportFn.self)
            let info = fn(PurchaselyRN.self, selector).pointee
            let objcName = String(cString: info.objcName)
            entries.append((jsName(info: info, objcName: objcName), objcName))
        }
        return entries
    }

    static func exportedJSNames() -> Set<String> {
        Set(exportedEntries().map(\.jsName))
    }

    /// Copied from RCTModuleMethod.mm:485-508 so the test agrees with the
    /// runtime instead of guessing.
    private static func jsName(info: RCTMethodInfo, objcName: String) -> String {
        if let raw = info.jsName {
            let explicit = String(cString: raw)
            if !explicit.isEmpty { return explicit }
        }
        let head = objcName.split(separator: ":", maxSplits: 1).first.map(String.init) ?? objcName
        return head.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
