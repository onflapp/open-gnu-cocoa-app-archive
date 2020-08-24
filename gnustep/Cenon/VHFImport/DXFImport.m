/* DXFImport.m
 * DXF import object
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-05-01
 * modified: 2012-09-13 (Diff(l, 0.0) < 0.0000001, else division with 0)
 *           2012-02-04 (-scanGroup: transform coordinates from OCS to WCS, if necessary)
 *           2012-02-03 (InternalToDeviceRes(), DeviceResToInternal(): float -> double)
 *           2011-12-11 (-getGraphicFromData: TODO for SPLINEs added)
 *           2011-04-04 (-getGraphicFromData: 3DFACE TODO-log added)
 *           2011-02-27 (-init: initialize group.handle, state.color, blockScanner, rable, vivibleList)
 *           2010-10-31 (buildArc(): dx, dy calced with double)
 *           2010-09-11 (-importDXF: try UTF8 and Latin encodings to make GNUstep happy)
 *           2010-06-11 (buildArc(): 360.0 - acos(cn), was 180.0 - )
 *           2010-04-03 (-getArc: negative 360 deg arcs work now, buildArc(): dx == 0 case)
 *           2007-01-30 (close PolyLine: check for start == end point)
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

#include "DXFImport.h"
#include "dxfColorTable.h"
#include "dxfOperators.h"
#include "../VHFShared/vhf2DFunctions.h"
#include "../VHFShared/VHFDictionaryAdditions.h"
#include "../VHFShared/VHFStringAdditions.h"
#include "../VHFShared/types.h"

//#define	SqrDistPoints(p1, p2)	(((p1).x-(p2).x)*((p1).x-(p2).x)+((p1).y-(p2).y)*((p1).y-(p2).y))

/* r in points/inch */
#define	InternalToDeviceRes(a, r)	((double)(a) * (double)(r) / 72.0)
#define	DeviceResToInternal(a, r)	((double)(a) * 72.0 / (double)(r))

static NSCharacterSet	*newLineSet, *skipSet;

static BOOL gotoNextLine(NSScanner *scanner);
static BOOL gotoNextId(NSScanner *scanner, NSString *dataId);
static BOOL gotoSection(NSScanner *scanner, NSString *name);
static BOOL gotoTable(NSScanner *scanner, NSString *name);
static BOOL gotoGroup( NSScanner *scanner, NSString *name);
static NSArray *getTableFromData(NSString *data);
static NSColor *getColorFromTable(NSString *str, NSArray *table);
static void buildArc(NSPoint beg, NSPoint end, double a, NSPoint *ctr, float *angle);

@interface DXFImport(PrivateMethods)
- (BOOL)getHeader:(NSString*)data;
- (BOOL)interpret:(NSString*)data;
- (NSColor*)currentColor;
- (BOOL)getGraphicFromData:(NSScanner*)scanner :cList;
- (BOOL)scanGroup:(NSScanner*)scanner;
- (BOOL)getLine:(NSScanner*)scanner :(NSPoint*)p0 :(NSPoint*)p1 :(NSColor**)color;
- (BOOL)getLine3D:(NSScanner*)scanner :(V3Point*)p0 :(V3Point*)p1 :(NSColor**)color;
- (BOOL)getLWPolyline:(NSScanner*)scanner addToList:(NSMutableArray*)list;
- (BOOL)getPolyline:(NSScanner*)scanner;
- (BOOL)getVertex:(NSScanner*)scanner :(int*)kind :(NSPoint*)p0 :(NSPoint*)p1 :(float*)angle;
- (BOOL)getSolid:(NSScanner*)scanner :(NSPoint*)ps :(int*)pCnt;
- (BOOL)getCircle:(NSScanner*)scanner :(NSPoint*)ctr :(NSPoint*)start :(float*)angle;
- (BOOL)getArc:(NSScanner*)scanner :(NSPoint*)ctr :(NSPoint*)start :(float*)angle;
- (BOOL)getText :(NSScanner*)scanner mtext:(BOOL)mext :(NSString**)string :(float*)angle :(NSPoint*)origin :(float*)size :(float*)ar :(int*)alignment;
- (BOOL)get3DFace:(NSScanner*)scanner points:(V3Point*)pts color:(NSColor**)color;
- (BOOL)getInsert:(NSScanner*)scanner :cList;
- (void)updateBounds:(NSPoint)p;

- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar at:(NSPoint)p 	toLayer:(NSString*)layerName;	// old
@end

@implementation DXFImport

static BOOL gotoNextLine(NSScanner *scanner)
{
    [scanner scanUpToCharactersFromSet:newLineSet intoString:NULL];	// CR or LF
    if ( [scanner scanString:@"\n" intoString:NULL] )
        [scanner scanString:@"\r" intoString:NULL];
    else if ( [scanner scanString:@"\r" intoString:NULL] )
        [scanner scanString:@"\n" intoString:NULL];
    return YES;
}

/* scan to given id line inside the current group (except we search a group id)
 * scanner have to be on an id!
 */
static BOOL gotoNextId(NSScanner *scanner, NSString* dataId)
{   NSString	*string;
    int		location = [scanner scanLocation];

    while ( ![scanner isAtEnd] )
    {
        /* we are on id line */
        if ( [scanner scanString:dataId intoString:&string] )
            return YES;
        if ( [scanner scanString:IDGROUP intoString:&string] )	/* end of group -> don't move pointer */
        {   [scanner setScanLocation:location];
            return NO;
        }
        gotoNextLine(scanner);	/* goto value */
        gotoNextLine(scanner);	/* goto id */
    }

    return NO;
}

/* created:   1993-05-12
 * modified:  2002-10-08
 *
 * purpose:   return scanner containing the block section
 * parameter: scanner (current position)
 * return:    blockScanner
 */
- (NSScanner*)blockScannerFromScanner:(NSScanner*)scanner
{   NSString	*string;
    int		location;

    if (blockScanner)
    {   [blockScanner setScanLocation:0];
        return blockScanner;
    }

    blockScanner = [NSScanner scannerWithString:[scanner string]];
    [blockScanner setCharactersToBeSkipped:skipSet];

    location = [blockScanner scanLocation];

    if ( !gotoSection(blockScanner, NAMBLOCKS) )
        return nil;
    [blockScanner scanUpToString:GRPENDSEC intoString:&string];	/* end of the section */
    blockScanner = [[NSScanner scannerWithString:[string stringByAppendingFormat:@"%@\r\n", GRPENDSEC]] retain];
    [blockScanner setCharactersToBeSkipped:skipSet];

    return blockScanner;
}

/* created:   12.05.93
 * modified:  12.05.93 10.03.97
 *
 * purpose:   set scanner to the beginning (first group entry) of a named section
 * parameter: scanner (current position)
 *		name (name of section)
 * return:    position on id of first entry
 */
static BOOL gotoSection(NSScanner *scanner, NSString *name)
{
    while ( ![scanner isAtEnd] )
    {
        if ( [scanner scanUpToString:GRPSECTION intoString:NULL] )	/* new section */
        {
            [scanner scanString:GRPSECTION intoString:NULL];
            [scanner scanCharactersFromSet:newLineSet intoString:NULL];
            if ( [scanner scanString:IDNAME intoString:NULL] )		/* name code */
            {
                if (![scanner scanCharactersFromSet:newLineSet intoString:NULL])
                    NSLog(@"GotoSection: Newline expected at location: %d", [scanner scanLocation]);
                if ( [scanner scanString:name intoString:NULL] )		/* check name */
                {
                    if (![scanner scanCharactersFromSet:newLineSet intoString:NULL])
                        NSLog(@"GotoSection: Newline expected at location: %d", [scanner scanLocation]);
                    return YES;
                }
            }
        }
    }
    return NO;
}

/* created:   12.05.93
 * modified:  08.12.97
 *
 * purpose:   set cp to the beginning (on the name) of a named table
 *            we set scanner to a position on start of first entry (id line)
 * parameter: scanner (current position)
 *            name (name of table)
 */
