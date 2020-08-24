/* LayerObject.m
 * Object managing a single layer and its attributes
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1996-03-07
 * Modified: 2012-01-25 (-setInvisible:, -invisible)
 *           2012-01-24 (-stepsForDip:)
 *           2008-11-12 (layerDict, clean-up)
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
#include <VHFShared/types.h>
#include <VHFShared/VHFDictionaryAdditions.h>
#include "LayerObject.h"
#include "messages.h"
#include "App.h"
#include "DocView.h"

@implementation LayerObject

/*
 * This sets the class version so that we can compatibly read
 * old VGraphic objects out of an archive.
 */
+ (void)initialize
{
    [LayerObject setVersion:4];
}

+ (id)layerObject
{
    return [[self new] autorelease];
}
+ (id)layerObjectWithFrame:(NSRect)bRect
{
    return [[[self alloc] initWithFrame:bRect] autorelease];
}

- (id)init
{
    [super init];

    [self setString:UNTITLED_STRING];
    [self setToolString:@""];
    state           = YES;
    editable        = YES;
    uniqueId        = 0;
    useForTile      = YES;
    likeOtherLayers = YES;
    dirty           = NO;
    list            = [NSMutableArray new]; // the object list

    /* CAM */
    toolIndex       = -1;
    filled          = NO;
    mirrored        = NO;
    inlay           = NO;
    side            = CUT_NOSIDE;
    flatness        = 0.15;
    removeLoops     = YES;
    revertDirection = NO;
    fillOverlap     = 0.15;		// 15%
    fillDirection   = 0.0;
    stepwise        = NO;
    calcSteps.count = 0;
    settleBefore    = NO;
    inlay           = NO;
    levelingX       = levelingY = 2;
    invisible       = NO;

    return self;
}

- (id)initWithFrame:(NSRect)bRect
{
    [self init];
    [self createPerformanceMapWithFrame:bRect];
    return self;
}


- (void)createPerformanceMapWithFrame:(NSRect)rect
{
    if (performanceMap)
    {   [performanceMap removeAllObjects];
        [performanceMap release];
    }
    performanceMap = [[PerformanceMap alloc] initWithFrame:NSIntegralRect(rect)];
    [performanceMap addObjectList:list withReferenceList:nil];
}
- (PerformanceMap*)performanceMap
{
    return performanceMap;
}

/* manage graphic objects in list and performance map
 */
- (void)setList:(NSMutableArray*)aList
{
    [list release];
    list = [aList retain];
    [performanceMap initList:list];
}
- (NSMutableArray*)list			{ return list; }

- (void)insertObject:(id)obj atIndex:(unsigned)ix
{
    if ([list containsObject:obj])
        NSLog(@"LayerObject: Object already in list!");
    [list insertObject:obj atIndex:ix];
    [performanceMap addObject:obj inTryNumber:0 withReferenceList:list];
    dirty = YES;
}
- (void)addObject:(id)obj
{
    if ([list containsObject:obj])
        NSLog(@"LayerObject: Object already in list!");
    [list addObject:obj];
    [performanceMap addObject:obj];
    dirty = YES;
}
/* faster without check if object already is in list !
 */
- (void)addObjectWithoutCheck:(id)obj
{
    [list addObject:obj];
    [performanceMap addObject:obj];
    dirty = YES;
}
- (void)addObjectsFromArray:(NSArray*)array
{
    [list addObjectsFromArray:array];
    [performanceMap addObjectList:array withReferenceList:nil];
    dirty = YES;
}
- (void)updateObject:(VGraphic*)g
{
    [performanceMap updateObject:g withReferenceList:list];
    dirty = YES;
}
- (void)removeObject:(id)obj
{   int	i, cnt;

    for (i=0, cnt = [[obj pmList] count]; i<cnt; i++)
        [[[obj pmList] objectAtIndex:i] removeObject:obj];
    [[obj pmList] removeAllObjects];
    [list removeObject:obj];
    dirty = YES;
}
- (void)removeAllObjects
{
    [list removeAllObjects];
    [performanceMap initList:list];
}
/* draw layer
 * if we have a performance map, we let the map draw our objects
 * otherwise we draw ourself directly
 */
