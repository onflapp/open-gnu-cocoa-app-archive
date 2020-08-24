/* VGraphic.m
 * Graphic object - root class
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-29
 * modified: 2011-05-28 (excluded, -isExcluded, -setExcluded:, +initialize: version=5)
 *           2011-04-06 (-drawStartAtScale: added)
 *           2011-03-04 (-size, -setSize: default implementation to make it work for all objects)
 *           2010-07-28 (-setLabel:, -label added, version = 4)
 *           2010-07-08 (-transform: added)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by vhf interservice GmbH. Among other things, the
 * License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this program; see the file LICENSE. If not, write to vhf.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#include <AppKit/AppKit.h>
#include "../App.h"
#include "../DocWindow.h"
#include "../Document.h"
#include "../DocView.h"	// scaleFactor, mustDrawPale
#include "VGraphic.h"

@implementation VGraphic

/* The fastKnobFill optimization just keeps a list of black and dark gray
 * rectangles (the knobbies are made out of black and dark gray rectangles)
 * and emits them in a single NSRectFillList() which is much faster than
 * doing individual rectfills (we also save the repeated setgrays).
 */
static NSRect *lgrayRectList  = NULL;
static int lgrayRectSize   = 0;
static int lgrayRectCount  = 0;
static NSRect *blackRectList  = NULL;
static int blackRectSize   = 0;
static int blackRectCount  = 0;
static NSRect *dkgrayRectList = NULL;
static int dkgrayRectSize  = 0;
static int dkgrayRectCount = 0;


+ (float)maxKnobSizeWithScale:(float)scaleFactor
{
    return (KNOBSIZE+4.0) / scaleFactor;    // 2008-02-25: was 2.0
}

+ fastKnobFill:(NSRect)aRect isBlack:(int)isBlack
{
    if ( isBlack == YES )
    {
        if (!blackRectList)
        {   blackRectSize = 16;
            blackRectList = NSZoneMalloc((NSZone *)[(NSObject *)NSApp zone], (blackRectSize) * sizeof(NSRect));
        }
        else if ( blackRectCount >= blackRectSize )
        {
            while (blackRectCount >= blackRectSize)
                    blackRectSize <<= 1;
            blackRectList = NSZoneRealloc((NSZone *)[(NSObject *)NSApp zone], blackRectList, (blackRectSize) * sizeof(NSRect));
        }
        blackRectList[blackRectCount++] = aRect;
    }
    else if ( isBlack == NO )
    {
        if (!dkgrayRectList)
        {   dkgrayRectSize = 16;
            dkgrayRectList = NSZoneMalloc((NSZone *)[(NSObject *)NSApp zone], (dkgrayRectSize) * sizeof(NSRect));
        }
        else if ( dkgrayRectCount >= dkgrayRectSize )
        {
            while (dkgrayRectCount >= dkgrayRectSize)
                dkgrayRectSize <<= 1;
            dkgrayRectList = NSZoneRealloc((NSZone *)[(NSObject *)NSApp zone], dkgrayRectList, (dkgrayRectSize) * sizeof(NSRect));
        }
        dkgrayRectList[dkgrayRectCount++] = aRect;
    }
    else // 2
    {
        if (!lgrayRectList)
        {   lgrayRectSize = 16;
            lgrayRectList = NSZoneMalloc((NSZone *)[(NSObject *)NSApp zone], (lgrayRectSize) * sizeof(NSRect));
        }
        else if ( lgrayRectCount >= lgrayRectSize )
        {
            while (lgrayRectCount >= lgrayRectSize)
                lgrayRectSize <<= 1;
            lgrayRectList = NSZoneRealloc((NSZone *)[(NSObject *)NSApp zone], lgrayRectList, (lgrayRectSize) * sizeof(NSRect));
        }
        lgrayRectList[lgrayRectCount++] = aRect;
    }

    return self;
}

+ (void)showFastKnobFills
{
    if (lgrayRectCount)
    {   [[NSColor whiteColor] set]; // lightGrayColor
        NSRectFillList(lgrayRectList, lgrayRectCount);
        lgrayRectCount = 0;
    }
    if (blackRectCount)
    {   [[NSColor blackColor] set];
        NSRectFillList(blackRectList, blackRectCount);
        blackRectCount = 0;
    }
    if (dkgrayRectCount)
    {   [[NSColor lightGrayColor] set];
        NSRectFillList(dkgrayRectList, dkgrayRectCount);
        dkgrayRectCount = 0;
    }
}

