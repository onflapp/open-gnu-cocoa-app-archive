/* VTextPath.m
 * 2-D Textpath - text written on path
 *
 * Copyright (C) 2000-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-07-31
 * modified: 2011-05-30 (-label, -setLabel: forwarded to path object)
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
 *
 * TODO: this implementation is too inflexible and too hard to maintain.
 *       We now forward everything to our path object or text that we don't
 *       respond to but our path or text responds to.
 *       So, now we can probably remove most of the separate forward methods.
 */

#include <AppKit/AppKit.h>
#include "VTextPath.h"
#include "VLine.h"
#include "VArc.h"
#include "VCurve.h"
#include "VPath.h"
#include "VGroup.h"
#include "../DocView.h"	// scaleFactor

@interface VTextPath(PrivateMethods)
@end

@implementation VTextPath

+ (BOOL)canBindToObject:(id)obj
{
    if ( [obj isKindOfClass:[VLine class]] ||
         [obj isKindOfClass:[VArc class]]  ||
         [obj isKindOfClass:[VCurve class]] /*||
         [obj isKindOfClass:[VPolyLine class]] ||   // FIXME: why are PolyLine and Path not working ?
         [obj isKindOfClass:[VPath class]]*/ )
        return YES;
    return NO;
}

+ (id)textPathWithText:(VText*)theText path:(VGraphic*)thePath
{
    return [[self newWithText:theText path:thePath] autorelease];
}

+ (id)newWithText:(VText*)theText path:(VGraphic*)thePath
{
    return [[VTextPath alloc] initWithText:theText path:thePath];
}

- (id)initWithText:(VText*)theText path:(VGraphic*)thePath
{
    [super init];
    text = [theText retain];
    [text setOutputStream:nil];
    [text setTextPath:self];
    path = [thePath retain];
    [path setOutputStream:nil];
    showPath = YES;
    return self;
}

- (NSString*)title
{
    return @"Textpath";
}

/* dissolve ourself to ulist
 */
- (void)splitTo:ulist
{
    [text setSelected:YES];
    [text setDirty:YES];
    [text setTextPath:nil];
    [ulist addObject:text];
    [path setSelected:YES];
    [path setDirty:YES];
    [ulist addObject:path];
}

- (VText*)textGraphic		{ return text; }
- (id)path				{ return path; }
- (void)setShowPath:(BOOL)flag		{ showPath = flag; dirty = YES; }
- (BOOL)showsPath			{ return showPath; }

/* methods passed to VText
 */
- (BOOL)edit:(NSEvent *)event in:view
{
    [text moveTo:[path pointAt:0.0]];
    return [text edit:event in:view];
}

- (void)setSerialNumber:(BOOL)flag	{ [text setSerialNumber:flag]; dirty = YES; }
- (BOOL)isSerialNumber			{ return [text isSerialNumber]; }
- (void)incrementSerialNumberBy:(int)o	{ [text incrementSerialNumberBy:o]; dirty = YES; }


- (void)setFontSize:(float)v	{ [text setFontSize:v]; dirty = YES; }
- (float)fontSize		{ return [text fontSize]; }

- (void)setColor:(NSColor*)col	{ [text setColor:col]; }
- (NSColor*)color		{ return [text color]; }

- (NSColor*)fillColor			{ return [text fillColor]; }
- (void)setFillColor:(NSColor*)col;	{ [text setFillColor:col]; }
- (NSColor*)endColor			{ return [text endColor]; }
- (void)setEndColor:(NSColor*)col;	{ [text setEndColor:col]; }
- (float)graduateAngle			{ return [text graduateAngle]; }
- (void)setGraduateAngle:(float)a;	{ [text setGraduateAngle:a]; }
- (NSPoint)radialCenter			{ return [text radialCenter]; }
- (void)setRadialCenter:(NSPoint)rc	{ [text setRadialCenter: rc]; }
- (void)setStepWidth:(float)sw;		{ [text setStepWidth:sw]; }
- (float)stepWidth			{ return [text stepWidth]; }


/* New flexible forwarding methods
 */

/* pretend to respond to path object and text methods too
 */
