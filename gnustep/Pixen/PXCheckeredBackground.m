//
//  PXCheckeredBackground.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Tue Oct 28 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXCheckeredBackground.h"


@implementation PXCheckeredBackground

- defaultName
{
    return NSLocalizedString(@"CHECKERED_BACKGROUND", @"Checkered Background");
}

- (void)drawRect:(NSRect)rect withinRect:(NSRect)wholeRect
{
#ifdef __COCOA__
    [backColor set];
#else
    [[backWell color] set];
#endif
    NSRectFill(wholeRect);
#ifdef __COCOA__
    [color set];
#else
    [[colorWell color] set];
#endif
    int i, j;
    BOOL drawForeground = NO;
    for(i = 0; i < wholeRect.size.width; i+=10)
    {
        drawForeground = i % 20 == 0;
        for(j = 0; j < wholeRect.size.height; j+=10)
        {
            if(drawForeground)
            {
                NSRectFill(NSMakeRect(wholeRect.origin.x+i, wholeRect.origin.y+j, 10, 10));
            }
            drawForeground = !drawForeground;
        }
    }
}

@end