/* Draws the knob
 * direct=YES draws the knob directly to the view
 * direct=NO draws the knob to the rectlist to be shown with showFastRectList
 */
static void drawKnob( NSPoint origin, BOOL direct, BOOL selectedKnob, float scaleFactor )
{   NSRect	knob;
    float	scale = 1.0 / scaleFactor;
    float	knobsize = (selectedKnob) ? KNOBSIZE+3.0 : KNOBSIZE+1;  // 2008-02-25: was: KNOBSIZE+2.0 : KNOBSIZE;

    knob.size.width = knob.size.height = knobsize*scale;
    knob.origin.x = origin.x - ((knobsize - 1.0) / 2.0)*scale;
    knob.origin.y = origin.y - ((knobsize - 1.0) / 2.0)*scale;
    if ( direct )
        NSRectFill(knob);
    else
        [VGraphic fastKnobFill:knob isBlack:2]; // lgrayRectList

    knob.origin.x = origin.x - ((knobsize - 3.0) / 2.0)*scale;
    knob.origin.y = origin.y - ((knobsize - 3.0) / 2.0)*scale;
    knob.size.width = knob.size.height = (knobsize-2.0)*scale;
    if ( direct )
        NSRectFill(knob);
    else
        [VGraphic fastKnobFill:knob isBlack:YES];

}
/* Draws the control knobs
 * direct=YES draws the knob directly to the view
 * direct=NO draws the knob to the rectlist to be shown with showFastRectList
 */
static void drawControl( NSPoint origin, BOOL direct, BOOL selectedKnob, float scaleFactor )
{   NSRect	knob;
    float	scale = 1.0 / scaleFactor;
    float	knobsize = (selectedKnob) ? KNOBSIZE+2.0 : KNOBSIZE;

    knob.size.width = knob.size.height = knobsize*scale;
    knob.origin.x = origin.x - ((knobsize - 1.0) / 2.0)*scale;
    knob.origin.y = origin.y - ((knobsize - 1.0) / 2.0)*scale;
    if ( direct )
        NSRectFill(knob);
    else
        [VGraphic fastKnobFill:knob isBlack:YES];

    knob.origin.x = origin.x - ((knobsize - 3.0) / 2.0)*scale;
    knob.origin.y = origin.y - ((knobsize - 3.0) / 2.0)*scale;
    knob.size.width = knob.size.height = (knobsize-2.0)*scale;
    if ( direct )
        NSRectFill(knob);
    else
        [VGraphic fastKnobFill:knob isBlack:NO];
}


/*
 * This sets the class version so that we can compatibly read
 * old VGraphic objects out of an archive.
 */
+ (void)initialize
{
    [VGraphic setVersion:5];
    return;
}

+ (VGraphic*)graphic
{
    return [[[self allocWithZone:[self zone]] init] autorelease];
}

+ currentView
{   DocWindow	*window = (DocWindow*)[NSApp mainWindow];
    id		view;

    if ([window isMemberOfClass:[DocWindow class]])
    {	id	docu = [window document];
        if ([docu isMemberOfClass:[Document class]])
            return [docu documentView];
    }
    else if ((view = [[(App*)NSApp currentDocument] documentView]))
        return view;
    NSLog(@"VGraphic, +currentView: No current view!");
    return nil;
}

+ currentWindow
{   DocWindow	*window = (DocWindow*)[NSApp mainWindow];

    if ([window isMemberOfClass:[DocWindow class]])
        return window;
    else
        return [[[(App*)NSApp currentDocument] documentView] window];
    return nil;
}

+ (NSArray*)objectsOfClass:(Class)cls inArray:(NSArray*)array
{   int             i;
    NSMutableArray  *mArray = nil;

    for ( i=[array count]-1; i>=0; i-- )
    {   VGraphic	*g = [array objectAtIndex:i];

        if ( [g isMemberOfClass:cls] )
        {
            if ( !mArray )
                mArray = [NSMutableArray array];
            [mArray addObject:g];
        }
    }
    return mArray;
}

- init
{
    pmList = [NSMutableArray new];
    label = nil;
    color = [[NSColor blackColor] retain];
    isDirectionCCW = YES;
    dirty = YES;	// needs calculation of output

    relief = NO; reliefType = reliefDirection = 0; reliefFlatness = 1.0;

    return self;
}