- (BOOL)respondsToSelector:(SEL)aSelector
{
    if ( [super respondsToSelector:aSelector] )
        return YES;
    if ( [text respondsToSelector:aSelector] )
        return YES;
    if ( [path respondsToSelector:aSelector] )
        return YES;
    return NO;
}
/* Here, we ask the two objects, path first, for their method
 * signatures, since we'll be forwarding the message to one or the other
 * of them in -forwardInvocation:.  If path returns a non-nil
 * method signature, we use that, so in effect it has priority.
 */
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{   NSMethodSignature   *sig;

    if ( (sig = [path methodSignatureForSelector:aSelector]) )  // 1st path
        return sig;
    sig = [text methodSignatureForSelector:aSelector];          // 2nd text
    return sig;
}
/* forward unrecognized methods
 */
- (void)forwardInvocation:(NSInvocation*)invocation
{
    if ( [path methodSignatureForSelector:[invocation selector]] )
    {   [invocation invokeWithTarget:path];
        dirty = [path isDirty];
    }
    else if ( [text methodSignatureForSelector:[invocation selector]] )
    {   [invocation invokeWithTarget:text];
        dirty = [text isDirty];
    }
    else
        [super forwardInvocation:invocation];
}
/* subclass VGraphic method to set our path and text not dirty too, because we feed on them
 */
- (void)setDirty:(BOOL)flag
{   dirty = flag;
    if ( !dirty )
    {   [path setDirty:NO];
        [text setDirty:NO];
    }
}

/* subclass VGraphic label methods to forward to path object (don't remove !) */
- (void)setLabel:(NSString*)newLabel    { [path setLabel:newLabel]; }
- (NSString*)label                      { return [path label]; }


/* methods passed to path
 */

- (void)setWidth:(float)w       { [path setWidth:w]; dirty = YES; }
- (float)width                  { return [path width]; }

- (void)setLength:(float)l      { [(VGraphic*)path setLength:l]; dirty = YES; }
- (float)length                 { return [(VGraphic*)path length]; }
- (void)setRadius:(float)r      { [path setRadius:r]; dirty = YES; }
- (float)radius                 { return [path radius]; }
- (void)setBegAngle:(float)a    { [(VArc*)path setBegAngle:a]; dirty = YES; }
- (float)begAngle               { return [(VArc*)path begAngle]; }
- (void)setAngle:(float)a       { [(VArc*)path setAngle:a]; dirty = YES; }
- (float)angle                  { return [path angle]; }

- (void)changeDirection         { [path changeDirection]; dirty = YES; }
- (int)selectedKnobIndex        { return [path selectedKnobIndex]; }


/* subclassed methods
 */

/*
 * set the selection of the plane
 */
- (void)setSelected:(BOOL)flag
{
    if (!flag)
        [path setSelected:NO];
    [super setSelected:flag];
}

/* created:  00/08/03
 * modified: 
 * purpose:  draw graphic rotated around cp
 */
- (void)drawAtAngle:(float)angle withCenter:(NSPoint)cp in:view
{
    [path drawAtAngle:angle withCenter:cp in:view];
}

/* created:  00/08/03
 * modified: 
 * purpose:  rotate path around cp
 */
- (void)setAngle:(float)angle withCenter:(NSPoint)cp
{
    [path setAngle:angle withCenter:cp];
    dirty = YES;
}

- (void)scale:(float)x :(float)y withCenter:(NSPoint)cp
{
    [path scale:x :y withCenter:cp];
    [text scale:x :y withCenter:cp];
    dirty = YES;
}

- (void)mirrorAround:(NSPoint)p
{
    [path mirrorAround:p];
    [text mirrorAround:p];
    dirty = YES;
}

/*
 * draws the graphic
 * we start drawing the text at the beginning of the path
 * we get each character position (seperated by their widths)
 * and rotate them to the gradient of the path at the related position
 */