- (void)draw:(NSRect)rect inView:(id)view
{   int	i, iCnt;

    if ( !state )	// we are not visible
        return;
    if (performanceMap)
    {
        //rect = [view centerScanRect:rect];
        if (NSIsEmptyRect(rect))
            rect = [performanceMap bounds];
        [performanceMap drawInRect:rect principal:view];
        //[performanceMap drawSegmentBoundaries];	// debugging
    }
    else
        for (i=0, iCnt=[list count]; i<iCnt; i++)
            [(VGraphic*)[list objectAtIndex:i] drawWithPrincipal:view];
}


/* all layers which can either be filled or not */
- (BOOL)isFillable
{
    if ( type == LAYER_STANDARD &&
         side != CUT_ISOLATION && side != CUT_BLOWUP && side != CUT_RUBOUT )
        return YES;
    return NO;
}
/* all layers ment for output */
- (BOOL)hasDip
{
    if ( type == LAYER_CLIPPING || type == LAYER_LEVELING )
        return NO;
    return YES;
}
/* layers which can't be edited */
- (BOOL)isPassive
{
    return (LAYER_PASSIVE) ? YES : NO;
}
/* all layers which should have a side correction icon */
- (BOOL)fastSideSelection
{
    if ( type == LAYER_STANDARD &&
         (side == CUT_INSIDE || side == CUT_OUTSIDE || side == CUT_NOSIDE || side == CUT_PICKOUT) )
        return YES;
    return NO;
}

- (void)setString:(NSString *)aString   { [string release]; string = [aString retain]; }
- (NSString *)string                    { return string; }

- (void)setTag:(int)newTag              { tag = newTag; }
- (int)tag                              { return tag; }

- (void)setColor:(NSColor *)aColor      { color=aColor; }
- (NSColor *)color                      { return color; }

- (void)setState:(int)flag              { state = flag; }
- (int)state                            { return state; }

- (void)setInvisible:(int)flag          { invisible = flag; }
- (int)invisible                        { return invisible; }

- (void)setEditable:(BOOL)flag
{
    editable = flag;
    if (editable)
        state = YES;
}
- (BOOL)editable                        { return ( !state ) ? NO : editable; }

- (int)type                             { return type; }
- (void)setType:(int)newType
{
    type = newType;
    switch (type)
    {
        case LAYER_CLIPPING:
        case LAYER_LEVELING:
        case LAYER_TEMPLATE:
        case LAYER_TEMPLATE_1:
        case LAYER_TEMPLATE_2:
            likeOtherLayers = NO;
            useForTile = NO;
        default:
            break;
    }
}

- (int)uniqueId				{ return uniqueId; }
- (void)setUniqueId:(int)newId		{ uniqueId = newId; }

- (BOOL)useForTile		{ return (type == LAYER_CLIPPING || type == LAYER_LEVELING) ? NO : useForTile; }
- (void)setUseForTile:(BOOL)flag	{ useForTile = flag;  }
- (void)setTileCount:(int)c		{ tileCount = c; }
- (int)tileCount			{ return tileCount; }

- (BOOL)likeOtherLayers			{ return likeOtherLayers; }
- (void)setLikeOtherLayers:(BOOL)flag	{ likeOtherLayers = flag; }

/* whether we need to be calculated
 * if flag is YES and we are allowed to calculate we calculate the contour
 */
- (void)setDirty:(BOOL)flag calculate:(BOOL)cflag
{
    if ( flag != dirty )
    {
        dirty = flag;
        if (flag && cflag)
        {
            [NSObject cancelPreviousPerformRequestsWithTarget:[[(App*)NSApp currentDocument] documentView]
                                                     selector:@selector(calcOutput) object:NULL];
            [[[(App*)NSApp currentDocument] documentView] performSelector:@selector(calcOutput)
                                                               withObject:NULL afterDelay:0.0];
        }
    }
}
- (void)setDirty:(BOOL)flag	{ [self setDirty:flag calculate:YES]; }
- (BOOL)dirty			{ return dirty; }


/*
 * CAM methods
 */
- (void)setToolIndex:(int)aTool { toolIndex = aTool; }
- (int)toolIndex                { return toolIndex; }

- (void)setToolString:(NSString*)aString
{
    [toolString release];
    toolString = (!aString) ? @"" : [aString retain];
}
- (NSString*)toolString         { return toolString; }