/* deep copy object
 * overwritten by subclasses
 */
- copy
{   NSMutableData   *data = [[NSMutableData alloc] init];
    NSArchiver      *ts;
    id              g;

    /* writes the path to a NSData object and reads it back from it */
    ts = [[NSArchiver alloc] initForWritingWithMutableData:data];
    [ts encodeRootObject:self];
    [ts release];

    ts = [[NSUnarchiver alloc] initForReadingWithData:data];
    g = [[ts decodeObject] retain];
    [ts release];
    [data release];
    [g setDirty:YES];

    return g;
}


- (NSString*)description
{
    return [NSString stringWithFormat:@"%@: id = '%@', width = %f", [self title], (label) ? label : @"", width];
}

- (NSString *)title
{
    return NSLocalizedString( [(NSObject *)[self class] description], nil );
}

- (NSMutableArray*)pmList	{ return pmList; }	// list of segments we are in

/* YES = object is selected */
- (BOOL)isSelected		{ return isSelected; }
- (void)setSelected:(BOOL)flag	{ isSelected = flag; }
- (int)selectedKnobIndex	{ return -1; }

- (void)setLabel:(NSString*)newLabel    { [label release]; label = [newLabel retain]; }
- (NSString*)label                      { return label; }

- (void)setColor:(NSColor *)col
{
    if (color)
        [color release];
    color = [col retain];
}
- (NSColor *)color
{
    return color;
}

- (NSColor *)separationColor:(NSColor *)col
{   NSColor	*sepColor = nil;
    NSColor	*curColToSeparate = [[[self class] currentView] separationColor]; // cmyk || bw || special

    if ([[col colorSpaceName] isEqual:@"NSCalibratedWhiteColorSpace"]) // draw only in black file !
    {
        if (col && [curColToSeparate blackComponent]) // black
            sepColor = col; // [NSColor colorWithCalibratedWhite:[col whiteComponent] alpha:1.0];
        else
            sepColor = [NSColor whiteColor];
    }
    else if ([[curColToSeparate colorSpaceName] isEqual:@"NSDeviceCMYKColorSpace"])
    {   float	c = 0, m = 0, y = 0, k = 0;

        if ([[col colorSpaceName] isEqual:@"NSDeviceCMYKColorSpace"])
        {   c = [col cyanComponent];
            m = [col magentaComponent];
            y = [col yellowComponent];
            k = [col blackComponent];
        }
        else // rgb
        {   c = 1.0 - [col redComponent];
            m = 1.0 - [col greenComponent];
            y = 1.0 - [col blueComponent];
            if (c >= 0.9999 && m >= 0.9999 && y >= 0.9999)
            {   /* realy black */
                c = 0.5;
                m = y = 0;
                k = 1.0;
            }
            else if (Min(c, Min(m, y)) > 0.0001)
            {   float	min = Min(c, Min(m, y));

                k = min;
                c -= min;
                m -= min;
                y -= min;
            }
        }
        col = [col colorUsingColorSpaceName:@"NSDeviceCMYKColorSpace"];
        if (col && [curColToSeparate cyanComponent]) // cyan
            sepColor = [NSColor colorWithCalibratedWhite:1.0-c alpha:1.0];
        else if (col && [curColToSeparate magentaComponent]) // magenta
            sepColor = [NSColor colorWithCalibratedWhite:1.0-m alpha:1.0];
        else if (col && [curColToSeparate yellowComponent]) // yellow
            sepColor = [NSColor colorWithCalibratedWhite:1.0-y alpha:1.0];
        else if (col && [curColToSeparate blackComponent]) // black
            sepColor = [NSColor colorWithCalibratedWhite:1.0-k alpha:1.0];
        else
            sepColor = [NSColor whiteColor];
    }
    else if (col && [col isEqual:curColToSeparate]) // custom
        sepColor = [NSColor blackColor]; // full custom color
    else
        sepColor = [NSColor whiteColor]; // white
    return sepColor;
}

- (void)setWidth_ptr:(float*)w
{
    [self setWidth:*w];
}
- (void)setWidth:(float)w
{
    width = w;
    dirty = YES;
}
- (float)width
{
    return width;
}

/* intended to be subclassed
 */
- (float)length
{
    return 0.0;
}
- (void)setLength:(float)l
{
}

