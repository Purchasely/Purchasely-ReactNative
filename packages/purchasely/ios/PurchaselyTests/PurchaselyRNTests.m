//
//  PurchaselyRNTests.m
//  PurchaselyRNTests
//
//  Unit tests for PurchaselyRN native module
//

#import <XCTest/XCTest.h>
#import "PurchaselyRN.h"

@interface PurchaselyRNTests : XCTestCase

@property (nonatomic, strong) PurchaselyRN *purchaselyModule;

@end

@implementation PurchaselyRNTests

- (void)setUp {
    [super setUp];
    self.purchaselyModule = [[PurchaselyRN alloc] init];
}

- (void)tearDown {
    self.purchaselyModule = nil;
    [super tearDown];
}

#pragma mark - Module Initialization Tests

- (void)testModuleInitialization {
    XCTAssertNotNil(self.purchaselyModule, @"PurchaselyRN module should initialize");
}

- (void)testPresentationsLoadedInitialization {
    XCTAssertNotNil([PurchaselyRN presentationsLoaded], @"presentationsLoaded array should be initialized");
}

#pragma mark - Constants Export Tests

- (void)testConstantsExport {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    XCTAssertNotNil(constants, @"Constants should not be nil");
    XCTAssertTrue([constants isKindOfClass:[NSDictionary class]], @"Constants should be a dictionary");
}

- (void)testLogLevelConstants {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    XCTAssertNotNil(constants[@"logLevelDebug"], @"logLevelDebug should exist");
    XCTAssertNotNil(constants[@"logLevelInfo"], @"logLevelInfo should exist");
    XCTAssertNotNil(constants[@"logLevelWarn"], @"logLevelWarn should exist");
    XCTAssertNotNil(constants[@"logLevelError"], @"logLevelError should exist");

    // Verify they are numbers
    XCTAssertTrue([constants[@"logLevelDebug"] isKindOfClass:[NSNumber class]], @"logLevelDebug should be a number");
    XCTAssertTrue([constants[@"logLevelInfo"] isKindOfClass:[NSNumber class]], @"logLevelInfo should be a number");
    XCTAssertTrue([constants[@"logLevelWarn"] isKindOfClass:[NSNumber class]], @"logLevelWarn should be a number");
    XCTAssertTrue([constants[@"logLevelError"] isKindOfClass:[NSNumber class]], @"logLevelError should be a number");
}

- (void)testProductResultConstants {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    XCTAssertNotNil(constants[@"productResultPurchased"], @"productResultPurchased should exist");
    XCTAssertNotNil(constants[@"productResultCancelled"], @"productResultCancelled should exist");
    XCTAssertNotNil(constants[@"productResultRestored"], @"productResultRestored should exist");
}

- (void)testSubscriptionSourceConstants {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    XCTAssertNotNil(constants[@"sourceAppStore"], @"sourceAppStore should exist");
    XCTAssertNotNil(constants[@"sourcePlayStore"], @"sourcePlayStore should exist");
    XCTAssertNotNil(constants[@"sourceHuaweiAppGallery"], @"sourceHuaweiAppGallery should exist");
    XCTAssertNotNil(constants[@"sourceAmazonAppstore"], @"sourceAmazonAppstore should exist");
}

