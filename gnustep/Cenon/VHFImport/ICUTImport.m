/* ICUTImport.m
 * i-cut import object
 *
 * Copyright (C) 2012 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2011-09-16
 * modified: 2012-06-22 (shape added, any layer with names possible)
 *           2012-02-29 (ignore stuff after ops.cutcontour)
 *           2012-02-13 (ops.cutcontour like ops.corner, state.path = 0 after else)
 *
 * This file is part of the vhf Import Library.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by the vhf interservice GmbH. Among other things,
 * the License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this library; see the file LICENSE. If not, write to vhf.
 *
 * If you want to link this library to your proprietary software,
 * or for other uses which are not covered by the definitions
 * laid down in the vhf Public License, vhf also offers a proprietary
 * license scheme. See the vhf internet pages or ask for details.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#include <math.h>

#include "ICUTImport.h"
#include "functions.h"
//#include "../VHFShared/vhfCFGFunctions.h"
#include "../VHFShared/types.h"

#define DIGITS		@".+-0123456789"
#define JUMPDIGITS	@",.+-0123456789"
#define NOP		@" \t\r\n,"

/* r in points/inch */
#define	InternalToDeviceRes(a, r)	((float)(a) * (float)(r) / 72.0)
#define	DeviceResToInternal(a, r)	((float)(a) * 72.0 / (float)(r))

//static int linePattern[9][9] = {{0, -1, -1, -1, -1, -1, -1, -1, -1}, {0, 100, -1, -1, -1, -1, -1, -1, -1}, {50, 50, -1, -1, -1, -1, -1, -1, -1}, {70, 30, -1, -1, -1, -1, -1, -1, -1}, {80, 10, 0, 10, -1, -1, -1, -1, -1}, {70, 10, 10, 10, -1, -1, -1, -1, -1}, {50, 10, 10, 10, 10, 10, -1, -1, -1}, {70, 10, 0, 10, 0, 10, -1, -1, -1}, {50, 10, 0, 10, 10, 10, 0, 10, -1}};

//static void addToBeginNew(NSString *newOp, NSMutableString *beginNew);

@interface ICUTImport(PrivateMethods)
- (float)unitFromUnit:(int)u :(float)v;
- (void)initParameter;
- (BOOL)setUnitFromData:(NSData*)icutData;
- (BOOL)interpret:(NSString*)dataP;
- (BOOL)getGraphicFromData:(NSScanner*)scanner :cList;
//- (void)setPath:(NSScanner*)scanner :cList;
- (void)setPath:(NSScanner*)scanner :(NSString*)layerName;
- (void)updateBounds:(NSPoint)p;
@end

@implementation ICUTImport

- (float)unitFromUnit:(int)u :(float)v
{
    switch ( u )
    {
        case UNIT_MM:
            switch ( unit )
            {
                case UNIT_MM:		return v;                   // mm to mm
                case UNIT_INCH:		return ((v)*25.4);          // inch to mm
                default:            return ((v) / 72.0*25.4);   // point to mm
            }
        case UNIT_INCH:
            switch ( unit )
            {
                case UNIT_MM:		return ((v)/25.4);  // mm to inch
                case UNIT_INCH:		return v;           // inch to inch
                default:            return ((v)/72.0);  // point/internal to inch ??????
            }
        default:
            switch ( unit )
            {
                case UNIT_MM:		return ((v)*72.0/25.4); // mm to point
                case UNIT_INCH:		return ((v)*72.0);      // inch to point
                default:            return v;               // point point do degree to point
            }
    }
    return v;
}

- init
{
    [super init];

    unit = UNIT_INCH;
    fillClosedPaths = NO;
    originUL = NO;

    state.mode = 0;
    state.path = 0;
    state.pindex = 0;
    state.p0.x = state.p0.y = 0.0;
    state.p1.x = state.p1.y = 0.0;
    state.p2.x = state.p2.y = 0.0;
    state.p3.x = state.p3.y = 0.0;

    return self;
}

/* created:   03.05.96
 * modified:  09.03.97
 * parameter: fileName
 * purpose:   load parameter file
 */