- (void)setSize:(NSSize)newSize
{   NSRect	bRect = [self coordBounds];

    [self scale:((bRect.size.width)  ? newSize.width /bRect.size.width  : 1.0)
               :((bRect.size.height) ? newSize.height/bRect.size.height : 1.0)
     withCenter:bRect.origin];
}
- (NSSize)size
{   NSRect	bRect = [self coordBounds];
    return bRect.size;
}

- (void)setRadius:(float)r
{
    NSLog(@"method -setRadius: not implemented");
}
- (float)radius
{
    NSLog(@"method -radius not implemented");
    return 0.0;
}

- (BOOL)isExcluded              { return isExcluded; }
- (void)setExcluded:(BOOL)flag  { isExcluded = flag; }

- (BOOL)isLocked                { return isLocked; }
- (void)setLocked:(BOOL)l       { isLocked = l; }

- (float)angle
{
    return 0.0;
}

- (BOOL)filled
{
    return NO;
}
- (void)setFilled:(BOOL)flag
{
}

/* created: 02.04.98
 * purpose: return the gradient (delta x, y, z) of the object at t
 */
- (NSPoint)gradientAt:(float)t
{
    return NSMakePoint(0.0, 0.0);
}

/* created: 05.03.97
 */
- (NSPoint)center
{   NSRect	rect;
    NSPoint	p;

    rect = [self bounds];
    p.x = rect.origin.x + rect.size.width/2.0;
    p.y = rect.origin.y + rect.size.height/2.0;
    return p;
}

- parallelObject:(NSPoint)begO :(NSPoint)endO :(NSPoint)beg :(NSPoint)end
{
    return nil;
}

/* created:  05.03.97
 */
- (void)drawAtAngle:(float)angle in:view
{
    [self drawAtAngle:angle withCenter:[self center] in:view];
}

- (void)drawAtAngle:(float)angle withCenter:(NSPoint)cp in:view
{
    [self drawWithPrincipal:view];
}

/* created:  05.03.97
 */
- (void)rotate:(float)angle
{
    [self setAngle:angle withCenter:[self center]];
}

- (float)rotAngle
{
    return 0.0;
}

- (void)setAngle:(float)angle withCenter:(NSPoint)cp
{
	 
}

- (BOOL)create:(NSEvent *)event in:view
{
    return NO;
}

- (void)transform:(NSAffineTransform*)matrix
{   NSSize  size = NSMakeSize(width, width);

    size = [matrix transformSize:size];
    width = (Abs(size.width) + Abs(size.height)) / 2;
}

- (void)scale:(float)x :(float)y withCenter:(NSPoint)cp
{
	 
}

/* modified: 05.03.97
 */
- (void)mirror
{
    [self mirrorAround:[self center]];
}

- (void)mirrorAround:(NSPoint)p
{
}

- (void)changeDirection
{
}

- (void)drawColorPale:(BOOL)drawPale
{
    if ( drawPale )
    {   CGFloat h, s, b, a;

        [[color colorUsingColorSpaceName:NSDeviceRGBColorSpace] getHue:&h saturation:&s brightness:&b alpha:&a];
        [[NSColor colorWithCalibratedHue:h saturation:s brightness:(b<0.5) ? 0.5 : b alpha:a] set];
    }
#if !defined(GNUSTEP_BASE_VERSION) && !defined(__APPLE__)	// OpenStep 4.2
    else if (VHFIsDrawingToScreen() && [[color colorSpaceName] isEqualToString:NSDeviceCMYKColorSpace])
        [[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace] set];
#endif
    else
        [color set];
}

- (void)drawWithPrincipal:principal
{
    [self drawColorPale:[principal mustDrawPale]];
}

/*
 * Draws the graphic inside rect.  If rect is an "empty" rect, then it draws
 * the entire VGraphic.  If the VGraphic is not intersected by rect, then it
 * is not drawn at all.  If the VGraphic is selected, it is drawn with
 * its knobbies.  This method is not intended to be overridden.  It
 * calls the overrideable method "draw" which doesn't have to worry
 * about drawing the knobbies.
 *
 * Note the showFastKnobFills optimization here.  If this VGraphic is
 * opaque then there is a possibility that it might obscure knobbies
 * of Graphics underneath it, so we must emit the cached rectfills
 * before drawing this VGraphic.
 *
 * modified: 2008-02-25 (VImage added)
 */
