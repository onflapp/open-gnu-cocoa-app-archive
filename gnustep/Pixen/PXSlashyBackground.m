//  PXSlashyBackground.m
//  Pixen
//
//  Created by Joe Osborn on Thu Sep 18 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXSlashyBackground.h"


@implementation PXSlashyBackground

- defaultName
{
    return NSLocalizedString(@"SLASHED_BACKGROUND", @"Slashed Background");
}

- (void)drawBackgroundLinesInRect:(NSRect)aRect
{
  


    //rounding off the values in aRect... we can't have them being floating points, can we?
    NSRect rect = NSMakeRect((int)(aRect.origin.x), (int)(aRect.origin.y), (int)(aRect.size.width), (int)(aRect.size.height));
    float oldWidth = [NSBezierPath defaultLineWidth];
    BOOL oldShouldAntialias = [[NSGraphicsContext currentContext] shouldAntialias];
    [[NSGraphicsContext currentContext] setShouldAntialias:NO];
    [NSBezierPath setDefaultLineWidth:10];

#ifdef __COCOA__
    [color set];
#else
    [[colorWell color] set];
#endif
    int higherOrigin = (int)((rect.size.width >= rect.size.height) ? rect.origin.x : rect.origin.y);
    int higherDimension = 2*(int)((rect.size.width >= rect.size.height) ? rect.size.width : rect.size.height);
    int i = (int)(higherOrigin-higherDimension);
    while(i < (higherOrigin+higherDimension))
    {
        NSPoint startPoint = NSMakePoint(i-20, rect.origin.y-20);
        NSPoint endPoint = NSMakePoint(i+2*rect.size.width+20, rect.origin.y+2*rect.size.width+20);
        if(rect.size.height > rect.size.width)
        {
            startPoint = NSMakePoint(rect.origin.x-20, i-20);
            endPoint = NSMakePoint(rect.origin.x+2*rect.size.height+20, i+2*rect.size.height+20);
        }
        NSAssert(endPoint.x-startPoint.x == endPoint.y-startPoint.y, @"Bad points!");
        [NSBezierPath strokeLineFromPoint:startPoint toPoint:endPoint];
        i+=33;
    }
    [NSBezierPath setDefaultLineWidth:oldWidth];
    [[NSGraphicsContext currentContext] setShouldAntialias:oldShouldAntialias];
}

- (void)drawRect:(NSRect)rect withinRect:(NSRect)wholeRect
{
#ifdef __COCOA__
    [backColor set];
#else
    [[backWell color] set];
#endif
    
    NSRectFill(wholeRect);
    [self drawBackgroundLinesInRect:wholeRect];
}

@end