static BOOL gotoTable(NSScanner *scanner, NSString *name)
{
    while ( ![scanner isAtEnd] )
    {
        if ( [scanner scanUpToString:GRPTABLE intoString:NULL] )	/* new table */
        {
            [scanner scanString:GRPTABLE intoString:NULL];
            if ( [scanner scanCharactersFromSet:newLineSet intoString:NULL] && [scanner scanString:@"2" intoString:NULL] )	/* newline, name code */
            {
                if (![scanner scanCharactersFromSet:newLineSet intoString:NULL])
                    NSLog(@"GotoTable: Newline expected at location: %d", [scanner scanLocation]);
                if ( [scanner scanString:name intoString:NULL] )		/* check name */
                {
                    if (![scanner scanCharactersFromSet:newLineSet intoString:NULL])
                        NSLog(@"GotoTable: Newline expected at location: %d", [scanner scanLocation]);
                    return YES;
                }
            }
        }
    }
    return NO;
}

/* created:   1993-05-17
 * modified:  2001-02-23
 *
 * purpose:   get tables from data
 *            at the moment we only read the layer table...
 * parameter: data (dxf file)
 */
static NSArray *getTableFromData(NSString *data)
{   NSScanner           *scanner = [NSScanner scannerWithString:data];
    NSString            *string;
    NSMutableArray      *table = [NSMutableArray array];
    NSMutableDictionary *dict = nil;

    [scanner setCharactersToBeSkipped:skipSet];

    if ( !gotoSection(scanner, NAMTABLES) )
    {   NSLog(@"Can't get section 'TABLE' from dxf data");
        return nil;
    }

    /* read the layer table
     */
    if (!gotoTable(scanner, NAMLAYER))
    {   NSLog(@"Can't get table 'LAYER' from dxf data");
        return nil;
    }
    /* 2
     * LAYER
     * we are here
     */
    while ( ![scanner isAtEnd] )
    {	int	ident, i;

        /* scan id */
        if ( ![scanner scanInt:&ident] )
        {   NSLog(@"DXF-Import: id expected at location: %d", [scanner scanLocation]);
            return NO;
        }
        gotoNextLine(scanner);	// goto value line
        switch ( ident )
        {
            case ID_GROUP:
                if (![scanner scanUpToCharactersFromSet:newLineSet intoString:&string])
                    string = @"";
                if (![string isEqual:GRPLAYER])	// ENDTAB
                    break;
                dict = [NSMutableDictionary dictionary];
                break;
            case ID_NAME:
                if (![scanner scanUpToCharactersFromSet:newLineSet intoString:&string])
                    break;
                [dict setObject:string forKey:@"name"];
                [table addObject:dict];
                break;
            case ID_COLOR:
                [scanner scanUpToCharactersFromSet:newLineSet intoString:&string];
                [dict setObject:string forKey:@"colorNum"];
                break;
            case ID_FLAGS:
                if (![scanner scanInt:&i])
                    i = 0;
                [dict setInt:i forKey:@"flags"];
                break;
        }
        gotoNextLine(scanner);	// goto id line
        if (ident == ID_GROUP && ![string isEqual:@"LAYER"])
            break;
    }

    return table;
}

/* get visible objects from OBJECTS section
 * parameter: data (dxf file)
 *
 * created:  2001-02-23
 * modified: 2005-11-23 (check for EOF)
 */
static NSArray *getVisibleListFromData(NSString *data)
{   NSScanner		*scanner = [NSScanner scannerWithString:data];
    NSString		*string;
    NSMutableArray	*visibleList = [NSMutableArray array];
    BOOL		idbuffer = NO;

    [scanner setCharactersToBeSkipped:skipSet];

    if ( !gotoSection(scanner, NAMOBJECTS) )
        return nil;

    /* 2
     * OBJECTS
     * we are here
     */
    while ( ![scanner isAtEnd] )
    {	int	ident;

        /* scan id */
        if ( ![scanner scanInt:&ident] )
        {   NSLog(@"DXF-Import: id expected at location: %d", [scanner scanLocation]);
            return nil;
        }
        gotoNextLine(scanner);	// goto value line
        switch ( ident )
        {
            case ID_GROUP:	// 0
                if (![scanner scanUpToCharactersFromSet:newLineSet intoString:&string])
                    string = @"";
                if ([string isEqual:GRPEOF])
                    return nil;
                idbuffer = ([string isEqual:GRPIDBUFFER]) ? YES : NO;
                break;
            case ID_REFENTITY:	// 330
                if (!idbuffer)
                    break;
                if (![scanner scanUpToCharactersFromSet:newLineSet intoString:&string])
                    break;
                [visibleList addObject:string];
        }
        gotoNextLine(scanner);	// goto id line
        if (ident == ID_GROUP && [string isEqual:@"GRPENDSEC"])
            break;
    }

    return visibleList;
}

/* created:   17.05.93
 * modified:  17.05.93 10.03.97 18.06.99
 *
 * purpose:   set the pointer to the beginning of a new group
 * parameter: scanner (the dxf file, position at id line)
 * return:    pointer behind the name of the new group but still in the line of the name
 */
static BOOL gotoGroup( NSScanner *scanner, NSString *name )
{   BOOL	caseSensitive = [scanner caseSensitive];

    [scanner setCaseSensitive:YES];
    while ( ![scanner isAtEnd] )
    {
	/* search identifier */
        [scanner scanUpToString:IDGROUP intoString:NULL];

        if ( ![scanner scanString:IDGROUP intoString:NULL] )
            break;
        if ( ![scanner scanCharactersFromSet:newLineSet intoString:NULL] )
            continue;

        if ( [scanner scanString:name intoString:NULL] )
        {
            if (![scanner scanCharactersFromSet:newLineSet intoString:NULL])
                NSLog(@"GotoGroup: Newline expected at location: %d", [scanner scanLocation]);
            [scanner setCaseSensitive:caseSensitive];
            return YES;
        }
    }
    [scanner setCaseSensitive:caseSensitive];

    return NO;
}

/* created:   1993-05-16
 * modified:  2001-02-23
 *
 * purpose:   get color from color table
 * parameter: str (string representing the layer name "YELLOW")
 *            table ()
 * return:    color
 */
static NSColor *getColorFromTable(NSString *str, NSArray *table)
{   int			i;
    DXFColor		col;
    NSColor		*color;
    //NSDictionary	*dict;

    /*if (dict = [table objectForKey:str])
    {   int	colIx = [dict intForKey:@"colorNum"];

        col = colorTable[(colIx > 0) ? colIx-1 : 0];
        color = [NSColor colorWithCalibratedRed:col.r green:col.g blue:col.b alpha:1.0];
        return color;
    }*/
    for (i=[table count]-1; i>=0; i--)
    {   NSDictionary	*dict = [table objectAtIndex:i];

        if ( [[dict objectForKey:@"name"] isEqual:str] )
        {   int	colIx = [[dict objectForKey:@"colorNum"] intValue];

            col = colorTable[(colIx > 0) ? colIx-1 : 0];
            color = [NSColor colorWithCalibratedRed:col.r green:col.g blue:col.b alpha:1.0];
            return color;
        }
    }
    color = [NSColor blackColor];
    return color;
}

- init
{
    [super init];

    res = 25.4;
    group.text = nil;
    group.name = nil;
    group.layer = nil;
    group.handle = nil;

    state.color = nil;

    blockScanner = nil;
    table = nil;
    visibleList = nil;

    return self;
}

- (void)setRes:(float)rs
{
    res = rs; 
}

/* created:   1996-01-25
 * modified:  2010-09-11 (load UTF8 instead of ASCII, if it fails try Latin)
 * parameter: dxfData	the DXF data stream
 * purpose:   start interpretation of dxfData
 */