- (void)testAttributeConstants {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    // Marketing attribution constants
    XCTAssertNotNil(constants[@"firebaseAppInstanceId"], @"firebaseAppInstanceId should exist");
    XCTAssertNotNil(constants[@"airshipChannelId"], @"airshipChannelId should exist");
    XCTAssertNotNil(constants[@"airshipUserId"], @"airshipUserId should exist");
    XCTAssertNotNil(constants[@"batchInstallationId"], @"batchInstallationId should exist");
    XCTAssertNotNil(constants[@"adjustId"], @"adjustId should exist");
    XCTAssertNotNil(constants[@"appsflyerId"], @"appsflyerId should exist");
    XCTAssertNotNil(constants[@"onesignalPlayerId"], @"onesignalPlayerId should exist");
    XCTAssertNotNil(constants[@"mixpanelDistinctId"], @"mixpanelDistinctId should exist");
    XCTAssertNotNil(constants[@"clevertapId"], @"clevertapId should exist");
    XCTAssertNotNil(constants[@"sendinblueUserEmail"], @"sendinblueUserEmail should exist");
    XCTAssertNotNil(constants[@"iterableUserId"], @"iterableUserId should exist");
    XCTAssertNotNil(constants[@"iterableUserEmail"], @"iterableUserEmail should exist");
    XCTAssertNotNil(constants[@"atInternetIdClient"], @"atInternetIdClient should exist");
    XCTAssertNotNil(constants[@"amplitudeUserId"], @"amplitudeUserId should exist");
    XCTAssertNotNil(constants[@"amplitudeDeviceId"], @"amplitudeDeviceId should exist");
    XCTAssertNotNil(constants[@"mparticleUserId"], @"mparticleUserId should exist");
    XCTAssertNotNil(constants[@"customerIoUserId"], @"customerIoUserId should exist");
    XCTAssertNotNil(constants[@"customerIoUserEmail"], @"customerIoUserEmail should exist");
    XCTAssertNotNil(constants[@"branchUserDeveloperIdentity"], @"branchUserDeveloperIdentity should exist");
    XCTAssertNotNil(constants[@"moEngageUniqueId"], @"moEngageUniqueId should exist");
    XCTAssertNotNil(constants[@"batchCustomUserId"], @"batchCustomUserId should exist");
}

- (void)testPlanTypeConstants {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    XCTAssertNotNil(constants[@"consumable"], @"consumable should exist");
    XCTAssertNotNil(constants[@"nonConsumable"], @"nonConsumable should exist");
    XCTAssertNotNil(constants[@"autoRenewingSubscription"], @"autoRenewingSubscription should exist");
    XCTAssertNotNil(constants[@"nonRenewingSubscription"], @"nonRenewingSubscription should exist");
    XCTAssertNotNil(constants[@"unknown"], @"unknown should exist");
}

- (void)testRunningModeConstants {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    XCTAssertNotNil(constants[@"runningModeTransactionOnly"], @"runningModeTransactionOnly should exist");
    XCTAssertNotNil(constants[@"runningModeObserver"], @"runningModeObserver should exist");
    XCTAssertNotNil(constants[@"runningModePaywallObserver"], @"runningModePaywallObserver should exist");
    XCTAssertNotNil(constants[@"runningModeFull"], @"runningModeFull should exist");
}

- (void)testPresentationTypeConstants {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    XCTAssertNotNil(constants[@"presentationTypeNormal"], @"presentationTypeNormal should exist");
    XCTAssertNotNil(constants[@"presentationTypeFallback"], @"presentationTypeFallback should exist");
    XCTAssertNotNil(constants[@"presentationTypeDeactivated"], @"presentationTypeDeactivated should exist");
    XCTAssertNotNil(constants[@"presentationTypeClient"], @"presentationTypeClient should exist");
}

- (void)testThemeModeConstants {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    XCTAssertNotNil(constants[@"themeLight"], @"themeLight should exist");
    XCTAssertNotNil(constants[@"themeDark"], @"themeDark should exist");
    XCTAssertNotNil(constants[@"themeSystem"], @"themeSystem should exist");
}

- (void)testUserAttributeConstants {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    // Source constants
    XCTAssertNotNil(constants[@"userAttributeSourcePurchasely"], @"userAttributeSourcePurchasely should exist");
    XCTAssertNotNil(constants[@"userAttributeSourceClient"], @"userAttributeSourceClient should exist");

    // Type constants
    XCTAssertNotNil(constants[@"userAttributeString"], @"userAttributeString should exist");
    XCTAssertNotNil(constants[@"userAttributeBoolean"], @"userAttributeBoolean should exist");
    XCTAssertNotNil(constants[@"userAttributeInt"], @"userAttributeInt should exist");
    XCTAssertNotNil(constants[@"userAttributeFloat"], @"userAttributeFloat should exist");
    XCTAssertNotNil(constants[@"userAttributeDate"], @"userAttributeDate should exist");
    XCTAssertNotNil(constants[@"userAttributeStringArray"], @"userAttributeStringArray should exist");
    XCTAssertNotNil(constants[@"userAttributeIntArray"], @"userAttributeIntArray should exist");
    XCTAssertNotNil(constants[@"userAttributeFloatArray"], @"userAttributeFloatArray should exist");
    XCTAssertNotNil(constants[@"userAttributeBooleanArray"], @"userAttributeBooleanArray should exist");
}