- (void)setSide:(int)s
{
    if (side != s)
    {	side = s;
        //if (side != CUT_INSIDE && side != CUT_OUTSIDE)
        //    [self setSettle:0.0];	// turn off settlement !
        [self setDirty:YES];
    }
}
- (int)side				{ return side; }

- (void)setFilled:(BOOL)v
{
    if (filled != v)
    {	filled = v;
        [self setDirty:YES];
    }
    else
        filled = v;
}
- (BOOL)filled				{ return filled; }

- (void)setMirrored:(BOOL)v
{
    if (mirrored != v)
    {	mirrored = v;
        [self setDirty:YES];
    }
    else
        mirrored = v;
}
- (BOOL)mirrored			{ return mirrored; }

- (void)setInlay:(BOOL)v
{
    if (inlay != v)
    {	inlay = v;
        [self setDirty:YES];
    }
    else
        inlay = v;
}
- (BOOL)inlay				{ return inlay; }

- (void)setFlatness:(float)v
{
    if (flatness != v)
    {	flatness = v;
        [self setDirty:YES];
    }
    else
        flatness = v;
}
- (float)flatness			{ return flatness; }

/* a value between 0 and 1 */
- (float)fillOverlap			{ return fillOverlap; }
- (void)setFillOverlap:(float)v
{
    v = Min(v, 95.0);
    if (fillOverlap != v)
    {	fillOverlap = v;
        [self setDirty:YES];
    }
    else
        fillOverlap = v;
}

/* fill direction for standard fill algorithm
 */
- (float)fillDirection			{ return fillDirection; }
- (void)setFillDirection:(float)v
{
    while (v >= 360.0)
        v -= 360.0;
    while (v < 0)
        v += 360.0;
    if (fillDirection != v)
    {	fillDirection = v;
        [self setDirty:YES];
    }
    else
        fillDirection = v;
}

- (void)setRemoveLoops:(BOOL)v
{
    if (removeLoops != v)
    {	removeLoops = v;
        [self setDirty:YES];
    }
    else
        removeLoops = v;
}
- (BOOL)removeLoops			{ return removeLoops; }

- (void)setRevertDirection:(BOOL)v
{
    if ( revertDirection != v )
    {	revertDirection = v;
        [self setDirty:YES];
    }
}
- (BOOL)revertDirection	{ return revertDirection; }

- (void)setDippingDepth:(float)d
{
    if (d != dippingDepth)
    {   float	h;

        dippingDepth = d;

        step[0] = Min(step[0], dippingDepth);
        step[2] = Min(step[2], dippingDepth-step[0]);
        h = dippingDepth - step[0] - step[2];
        if (h && !numSteps) numSteps = 1;
        step[1] = (h<TOLERANCE) ? 0.0 : h/numSteps;
        calcSteps.count = 0;

        [self setDirty:YES];
    }
}
- (float)dippingDepth			{ return dippingDepth; }

- (void)setApproachAngle:(float)angle
{
    if (angle != approachAngle)
    {
        approachAngle = angle;
        [self setDirty:YES];
    }
}
- (float)approachAngle			{ return approachAngle; }

- (void)setStepwise:(BOOL)flag
{
    if (flag != stepwise)
    {
        stepwise = flag;
        calcSteps.count = 0;
        [self setDirty:YES];
    }
}
- (BOOL)stepwise			{ return stepwise; }
- (void)setFirstStep:(float)st
{
    if (st != step[0])
    {   float	h;

        step[0] = Min(st, dippingDepth);
        step[2] = Min(step[2], dippingDepth-step[0]);
        h = dippingDepth - step[0] - step[2];
        if (h && !numSteps) numSteps = 1;
        step[1] = (h<TOLERANCE) ? 0.0 : h/numSteps;
        calcSteps.count = 0;
        [self setDirty:YES];
    }
}
/* modify numSteps, keep height in legal range, but don't change other steps
 */