- (void)drawControls:(NSRect)rect direct:(BOOL)direct scaleFactor:(float)scaleFactor
{
    // [self drawKnobs:rect direct:direct scaleFactor:scaleFactor];
    if ( (NSIsEmptyRect(rect) ||
          !NSIsEmptyRect(NSIntersectionRect(rect, [self extendedBoundsWithScale:scaleFactor]))) )
    {
        if ( VHFIsDrawingToScreen() && isSelected )
        {   int	i;

            if ( ![self isKindOfClass:[VRectangle class]] && ![self isKindOfClass:[VText class]] &&
                 ![self isKindOfClass:[VImage class]])
            {
                for ( i=[self numPoints]-2; i>0; i-- )
                    drawControl( [self pointWithNum:i], direct, [self selectedKnobIndex]==i, scaleFactor );
            }
        }
    }
}
/* draw only the start and end point - VRectangle, VText
 * modified: 2008-02-25 (==i instead of ==0)
 */
- (void)drawKnobs:(NSRect)rect direct:(BOOL)direct scaleFactor:(float)scaleFactor
{
    if ( (NSIsEmptyRect(rect) ||
          !NSIsEmptyRect(NSIntersectionRect(rect, [self extendedBoundsWithScale:scaleFactor]))) )
    {
        if ( VHFIsDrawingToScreen() && isSelected )
        {
            if ( [self isKindOfClass:[VRectangle class]] || [self isKindOfClass:[VText class]] ||
                 [self isKindOfClass:[VImage class]] )
            {   int	i;

                for ( i=[self numPoints]-1; i>=0; i-- )
                    drawKnob([self pointWithNum:i], direct, [self selectedKnobIndex]==i, scaleFactor);
            }
            else
            {   drawKnob([self pointWithNum:0], direct, [self selectedKnobIndex]==0, scaleFactor);
                drawKnob([self pointWithNum:MAXINT], direct, [self selectedKnobIndex]==[self numPoints]-1, scaleFactor);
            }
        }
    }
}

/* direction
 */
- (BOOL)isDirectionCCW			{ return isDirectionCCW; }
- (void)drawDirectionAtScale:(float)scaleFactor
{   NSPoint		p0, p;
    float		a, scale = 1.0 / scaleFactor;
    NSBezierPath	*bPath = [NSBezierPath bezierPath];

    p = [self gradientAt:0.0];
    a = (!p.x) ?  ((p.y>0)?90.0:270.0) : RadToDeg(atan(p.y/p.x));
    if (p.x < 0)
        a += 180.0;
    p0 = [self pointAt:0.0];

    PSgsave();
    [[NSColor blackColor] set];
    [bPath setLineWidth:0.0];
    [bPath moveToPoint:p0];
    p = vhfPointRotatedAroundCenter(NSMakePoint(p0.x, p0.y - 2.5*scale), a, p0);
    [bPath lineToPoint:p];
    p = vhfPointRotatedAroundCenter(NSMakePoint(p0.x + 7.0*scale, p0.y), a, p0);
    [bPath lineToPoint:p];
    p = vhfPointRotatedAroundCenter(NSMakePoint(p0.x, p0.y + 2.5*scale), a, p0);
    [bPath lineToPoint:p];
    [bPath lineToPoint:p0];
    [bPath fill];
    PSgrestore();
}

- (void)drawStartAtScale:(float)scaleFactor
{   NSPoint         p0, p;
    float           a, scale = 1.0 / scaleFactor;
    NSBezierPath    *bPath = [NSBezierPath bezierPath];

    p = [self gradientAt:0.0];
    a = (!p.x) ?  ((p.y>0)?90.0:270.0) : RadToDeg(atan(p.y/p.x));
    if (p.x < 0)
        a += 180.0;
    p0 = [self pointAt:0.0];

    PSgsave();
    [[NSColor blackColor] set];
    [bPath setLineWidth:0.0];
    [bPath moveToPoint:p0];
    p = vhfPointRotatedAroundCenter(NSMakePoint(p0.x, p0.y - 6*scale), a, p0);
    [bPath lineToPoint:p];
    p = vhfPointRotatedAroundCenter(NSMakePoint(p0.x+2*scale, p0.y - 6*scale), a, p0);
    [bPath lineToPoint:p];
    p = vhfPointRotatedAroundCenter(NSMakePoint(p0.x+2*scale, p0.y + 6*scale), a, p0);
    [bPath lineToPoint:p];
    p = vhfPointRotatedAroundCenter(NSMakePoint(p0.x, p0.y + 6*scale), a, p0);
    [bPath lineToPoint:p];
    [bPath lineToPoint:p0];
    [bPath fill];
    PSgrestore();
}