- (id)importDXF:(NSData*)dxfData
{   NSString	*data = [[[NSString alloc] initWithData:dxfData
                                            encoding:NSUTF8StringEncoding] autorelease];

    if ( ! data )   // try latin
        data = [[[NSString alloc] initWithData:dxfData
                                      encoding:NSISOLatin1StringEncoding] autorelease];

    newLineSet = [NSCharacterSet characterSetWithCharactersInString:@"\r\n"];
    skipSet = [NSCharacterSet characterSetWithCharactersInString:@" \t"];

    state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];
    state.begWidth = state.endWidth = 0.0;

    [blockScanner release];
    blockScanner = nil;

    /* read header */
    if (![self getHeader:data])
        return nil;

    /* read table
     */
    table = getTableFromData(data);

    /* get visible list from OBJECT section */
    visibleList = getVisibleListFromData(data);

    /* interpret data
     */
    if ( ![self interpret:data] )
        return nil;

    return [list autorelease];
}

/* private methods
 */

- (BOOL)getHeader:(NSString*)data
{   NSScanner	*scanner = [NSScanner scannerWithString:data];
    BOOL	ready = NO;
    NSString	*name = nil;

    [scanner setCharactersToBeSkipped:skipSet];
    if ( !gotoSection(scanner, NAMHEADER) )
        return YES;

    /* we are on id line */
    while ( ![scanner isAtEnd] && !ready )
    {   int	i;

        if (![scanner scanInt:&i])	// get id
            NSLog(@"getHeader: integer expected at location: %d", [scanner scanLocation]);

        gotoNextLine(scanner);		// goto value
        switch (i)
        {
            case ID_X0:
                [scanner scanFloat:&group.x0];
                break;
            case ID_Y0:
                [scanner scanFloat:&group.y0];
                break;
            case ID_GROUP:
            case ID_VARNAME:
                if ( [name isEqual:GRPEXTMIN] )
                {
                    extMin.x = DeviceResToInternal(group.x0, res);
                    extMin.y = DeviceResToInternal(group.y0, res);
                }
                else if ( [name isEqual:GRPEXTMAX] )
                {
                    extMax.x = DeviceResToInternal(group.x0, res);
                    extMax.y = DeviceResToInternal(group.y0, res);
                }

                if ( i == ID_GROUP )	// ENDSEC -> ready
                {
                    ready = YES;
                    break;
                }
                [scanner scanUpToCharactersFromSet:newLineSet intoString:&name];	// get name
        }
        gotoNextLine(scanner);	// goto id
    }

    return YES;
}

- (BOOL)interpret:(NSString*)data
{   NSMutableArray  *cList;		// current list
    NSRect          bounds;
    NSScanner       *scanner = [NSScanner scannerWithString:data];

    /* init bounds */
    ll.x = ll.y = LARGE_COORD;
    ur.x = ur.y = LARGENEG_COORD;

    [scanner setCharactersToBeSkipped:skipSet];
    if (!gotoSection(scanner, NAMENTITIES))
    {   NSLog(@"Can't get section 'ENTITIES' from dxf data");
        return NO;
    }

    list = [self allocateList:table];
    cList = [NSMutableArray array];

    while ( ![scanner isAtEnd] )
        if (![self getGraphicFromData:scanner :cList])
            return NO;

    bounds.origin = extMin;
    bounds.size.width  = extMax.x - extMin.x;
    bounds.size.height = extMax.y - extMin.y;
    if (bounds.size.width < TOLERANCE || bounds.size.height < TOLERANCE)
    {
        bounds.origin = ll;
        bounds.size.width = ur.x - ll.x;
        bounds.size.height = ur.y - ll.y;
    }
    else if (ll.x < extMin.x || ll.y < extMin.y || ur.x > extMax.x || ur.y > extMax.y)
        NSLog(@"DXF-Import: Drawing extends ($EXTMIN, $EXTMAX) do not contain all coordinates !!");

    [self setBounds:bounds];

    return YES;
}

/* we need scanner on the id line of a group
 * modified: 2005-09-26 (close polyline with arc)
 */
- (BOOL)getGraphicFromData:(NSScanner*)scanner :(id)cList
{   NSPoint     p0, p1;
    NSString    *name;

    /* goto name line */
    [scanner scanUpToCharactersFromSet:newLineSet intoString:NULL];
    [scanner scanCharactersFromSet:newLineSet intoString:NULL];
    /* get name */
    [scanner scanUpToCharactersFromSet:newLineSet intoString:&name];
    /* goto id line */
    if (![scanner scanCharactersFromSet:newLineSet intoString:NULL])
        NSLog(@"getGraphicFromData:: Newline expected at location: %d", [scanner scanLocation]);

    switch ( state.mode )
    {
        case MODE_NORMAL:
            /* line */
            if ( [name isEqual:GRPLINE] )
            {
                if ([self getLine:scanner :&p0 :&p1 :&state.color])
                    [self addLine:p0 :p1 toLayer:group.layer];
            }
            /* lwpolyline */
            else if ( [name isEqual:GRPLWPOLYLINE] )
            {
                [self getLWPolyline:scanner addToList:cList];
            }
            /* polyline */
            else if ( [name isEqual:GRPPOLYLINE] )
            {
                [self getPolyline:scanner];
            }
            /* solid */
            else if ( [name isEqual:GRPSOLID] )
            {	NSPoint	ps[8];
                int	i, cnt;

                if ([self getSolid:scanner :ps :&cnt])
                {
                    for (i=0; i<cnt-1; i++)
                    {   [self addLine:ps[i] :ps[i+1] toList:cList];
                        [self updateBounds:ps[i]];
                    }
                    if ([cList count])
                    {   [self addFillList:cList toLayer:group.layer];
                        [cList removeAllObjects];
                    }
                }
            }
            /* circle */
            else if ( [name isEqual:GRPCIRCLE] )
            {	NSPoint	ctr, start;
                float	angle;

                if ([self getCircle:scanner :&ctr :&start :&angle])
                    [self addArc:ctr :start :angle toLayer:group.layer];
            }
            /* arc */
            else if ( [name isEqual:GRPARC] )
            {	NSPoint	ctr, start;
                float	angle;

                if ([self getArc:scanner :&ctr :&start :&angle])
                    [self addArc:ctr :start :angle toLayer:group.layer];
            }
            /* text, mtext */
            else if ( [name isEqual:GRPTEXT] || [name isEqual:GRPMTEXT] )
            {	NSPoint     origin;
                float       angle, size, ar;
                int         alignment;
                NSString    *string = nil;

                if ([self getText:scanner mtext:[name isEqual:GRPMTEXT]
                                 :&string :&angle :&origin :&size :&ar :&alignment])
                {
                    if ([self respondsToSelector:@selector(addText:::::at:toLayer:)])	// old
                        [self addText:string :@"Courier" :angle :size :ar at:origin
                              toLayer:group.layer];
                    else
                        [self addText:string :@"Courier" :angle :size :ar :alignment at:origin
                              toLayer:group.layer];
                }
                [string autorelease];
            }
            /* insert */
            else if ( [name isEqual:GRPINSERT] )
            {
                [self getInsert:scanner :cList];
            }
            /* SPLINE */
            else if ( [name isEqual:GRPSPLINE] )
            {
                // TODO: SPLINEs (see example Stebner_SPLINEs*.dxf)
                //if ([self getSpline:scanner :pts :&state.color])  // we should return/convert to bezier curve(s)
                //    [self addCurve:pts toLayer:group.layer];
                printf("TODO, DXF-Import: SPLINEs not implemented\n");
            }
            /* 3D LINE */
            else if ( [name isEqual:GRP3DLINE] )
            {   V3Point p0, p1;

                if ([self getLine3D:scanner :&p0 :&p1 :&state.color])
                    [self addLine3D:p0 :p1 toLayer:group.layer];
            }
            /* 3D FACE */
            else if ( [name isEqual:GRP3DFACE] )
            {   V3Point pts[4];

                if ([self get3DFace:scanner points:pts color:&state.color] )
                    [self add3DFace:pts toLayer:group.layer];
            }
            break;
        case MODE_VERTEX:
            /* vertex */
            if ( [name isEqual:GRPVERTEX] )
            {	int     kind;
                float   a;

                [self getVertex:scanner :&kind :&p0 :&p1 :&a];
                //printf("kind=%d p0={%.0f %.0f} p1={%.0f %.0f} a=%.0f\n", kind, p0.x, p0.y, p1.x, p1.y, a);
                switch (kind)
                {
                    case 1: [self addLine:p0 :p1   toList:cList]; break;
                    case 2: [self addArc:p1 :p0 :a toList:cList]; break;
                }
            }
            else if ( [name isEqual:GRPSEQEND] )
            {
                if (state.modeClosed)
                {   NSPoint	ctr;
                    float	angle;

                    if ( Diff(state.first.x, state.point.x) > TOLERANCE ||
                         Diff(state.first.y, state.point.y) > TOLERANCE )
                    {
                        if (!group.a /* state.A*/)
                            [self addLine:state.first :state.point toList:cList];
                        else
                        {   buildArc(state.point, state.first, group.a, &ctr, &angle);
                            [self addArc:ctr :state.point :angle toList:cList];
                        }
                    }
                }
                if ([cList count])
                {   [self addStrokeList:cList toLayer:group.layer];
                    [cList removeAllObjects];
                }
                state.mode = MODE_NORMAL;
                state.modeClosed = MODE_NORMAL;
                state.id = 0;
            }
    }

    gotoNextId(scanner, IDGROUP);

    return YES;
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
    [group.text release];
    [group.name release];
    [group.layer release];

    [blockScanner release];

    [super dealloc];
}