- (void)setStepHeight:(float)height
{
    if (height != step[1])
    {
        if ( height < TOLERANCE)
        {
            step[1] = 0.0;
            step[0] = dippingDepth - step[2];
        }
        else
        {   float	h = dippingDepth - step[0] - step[2];

            numSteps = Min( Max(1, h/height), OUTPUT_STEPMAX-1);
            step[1] = h/numSteps;
        }
        calcSteps.count = 0;
        [self setDirty:YES];
    }
}
- (float)stepHeight
{   float	h = dippingDepth - step[0] - step[2];

    return (h<TOLERANCE) ? 0.0 : h/numSteps;
}
- (void)setNumSteps:(int)n
{
    if (n != numSteps)
    {
        numSteps = n;
        if (!numSteps)
        {
            step[0] = dippingDepth - step[2];
            step[1] = 0.0;
        }
        else
        {   float	h = dippingDepth - step[0] - step[2];

            step[1] = (!numSteps || h<TOLERANCE) ? 0.0 : h/numSteps;
        }
        calcSteps.count = 0;
        [self setDirty:YES];
    }
}
- (int)numSteps	{ return numSteps; }
- (void)setFinalStep:(float)st
{
    if (st != step[2])
    {   float	h;

        step[2] = Min(st, dippingDepth);
        step[0] = Min(step[0], dippingDepth-step[2]);
        h = dippingDepth - step[0] - step[2];
        if (h && !numSteps) numSteps = 1;
        step[1] = (h<TOLERANCE) ? 0.0 : h/numSteps;
        calcSteps.count = 0;
        [self setDirty:YES];
    }
}

- (float)stepWithNum:(int)n;		{ return step[n]; }

/* steps used for generating output
 * return steps < 0
 */
- (OutputSteps)steps
{
    if (!calcSteps.count)
        calcSteps = [self stepsForDip:dippingDepth];
    return calcSteps;
}
- (OutputSteps)stepsForDip:(float)dip   // [mm]
{   OutputSteps dipSteps;
    float       h, prev = 0.0;
    int         i;

    dipSteps.count = 0;

    if (!stepwise || dip == 0.0)
    {   dipSteps.count = 1;
        //dipSteps.step[0] = -dippingDepth;
        dipSteps.step[0] = -dip;    // 2012-01-24
        return dipSteps;
    }

    if (step[0] > TOLERANCE )
    {   dipSteps.step[0] = prev = -step[0];
        dipSteps.count ++;
    }
    //h = dippingDepth - step[0] - step[2];
    h = dip - step[0] - step[2];    // 2012-01-24
    if (h > TOLERANCE)
        for (i=0; i<numSteps; i++)
        {   dipSteps.step[dipSteps.count] = prev = prev - h/numSteps;
            dipSteps.count ++;
        }
    if (step[2] > TOLERANCE)
    {   dipSteps.step[dipSteps.count] = prev - step[2];
        dipSteps.count ++;
    }
    return dipSteps;
}

- (void)setSettle:(float)v
{
    if (v != settle)
    {
        settle = v;
        [self setDirty:YES];
    }
}
- (float)settle				{ return (side == CUT_INSIDE || side == CUT_OUTSIDE) ? settle : 0.0; }
- (void)setSettleBefore:(BOOL)flag
{
    if (flag != settleBefore)
    {
        settleBefore = flag;
        [self setDirty:YES];
    }
}
- (BOOL)settleBefore			{ return settleBefore; }

- (void)setLevelingPointsX:(int)x y:(int)y
{
    levelingX = x;
    levelingY = y;
}
- (int)levelingPointsX			{ return levelingX; }
- (int)levelingPointsY			{ return levelingY; }

/* CAM output
 */
- (void)setWebList:(NSArray*)array	{ webList = array; }
- (NSArray*)webList			{ return webList; }
- (void)setClipObject:obj		{ clipObject = obj; }
- clipObject				{ return clipObject; }