/* exact coordinate bounds of an object
 * in case of curve this gives a slow calculation but more precise bounds
 * may have zero size!
 */
- (NSRect)coordBounds
{
    return NSZeroRect;
}
/* bounds of object including width and vertices
 * never becomes zero!
 */
- (NSRect)bounds
{   NSRect	bRect = [self coordBounds];

    bRect.size.width  = MAX(bRect.size.width,  0.001);
    bRect.size.height = MAX(bRect.size.height, 0.001);
    bRect = NSInsetRect(bRect, -width, -width);
    //bRect = NSIntegralRect(bRect);	// too much!
    return bRect;
}
/* bounds including width and knob size
 * never becomes zero!
 */
- (NSRect)extendedBoundsWithScale:(float)scaleFactor
{   NSRect	bRect = [self bounds];
    float	knobsize = -[VGraphic maxKnobSizeWithScale:scaleFactor]/2.0;

    bRect = NSInsetRect(bRect, knobsize, knobsize);
    bRect = NSIntegralRect(bRect);
    return bRect;
}

/* maximum possible bounds (bounds for all angles of rotation)
 */
- (NSRect)maximumBounds
{   float	dx, dy;
    NSRect	rect;

    rect = [self bounds];
    dx = rect.size.width;
    dy = rect.size.height;
    rect.origin.x += dx/2.0;
    rect.origin.y += dy/2.0;
    rect.size.width = rect.size.height = sqrt(dx*dx+dy*dy);
    rect.origin.x -= rect.size.width /2.0;
    rect.origin.y -= rect.size.height/2.0;
    return rect;
}

/* created:		22.10.95
 * modified:	
 *
 * Returns the bounds at the given rotation.
 */
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp
{
    return [self bounds];
}

- (NSRect)scrollRect:(int)pt_num inView:(id)aView
{
    return [self bounds]; 
}

- (void)constrainPoint:(NSPoint *)aPt andNumber:(int)pt_num toView:aView
{   NSPoint	viewMax;
    NSRect	viewRect;

    viewRect = [aView bounds];
    viewMax.x = viewRect.origin.x + viewRect.size.width;
    viewMax.y = viewRect.origin.y + viewRect.size.height;

    viewMax.x -= MARGIN;
    viewMax.y -= MARGIN;
    viewRect.origin.x += MARGIN;
    viewRect.origin.y += MARGIN;

    aPt->x = MAX(viewRect.origin.x, aPt->x);
    aPt->y = MAX(viewRect.origin.y, aPt->y);

    aPt->x = MIN(viewMax.x, aPt->x);
    aPt->y = MIN(viewMax.y, aPt->y); 
}

- (void)movePoint:(int)pt_num to:(NSPoint)p
{
}

- (void)movePoint:(int)pt_num by:(NSPoint)pt
{
}

- (void)moveBy_ptr:(NSPoint*)pt
{
    [self moveBy:*pt];
}
- (void)moveBy:(NSPoint)pt
{
}

/* The p argument holds the destination of the reference point (origin). */
- (void)moveTo:(NSPoint)p
{   NSPoint	p0 = [self pointWithNum:0];

    [self moveBy:NSMakePoint( p.x-p0.x, p.y-p0.y )];
}

/* created:	
 * modified:
 * parameter:	p	the point
 *		t	0 <= t <= 1
 * purpose:	get a point on the object at t
 */
- (NSPoint)pointAt:(float)t
{
    NSLog(@"pointAt: not implemented");
    return NSMakePoint(0.0, 0.0);
}
- (void)getPoint:(NSPoint*)p at:(float)t
{
    *p = [self pointAt:t];
}

- (int)numPoints
{
    return 0;
}
- (NSPoint)pointWithNum:(int)pt_num
{
    NSLog(@"pointWithNum: not implemented");
    return NSMakePoint(0.0, 0.0);
}
- (void)getPoint:(int)pt_num :(NSPoint *)pt
{
    *pt = [self pointWithNum:pt_num];
}

