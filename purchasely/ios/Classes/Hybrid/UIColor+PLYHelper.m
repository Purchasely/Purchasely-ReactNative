//
//  NSColor+PLYHelper.m
//  Purchasely
//
//  Created by Jean-François GRANG on 21/12/2022.
//  Copyright © 2022 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIColor+PLYHelper.h"

@implementation UIColor (PLYHelper)

+ (UIColor * _Nullable)ply_fromHex:(NSString *)hex {

	NSString *cString = [hex stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

	if ([cString length] == 0) {
		return nil;
	}

	if ([cString characterAtIndex:0] == '#') {
		cString = [cString substringFromIndex:1];
	}

	if (cString.length != 6 && cString.length != 8) {
		return nil;
	}

	unsigned colorCode = 0;
	unsigned char redByte, greenByte, blueByte, alphaByte;

	NSScanner* scanner = [NSScanner scannerWithString:cString];
	(void) [scanner scanHexInt:&colorCode];

	if (cString.length == 6) {
		redByte = (unsigned char)(colorCode >> 16);
		greenByte = (unsigned char)(colorCode >> 8);
		blueByte = (unsigned char)(colorCode);
		
		return [UIColor
				colorWithRed:(CGFloat)redByte / 0xff
				green:(CGFloat)greenByte / 0xff
				blue:(CGFloat)blueByte / 0xff
				alpha:1.0];
	}

	if (cString.length == 8) {
		redByte = (unsigned char)(colorCode >> 24);
		greenByte = (unsigned char)(colorCode >> 16);
		blueByte = (unsigned char)(colorCode >> 8);
		alphaByte = (unsigned char)(colorCode);

		return [UIColor
				colorWithRed:(CGFloat)redByte / 0xff
				green:(CGFloat)greenByte / 0xff
				blue:(CGFloat)blueByte / 0xff
				alpha:(CGFloat)alphaByte / 0xff];
	}


	return nil;
}


@end