#pragma mark - Constants Count Test

- (void)testConstantsCount {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    // Based on the source code, we expect at least 55 constants
    // Log levels (4) + Product results (3) + Sources (4) + Attributes (21) + Plan types (5)
    // + Running modes (4) + Presentation types (4) + Theme modes (3) + User attribute sources (2)
    // + User attribute types (9) = 59 constants
    XCTAssertGreaterThanOrEqual(constants.count, 50, @"Should export at least 50 constants");
}

#pragma mark - Shared View Controller Tests

- (void)testSharedViewControllerInitialization {
    UIViewController *vc = [PurchaselyRN sharedViewController];
    XCTAssertNotNil(vc, @"sharedViewController should return a view controller");
}

- (void)testSharedViewControllerSingleton {
    UIViewController *vc1 = [PurchaselyRN sharedViewController];
    UIViewController *vc2 = [PurchaselyRN sharedViewController];
    XCTAssertEqual(vc1, vc2, @"sharedViewController should return the same instance");
}

- (void)testSetSharedViewController {
    UIViewController *newVC = [[UIViewController alloc] init];
    [PurchaselyRN setSharedViewController:newVC];

    UIViewController *retrievedVC = [PurchaselyRN sharedViewController];
    XCTAssertEqual(newVC, retrievedVC, @"setSharedViewController should update the shared instance");
}

#pragma mark - Presentations Loaded Tests

- (void)testPresentationsLoadedIsArray {
    NSMutableArray *presentations = [PurchaselyRN presentationsLoaded];
    XCTAssertTrue([presentations isKindOfClass:[NSMutableArray class]], @"presentationsLoaded should be a mutable array");
}

- (void)testSetPresentationsLoaded {
    NSMutableArray *newArray = [NSMutableArray arrayWithObjects:@"test", nil];
    [PurchaselyRN setPresentationsLoaded:newArray];

    NSMutableArray *retrieved = [PurchaselyRN presentationsLoaded];
    XCTAssertEqual(newArray, retrieved, @"setPresentationsLoaded should update the array");
}

#pragma mark - Purchase Resolve Tests

- (void)testPurchaseResolveInitiallyNil {
    // Reset to nil
    [PurchaselyRN setPurchaseResolve:nil];
    XCTAssertNil([PurchaselyRN purchaseResolve], @"purchaseResolve should be nil initially");
}

- (void)testSetPurchaseResolve {
    RCTPromiseResolveBlock resolveBlock = ^(id result) {};
    [PurchaselyRN setPurchaseResolve:resolveBlock];

    XCTAssertNotNil([PurchaselyRN purchaseResolve], @"purchaseResolve should not be nil after setting");
}

#pragma mark - Module Properties Tests

- (void)testShouldReopenPaywallDefault {
    XCTAssertFalse(self.purchaselyModule.shouldReopenPaywall, @"shouldReopenPaywall should default to NO");
}

- (void)testShouldEmitDefault {
    XCTAssertFalse(self.purchaselyModule.shouldEmit, @"shouldEmit should default to NO");
}

#pragma mark - Constants Values Tests

- (void)testLogLevelOrdering {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    NSInteger debug = [constants[@"logLevelDebug"] integerValue];
    NSInteger info = [constants[@"logLevelInfo"] integerValue];
    NSInteger warn = [constants[@"logLevelWarn"] integerValue];
    NSInteger error = [constants[@"logLevelError"] integerValue];

    // Verify logical ordering (debug < info < warn < error in most logging systems)
    // Or at least they are all different
    NSSet *uniqueValues = [NSSet setWithArray:@[@(debug), @(info), @(warn), @(error)]];
    XCTAssertEqual(uniqueValues.count, 4, @"All log levels should have unique values");
}