- (BOOL)hitEdge:(NSPoint)p fuzz:(float)fuzz :(NSPoint*)pt :(float)controlsize
{
    return NO;
}

- (BOOL)hitControl:(NSPoint)p :(int *)pt_num controlSize:(float)controlsize
{
    return NO;
}

- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz
{
    return NO;
}

- contour:(float)w
{
    //NSLog(@"VGraphic, -contour: not implemented!");
    return nil;
}

- (id)shape		{ return [self contour:0.0]; }

- flattenedObject
{
    return [self copy];
}

#if 0
- (NSMutableArray*)getListOfObjectsSplittedFrom:g
{   NSPoint	*pArray;
    int		iCnt;

    if (!(iCnt = [self getIntersections:&pArray with:g]))
        return nil;
    return [self getListOfObjectsSplittedFrom:pArray :iCnt];
}
#endif

- (NSMutableArray*)getListOfObjectsSplittedFromGraphic:g
{   int			iCnt;
    NSPoint		*iPts;
    NSMutableArray	*a = nil;

    if ( (iCnt = [self getIntersections:&iPts with:g]) )
    {   a = [self getListOfObjectsSplittedFrom:iPts :iCnt];
        if ( iPts ) free(iPts);
    }
    return ([a count]>1) ? a : nil;
}

- (NSMutableArray*)getListOfObjectsSplittedFrom:(NSPoint*)pArray :(int)iCnt
{
    NSLog(@"VGraphic, -getListOfObjectsSplittedFrom not implemented!");
    return nil;
}

- (NSMutableArray*)getListOfObjectsSplittedAtPoint:(NSPoint)pt
{
    NSLog(@"VGraphic, -getListOfObjectsSplittedAtPoint: not implemented!");
    return nil;
}

/* whether we are a path object
 * eg. line, polyline, arc, curve, rectangle, path
 * group is not a path object because we don't know what is inside!
 */
- (BOOL)isPathObject	{ return NO; }

/* check for intersection with rect.
 * We does not check if we are completely inside rect !!
 * If object is a path object (line, arc, curve, rectangle), then
 * we intersect each line of the rectangle with the object.
 * If object is not a path object we only intersect the bounds.
 */
- (BOOL)intersectsRect:(NSRect)rect
{   NSPoint	pts[10], p[4];
    NSRect	bRect = [self bounds];
    id		shape;

    /* no bounds overlap -> no intersection */
    if (!NSIntersectsRect(rect, bRect))
        return NO;
    if (![self isPathObject])
        return YES;
    shape = (width) ? [self shape] : self;	// shape to have width included
    p[0] = rect.origin;
    p[1] = NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y);
    p[2] = NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height);
    p[3] = NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height);
    if ( [shape intersectLine:pts :p[0] :p[1]] ||
         [shape intersectLine:pts :p[1] :p[2]] ||
         [shape intersectLine:pts :p[2] :p[3]] ||
         [shape intersectLine:pts :p[3] :p[0]] )
        return YES;
    return NO;
}

/* get intersections with line segment
 */
- (int)intersectLine:(NSPoint*)pArray :(NSPoint)pl0 :(NSPoint)pl1
{
    return 0;
}

/* get intersections with other graphic object
 */
- (int)getIntersections:(NSPoint**)ppArray with:g
{
    NSLog(@"VGraphic, -getIntersections: not implemented!");
    return 0;
}

- (void)getPointBeside:(NSPoint*)point :(int)left :(float)dist
{
    NSLog(@"VGraphic, -getPointOnSide::: not implemented!");
}

- uniteWith:(VGraphic*)ug
{
    return nil;
}

- (BOOL)identicalWith:(VGraphic*)g
{
    return NO;
}

- (float)sqrDistanceGraphic:g :(NSPoint*)pg1 :(NSPoint*)pg2
{
    NSLog(@"VGraphic, -sqrDistanceGraphic::: not implemented!");
    return MAXCOORD;
}
- (float)sqrDistanceGraphic:g
{
    NSLog(@"VGraphic, -sqrDistanceGraphic: not implemented!");
    return MAXCOORD;
}
- (float)distanceGraphic:g
{
    NSLog(@"VGraphic, -distanceGraphic: not implemented!");
    return MAXCOORD;
}

/* returns autoreleased object */
- (id)clippedWithRect:(NSRect)rect
{
    return nil;
}