/* created:   17.05.93
 * modified:  18.05.93 10.03.97
 *
 * purpose:   get line
 * parameter: scanner (the dxf data)
 *            g (the destination for the element)
 *            state
 *            parms
 */
- (BOOL)getLine:(NSScanner*)scanner :(NSPoint*)p0 :(NSPoint*)p1 :(NSColor**)color
{
    [self scanGroup:scanner];
    if ( [visibleList count] && ![visibleList containsObject:group.handle])
        return NO;

    *color = [self currentColor];
    p0->x = DeviceResToInternal(group.x0, res) + state.offset.x;
    p0->y = DeviceResToInternal(group.y0, res) + state.offset.y;
    p1->x = DeviceResToInternal(group.x1, res) + state.offset.x;
    p1->y = DeviceResToInternal(group.y1, res) + state.offset.y;

    state.width = 0.0;

    [self updateBounds:*p0];
    [self updateBounds:*p1];

    return YES;
}

/* created:   2011-04-04
 * modified:  
 *
 * purpose:   get 3D line
 * parameter: scanner (the dxf data)
 *            g (the destination for the element)
 *            state
 *            parms
 */
- (BOOL)getLine3D:(NSScanner*)scanner :(V3Point*)p0 :(V3Point*)p1 :(NSColor**)color
{
    [self scanGroup:scanner];
    if ( [visibleList count] && ![visibleList containsObject:group.handle])
        return NO;

    *color = [self currentColor];
    p0->x = DeviceResToInternal(group.x0, res) + state.offset.x;
    p0->y = DeviceResToInternal(group.y0, res) + state.offset.y;
    p0->z = DeviceResToInternal(group.z0, res) /*+ state.offset.z*/;
    p1->x = DeviceResToInternal(group.x1, res) + state.offset.x;
    p1->y = DeviceResToInternal(group.y1, res) + state.offset.y;
    p1->z = DeviceResToInternal(group.z1, res) /*+ state.offset.z*/;

    state.width = 0.0;

    [self updateBounds:NSMakePoint(p0->x, p0->y)];
    [self updateBounds:NSMakePoint(p1->x, p1->y)];

    return YES;
}

/* created:   2001-02-22
 * modified:  2006-08-10 (check for close with & operator)
 *
 * purpose:   get LWPOLYLINE group
 * parameter: scanner (the dxf data at id line)
 */
- (BOOL)getLWPolyline:(NSScanner*)scanner addToList:(NSMutableArray*)cList
{   BOOL	coordsScanned = NO;

    /* 0
     * LWPOLYLINE
     * here we are !
     */

    state.id = 0;
    state.width = 0.0;

    [group.layer release]; group.layer = nil;
    [group.handle release]; group.handle = nil;
    group.color = 0;
    group.width = 0.0;
    group.endWidth = 0.0;
    group.x0 = group.y0 = 0.0;
    group.a = 0.0;

    while ( ![scanner isAtEnd] )
    {	int	i, location = [scanner scanLocation];

        /* scan id */
        if ( ![scanner scanInt:&i] )
        {   NSLog(@"DXF-Import: id expected at location: %d", [scanner scanLocation]);
            return NO;
        }
        gotoNextLine(scanner);	// goto value line
        switch ( i )
        {
            case ID_LAYER:
                if (![scanner scanUpToCharactersFromSet:newLineSet intoString:&group.layer])
                    group.layer = nil;
                [group.layer retain];
                state.color = [self currentColor];
                break;
            case ID_HANDLE:
                if (![scanner scanUpToCharactersFromSet:newLineSet intoString:&group.handle])
                    group.handle = nil;
                [group.handle retain];
                break;
            case ID_X0:
            case ID_GROUP:
                /* add elements */
                if (coordsScanned)
                {   NSPoint	beg, end, ctr;
                    float	angle;

                    if (state.id)
                        beg = state.point;
                    end.x = DeviceResToInternal(group.x0, res) + state.offset.x;
                    end.y = DeviceResToInternal(group.y0, res) + state.offset.y;

                    if ( !state.id )	// start
                    {	state.first = end;
                        state.id = 1;
                    }
                    else if (state.A)	// arc
                    {   float	begA, r;
                        NSRect	rect;

                        buildArc(beg, end, state.A, &ctr, &angle);
                        //[self updateBounds:beg];
                        //[self updateBounds:end];
                        //[self updateBounds:ctr];
                        r = sqrt(SqrDistPoints(ctr, beg));
                        begA = vhfAngleOfPointRelativeCenter(beg, ctr);
                        rect = vhfBoundsOfArc(ctr, r, begA, angle);
                        [self updateBounds:rect.origin];
                        [self updateBounds:NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y)];
                        [self updateBounds:NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y+rect.size.height)];
                        [self updateBounds:NSMakePoint(rect.origin.x, rect.origin.y+rect.size.height)];
                        [self addArc:ctr :beg :angle toList:cList];
                    }
                    else		// line
                    {
                        [self updateBounds:beg];
                        [self updateBounds:end];
                        [self addLine:beg :end toList:cList];
                    }
                    state.point = end;
                    state.A = group.a;
                    group.endWidth = 0.0;
                    group.a = 0.0;
                }
                /* get coordinate */
                if (i == ID_X0)
                {
                    if (![scanner scanFloat:&group.x0])
                        group.x0 = 0.0;
                    coordsScanned = YES;
                    break;
                }
                /* ready */
                [scanner setScanLocation:location];
                if (state.modeClosed)
                {
                    if (state.A)
                    {   NSPoint	ctr;
                        float	angle;

                        buildArc(state.point, state.first, state.A, &ctr, &angle);
                        [self addArc:ctr :state.point :angle toList:cList];
                    }
                    else
                        [self addLine:state.first :state.point toList:cList];
                }
                if ( ![visibleList count] || [visibleList containsObject:group.handle])
                {
                    if ([cList count])
                    {   [self addStrokeList:cList toLayer:group.layer];
                        [cList removeAllObjects];
                    }
                }
                state.mode = MODE_NORMAL;
                state.modeClosed = MODE_NORMAL;
                state.id = 0;
                return YES;
            case ID_Y0:
                if (![scanner scanFloat:&group.y0])
                    group.y0 = 0.0;
                break;
            case ID_CONSTWIDTH:
                if (![scanner scanFloat:&group.width])
                    group.width = 0.0;
                state.width = DeviceResToInternal(Abs(group.width), res);
                break;
            case ID_WIDTH:
                if (![scanner scanFloat:&group.width])
                    group.width = 0.0;
                state.width = DeviceResToInternal(Abs(group.width), res);
                break;
            case ID_ENDWIDTH:
                if (![scanner scanFloat:&group.endWidth])
                    group.endWidth = 0.0;
                state.endWidth = DeviceResToInternal(Abs(group.endWidth), res);
                break;
            case ID_A:
                if (![scanner scanFloat:&group.a])
                    group.a = 0.0;
                break;
            case ID_COLOR:
                if (![scanner scanInt:&group.color])
                    group.color = 0;
                state.color = [self currentColor];
                break;
            case ID_FLAGS:
                if (![scanner scanInt:&group.flags])
                    group.flags = 0;
                state.modeClosed = ( group.flags &  1 ) ? MODE_CLOSED : 0;
                break;
        }
        gotoNextLine(scanner);	// goto id line
    }

    NSLog(@"unexpected end of LWPOLILINE !");
    return YES;
}