- (void)initParameter
{
    ops.moveto = @"Moveto";
    ops.lineto = @"Lineto";
    ops.regmark = @"Regmark";
    ops.shape = @"Shape";
    ops.corner = @"Corner";
    ops.bezier = @"Bezier";
    ops.open   = @"Open";
    ops.closed = @"Closed";
    ops.cutcontour = @"CutContour";
    ops.comma  = @",";
    ops.termi  = @"\n";
}

- (void)fillClosedPaths:(BOOL)flag
{
    fillClosedPaths = flag;
}
- (void)originUL:(BOOL)flag
{
    originUL = flag;
}
/*- (void)changeXY:(BOOL)flag
{
    changeXY = flag;
}*/

- (BOOL)setUnitFromData:(NSData*)icutData
{   NSString		*dataStr;
    NSMutableString *unitLineStr = nil;
    NSScanner		*scanner;
    NSRange         range;
    int             location, firstLoc;

    dataStr = [[[NSString alloc] initWithData:icutData encoding:NSASCIIStringEncoding] autorelease];

    //if ( !(toolData = [NSMutableString stringWithContentsOfFile:fileName]) )
    if ( !dataStr )
        return NO;

    scanner = [NSScanner scannerWithString:dataStr];
    [scanner setCaseSensitive:YES];
    firstLoc  = location = [scanner scanLocation];
    
    [scanner scanUpToString:@"i-cut script" intoString:NULL];
    if ( ![scanner scanString:@"i-cut script" intoString:NULL] )
    {   NSLog(@"ICUTImport: No i-cut File");
        return NO;
    }
    [scanner scanUpToString:@"SystemUnits" intoString:NULL];
    [scanner scanUpToCharactersFromSet:termiSet intoString:&unitLineStr];

    range = [unitLineStr rangeOfString:@"Inch"];
    if ( range.length )
        unit = UNIT_INCH; // inch
    else
//    range = [unitLineStr rangeOfString:@"MM"];    // fixme: we dont know mm or MM
//    if ( range.length )
        unit = UNIT_MM; // millimeters

    return YES;
}

/* created:   1996-01-25
 * modified:  2002-10-26
 * parameter: hpglData	the HPGL data stream
 * purpose:   start interpretation of the contents of hpglData
 */
- importICUT:(NSData*)icutData
{
    [self initParameter];

    digitsSet = [NSCharacterSet characterSetWithCharactersInString:DIGITS];
    invDigitsSet = [digitsSet invertedSet];
    jumpSet = [NSCharacterSet characterSetWithCharactersInString:JUMPDIGITS];
    termiSet = [NSCharacterSet characterSetWithCharactersInString:ops.termi];
    newLineSet = [NSCharacterSet characterSetWithCharactersInString:@"\r\n"];

    if ( ![self setUnitFromData:icutData] )
        return nil;

    /* interpret data */
    if ( ![self interpret:[[[NSString alloc] initWithData:icutData
                                                 encoding:NSASCIIStringEncoding] autorelease]] )
        return nil;

    return [list autorelease];
}

/* private methods
 */
- (BOOL)interpret:(NSString*)dataP
{   NSRect          bounds;
    NSScanner       *scanner = [NSScanner scannerWithString:dataP];
    NSCharacterSet  *skipSet = [NSCharacterSet characterSetWithCharactersInString:NOP];

    /* init bounds */
    ll.x = ll.y = LARGE_COORD;
    ur.x = ur.y = LARGENEG_COORD;

    list = [self allocateList];

    [scanner setCharactersToBeSkipped:skipSet];
    while ( ![scanner isAtEnd] )
        if ( ![self getGraphicFromData:scanner :list] )
            break;


    bounds.origin = ll;
    bounds.size.width = ur.x - ll.x;
    bounds.size.height = ur.y - ll.y;
    [self setBounds:bounds];

    return YES;
}

/* the graphics list
 */
- (id)list;
{
    return list;
}

/* we need cp on a number !
 * modified: 2008-06-15
 */
