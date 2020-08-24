//  PXPixel.h
//  Pixen
//
//  Created by Joe Osborn on Thu Sep 11 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface PXPixel : NSObject <NSCoding, NSCopying>{
    NSColor * color;
}

+ withColor:aColor;
- initWithColor:aColor;
- (void)dealloc;

- color;
- (void)setColor:aColor;

- (void)drawAtPoint:(NSPoint)aPoint withOpacity:(float)anOpacity;
- copyWithZone:(NSZone *)zone;

@end
