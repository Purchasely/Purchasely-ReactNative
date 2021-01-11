//
//  RCTConvert_PurchaselyRN.m
//  reactTutorialApp
//
//  Created by Jean-François GRANG on 15/11/2020.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTConvert.h>
#import <Purchasely/Purchasely-Swift.h>

@implementation RCTConvert (PurchaselyRN)

RCT_ENUM_CONVERTER(LogLevel, (@{ @"logLevelDebug": @(LogLevelDebug),
                                 @"logLevelInfo": @(LogLevelInfo),
                                 @"logLevelWarn": @(LogLevelWarn),
                                 @"logLevelError": @(LogLevelError)}),
                   LogLevelError, integerValue)

RCT_ENUM_CONVERTER(PLYProductViewControllerResult, (@{ @"productResultPurchased": @(PLYProductViewControllerResultPurchased),
                                                       @"productResultCancelled": @(PLYProductViewControllerResultCancelled),
                                                       @"productResultRestored": @(PLYProductViewControllerResultRestored)}),
                   PLYProductViewControllerResultPurchased, integerValue)

@end