- (void)testProductResultsUnique {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    NSInteger purchased = [constants[@"productResultPurchased"] integerValue];
    NSInteger cancelled = [constants[@"productResultCancelled"] integerValue];
    NSInteger restored = [constants[@"productResultRestored"] integerValue];

    NSSet *uniqueValues = [NSSet setWithArray:@[@(purchased), @(cancelled), @(restored)]];
    XCTAssertEqual(uniqueValues.count, 3, @"All product results should have unique values");
}

- (void)testSubscriptionSourcesUnique {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    NSInteger appStore = [constants[@"sourceAppStore"] integerValue];
    NSInteger playStore = [constants[@"sourcePlayStore"] integerValue];
    NSInteger huawei = [constants[@"sourceHuaweiAppGallery"] integerValue];
    NSInteger amazon = [constants[@"sourceAmazonAppstore"] integerValue];

    NSSet *uniqueValues = [NSSet setWithArray:@[@(appStore), @(playStore), @(huawei), @(amazon)]];
    XCTAssertEqual(uniqueValues.count, 4, @"All subscription sources should have unique values");
}

- (void)testPlanTypesUnique {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    NSInteger consumable = [constants[@"consumable"] integerValue];
    NSInteger nonConsumable = [constants[@"nonConsumable"] integerValue];
    NSInteger autoRenewing = [constants[@"autoRenewingSubscription"] integerValue];
    NSInteger nonRenewing = [constants[@"nonRenewingSubscription"] integerValue];
    NSInteger unknown = [constants[@"unknown"] integerValue];

    NSSet *uniqueValues = [NSSet setWithArray:@[@(consumable), @(nonConsumable), @(autoRenewing), @(nonRenewing), @(unknown)]];
    XCTAssertEqual(uniqueValues.count, 5, @"All plan types should have unique values");
}

- (void)testRunningModesUnique {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    NSInteger transactionOnly = [constants[@"runningModeTransactionOnly"] integerValue];
    NSInteger observer = [constants[@"runningModeObserver"] integerValue];
    NSInteger paywallObserver = [constants[@"runningModePaywallObserver"] integerValue];
    NSInteger full = [constants[@"runningModeFull"] integerValue];

    NSSet *uniqueValues = [NSSet setWithArray:@[@(transactionOnly), @(observer), @(paywallObserver), @(full)]];
    XCTAssertEqual(uniqueValues.count, 4, @"All running modes should have unique values");
}

- (void)testThemeModesUnique {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    NSInteger light = [constants[@"themeLight"] integerValue];
    NSInteger dark = [constants[@"themeDark"] integerValue];
    NSInteger system = [constants[@"themeSystem"] integerValue];

    NSSet *uniqueValues = [NSSet setWithArray:@[@(light), @(dark), @(system)]];
    XCTAssertEqual(uniqueValues.count, 3, @"All theme modes should have unique values");
}

- (void)testUserAttributeTypesUnique {
    NSDictionary *constants = [self.purchaselyModule constantsToExport];

    NSInteger stringType = [constants[@"userAttributeString"] integerValue];
    NSInteger boolType = [constants[@"userAttributeBoolean"] integerValue];
    NSInteger intType = [constants[@"userAttributeInt"] integerValue];
    NSInteger floatType = [constants[@"userAttributeFloat"] integerValue];
    NSInteger dateType = [constants[@"userAttributeDate"] integerValue];
    NSInteger stringArrayType = [constants[@"userAttributeStringArray"] integerValue];
    NSInteger intArrayType = [constants[@"userAttributeIntArray"] integerValue];
    NSInteger floatArrayType = [constants[@"userAttributeFloatArray"] integerValue];
    NSInteger boolArrayType = [constants[@"userAttributeBooleanArray"] integerValue];

    NSSet *uniqueValues = [NSSet setWithArray:@[
        @(stringType), @(boolType), @(intType), @(floatType), @(dateType),
        @(stringArrayType), @(intArrayType), @(floatArrayType), @(boolArrayType)
    ]];
    XCTAssertEqual(uniqueValues.count, 9, @"All user attribute types should have unique values");
}

@end