- (void)drawWithPrincipal:principal
{   int		i, charCnt = [text stringLength];
    float	length, x, angle;
    NSPoint	p, g;
    VText	*charText;

    if ( showPath )
        [(VGraphic*)path drawWithPrincipal:principal];

    [text setAlignment:NSLeftTextAlignment];
    [text sizeToFit];
    length = [(VGraphic*)path length];	// length of path
    for ( i=0; i<charCnt; i++ )
    {   NSRect	rect = [text boundingRectAtIndex:i];

        //x = [text characterOffsetAtIndex:i];
        x = rect.origin.x;
        p = [path pointAt:x/length];
        charText = [text subTextWithRange:NSMakeRange(i, 1)];
        [charText moveTo:NSMakePoint(p.x, p.y+[[charText font] descender])];
        g = [path gradientAt:(x+rect.size.width/2.0)/length];
        angle = (Diff(g.x/2.0, 0.0)<TOLERANCE) ? 90.0 : Atan(g.y/g.x);
        if ( (g.x<0.0 && g.y>0.0) || (g.x<0.0 && g.y<0.0) )	// 2nd, and 3rd quadrant
            angle += 180.0;
        [charText drawAtAngle:-angle withCenter:p in:principal];
    }
}

- (void)drawSerialNumberAt:(NSPoint)p withOffset:(int)o
{
    [text moveTo:[path pointAt:0.0]];
    [text drawSerialNumberAt:p withOffset:o];
}

/*
 * Returns the bounds.  The flag variable determines whether the
 * knobs should be factored in. They may need to be for drawing but
 * might not if needed for constraining reasons.
 */
- (NSRect)coordBounds
{   NSRect	bRect = [path coordBounds];
    float	h = [text lineHeight];

    bRect = NSInsetRect(bRect, -h, -h);
    return bRect;
}
- (NSRect)bounds
{   NSRect	bRect = [path bounds];
    float	h = [text lineHeight];

    bRect = NSInsetRect(bRect, -h, -h);
    return bRect;
}

/*
 * Return the bounds with the given rotation.
 */
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp
{   NSPoint	p, ll, ur;
    NSRect	bounds, bRect;

    bounds = bRect = [self bounds];
    p = bounds.origin;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    ll = ur = p;

    p.x = bounds.origin.x+bounds.size.width;
    p.y = bounds.origin.y;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

    p.x = bounds.origin.x+bounds.size.width;
    p.y = bounds.origin.y+bounds.size.height;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

    p.x = bounds.origin.x;
    p.y = bounds.origin.y+bounds.size.height;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

    bRect.origin = ll;
    bRect.size.width  = ur.x-ll.x;
    bRect.size.height = ur.y-ll.y;

    return bRect;
}

/*
 * Depending on the pt_num passed in, return the rectangle
 * that should be used for scrolling purposes. When the rectangle
 * passes out of the visible rectangle then the screen should
 * scroll. If the first and last points are selected, then the second
 * and third points are included in the rectangle. If the second and
 * third points are selected, then they are used by themselves.
 */
- (NSRect)scrollRect:(int)pt_num inView:(id)aView
{
    return [path scrollRect:pt_num inView:aView];
}

/* 
 * This method constains the point to the bounds of the view passed
 * in. Like the method above, the constaining is dependent on the
 * control point that has been selected.
 */
- (void)constrainPoint:(NSPoint *)aPt andNumber:(int)pt_num toView:(id)aView
{
    [path constrainPoint:aPt andNumber:pt_num toView:aView];
}

/*
 * created:   1995-09-25
 * modified:  
 * parameter: ptNum  index of vertex
 *            p      the new position in
 * purpose:   Sets a vertex to a new position.
 *            If it is a edge move the vertices with it
 *            Default must be the last point!
 */
- (void)movePoint:(int)ptNum to:(NSPoint)p
{
    [path movePoint:ptNum to:p];
    dirty = YES;
}

/*
 * pt_num is the changing control point. pt holds the relative change in each coordinate. 
 * The relative is needed and not the absolute because the closest inside control point
 * changes when one of the outside points change.
 */
- (void)movePoint:(int)ptNum by:(NSPoint)pt
{
    [path movePoint:ptNum by:pt]; 
    dirty = YES;
}

/* The pt argument holds the relative point change
 */
- (void)moveBy:(NSPoint)pt
{
    [path moveBy:pt];
    dirty = YES;
}

- (int)numPoints
{
    return [path numPoints];
}

/* Given the point number, return the point.
 * Default must be p1
 */
- (NSPoint)pointWithNum:(int)ptNum
{
    return [path pointWithNum:ptNum];
}

/*
 * Check for a edge point hit.
 * parameter: p	the mouse position
 *            fuzz        the distance inside we snap to a point
 *            pt          the edge point
 *            controlsize the size of the controls
 */