/* created:   18.05.93
 * modified:  10.06.93 30.09.94 01.05.96
 *
 * purpose:   get polyline
 * parameter: scanner (the dxf data at id line)
 */
- (BOOL)getPolyline:(NSScanner*)scanner
{
    /* 0
     * POLYLINE
     * here we are !
     */

    [self scanGroup:scanner];
    if ( [visibleList count] && ![visibleList containsObject:group.handle])
        return NO;

    /* get element specific begin width */
    state.begWidth = (group.width<0) ? 0 : DeviceResToInternal(group.width, res);
    /* get element specific end width */
    state.endWidth = (group.endWidth<0) ? 0 : DeviceResToInternal(group.endWidth, res);

    state.mode = (group.more == 1) ? MODE_VERTEX : 0;
    state.modeClosed = ( group.flags ==  1 ) ? MODE_CLOSED : 0;

    state.id = 0;

    return YES;
}

/* created:   1993-05-18
 * modified:  1998-08-05
 *
 * purpose:   get vertex
 * parameter: cp (the dxf data)
 *            g (the destination for the element)
 */
- (BOOL)getVertex:(NSScanner*)scanner :(int*)kind :(NSPoint*)p0 :(NSPoint*)p1 :(float*)angle
{   float	x, y, a = 0;
    float	bw, ew;
    NSPoint	beg, end;

    a = group.a;	// type is one behind
    [self scanGroup:scanner];

    state.color = [self currentColor];
    /* get element specific begin width */
    bw = (group.width<0)    ? state.begWidth : DeviceResToInternal(group.width, res);
    /* get element specific end width */
    ew = (group.endWidth<0) ? state.endWidth : DeviceResToInternal(group.endWidth, res);
    x = group.x0;
    y = group.y0;

    beg = state.point;
    end.x = DeviceResToInternal(x, res) + state.offset.x;
    end.y = DeviceResToInternal(y, res) + state.offset.y;

    /* segments */
    if ( !state.id )	// start
    {	state.first = end;
        //state.A = a;
        //state.bw = bw;	/* remember begin width */
        //state.ew = ew;	/* remember end width */
        state.id = 1;
        *kind = 0;
    }
    else if (a)		// arc
    {   NSRect	rect;
        float	begA, r;

        *p0 = beg;
        buildArc(beg, end, a, p1, angle);	// begPt, endPt, Arg! -> center, angle
        //[self updateBounds:end];
        //[self updateBounds:*p0];
        //[self updateBounds:*p1];
        r = sqrt(SqrDistPoints(*p1, beg));
        begA = vhfAngleOfPointRelativeCenter(beg, *p1);
        rect = vhfBoundsOfArc(*p1, r, begA, *angle);
        [self updateBounds:rect.origin];
        [self updateBounds:NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y)];
        [self updateBounds:NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y+rect.size.height)];
        [self updateBounds:NSMakePoint(rect.origin.x, rect.origin.y+rect.size.height)];
        /* we need to add update bounds with a !! */
        *kind = 2;
    }
    else		// line
    {
        *p0 = beg;
        *p1 = end;
        *angle = 0;
        *kind = 1;
        [self updateBounds:*p0];
        [self updateBounds:*p1];
    }

    /* begin new element */
    state.point = end;
    state.bw = bw;		/* remember begin width */
    state.ew = ew;		/* remember end width */
    state.A = a;

    state.width = bw;

    return YES;
}

/* Note: see page 323 of DXF book
 * modified: 2012-09-13 (Diff(l, 0.0) < 0.0000001, else division with 0)
 *           2010-10-31 (dx, dy calced with double)
 *           2010-06-11 (360 - acos(cn))
 *           2010-04-03
 */
static void buildArc(NSPoint beg, NSPoint end, double a, NSPoint *ctr, float *angle)
{   NSPoint	p;
    double	l, ang, dx, dy, r, an, h;
    double  mx, my, begx = beg.x, begy = beg.y, endx = end.x, endy = end.y;

    ang = 4.0 * RadToDeg(atan( a ));
    l = sqrt(SqrDistPoints(beg, end));  // length of arc from point to point
    if ( Diff(l, 0.0) < 0.0000001 )
    {
        *ctr = beg;     // null length arc else division with 0
        *angle = 0.0;
        return;
    }
    h = (a*l)/2.0;                      // height of arc
    mx = (begx+endx)/2.0; my = (begy+endy)/2.0; // mit point between start and end
    dx = mx - begx;                     // 
    dy = my - begy;                     // 
    //if (h>0)	/* don't know if this is correct */
    //    ang = -ang;
//printf("h:%f ang:%f\n", h, ang);
    /* asin(dy/(l/2)) = angle from 0 degree to l, we may use atan(2h/l) instead */
    if ( Abs(dx) < TOLERANCE )              // larger y component (vertical arc) (only tested for vertical case !)
    {   double  cn = Max( -1.0, Min( 1.0, dx / (l/2.0) ) );
        if ( beg.y > end.y )
            an = 360.0 - (RadToDeg(acos(cn)) - (((ang<0) ? -90.0 : 90.0)-ang/2.0));
        else
            an = RadToDeg(acos(cn)) + (((ang<0) ? -90.0 : 90.0)-ang/2.0);
    }
    else                                    // larger x component
    {   double  sn = Max( -1.0, Min( 1.0, dy / (l/2.0) ) );
        if ( beg.x > end.x )
            an = 180.0 - (RadToDeg(asin(sn)) - (((ang<0) ? -90.0 : 90.0)-ang/2.0));
        else
            an = RadToDeg(asin(sn)) + (((ang<0) ? -90.0 : 90.0)-ang/2.0);
    }
    r = Abs(l/(2.0*sin(DegToRad(ang/2.0))));
//NSLog(@"0 h=%f an=%f dy=%f l=%f ang=%f r=%f", h, an, dy, l, ang, r);
    p.x = beg.x + r; p.y = beg.y;
    vhfRotatePointAroundCenter(&p, beg, an);
    *ctr = p;
    *angle = (float)ang;
}

/* created:   18.05.93
 * modified:  18.05.93 01.05.96
 *
 * purpose:   get solid
 * parameter: cp (the dxf data)
 *		ps[8]	points
 *		cnt	number of points in array
 */
- (BOOL)getSolid:(NSScanner*)scanner :(NSPoint*)ps :(int*)pCnt
{   NSPoint	p0, p1, p2, p3;
    int		i, cnt = 0;

    [self scanGroup:scanner];
    if ( [visibleList count] && ![visibleList containsObject:group.handle])
        return NO;

    state.color = [self currentColor];
    p0.x = DeviceResToInternal(group.x0, res) + state.offset.x;
    p0.y = DeviceResToInternal(group.y0, res) + state.offset.y;
    p1.x = DeviceResToInternal(group.x1, res) + state.offset.x;
    p1.y = DeviceResToInternal(group.y1, res) + state.offset.y;
    p2.x = DeviceResToInternal(group.x2, res) + state.offset.x;
    p2.y = DeviceResToInternal(group.y2, res) + state.offset.y;
    p3.x = DeviceResToInternal(group.x3, res) + state.offset.x;
    p3.y = DeviceResToInternal(group.y3, res) + state.offset.y;

    ps[cnt++] = p0;
    ps[cnt++] = p1;

    ps[cnt++] =	p1;
    ps[cnt++] = (p3.x != p2.x || p3.y != p2.y) ? p3 : p2;

    if (p3.x != p2.x || p3.y != p2.y)
    {	ps[cnt++] = p3;
        ps[cnt++] = p2;
    }

    ps[cnt++] = p2;
    ps[cnt++] = p0;

    *pCnt = cnt;

    state.width = 0.0;

    for (i=0; i<cnt; i+=2)
        [self updateBounds:ps[i]];

    return YES;
}