- (void)writeFilesToDirectory:(NSString*)directory
{
}

- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    pmList = [NSMutableArray new];

    version = [aDecoder versionForClassName:@"VGraphic"];
    if ( version <= 1 )
    {   [aDecoder decodeValuesOfObjCTypes:"c", &isSelected];
        isSelected = 0;
    }
    color = [[aDecoder decodeObject] retain];
    if ( version >= 1 )
        [aDecoder decodeValuesOfObjCTypes:"f", &width];
    if ( version >= 2 )
        [aDecoder decodeValuesOfObjCTypes:"c", &isLocked];
    if ( version >= 3 ) // 2008-03-18
    {   [aDecoder decodeValuesOfObjCTypes:"ciif", &relief, &reliefType, &reliefDirection, &reliefFlatness];
        if ( !reliefFlatness )
            reliefFlatness = 1.0;
    }
    if ( version >= 4 ) // 2010-07-28
        label = [[aDecoder decodeObject] retain];
    if ( version >= 5 ) // 2011-05-28
        [aDecoder decodeValuesOfObjCTypes:"c", &isExcluded];

    return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    //[aCoder encodeValuesOfObjCTypes:"c", &isSelected];
    [aCoder encodeObject:color];
    [aCoder encodeValuesOfObjCTypes:"f", &width];
    [aCoder encodeValuesOfObjCTypes:"c", &isLocked];
    [aCoder encodeValuesOfObjCTypes:"ciif", &relief, &reliefType, &reliefDirection, &reliefFlatness];
    [aCoder encodeObject:label];
    [aCoder encodeValuesOfObjCTypes:"c", &isExcluded];
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [NSMutableDictionary dictionaryWithCapacity:10];

    [plist setObject:NSStringFromClass([self class]) forKey:@"Class"];
    if ( label && [label length] )
        [plist setObject:label forKey:@"id"];
    if ( color && color != [NSColor blackColor] )
        [plist setObject:propertyListFromNSColor(color) forKey:@"color"];
    if (width)          [plist setObject:propertyListFromFloat(width) forKey:@"width"];
    if (isExcluded)     [plist setObject:@"1" forKey:@"isExcluded"];
    if (isLocked)       [plist setObject:@"1" forKey:@"isLocked"];
    if (isDirectionCCW) [plist setObject:@"1" forKey:@"ccw"];
    //if (!isDirectionCCW) [plist setObject:@"1" forKey:@"cw"];

    /* Relief */
    if (relief)          [plist setObject:@"YES" forKey:@"relief"];
    if (reliefType)      [plist setInt:reliefType forKey:@"reliefType"];
    if (reliefDirection) [plist setInt:reliefDirection forKey:@"reliefDirection"];
    if (reliefFlatness != 1.0)  [plist setObject:propertyListFromFloat(reliefFlatness) forKey:@"reliefFlatness"];

    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    pmList = [NSMutableArray new];
    label = [[plist objectForKey:@"id"] retain];
    if (!(color = colorFromPropertyList([plist objectForKey:@"color"], [self zone])))
        [self setColor:[NSColor blackColor]];
    width = [plist floatForKey:@"width"];
    isExcluded = ([plist objectForKey:@"isExcluded"]) ? YES : NO;
    isLocked   = ([plist objectForKey:@"isLocked"])   ? YES : NO;
    //isDirectionCCW = ([plist objectForKey:@"cw"]) ? NO : YES;
    isDirectionCCW = ([plist objectForKey:@"ccw"] || [plist objectForKey:@"isDirectionCCW"]) ? YES : NO;

    /* Relief */
    relief          = (([plist objectForKey:@"relief"]) ? YES : NO);
    reliefType      = [plist intForKey:@"reliefType"];
    reliefDirection = [plist intForKey:@"reliefDirection"];
    if ( !(reliefFlatness = [plist floatForKey:@"reliefFlatness"]) )
        reliefFlatness = 1.0;

    dirty = YES;
    return self;
}

- (BOOL)isDirty             { return dirty; }
- (void)setDirty:(BOOL)flag { dirty = flag; }
- (void)setOutputStream:(id)stream
{
    [outputStream release];
    outputStream = [stream retain];
}
- (id)outputStream
{
    return outputStream;
}

- (void)dealloc
{
    [label release];
    [color release];
    [outputStream release];
    [pmList release];
    [super dealloc];
}

@end
