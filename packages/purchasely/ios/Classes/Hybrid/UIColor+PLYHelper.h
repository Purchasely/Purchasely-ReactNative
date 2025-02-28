//
//  PLYHelper+NSColor.h
//  Purchasely
//
//  Created by Jean-François GRANG on 21/12/2022.
//  Copyright © 2022 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIColor (PLYHelper)

+ (UIColor * _Nullable)ply_fromHex:(NSString *)hex;

@end

NS_ASSUME_NONNULL_END