/* created:   1993-05-17
 * modified:  2004-08-04
 *
 * purpose:   get circle
 * parameter: scanner   the dxf data
 *            ctr       center
 *            start
 *            angle	360 degree
 */
- (BOOL)getCircle:(NSScanner*)scanner :(NSPoint*)ctr :(NSPoint*)start :(float*)angle
{   float	r;

    [self scanGroup:scanner];
    if ( [visibleList count] && ![visibleList containsObject:group.handle])
        return NO;

    state.color = [self currentColor];
    ctr->x = DeviceResToInternal(group.x0, res) + state.offset.x;
    ctr->y = DeviceResToInternal(group.y0, res) + state.offset.y;
    r = DeviceResToInternal(group.width, res);

    start->x = ctr->x + r;
    start->y = ctr->y;

    *angle = 360.0;
    state.width = 0.0;

    [self updateBounds:NSMakePoint(ctr->x+r, ctr->y+r)];
    [self updateBounds:NSMakePoint(ctr->x-r, ctr->y-r)];

    return YES;
}

/* created:   1993-05-17
 * modified:  2010-04-03 (negative 360 deg arcs work now)
 *
 * purpose:   get arc
 * parameter: cp (the dxf data)
 *            ctr
 *            start
 *            angle
 */
- (BOOL)getArc:(NSScanner*)scanner :(NSPoint*)ctr :(NSPoint*)start :(float*)angle
{   float	r, ba, ea;
    NSRect	rect;

    [self scanGroup:scanner];
    if ( [visibleList count] && ![visibleList containsObject:group.handle])
        return NO;

    state.color = [self currentColor];
    ctr->x = DeviceResToInternal(group.x0, res) + state.offset.x;
    ctr->y = DeviceResToInternal(group.y0, res) + state.offset.y;
    //FIXME: group.extX, group.extY, group.extZ
    r = DeviceResToInternal(group.width, res);
    ba = group.begAngle;
    ea = group.endAngle;

    start->x = ctr->x + r;
    start->y = ctr->y;
    *angle = 0.0;
    if ( Abs(ea - ba) >= 360.0 )
        *angle = ea - ba;
    if (ba >= 360.0) ba -= 360.0;
    if (ea < ba)     ea += 360.0;
    vhfRotatePointAroundCenter(start, *ctr, ba);

    if ( *angle == 0.0 )
        *angle = ea - ba;

    state.width = 0.0;

    //[self updateBounds:*start];
    rect = vhfBoundsOfArc(*ctr, r, ba, *angle);
    [self updateBounds:rect.origin];
    [self updateBounds:NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y)];
    [self updateBounds:NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y+rect.size.height)];
    [self updateBounds:NSMakePoint(rect.origin.x, rect.origin.y+rect.size.height)];

    return YES;
}

/* created:   1993-06-11
 * modified:  2002-01-09
 *
 * purpose:   get text (TEXT, MTEXT)
 *            read a sv-polygon for each character
 *            then position and rotate it
 * parameter: cp (the dxf data)
 *            string
 *            angle
 *            origin	base origin
 *            size
 *            ar	aspect ratio
 *            alignment	1 = top/left, 2= top/center, 3=top/right, 4=middle/left, ... 9 = bottom/right
 */
- (BOOL)getText:(NSScanner*)scanner mtext:(BOOL)mtext
               :(NSString**)string :(float*)angle :(NSPoint*)origin :(float*)size :(float*)ar :(int*)alignment
{   int		adjust = 0;
    NSPoint	adjustPoint,	// a point to adjust the text
		p;
    float	slopeAngle = 0.0;
    float	textHeight, textScale;

    *ar = 1.0;	/* aspect ratio */

    [self scanGroup:scanner];
    if ( [visibleList count] && ![visibleList containsObject:group.handle])
        return NO;
    if (![group.text length])
        return NO;

    state.color = [self currentColor];
    textHeight = *size = DeviceResToInternal(group.width, res) * 3.0/2.0;
    *string = [[group.text stringByReplacing:@"\\P" by:@"\n"] retain];	// convert newline
    origin->x = DeviceResToInternal(group.x0, res) + state.offset.x;
    origin->y = DeviceResToInternal(group.y0, res) + state.offset.y;
    *angle = group.begAngle;
    textScale = (group.endWidth == 0.0) ? 1.0 : group.endWidth;
    slopeAngle = group.endAngle;
    *alignment = (mtext) ? group.genFlags : 7;	// default = bottom/left
    adjust = group.adjust;	// get adjust position from file
    adjustPoint.x = DeviceResToInternal(group.x1, res);
    adjustPoint.y = DeviceResToInternal(group.y1, res);

    if (!mtext)
    {
        if (group.genFlags == 2)		// mirror around x
        {   //svMirrorGraphicAroundY(&cg, origin->x);
            *ar = -*ar;
        }
    }

    /* adjust text
     */
    p = *origin;
#if 0
    switch (adjust)
    {
        case 1:	/* horizontal centered */
            p.x = (adjustPoint.x - origin->x) - g->bounds.size.width / 2;
            p.y = 0;
            svMoveGraphicBy(g, &p);
            break;
        case 2:	/* align rigth */
            p.x = adjustPoint.x - g->bounds.size.width;
            p.y = 0;
            svMoveGraphicBy(g, &p);
            break;
        case 3:	/* bring in line with the two points */
            break;
        case 4:	/* centered */
            p.x = (adjustPoint.x - origin->x) - g->bounds.size.width  / 2;
            p.y = (adjustPoint.y - origin->y) - g->bounds.size.height / 2;
            svMoveGraphicBy(g, &p);
            break;
        case 5:	/* fit between the two points */
            break;
    }
#endif

    [self updateBounds:*origin];

    return YES;
}

/* created:   2011-04-04
 * modified:  2011-04-04
 *
 * purpose:   get insert
 * parameter: scanner (the dxf data)
 *            layer
 * 3DFACE    Four points defining the corners of the face: (10, 20, 30),
 * (11, 21, 31), (12, 22, 32), and (13, 23, 33).  70 (invisible
 * edge flags -optional 0).  If only three points were entered
 * (forming a triangular face), the third and fourth points will
 * be the same.  The meanings of the bit-coded "invisible edge
 * flags" are shown in the following table.
 *
 * Flag bit value           Meaning
 * 1        First edge is invisible
 * 2        Second edge is invisible
 * 4        Third edge is invisible
 * 8        Fourth edge is invisible
 */
- (BOOL)get3DFace:(NSScanner*)scanner points:(V3Point*)pts color:(NSColor**)color
{
    [self scanGroup:scanner];
    if ( [visibleList count] && ![visibleList containsObject:group.handle])
        return NO;

    *color = [self currentColor];
    pts[0].x = DeviceResToInternal(group.x0, res) + state.offset.x;
    pts[0].y = DeviceResToInternal(group.y0, res) + state.offset.y;
    pts[0].z = DeviceResToInternal(group.z0, res) /*+ state.offset.z*/;
    pts[1].x = DeviceResToInternal(group.x1, res) + state.offset.x;
    pts[1].y = DeviceResToInternal(group.y1, res) + state.offset.y;
    pts[1].z = DeviceResToInternal(group.z1, res) /*+ state.offset.z*/;
    pts[2].x = DeviceResToInternal(group.x2, res) + state.offset.x;
    pts[2].y = DeviceResToInternal(group.y2, res) + state.offset.y;
    pts[2].z = DeviceResToInternal(group.z2, res) /*+ state.offset.z*/;
    pts[3].x = DeviceResToInternal(group.x3, res) + state.offset.x;
    pts[3].y = DeviceResToInternal(group.y3, res) + state.offset.y;
    pts[3].z = DeviceResToInternal(group.z3, res) /*+ state.offset.z*/;

    state.width = 0.0;

    [self updateBounds:NSMakePoint(pts[0].x, pts[0].y)];
    [self updateBounds:NSMakePoint(pts[1].x, pts[1].y)];
    [self updateBounds:NSMakePoint(pts[2].x, pts[2].y)];
    [self updateBounds:NSMakePoint(pts[3].x, pts[3].y)];

    return YES;
}

