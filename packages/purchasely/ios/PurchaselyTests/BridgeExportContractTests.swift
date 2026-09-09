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

    /// The BARE Objective-C selector behind each of the 63 JS exports —
    /// argument label heads and their colons only, e.g. `"start:stores:…"` —
    /// snapshotted from `PurchaselyRN.m` while it is still the live
    /// Objective-C module. The colon count still equals the argument count,
    /// which is what Global Constraint 1 protects, but the value no longer
    /// carries the macro's parameter types or names, so 61 of these 63
    /// survive Task 14's rewrite to `RCT_EXTERN_METHOD` lines without going
    /// red for a legitimate, non-breaking reason (a `RCTMethodInfo.objcName`
    /// whose text differs only in how the same selector is spelled across
    /// the two macros). `bareSelector(from:)` below is what produces this
    /// from the raw `objcName` at comparison time; these values are already
    /// in that normalised form.
    ///
    /// The other two, `restoreAllProducts` and `silentRestoreAllProducts`,
    /// are the ONLY entries allowed to change at Task 14. Both use
    /// `RCT_REMAP_METHOD` today, so their selector's first segment
    /// (`resolve:reject:` / `silentRestoreWithResolve:reject:`) does not
    /// start with the JS name — but `RCT_EXTERN_REMAP_METHOD` is not public
    /// in RN 0.86 (`RCTBridgeModule.h:310-323`), so Task 14 cannot preserve
    /// that remap in the shim and must give both a selector whose first
    /// segment IS the JS name. Per the plan's Task 11 trap 1, the expected
    /// post-swap selectors are `restoreAllProducts:reject:` and
    /// `silentRestoreAllProducts:reject:` — see the two inline comments
    /// below. Neither change is JS-visible: the JS name and argument count
    /// are unchanged, only the Objective-C spelling.
    ///
    /// This is a before-image, not Task 14's BridgeSelectorResolutionTests:
    /// it snapshots what the Objective-C module exports today so a later
    /// task has something to diff its Swift-shim after-image against.
    ///
    /// Generated by a throwaway test that printed
    /// `Self.exportedEntries().map { ($0.jsName, Self.bareSelector(from: $0.objcName)) }`
    /// sorted by JS name, pasted here, then deleted (mirrors the
    /// constants-capture step in Task 5 Step 2) — never hand-write these.
    static let expectedSelectors: [String: String] = [
        "allProducts": "allProducts:reject:",
        "allowCampaigns": "allowCampaigns:",
        "allowDeeplink": "allowDeeplink:",
        "clearBuiltInAttributes": "clearBuiltInAttributes",
        "clearDynamicOfferings": "clearDynamicOfferings",
        "clearUserAttribute": "clearUserAttribute:",
        "clearUserAttributes": "clearUserAttributes",
        "clientPresentationClosed": "clientPresentationClosed:",
        "clientPresentationDisplayed": "clientPresentationDisplayed:",
        "closeAllScreens": "closeAllScreens",
        "closePresentation": "closePresentation:",
        "completeActionInterceptor": "completeActionInterceptor:result:",
        "decrementUserAttribute": "decrementUserAttribute:value:legalBasis:",
        "displayPresentation": "displayPresentation:payload:transition:resolve:reject:",
        "getAnonymousUserId": "getAnonymousUserId:reject:",
        "getBuiltInAttribute": "getBuiltInAttribute:resolve:reject:",
        "getBuiltInAttributes": "getBuiltInAttributes:reject:",
        "getDynamicOfferings": "getDynamicOfferings:reject:",
        "goBackToPreviousScreen": "goBackToPreviousScreen:",
        "handleDeeplink": "handleDeeplink:resolve:reject:",
        "incrementUserAttribute": "incrementUserAttribute:value:legalBasis:",
        "isAnonymous": "isAnonymous:reject:",
        "isEligibleForIntroOffer": "isEligibleForIntroOffer:resolve:reject:",
        "planWithIdentifier": "planWithIdentifier:resolve:reject:",
        "preloadPresentation": "preloadPresentation:payload:resolve:reject:",
        "productWithIdentifier": "productWithIdentifier:resolve:reject:",
        "purchaseWithPlanVendorId": "purchaseWithPlanVendorId:offerId:contentId:resolve:reject:",
        "readyToOpenDeeplink": "readyToOpenDeeplink:",
        "registerActionInterceptor": "registerActionInterceptor:",
        "removeDefaultPresentationDismissHandler": "removeDefaultPresentationDismissHandler",
        "removeDynamicOffering": "removeDynamicOffering:",
        // CHANGED AT TASK 14 (was "resolve:reject:" via RCT_REMAP_METHOD;
        // RCT_EXTERN_REMAP_METHOD is not public in RN 0.86, so the shim gives
        // it a selector whose first segment is the JS name instead). Not
        // JS-visible: the JS name and argument count are unchanged.
        "restoreAllProducts": "restoreAllProducts:reject:",
        "revokeDataProcessingConsent": "revokeDataProcessingConsent:",
        "setAttribute": "setAttribute:value:",
        "setDebugMode": "setDebugMode:",
        "setDefaultPresentationDismissHandler": "setDefaultPresentationDismissHandler",
        "setDynamicOffering": "setDynamicOffering:planVendorId:offerId:billingPlanType:resolve:reject:",
        "setLanguage": "setLanguage:",
        "setLogLevel": "setLogLevel:",
        "setThemeMode": "setThemeMode:",
        "setUserAttributeWithBoolean": "setUserAttributeWithBoolean:value:legalBasis:",
        "setUserAttributeWithBooleanArray": "setUserAttributeWithBooleanArray:value:legalBasis:",
        "setUserAttributeWithDate": "setUserAttributeWithDate:value:legalBasis:",
        "setUserAttributeWithDouble": "setUserAttributeWithDouble:value:legalBasis:",
        "setUserAttributeWithDoubleArray": "setUserAttributeWithDoubleArray:value:legalBasis:",
        "setUserAttributeWithInt": "setUserAttributeWithInt:value:legalBasis:",
        "setUserAttributeWithIntArray": "setUserAttributeWithIntArray:value:legalBasis:",
        "setUserAttributeWithNumber": "setUserAttributeWithNumber:value:legalBasis:",
        "setUserAttributeWithNumberArray": "setUserAttributeWithNumberArray:value:legalBasis:",
        "setUserAttributeWithString": "setUserAttributeWithString:value:legalBasis:",
        "setUserAttributeWithStringArray": "setUserAttributeWithStringArray:value:legalBasis:",
        "signPromotionalOffer": "signPromotionalOffer:storeOfferId:resolve:reject:",
        // CHANGED AT TASK 14 (was "silentRestoreWithResolve:reject:" via
        // RCT_REMAP_METHOD; RCT_EXTERN_REMAP_METHOD is not public in RN 0.86,
        // so the shim gives it a selector whose first segment is the JS name
        // instead). Not JS-visible: the JS name and argument count are
        // unchanged.
        "silentRestoreAllProducts": "silentRestoreAllProducts:reject:",
        "start": "start:stores:storeKit1:userId:logLevel:runningMode:purchaselySdkVersion:startOptions:initialized:reject:",
        "synchronize": "synchronize:reject:",
        "unregisterActionInterceptor": "unregisterActionInterceptor:",
        "userAttribute": "userAttribute:resolve:reject:",
        "userAttributes": "userAttributes:reject:",
        "userDidConsumeSubscriptionContent": "userDidConsumeSubscriptionContent",
        "userLogin": "userLogin:resolve:reject:",
        "userLogout": "userLogout:",
        "userSubscriptions": "userSubscriptions:resolve:reject:",
        "userSubscriptionsHistory": "userSubscriptionsHistory:resolve:reject:",
    ]

    /// Strips a `RCTMethodInfo.objcName`'s parenthesised types and parameter
    /// names down to its bare selector — the argument-label heads and their
    /// colons only. `"start:(NSString * _Nonnull)apiKey stores:(NSArray *
    /// _Nullable)stores"` becomes `"start:stores:"`. A niladic export (no
    /// colon, e.g. `"clearBuiltInAttributes"`) is returned unchanged.
    static func bareSelector(from objcName: String) -> String {
        objcName.replacingOccurrences(
            of: #"\([^()]*\)\s*[A-Za-z_][A-Za-z0-9_]*\s*"#,
            with: "",
            options: .regularExpression
        )
    }

    func testBareSelectorStripsTypesAndParameterNames() {
        XCTAssertEqual(
            Self.bareSelector(from: "start:(NSString * _Nonnull)apiKey stores:(NSArray * _Nullable)stores"),
            "start:stores:"
        )
        XCTAssertEqual(Self.bareSelector(from: "clearBuiltInAttributes"), "clearBuiltInAttributes")
        // The odd-formatting cases in PurchaselyRN.m — an extra space before
        // the parameter name — must normalise the same way.
        XCTAssertEqual(
            Self.bareSelector(from: "userSubscriptions:(BOOL) invalidate resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject"),
            "userSubscriptions:resolve:reject:"
        )
    }

    func testExportedSelectorsMatchTheContract() {
        // Built with a loop, not Dictionary(uniqueKeysWithValues:), which
        // TRAPS on a duplicate key — that would abort the whole test bundle
        // instead of failing this one assertion. A duplicate JS name is
        // reported as a failure here instead.
        var actual: [String: String] = [:]
        for (jsName, objcName) in Self.exportedEntries() {
            if let existing = actual[jsName] {
                XCTFail("duplicate export for JS name '\(jsName)': '\(existing)' and '\(objcName)'")
                continue
            }
            actual[jsName] = Self.bareSelector(from: objcName)
        }
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
