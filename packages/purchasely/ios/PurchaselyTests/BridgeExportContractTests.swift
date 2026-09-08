//
//  BridgeExportContractTests.swift
//  The parity gate for the Objective-C → Swift port of the bridge module.
//
//  The export shim is parsed as TEXT at registration, not linked: a Swift
//  @objc signature that disagrees with its RCT_EXTERN_METHOD line produces no
//  compile error and fails at run time in a client app with "method not
//  found". This test turns all 63 of those runtime risks into one CI failure.
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

    func testExportedMethodCountMatches() {
        XCTAssertEqual(Self.exportedEntries().count, 63)
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