/* created:   30.09.94
 * modified:  30.09.94 10.03.97
 *
 * purpose:   get insert
 * parameter: scanner (the dxf data)
 *            cList
 */
- (BOOL)getInsert:(NSScanner*)scanner :(id)cList
{   NSPoint             point;				/* position of the text */
    NSString            *name, *string;
    float               angle;
    NSScanner           *myBlockScanner = nil;
    int                 location;
    NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];

    [self scanGroup:scanner];
    if ( [visibleList count] && ![visibleList containsObject:group.handle])
        return YES;

    state.color = [self currentColor];
    name = group.name;
    angle = group.begAngle;
    point.x = DeviceResToInternal(group.x0, res);
    point.y = DeviceResToInternal(group.y0, res);

    location = [scanner scanLocation];

#if 0
    if (!(state.color=getColor(scanner, table)))	/* get color from file */
        return NO;

    /* name */
    if ( !gotoNextId(scanner, IDNAME) )
        return NO;
    gotoNextLine(scanner);	/* goto value */
    [scanner scanUpToCharactersFromSet:newLineSet intoString:&name];
    //gotoNextLine(scanner);	/* goto id */
    [scanner setScanLocation:location];

    if (!getCoord(scanner, IDBEGANGLE, &angle))	/* get rotation angle from file */
        angle = 0.0;

    if (!getCoord(scanner, IDX0, &point.x))	/* get position from file */
        return NO;
    point.x = DeviceResToInternal(point.x, res);
    if (!getCoord(scanner, IDY0, &point.y))
        return NO;
    point.y = DeviceResToInternal(point.y, res);
#endif

    if ( !(blockScanner = [self blockScannerFromScanner:scanner]) )
    {   [pool release];
        return NO;
    }
    while ( ![blockScanner isAtEnd] )
    {
        if ( !(gotoGroup(blockScanner, GRPBLOCK)) )		/* pointer to group */
        {   [pool release];
            return NO;
        }
        /* we are here:
         * BLOCK
         */
        if ( !(gotoNextId(blockScanner, IDNAME)) )	/* pointer to name */
            continue;
        gotoNextLine(blockScanner);	/* goto value */
        [blockScanner scanUpToCharactersFromSet:newLineSet intoString:&string];
        if ( [string isEqual:name] )	/* begin of block */
        {
            gotoNextLine(blockScanner);
            if ( [blockScanner scanUpToString:GRPENDBLOCK intoString:&string] )
            {   myBlockScanner = [NSScanner scannerWithString:[string stringByAppendingFormat:@"%@\r\n", GRPENDBLOCK]];
                [myBlockScanner setCharactersToBeSkipped:skipSet];
            }
            break;
        }
        gotoNextLine(blockScanner);
    }

    if ( !myBlockScanner )	/* end of block */
    {   [pool release];
        return NO;
    }

    /* get the elements from the block
     */
    state.offset = point;
    state.rotAngle = angle;
    while ( ![myBlockScanner isAtEnd] )
        [self getGraphicFromData:myBlockScanner :cList];
    [scanner setScanLocation:location];
    state.offset = NSMakePoint(0.0, 0.0);
    state.rotAngle = 0.0;

    [pool release];

    return YES;
}

/*
 */
- (NSColor*)currentColor
{   int		num = group.color;
    DXFColor	col;
    NSColor	*color;

    if ( num )
    {
        if (num>255 || num<1)
            num = 7;
        col = colorTable[num-1];
        color = [NSColor colorWithCalibratedRed:col.r green:col.g blue:col.b alpha:1.0];
        return color;
    }

    /* search the relating color from the color table */
    color = getColorFromTable(group.layer, table);
    return color;
}

/* arbitrary axis algorithm - transform OCS (Object) to WCS (World)
 * build the cross product
 *
 * W        our coordinate             [WCS]
 * AZ (N)   the extrusion direction    [WCS]
 * return   the transformed coordinate [OCS]
 * created: 2012-02-03
 */
static V3Point crossProduct(const V3Point a, const V3Point b)
{   V3Point result;

    result.x = a.y * b.z - a.z * b.y;
    result.y = a.z * b.x - a.x * b.z;
    result.z = a.x * b.y - a.y * b.x;
    return result;
}
static V3Point scaleToUnit(V3Point p)
{   double  len = sqrt(p.x*p.x + p.y*p.y + p.z*p.z);

    if (len != 0)
    {   p.x /= len;
        p.y /= len;
        p.z /= len;
    }
    return p;
}
static V3Point transformOCS(V3Point pOCS, V3Point AZ)
{   V3Point AX, AY, p;

    if ( Abs(AZ.x) < 1.0/64.0 && Abs(AZ.y) < 1.0/64.0 )
        AX = crossProduct(V3MakePoint(0.0, 1.0, 0.0), AZ);   // transform using unit vector Y
    else
        AX = crossProduct(V3MakePoint(0.0, 0.0, 1.0), AZ);   // transform using unit vector Z
    AX = scaleToUnit( AX );  // scale vector to unit (length = 1.0)
    AY = crossProduct(AZ, AX);
    AY = scaleToUnit( AY );

    /* these are direction cosines, we have to rotate each axis around this */
    {   double x = pOCS.x, y = pOCS.y, z = pOCS.z;

        p.x = x * AX.x + y * AY.x + z * AZ.x;
        p.y = x * AX.y + y * AY.y + z * AZ.y;
        p.z = x * AX.z + y * AY.z + z * AZ.z;
    }
    return p;
}

/* get group entries
 * scanner starts at id line of first entry
 * scanner scans until it reaches the next group
 * created:  1997-03-19
 * modified: 2011-04-04 (group.z0 - z3 added)
 *           2009-02-06 (read in extrusion direction)
 */