/* Archiving methods (DEPRECATED - Property list is used)
 */
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeValuesOfObjCTypes:"i@", &toolIndex, &toolString];
    [aCoder encodeValuesOfObjCTypes:"@", &string];
    [aCoder encodeValuesOfObjCTypes:"icc", &state, &filled, &editable];
    [aCoder encodeValuesOfObjCTypes:"ci", &removeLoops, &type];
    [aCoder encodeValuesOfObjCTypes:"ii", &levelingX, &levelingY];
    [aCoder encodeValuesOfObjCTypes:"c", &revertDirection];
    [aCoder encodeValuesOfObjCTypes:"i", &side];
    [aCoder encodeValuesOfObjCTypes:"f", &dippingDepth];
    [aCoder encodeValuesOfObjCTypes:"ff", &flatness, &fillOverlap];
    [aCoder encodeValuesOfObjCTypes:"ccc", &inlay, &likeOtherLayers, &useForTile];
    [aCoder encodeObject:color];
    [aCoder encodeValuesOfObjCTypes:"@", &list];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   float	minLineLength, maxLineLength;
    int		version;
    BOOL	flag;

    version = [aDecoder versionForClassName:@"LayerObject"];
    [aDecoder decodeValuesOfObjCTypes:"i@", &toolIndex, &toolString];
    [aDecoder decodeValuesOfObjCTypes:"@", &string];
    [aDecoder decodeValuesOfObjCTypes:"icc", &state, &filled, &editable];
    if ( version < 1 )
        [aDecoder decodeValuesOfObjCTypes:"cc", &removeLoops, &flag];
    else if ( version < 3 )	// 03.98
    {   [aDecoder decodeValuesOfObjCTypes:"cc", &removeLoops, &flag];
        type = (flag) ? LAYER_PASSIVE : LAYER_STANDARD;
    }
    else 			// 07.12.99
    {   [aDecoder decodeValuesOfObjCTypes:"ci", &removeLoops, &type];
        [aDecoder decodeValuesOfObjCTypes:"ii", &levelingX, &levelingY];	// 11.12.99
    }
    if ( version >= 2 )		// 07.04.98
        [aDecoder decodeValuesOfObjCTypes:"c", &revertDirection];
    [aDecoder decodeValuesOfObjCTypes:"i", &side];
    [aDecoder decodeValuesOfObjCTypes:"f", &dippingDepth];
    if (version >= 4)		// 2000-09-27
        [aDecoder decodeValuesOfObjCTypes:"ff", &flatness, &fillOverlap];
    else
    {   [aDecoder decodeValuesOfObjCTypes:"ffff", &flatness, &minLineLength, &maxLineLength, &fillOverlap];
        fillOverlap = 1.0 - fillOverlap;
    }
    [aDecoder decodeValuesOfObjCTypes:"ccc", &inlay, &likeOtherLayers, &useForTile];
    color = [[aDecoder decodeObject] retain];
    [aDecoder decodeValuesOfObjCTypes:"@", &list];

    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithCapacity:9];
    NSPoint             p;

    [plist setObject:NSStringFromClass([self class])                forKey:@"Class"];
    [plist setObject:propertyListFromInt([[self class] version])    forKey:@"v"];
    [plist setObject:string                                         forKey:@"string"];
    [plist setInt:tag                                               forKey:@"tag"];
    [plist setObject:propertyListFromInt(state)                     forKey:@"state"];
    if (editable) [plist setObject:@"YES"                           forKey:@"editable"];
    [plist setObject:propertyListFromInt(type)                      forKey:@"type"];
    if (uniqueId)
        [plist setObject:propertyListFromInt(uniqueId)              forKey:@"uniqueId"];
    if (useForTile) [plist setObject:@"YES"                         forKey:@"useForTile"];
    if ( color )
        [plist setObject:propertyListFromNSColor(color)             forKey:@"color"];
    [plist setObject:propertyListFromArray(list)                    forKey:@"list"];

    if (layerDict)
        [plist setObject:layerDict                                  forKey:@"layerDict"];

    /* CAM */
    [plist setObject:propertyListFromInt(toolIndex)                 forKey:@"toolIndex"];
    [plist setObject:toolString                                     forKey:@"toolString"];
    if (filled) [plist setObject:@"YES"                             forKey:@"filled"];
    if (mirrored) [plist setObject:@"YES"                           forKey:@"mirrored"];
    if (removeLoops) [plist setObject:@"YES"                        forKey:@"removeLoops"];
    p = NSMakePoint((float)levelingX, (float)levelingY);
    [plist setObject:propertyListFromNSPoint(p)                     forKey:@"levelingLimits"];
    if (revertDirection) [plist setObject:@"YES"                    forKey:@"revertDirection"];
    [plist setObject:propertyListFromInt(side)                      forKey:@"side"];
    [plist setObject:propertyListFromFloat(dippingDepth)            forKey:@"dippingDepth"];
    [plist setObject:propertyListFromFloat(approachAngle)           forKey:@"approachAngle"];
    [plist setObject:propertyListFromFloat(flatness)                forKey:@"flatness"];
    [plist setObject:propertyListFromFloat(fillOverlap)             forKey:@"fillOverlap"];
    [plist setObject:propertyListFromFloat(fillDirection)           forKey:@"fillDirection"];
    if (inlay) [plist setObject:@"YES"                              forKey:@"inlay"];
    if (likeOtherLayers) [plist setObject:@"YES"                    forKey:@"likeOtherLayers"];

    if (stepwise) [plist setObject:@"YES"                           forKey:@"stepwise"];
    [plist setInt:numSteps                                          forKey:@"numSteps"];
    [plist setObject:propertyListFromFloat(step[0])                 forKey:@"step0"];
    [plist setObject:propertyListFromFloat(step[1])                 forKey:@"step1"];
    [plist setObject:propertyListFromFloat(step[2])                 forKey:@"step2"];

    if (settleBefore) [plist setObject:@"YES"                       forKey:@"settleBefore"];
    [plist setObject:propertyListFromFloat(settle)                  forKey:@"settle"];

    if (invisible) [plist setObject:@"YES"                          forKey:@"invisible"];

    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{   NSPoint	p;

    string          = [[plist objectForKey:@"string"] retain];
    tag             = [plist intForKey:@"tag"];
    state           = [plist intForKey:@"state"];
    editable        = ([plist objectForKey:@"editable"] ? YES : NO);
    type            = [plist intForKey:@"type"];
    uniqueId        = [plist intForKey:@"uniqueId"];
    likeOtherLayers = ([plist objectForKey:@"likeOtherLayers"] ? YES : NO);
    useForTile      = ([plist objectForKey:@"useForTile"] ? YES : NO);
    color           = colorFromPropertyList([plist objectForKey:@"color"], [self zone]);
    list            = arrayFromPropertyList([plist objectForKey:@"list"], directory, [self zone]);

    layerDict       = [[plist objectForKey:@"layerDict"] mutableCopy];

    /* CAM */
    toolIndex       = [plist intForKey:@"toolIndex"];
    toolString      = [[plist objectForKey:@"toolString"] retain];
    filled          = ([plist objectForKey:@"filled"] ? YES : NO);
    mirrored        = ([plist objectForKey:@"mirrored"] ? YES : NO);
    removeLoops     = ([plist objectForKey:@"removeLoops"] ? YES : NO);
    p               = pointFromPropertyList([plist objectForKey:@"levelingLimits"]);
    levelingX       = (int)p.x;
    levelingY       = (int)p.y;
    revertDirection = ([plist objectForKey:@"revertDirection"] ? YES : NO);
    side            = [plist intForKey:@"side"];
    dippingDepth    = [plist floatForKey:@"dippingDepth"];
    approachAngle   = [plist floatForKey:@"approachAngle"];
    flatness        = [plist floatForKey:@"flatness"];
    fillOverlap     = [plist floatForKey:@"fillOverlap"];
    fillDirection   = [plist floatForKey:@"fillDirection"];
    if ([plist objectForKey:@"minLineLength"])	// Cenon 3.30 - 3.31
        fillOverlap = 1.0 - fillOverlap;
    inlay           = ([plist objectForKey:@"inlay"] ? YES : NO);

    stepwise        = ([plist objectForKey:@"stepwise"] ? YES : NO);
    numSteps        = [plist intForKey:@"numSteps"];
    step[0]         = [plist floatForKey:@"step0"];
    step[1]         = [plist floatForKey:@"step1"];
    step[2]         = [plist floatForKey:@"step2"];
    calcSteps.count = 0;

    settleBefore    = ([plist objectForKey:@"settleBefore"] ? YES : NO);
    settle          = [plist floatForKey:@"settle"];

    invisible       = ([plist objectForKey:@"invisible"] ? YES : NO);

    return self;
}

- (void)dealloc
{
    [string release];
    [list release]; list = nil;
    [performanceMap removeAllObjects];  // remove references from graphics
    [performanceMap release];
    [layerDict release];

    [toolString release];

    [super dealloc];
}

@end