- (BOOL)getGraphicFromData:(NSScanner*)scanner :cList
{   int location;

    /* one line per -getGraphicFromData: */

    location = [scanner scanLocation];
    if ( [scanner scanString:ops.regmark intoString:NULL] ) // RegMark f, f, RegMark
    {   float   xval, yval;

        if ( state.path )
        {
            [scanner setScanLocation:location];
            state.path = 0;
            return YES; // return to -setPath:
        }
        [scanner scanFloat:&xval];
        [scanner scanString:ops.comma intoString:NULL];
        [scanner scanFloat:&yval];
        [scanner scanString:ops.comma intoString:NULL];
        if ( [scanner scanString:ops.regmark intoString:NULL] )
        {
            state.p0.x = [self unitFromUnit:UNIT_POINT :xval]; // get internal from Inch
            state.p0.y = [self unitFromUnit:UNIT_POINT :yval]; // get internal from Inch
            /*if ( changeXY )
            {   float   bufy = state.p0.y;
            
                state.p0.y = state.p0.x;
                state.p0.x = bufy;
            }*/
            [self updateBounds:state.p0];
            //[self addMark:state.p0 toList:cList];
            [self addMark:state.p0 toLayer:nil];
            return YES;
        }
        else return NO;
    }
    else if ( [scanner scanString:ops.shape intoString:NULL] ) // Shape f, f, f, f, 1, LayerName
    {   float           xval, yval, wval, hval;
        int             intval;
        NSMutableString *layerName = nil;

        if ( state.path )
        {
            [scanner setScanLocation:location];
            state.path = 0;
            return YES; // return to -setPath:
        }
        [scanner scanFloat:&xval];
        [scanner scanString:ops.comma intoString:NULL];
        [scanner scanFloat:&yval];
        [scanner scanString:ops.comma intoString:NULL];
        [scanner scanFloat:&wval];
        [scanner scanString:ops.comma intoString:NULL];
        [scanner scanFloat:&hval];
        [scanner scanString:ops.comma intoString:NULL];
        [scanner scanInt:&intval];  // no idea what this is
        [scanner scanString:ops.comma intoString:NULL];
        //if ( [scanner scanString:ops.regmark intoString:NULL] )
        if ( [scanner scanUpToCharactersFromSet:newLineSet intoString:&layerName] )
        {   NSPoint rsize;

            state.p0.x = [self unitFromUnit:UNIT_POINT :xval]; // get internal from Inch
            state.p0.y = [self unitFromUnit:UNIT_POINT :yval]; // get internal from Inch
            rsize.x = [self unitFromUnit:UNIT_POINT :wval]; // get internal from Inch
            rsize.y = [self unitFromUnit:UNIT_POINT :hval]; // get internal from Inch
            /*if ( changeXY )
            {   float   bufy = state.p0.y;
            
                state.p0.y = state.p0.x;
                state.p0.x = bufy;
            }*/
            [self updateBounds:state.p0];
            [self updateBounds:NSMakePoint(state.p0.x+rsize.x, state.p0.y)];
            [self updateBounds:NSMakePoint(state.p0.x+rsize.x, state.p0.y+rsize.y)];
            [self updateBounds:NSMakePoint(state.p0.x, state.p0.y+rsize.y)];
            [self addRect:state.p0 :rsize toLayer:layerName];
            return YES;
        }
        else return NO;
    }
    else if ( [scanner scanString:ops.moveto intoString:NULL] ) // Moveto f, f, Open/Closed, CutContour
    {   float           xval, yval;
        NSMutableString *layerName = nil;

        if ( state.path )
        {
            [scanner setScanLocation:location];
            state.path = 0;
            return YES; // return to -setPath:
        }
        state.path = 1;

        [scanner scanFloat:&xval];
        [scanner scanString:ops.comma intoString:NULL];
        [scanner scanFloat:&yval];
        [scanner scanString:ops.comma intoString:NULL];
        if ( [scanner scanString:ops.open intoString:NULL] )
            state.mode = 0; // openPath
        if ( [scanner scanString:ops.closed intoString:NULL] )
            state.mode = 1; // openPath
        //if ( [scanner scanString:ops.cutcontour intoString:NULL] )
        if ( [scanner scanUpToCharactersFromSet:newLineSet intoString:&layerName] )
        {
            state.p0.x = [self unitFromUnit:UNIT_POINT :xval]; // get internal from Inch
            state.p0.y = [self unitFromUnit:UNIT_POINT :yval]; // get internal from Inch
            state.pindex = 1; // p0 ist set, next is p1
            [self updateBounds:state.p0];
            //[self setPath:scanner :cList];
            [self setPath:scanner :layerName];
            return YES;
        }
        else return NO;
    }
    else if ( [scanner scanString:ops.lineto intoString:NULL] ) // Lineto f, f, Corner/Bezier
    {   float   xval, yval;

        [scanner scanFloat:&xval];
        [scanner scanString:ops.comma intoString:NULL];
        [scanner scanFloat:&yval];
        [scanner scanString:ops.comma intoString:NULL];
        if ( [scanner scanString:ops.bezier intoString:NULL] )
        {
            switch (state.pindex)
            {   case 1:
                        state.p1.x = [self unitFromUnit:UNIT_POINT :xval]; // get internal from Inch
                        state.p1.y = [self unitFromUnit:UNIT_POINT :yval]; // get internal from Inch
                        state.pindex = 2; // first crv pt, next is second crv pt
                        [self updateBounds:state.p1];
                        break;
                default:
                //case 2:
                        state.p2.x = [self unitFromUnit:UNIT_POINT :xval]; // get internal from Inch
                        state.p2.y = [self unitFromUnit:UNIT_POINT :yval]; // get internal from Inch
                        state.pindex = 3; // second crv pt, next is end pt
                        [self updateBounds:state.p2];
                        break;
            }
            return YES;
        }
        else //if ( [scanner scanString:ops.corner intoString:NULL] ||     // Corner
             //[scanner scanString:ops.cutcontour intoString:NULL] )  // CutContour - mh ?
        {
            switch (state.pindex)
            {   case 1:
                        state.p1.x = [self unitFromUnit:UNIT_POINT :xval]; // get internal from Inch
                        state.p1.y = [self unitFromUnit:UNIT_POINT :yval]; // get internal from Inch
                        state.pindex = 1; // line end already 1
                        [self updateBounds:state.p1];
                        [self addLine:state.p0 :state.p1 toList:cList];
                        state.p0 = state.p1; // is our new p0 !
                        break;
                default:
                //case 3:
                        state.p3.x = [self unitFromUnit:UNIT_POINT :xval]; // get internal from Inch
                        state.p3.y = [self unitFromUnit:UNIT_POINT :yval]; // get internal from Inch
                        state.pindex = 1; // curve end already 1
                        [self updateBounds:state.p3];
                        [self addCurve:state.p0 :state.p1 :state.p2 :state.p3 toList:cList];
                        state.p0 = state.p3; // is our new p0 !
                        break;
            }
            return YES;
        }
       /* else if ( [scanner scanString:ops.bezier intoString:NULL] )
        {
            switch (state.pindex)
            {   case 1:
                        state.p1.x = [self unitFromUnit:UNIT_POINT :xval]; // get internal from Inch
                        state.p1.y = [self unitFromUnit:UNIT_POINT :yval]; // get internal from Inch
                        state.pindex = 2; // first crv pt, next is second crv pt
                        [self updateBounds:state.p1];
                        break;
                default:
                //case 2:
                        state.p2.x = [self unitFromUnit:UNIT_POINT :xval]; // get internal from Inch
                        state.p2.y = [self unitFromUnit:UNIT_POINT :yval]; // get internal from Inch
                        state.pindex = 3; // second crv pt, next is end pt
                        [self updateBounds:state.p2];
                        break;
            }
            return YES;
        }
        else return NO;*/
    }
    else if ( [scanner scanUpToString:ops.termi intoString:NULL] )
    {
        /* if ( state.path ) // hier nicht evtl muell hinter CutContour verhindert sonst Pfadbildung
        {
            [scanner setScanLocation:location];
            state.path = 0;
            return YES; // return to -setPath:
        }*/
        return YES; // continue;
    }
    else if ( state.path )
    {
        [scanner setScanLocation:location];
        state.path = 0;
        return YES; // return to -setPath:
    }
    return YES;
}