- (BOOL)scanGroup:(NSScanner*)scanner
{   BOOL    exitLoop = NO;

    [group.text release]; group.text = nil;
    [group.name release]; group.name = nil;
    [group.layer release]; group.layer = nil;
    [group.handle release]; group.handle = nil;
    group.color = 0;
    group.width = -1.0;
    group.endWidth = -1.0;
    group.begAngle = group.endAngle = 0.0;
    group.x0 = group.y0 = group.z0 = 0.0;
    group.x1 = group.y1 = group.z1 = 0.0;
    group.x2 = group.y2 = group.z2 = 0.0;
    group.x3 = group.y3 = group.z3 = 0.0;
    group.a = 0.0;
    group.flags = group.genFlags = 0;
    group.extX = group.extY = 0.0; group.extZ = 1.0;

    while ( ![scanner isAtEnd] )
    {	int	i, location = [scanner scanLocation];

        /* scan id */
        if ( ![scanner scanInt:&i] )
        {   NSLog(@"DXF-Import: id expected at location: %d", [scanner scanLocation]);
            return NO;
        }
        gotoNextLine(scanner);	// goto value line
        switch ( i )
        {
            case ID_TEXT:
                if (![scanner scanUpToCharactersFromSet:newLineSet intoString:&group.text])
                    group.text = @"";
                else
                    [group.text retain];
                break;
            case ID_NAME:
                if (![scanner scanUpToCharactersFromSet:newLineSet intoString:&group.name])
                    group.name = @"";
                else
                    [group.name retain];
                break;
            //case ID_DESCRIPT:
            //    if (![scanner scanFloat:&group.descript intoString:&group.descript])
            //        group.descript = 0.0;
            //    break;
            case ID_HANDLE:
                if (![scanner scanUpToCharactersFromSet:newLineSet intoString:&group.handle])
                    group.handle = nil;
                [group.handle retain];
                break;
            case ID_LTYPE:
                if (![scanner scanInt:&group.lineType])
                    group.lineType = 0.0;
                break;
            case ID_LAYER:
                if (![scanner scanUpToCharactersFromSet:newLineSet intoString:&group.layer])
                    group.layer = nil;
                else
                    [group.layer retain];
                break;
            case ID_X0:
                if (![scanner scanFloat:&group.x0])
                    group.x0 = 0.0;
                break;
            case ID_Y0:
                if (![scanner scanFloat:&group.y0])
                    group.y0 = 0.0;
                break;
            case ID_Z0:
                if (![scanner scanFloat:&group.z0])
                    group.z0 = 0.0;
                break;
            case ID_X1:
                if (![scanner scanFloat:&group.x1])
                    group.x1 = 0.0;
                break;
            case ID_Y1:
                if (![scanner scanFloat:&group.y1])
                    group.y1 = 0.0;
                break;
            case ID_Z1:
                if (![scanner scanFloat:&group.z1])
                    group.z1 = 0.0;
                break;
            case ID_X2:
                if (![scanner scanFloat:&group.x2])
                    group.x2 = 0.0;
                break;
            case ID_Y2:
                if (![scanner scanFloat:&group.y2])
                    group.y2 = 0.0;
                break;
            case ID_Z2:
                if (![scanner scanFloat:&group.z2])
                    group.z2 = 0.0;
                break;
            case ID_X3:
                if (![scanner scanFloat:&group.x3])
                    group.x3 = 0.0;
                break;
            case ID_Y3:
                if (![scanner scanFloat:&group.y3])
                    group.y3 = 0.0;
                break;
            case ID_Z3:
                if (![scanner scanFloat:&group.z3])
                    group.z3 = 0.0;
                break;
            case ID_WIDTH:	/* begWidth, radius, sumLen, height */
                if (![scanner scanFloat:&group.width])
                    group.width = -1.0;
                group.width = Abs(group.width);
                break;
            case ID_ENDWIDTH:
                if (![scanner scanFloat:&group.endWidth])
                    group.endWidth = -1.0;
                group.endWidth = Abs(group.endWidth);
                break;
            case ID_A:
                if (![scanner scanFloat:&group.a])
                    group.a = 0.0;
                break;
            case ID_BEGANGLE:
                if (![scanner scanFloat:&group.begAngle])
                    group.begAngle = 0.0;
                break;
            case ID_ENDANGLE:
                if (![scanner scanFloat:&group.endAngle])
                    group.endAngle = 0.0;
                break;
            case ID_COLOR:
                if (![scanner scanInt:&group.color])
                    group.color = 0;
                break;
            case ID_MORE:
                if (![scanner scanInt:&group.more])
                    group.more = 0;
                break;
            case ID_FLAGS:
                if (![scanner scanInt:&group.flags])
                    group.flags = 0;
                break;
            case ID_GENFLAGS:
                if (![scanner scanInt:&group.genFlags])
                    group.genFlags = 0;
                break;
             case ID_ADJUST:
                if (![scanner scanFloat:&group.adjust])
                    group.adjust = 0.0;
                break;
            case ID_NUMGRP:
                if (![scanner scanInt:&group.numGrp])
                    group.numGrp = 0;
                break;
            case ID_EXT_X:
                if (![scanner scanFloat:&group.extX])
                    group.extX = 0.0;
                break;
            case ID_EXT_Y:
                if (![scanner scanFloat:&group.extY])
                    group.extY = 0.0;
                if ( group.extX != 0.0 || group.extY != 0.0 )   // FIXME: extrusion direction
                    NSLog(@"DXF-Import: extrusion direction not supported. File-Location = %lu", [scanner scanLocation]);
                break;
            case ID_EXT_Z:
                if (![scanner scanFloat:&group.extZ])
                    group.extZ = 1.0;
                break;
            case ID_GROUP:
                [scanner setScanLocation:location];
                exitLoop = YES;
                break;
            default:
                break;
        }
        if ( exitLoop )
            break;
        gotoNextLine(scanner);	// goto id line
    }

    /* transform coordinates from OCS to WCS (only if extrusion direction tells us so) */
    if ( group.extX != 0.0 || group.extY != 0.0 || group.extZ != 1.0 )
    {   V3Point N = V3MakePoint(group.extX, group.extY, group.extZ), p;

        p = transformOCS(V3MakePoint(group.x0, group.y0, group.z0), N);
        group.x0 = p.x; group.y0 = p.y; group.z0 = p.z;
        p = transformOCS(V3MakePoint(group.x1, group.y1, group.z1), N);
        group.x1 = p.x; group.y1 = p.y; group.z1 = p.z;
        p = transformOCS(V3MakePoint(group.x2, group.y2, group.z2), N);
        group.x2 = p.x; group.y2 = p.y; group.z2 = p.z;
        p = transformOCS(V3MakePoint(group.x3, group.y3, group.z3), N);
        group.x3 = p.x; group.y3 = p.y; group.z3 = p.z;
    }

    return YES;
}



/* methods which needs to be subclassed
 */
- (id)allocateList:(NSArray*)layers
{
    return nil;
}

- (void)addFillList:aList toLayer:(NSString*)layerName
{
    NSLog(@"add filled path to layer %@.", layerName); 
}

- (void)addStrokeList:aList toLayer:(NSString*)layerName
{
    NSLog(@"add stroked path to layer %@.", layerName); 
}

- (void)addLine:(NSPoint)beg :(NSPoint)end toList:(NSMutableArray*)aList
{
    NSLog(@"line: %f %f %f %f", beg.x, beg.y, end.x, end.y); 
}
- (void)addLine3D:(V3Point)beg :(V3Point)end toList:(NSMutableArray*)aList
{
    NSLog(@"line 3D: %f %f %f %f %f %f", beg.x, beg.y, beg.z, end.x, end.y, end.z);
}
- (void)addLine:(NSPoint)beg :(NSPoint)end toLayer:(NSString*)layerName
{
    NSLog(@"line: %@ %f %f %f %f", layerName, beg.x, beg.y, end.x, end.y); 
}
- (void)addLine3D:(V3Point)beg :(V3Point)end toLayer:(NSString*)layerName
{
    NSLog(@"line 3D: %@ %f %f %f %f %f %F", layerName, beg.x, beg.y, beg.z, end.x, end.y, end.z); 
}

- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:(NSMutableArray*)aList
{
    NSLog(@"arc: %f %f %f %f %f", center.x, center.y, start.x, start.y, angle); 
}
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toLayer:(NSString*)layerName
{
    NSLog(@"arc: %@ %f %f %f %f %f", layerName, center.x, center.y, start.x, start.y, angle); 
}

- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:(NSMutableArray*)aList
{
    NSLog(@"curve: %f %f %f %f %f %f %f %f", p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
}
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toLayer:(NSString*)layerName
{
    NSLog(@"curve: %@ %f %f %f %f %f %f %f %f", layerName, p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
}
- (void)add3DFace:(V3Point*)pts toLayer:(NSString*)layerName
{
    NSLog(@"3DFace: %@ %f %f %f, %f %f %f, %f %f %f, %f %f %f", layerName, pts[0].x, pts[0].y, pts[0].z,
          pts[1].x, pts[1].y, pts[1].z, pts[2].x, pts[2].y, pts[2].z, pts[3].x, pts[3].y, pts[3].z);
}

/* allocate a text object and add it to layer
 * parameter: text	the text string
 *            font	the font name
 *            angle	rotation angle
 *            size	the font size in pt
 *            ar	aspect ratio height/width
 *            layerInfo	the destination layer
 */
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar :(int)alignment at:(NSPoint)p toLayer:(NSString*)layerName
{
    NSLog(@"text: %@ %f %f %f %f %d %f \"%s\" \"%s\"", layerName, p.x, p.y, angle, size, ar, alignment, text, font); 
}

- (void)setBounds:(NSRect)bounds
{
    NSLog(@"bounds: %f %f %f %f", bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
}

@end