- (BOOL)hitEdge:(NSPoint)p fuzz:(float)fuzz :(NSPoint*)pt :(float)controlsize
{
    return [path hitEdge:p fuzz:fuzz :pt :controlsize];
}

/*
 * Check for a control point hit.
 * Return the point number hit in the pt_num argument.
 */
- (BOOL)hitControl:(NSPoint)p :(int*)ptNum controlSize:(float)controlsize
{
    return [path hitControl:p :ptNum controlSize:controlsize];
}

- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz
{
    return [path hit:p fuzz:fuzz];
}

/*
 * return a path representing the outline of us
 * the path holds two lines and two arcs
 * if we need not build a contour a copy of self is returned
 */
- (id)contour:(float)w
{
    return [[self flattenedObject] contour:w];
}

- (VPath*)pathRepresentation
{
    return [self getFlattenedObjectAt:NSMakePoint(0.0, 0.0) withOffset:0];
}
- (id)flattenedObject
{
    return [self getFlattenedObjectAt:NSMakePoint(0.0, 0.0) withOffset:0];
}

- (id)getFlattenedObjectAt:(NSPoint)offset withOffset:(int)o
{   VText	*tmpText;
    int		i, charCnt = [text stringLength];
    float	length, x, angle;
    NSPoint	p, g;
    VText	*charText;
    VGroup	*group = [VGroup group];

    if ( o )
    {   tmpText = [[text copy] autorelease];
        [tmpText setSerialTextFor:[VText sharedText] withOffset:o setData:YES];
    }
    else
        tmpText = text;

    [path moveBy:offset];

    if ( showPath )
        [[group list] addObject:path];

    [tmpText sizeToFit];
    length = [(VGraphic*)path length];	// length of path
    for ( i=0; i<charCnt; i++ )
    {   NSRect	rect = [text boundingRectAtIndex:i];

        //x = [tmpText characterOffsetAtIndex:i];
        x = rect.origin.x;
        p = [path pointAt:x/length];
        charText = [tmpText subTextWithRange:NSMakeRange(i, 1)];
        [charText moveTo:NSMakePoint(p.x, p.y+[[charText font] descender])];
        g = [path gradientAt:(x+rect.size.width/2.0)/length];
        angle = (Diff(g.x, 0.0)<TOLERANCE) ? 90.0 : Atan(g.y/g.x);
        if ( (g.x<0.0 && g.y>0.0) || (g.x<0.0 && g.y<0.0) )	// 2nd, and 3rd quadrant
            angle += 180.0;
        [charText setAngle:-angle withCenter:p];
        [[group list] addObject:[charText getFlattenedObject]];
    }

    [path moveBy:NSMakePoint(-offset.x, -offset.y)];	// restore path position

    return group;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeValuesOfObjCTypes:"@", &text];
    [aCoder encodeValuesOfObjCTypes:"@", &path];
    [aCoder encodeValuesOfObjCTypes:"c", &showPath];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VTextPath"];
    [aDecoder decodeValuesOfObjCTypes:"@", &text];
    [aDecoder decodeValuesOfObjCTypes:"@", &path];
    [aDecoder decodeValuesOfObjCTypes:"c", &showPath];
    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    [plist setObject:[text propertyList] forKey:@"text"];
    [plist setObject:[path propertyList] forKey:@"path"];
    if (showPath) [plist setObject:@"YES" forKey:@"showPath"];
    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString*)directory
{   NSString	*className;
    id		plistObject, obj;

    [super initFromPropertyList:plist inDirectory:directory];
    text = [[VText allocWithZone:[self zone]] initFromPropertyList:[plist objectForKey:@"text"] inDirectory:directory];
    [text setTextPath:self];
    plistObject = [plist objectForKey:@"path"];
    className = [plistObject objectForKey:@"Class"];
    obj = [NSClassFromString(className) allocWithZone:[self zone]];
    if (!obj)	// load old projects (< 3.50 beta 13)
        obj = [NSClassFromString(newClassName(className)) allocWithZone:[self zone]];
    path = [obj initFromPropertyList:plistObject inDirectory:directory];
    showPath = ([plist objectForKey:@"showPath"] ? YES : NO);
    return self;
}

- (void)dealloc
{
    [path release];
    [text release];
    [serialStreams release];
    [super dealloc];
}

@end