/*
 * created:   07.05.93
 * modified:  17.06.93 05.05.96
 * purpose:   set arc ccw
 * parameter: g
 */
//- (void)setPath:(NSScanner*)scanner :cList // cList is the array of the layer here
- (void)setPath:(NSScanner*)scanner :(NSString*)layerName // cList is the array of the layer here
{   NSMutableArray	*myList;				/* current list */

    [scanner scanString:ops.termi intoString:NULL]; // little bit faster

    myList = [[[NSMutableArray allocWithZone:[self zone]] init] autorelease];
    while (1)
    {
        if ( ![self getGraphicFromData:scanner :myList] )
            break;

        if ( !state.path ) // end of path ( new Moveto)
            break;
    }
    //add to layer
    if ( [myList count] > 1 )
    {
        if ( state.mode == 1 && fillClosedPaths ) // openPath
            //[self addFillList:myList toList:cList];
            [self addFillList:myList toLayer:layerName];
        else
            //[self addStrokeList:myList toList:cList];
            [self addStrokeList:myList toLayer:layerName];
        [myList removeAllObjects];
    }
    else if ( [myList count] ) // add single graphic in myList to cList
    {
        //[cList addObject:[myList objectAtIndex:0]];
        [self addStrokeList:myList toLayer:layerName]; // add only the single graphic
        [myList removeAllObjects];
    }
}

- (void)updateBounds:(NSPoint)p
{
    ll.x = Min(ll.x, p.x);
    ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x);
    ur.y = Max(ur.y, p.y);
}

- (void)dealloc
{
    [super dealloc];
}

/* methods to be subclassed
 */
- (id)allocateList
{
    return nil;
}

- (void)addFillList:aList toLayer:(NSString*)layerNamer
{
    NSLog(@"filled path. to layer");
}
- (void)addFillList:aList toList:(NSMutableArray*)bList
{
    NSLog(@"filled path.");
}

- (void)addStrokeList:aList toLayer:(NSString*)layerNamer
{
    NSLog(@"stroked path. to layer"); 
}
- (void)addStrokeList:aList toList:(NSMutableArray*)bList
{
    NSLog(@"stroked path."); 
}

- (void)addLine:(NSPoint)beg :(NSPoint)end toLayer:(NSString*)layerNamer
{
    NSLog(@"line: %f %f %f %f, to layer", beg.x, beg.y, end.x, end.y); 
}
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:(NSMutableArray*)aList
{
    NSLog(@"line: %f %f %f %f", beg.x, beg.y, end.x, end.y); 
}

- (void)addMark:(NSPoint)origin toLayer:(NSString*)layerNamer
{
    NSLog(@"regmark: %f %f, to layer", origin.x, origin.y); 
}
- (void)addMark:(NSPoint)origin toList:(NSMutableArray*)aList
{
    NSLog(@"regmark: %f %f", origin.x, origin.y); 
}

- (void)addRect:(NSPoint)origin :(NSPoint)rsize toLayer:(NSString*)layerNamer
{
    NSLog(@"rectangle: %f %f %f %f, to layer", origin.x, origin.y, rsize.x, rsize.y); 
}
- (void)addRect:(NSPoint)origin :(NSPoint)rsize toList:(NSMutableArray*)aList
{
    NSLog(@"rectangle: %f %f %f %f", origin.x, origin.y, rsize.x, rsize.y); 
}

- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toLayer:(NSString*)layerNamer
{
    NSLog(@"curve: %f %f %f %f %f %f %f %f, to layer", p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
}
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:(NSMutableArray*)aList
{
    NSLog(@"curve: %f %f %f %f %f %f %f %f", p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
}

- (void)setBounds:(NSRect)bounds
{
    NSLog(@"bounds: %f %f %f %f", bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
}
@end
