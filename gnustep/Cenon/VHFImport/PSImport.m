/* PSImport.m
 * PostScript import object
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-25
 * modified: 2011-09-03 (-importPS: for GhostScript: try several string loadings to get encoding right)
 *           2009-02-02 (-importPS: for GhostScript: -dNOSAFER flag added
 *           2009-01-31 (-importPS: for GhostScript+DPS: remove Corel Draw garbage before %!PS-ADOBE...)
 *           2008-11-29 (init state.color in GhostScript version of importPS)
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

#include <ctype.h>
#include <math.h>
#include "PSImport.h"
#include "../VHFShared/vhfCommonFunctions.h"
#include "../VHFShared/vhf2DFunctions.h"
#include "../VHFShared/types.h"
#include "../VHFShared/VHFScannerAdditions.h"
#include "../VHFShared/VHFStringAdditions.h"    // -writeToFile:... for 10.4

/* USEDPS: 1 = use Display PostScript, 0 = use gs (GhostScript) */
#if defined(GNUSTEP_BASE_VERSION)
#   define USE_DPS	0	// GNUstep
#elif defined(__APPLE__)
#   define USE_DPS	0	// Mac OS X
#else
#   define USE_DPS	1	// OpenStep 4.2
#endif

#if USE_DPS
#   import "psi.h"
#endif

/* GhostScript path */
#ifdef GNUSTEP_BASE_VERSION
#  define GS_PATH	@"gs"
#else
#  define GS_PATH	@"/usr/local/bin/gs"
#endif
#define   GS_PATH1	@"/usr/bin/gs"

@interface PSImport(PrivateMethods)
- (BOOL)interpret:(NSString*)data;
- (void)updateBounds:(NSPoint)p;
@end

@implementation PSImport

/* return a temporary path
 * created: 2012-02-07
 */
- (NSString*)tmpPath
{   NSString    *tmpPath = PS_TMPPATH;
    //NSString    *app = [[NSProcessInfo processInfo] processName];

#   if defined(__APPLE__) || defined(GNUSTEP_BASE_VERSION)
    tmpPath = NSTemporaryDirectory();
#   endif
    //tmpPath = [tmpPath stringByAppendingPathComponent:APPNAME];
    return tmpPath;
}

/* created:   1996-05-03
 * modified:  
 * parameter: flag
 */
- (void)flattenText:(BOOL)flag
{
    flattenText = flag;
}

/* created:   1996-05-03
 * modified:  
 * parameter: flag
 */
- (void)preferArcs:(BOOL)flag
{
    preferArcs = flag;
}

/* created:  2005-01-06
 * modified: 
 */
- (NSString*)gsPath
{   NSFileManager	*fileManager = [NSFileManager defaultManager];

    if (![GS_PATH hasPrefix:@"/"])	// location is known to the system
        return GS_PATH;
    if ([fileManager fileExistsAtPath:GS_PATH])
        return GS_PATH;
    return GS_PATH1;
}

/* created:   2002-01-29
 * modified:  2005-11-19
 * parameter: pdfData	the PDF data stream
 * purpose:   import pdf data
 */
- importPDF:(NSData*)pdfData
{   NSString    *app = [[NSProcessInfo processInfo] processName];
    NSString    *pdfFile = vhfPathWithPathComponents([self tmpPath],
                           [app stringByAppendingString:@"_pdfImport.pdf"], nil);
    id          result;

    [pdfData writeToFile:pdfFile atomically:NO];
    result = [self importPDFFromFile:pdfFile];
    [[NSFileManager defaultManager] removeFileAtPath:pdfFile handler:nil];

    return result;
}
- importPDFFromFile:(NSString*)pdfFile
{   NSString    *app = [[NSProcessInfo processInfo] processName], *commandLine;
    NSString    *psFile = vhfPathWithPathComponents([self tmpPath],
                          [app stringByAppendingString:@"_pdfImport.eps"], nil);
    NSData      *psData;

    /* convert pdf to eps */
    commandLine = [NSString stringWithFormat:@"%@ -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=epswrite -sOutputFile=%@ -c save pop -f '%@'", [self gsPath], psFile, pdfFile];
    system([commandLine UTF8String]);

    /* import ps */
    psData = [NSData dataWithContentsOfFile:psFile];

    [[NSFileManager defaultManager] removeFileAtPath:psFile handler:nil];

    return [self importPS:psData];
}

/* created:   1996-01-25
 * modified:  2005-01-06
 * parameter: psData	the PostScript stream
 * purpose:   start interpretation of the contents of psData
 */

/*
 * Display PostScript
 */
#if USE_DPS	// use Display PostScript

/* Use DPS Context to extract the interpreted PostScript to file
 * We can't use NSEPSImageRep because the context is write protected
 */
- importPS:(NSData*)psData
{   NSAutoreleasePool   *pool = [NSAutoreleasePool new];
    NSDPSContext        *curContext = [NSDPSContext currentContext];
    NSDPSServerContext  *psContext = nil;
    NSString            *app = [[NSProcessInfo processInfo] processName];
    NSString            *path = vhfPathWithPathComponents([self tmpPath],
                                [app stringByAppendingString:@"_psImport"], nil);
    NSString            *data;
    NSUserDefaults      *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString            *hostName = [userDefaults stringForKey:@"NSHost"];
    NSString            *serverName = [userDefaults stringForKey:@"NSPSName"];
    NSTimeInterval      timeout = [userDefaults floatForKey:@"NSNetTimeout"];

    if ( !psData )
        return nil;
    /* Workaround for Windows Corel Draw: if psData contains garbage before %!PS-Adobe, we remove that.
     * garbage at the end is only removed if file ends with "%%EOF".
     */
    {   NSString    *psStr, *psStr1;
        NSRange     range, range1;

        psStr = [[NSString alloc] initWithData:psData encoding:NSASCIIStringEncoding];
        if ( (range = [psStr rangeOfString:@"%!PS"]).length && range.location > 0 )  // garbage%!PS-Adobe
        {   int toIx;

            NSLog(@"PostScript-Import: Error in PostScript file - data starts with garbage (%@) !", [psStr substringToIndex:range.location]);
            if ( ! (range1 = [psStr rangeOfString:@"%%EOF" options:NSBackwardsSearch]).length )
                range1 = [psStr rangeOfString:@"showpage" options:NSBackwardsSearch];
            toIx = ((range1.length) ? range1.location+range1.length+1 : [psStr length]);
            psStr1 = [psStr substringWithRange:NSMakeRange(range.location, toIx-range.location)];
            [psStr release];
            psData = [psStr1 dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
        }
        else
            [psStr release];
    }

    state.color = [[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0] retain];
    state.width = 0.0;

    /* send data to windows server */
    NS_DURING
        psContext = [[NSDPSServerContext alloc] initWithHostName:(hostName ? hostName : @"")
                                                      serverName:(serverName ? serverName : @"")
                                                        textProc:NULL errorProc:NULL
                                                         timeout:((timeout == 0.0) ? 60.0 : timeout)
                                                          secure:NO encapsulated:NO];
        if (psContext == nil)
            NSLog(@"Could not connect to window server.");
        [NSDPSContext setCurrentContext:psContext];
        PSWInit([path cString]);
        PSWflattenText(flattenText);
        [psContext writePostScriptWithLanguageEncodingConversion:
                   [@"2.0 2.0 scale " dataUsingEncoding:NSASCIIStringEncoding]];
        [psContext writePostScriptWithLanguageEncodingConversion:psData];
        [psContext writePostScriptWithLanguageEncodingConversion:[@"\n" dataUsingEncoding:NSASCIIStringEncoding]];
        PSWclose();
        [psContext wait]; /* This does not return until the execution is done */
    NS_HANDLER
        NSLog(@"PostScript-Import: %@", [localException reason]);
    NS_ENDHANDLER

    [NSDPSContext setCurrentContext:curContext];	/* Restore the old context */
    [psContext release];				/* Get rid of the questionable context */

    /* load generated file */
    data = [[[NSString alloc] initWithContentsOfFile:path] autorelease];

    /* interpret data and send to receiving object */
    if ( ![self interpret:data] )
        return nil;

    [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
    [pool release];

    return [list autorelease];
}

/*
 * GhostScript
 */
#else // use GhostScript

static NSString	*prolog = nil;
- importPS:(NSData*)psData
{   NSString            *app = [[NSProcessInfo processInfo] processName], *commandLine, *path;
    NSString            *inFile  = vhfPathWithPathComponents([self tmpPath], [app stringByAppendingString:@"_psImport.in"],  nil);
    //NSString            *outFile = vhfPathWithPathComponents(PS_TMPPATH, @"_psImport.out", nil);    // see psImport.prolog !
    NSString            *outFile = vhfPathWithPathComponents([self tmpPath], [app stringByAppendingString:@"_psImport.out"], nil); // see psImport.prolog
    NSMutableString     *data = [NSMutableString string];
    NSStringEncoding    enc;

    if ( !psData )
        return nil;
    /* Workaround for Windows Corel Draw: if psData contains garbage before %!PS-Adobe, we remove that.
     * garbage at the end is only removed if file ends with "%%EOF".
     */
    {   NSString    *psStr, *psStr1;
        NSRange     range, range1;

        psStr = [[NSString alloc] initWithData:psData encoding:NSASCIIStringEncoding];
        if ( (range = [psStr rangeOfString:@"%!PS"]).length && range.location > 0 )  // garbage%!PS-Adobe
        {   int toIx;

            NSLog(@"PostScript-Import: Error in PostScript file - data starts with garbage (%@) !", [psStr substringToIndex:range.location]);
            if ( ! (range1 = [psStr rangeOfString:@"%%EOF" options:NSBackwardsSearch]).length )
                range1 = [psStr rangeOfString:@"showpage" options:NSBackwardsSearch];
            toIx = ((range1.length) ? range1.location+range1.length+1 : [psStr length]);
            psStr1 = [psStr substringWithRange:NSMakeRange(range.location, toIx-range.location)];
            [psStr release];
            psData = [psStr1 dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
        }
        else
            [psStr release];
    }

    state.color = [[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0] retain];
    state.width = 0.0;

    /* load prolog from framework or library directory */
    if ( !prolog )
    {
        path = [[NSBundle bundleForClass:[PSImport class]] resourcePath];
        path = [path stringByAppendingPathComponent:@"psImport.prolog"];
        prolog = [[NSString stringWithContentsOfFile:path] retain];
        if (prolog)
        {   NSRange range = [prolog rangeOfString:@"/tmp/psImport.out"];

            /* set file name */
            if ( [prolog respondsToSelector:@selector(stringByReplacingCharactersInRange:withString:)] )    // SDK >= 10.5
                prolog = [[[prolog autorelease] stringByReplacingCharactersInRange:range withString:outFile] retain];
            else
            {   NSMutableString *newProlog = [prolog mutableCopy];

                [prolog release];
                [newProlog replaceCharactersInRange:range withString:outFile];
                prolog = newProlog;
            }
        }
        else
            NSLog(@"Couldn't load psImport.prolog file '%@'", path);
    }

    [data appendString:prolog];
    if ( flattenText )
    	[data appendString:@" /flattenText 1 def\n"];
    [data appendString:@"0.0 1000.0 translate\n"];
    [data appendString:@"2.0 -2.0 scale\n"];
    [data appendString:[[[NSString alloc] initWithData:psData encoding:NSASCIIStringEncoding] autorelease]];
    [data appendString:@" flush cfile closefile\n"];
    /* If there are special characters in the file, we convert it to lossy ascii
     * to avoid strange encodings on mac os x (Apple)
     */
    if (![data canBeConvertedToEncoding:NSASCIIStringEncoding])
    {   NSData	*nsData;

        nsData = [data dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        data = [[[NSString alloc] initWithData:nsData encoding:NSASCIIStringEncoding] autorelease];
    }
    [data writeToFile:inFile atomically:NO encoding:NSASCIIStringEncoding error:NULL];  // >= 10.5
    //[data writeToFile:inFile atomically:NO];    // <= 10.4

    commandLine = [NSString stringWithFormat:@"%@ -dNODISPLAY -dBATCH -dNOSAFER -g1000x1000 '%@'", [self gsPath], inFile];
    system([commandLine UTF8String]);

    /* load generated file */
    //data = [[[NSString alloc] initWithContentsOfFile:outFile] autorelease];
    data = [[[NSString alloc] initWithContentsOfFile:outFile usedEncoding:&enc error:NULL] autorelease];
    if ( !data )    // files from Corel Draw, etc.
        data = [[[NSString alloc] initWithContentsOfFile:outFile encoding:NSISOLatin1StringEncoding error:NULL] autorelease];
    if ( !data )    // files from Next-Step (ex. Example file with Ducks)
        data = [[[NSString alloc] initWithContentsOfFile:outFile encoding:NSNEXTSTEPStringEncoding error:NULL] autorelease];

    /* interpret data and send to receiving object */
    if ( !data || ![self interpret:data] )
        return nil;

    [[NSFileManager defaultManager] removeFileAtPath:inFile  handler:nil];
    [[NSFileManager defaultManager] removeFileAtPath:outFile handler:nil];

    return [list autorelease];
}
#endif


/* private methods
 */
#define MAXCOORDCNT	14
#define MAXSTATES	20
#define NOP		@" \n\r\t"
#define DIGITS		@".+-e0123456789"
#define	GSAVE		@"gs"
#define	GRESTORE	@"gr"
#define	CLIP		@"cl"
#define	NEWLIST		@"n"
#define	LINE		@"l"
#define	CURVE		@"c"
#define	TEXT		@"t"
#define	FILL		@"f"
#define	WIDTH		@"w"
#define	COLOR		@"co"

#define DESCALE	0.5
- (BOOL)interpret:(NSString*)data
{   NSString            *string;
    float               value, c[MAXCOORDCNT];          // stack for coordinates
    NSMutableArray      *s = [NSMutableArray array];    // stack for strings
    int                 cCnt = 0, poolCnt = 0;
    NSPoint             p0, p1, p2, p3;
    NSMutableArray      *cList = [NSMutableArray array];    // current list
    NSRect              bounds;
    PSState             states[MAXSTATES];  // array of states for gsave and grestore
    int                 stateCnt = 0;
    NSScanner           *scanner = [NSScanner scannerWithString:data];
    NSCharacterSet      *skipCharacters = [scanner charactersToBeSkipped];
    NSCharacterSet      *noCharacters = [NSCharacterSet characterSetWithCharactersInString:@""];
    NSAutoreleasePool   *pool = nil;
    BOOL                ok = YES;

    coordinateSet = [NSCharacterSet characterSetWithCharactersInString:DIGITS];
    invCoordinateSet = [coordinateSet invertedSet];

    /* init bounds */
    ll.x = ll.y = LARGE_COORD;
    ur.x = ur.y = LARGENEG_COORD;

    list = [self allocateList];

    /* retain the color to let it survive the autorelease pool */
    [state.color retain];

    while ( ![scanner isAtEnd] )
    {
        /* every 100 steps we release the pool to minimize memory usage */
        if (!(poolCnt%100))
        {   [pool release];
            pool = [NSAutoreleasePool new];
        }
        poolCnt++;
        if ( [scanner scanString:GSAVE intoString:NULL] )		// gsave
        {
            if ( stateCnt <= MAXSTATES-1 )
                states[stateCnt++] = state;
            else
                NSLog(@"PSImport: gsave, Stack overflow!");
        }
        else if ( [scanner scanString:GRESTORE intoString:NULL] )	// grestore
        {
            if ( stateCnt > 0 )
                state = states[--stateCnt];
            else
                NSLog(@"PSImport: grestore, Stack underflow!");
        }
        else if ( [scanner scanString:CLIP intoString:NULL] )		// clip
        {
            if ([cList count])
            {	[self addStrokeList:cList toList:list];
                [cList removeAllObjects];
            }
            cCnt = 0;
        }
        else if ( [scanner scanString:NEWLIST intoString:NULL] )	// new list
        {
            if ([cList count])
            {	[self addStrokeList:cList toList:list];
                [cList removeAllObjects];
            }
            cCnt = 0;
        }
        else if ( [scanner scanString:FILL intoString:NULL] )		// fill list
        {
            if ([cList count])
            {	[self addFillList:cList toList:list];
                [cList removeAllObjects];
            }
            cCnt = 0;
        }
        else if ( [scanner scanString:WIDTH intoString:NULL] )		// width
        {
            if (cCnt < 1)
            {	NSLog(@"PSImport: Width, Stack underflow!");
                ok = NO; break;
            }
            state.width = Abs(c[cCnt-1]*DESCALE);
            cCnt = 0;
        }
        else if ( [scanner scanString:COLOR intoString:NULL] )		// cmyka color
        {   float	k = 1.0-c[cCnt-2];

            if (cCnt < 5)
            {	NSLog(@"PSImport: Color, Stack underflow!");
                ok = NO; break;
            }
            //[state.color release];	// FIXME: this should be active but creates a crash ???
            /*
             * (k-c[cCnt-5]) instead (1.0-c[cCnt-5])*k
             */
            state.color = [[NSColor colorWithCalibratedRed:(k-c[cCnt-5]) green:(k-c[cCnt-4]) blue:(k-c[cCnt-3]) alpha:c[cCnt-1]] retain];
            //state.color = [[NSColor colorWithCalibratedRed:(1.0-c[cCnt-5])*k green:(1.0-c[cCnt-4])*k blue:(1.0-c[cCnt-3])*k alpha:c[cCnt-1]] retain];
            cCnt = 0;
        }
        else if ( [scanner scanString:CURVE intoString:NULL] )		// curve
        {
            if (cCnt < 8)
            {	NSLog(@"PSImport: Curve, Stack underflow!");
                ok = NO; break;
            }
            p0.x = c[cCnt-8]*DESCALE; p0.y = c[cCnt-7]*DESCALE;
            p1.x = c[cCnt-6]*DESCALE; p1.y = c[cCnt-5]*DESCALE;
            p2.x = c[cCnt-4]*DESCALE; p2.y = c[cCnt-3]*DESCALE;
            p3.x = c[cCnt-2]*DESCALE; p3.y = c[cCnt-1]*DESCALE;
            [self updateBounds:p0];
            [self updateBounds:p1];
            [self updateBounds:p2];
            [self updateBounds:p3];
            cCnt = 0;
            if (preferArcs)
            {	NSPoint	pc[4], center, start;
                float	angle;

                pc[0] = p0; pc[1] = p1; pc[2] = p2; pc[3] = p3;
                if (vhfConvertCurveToArc(pc, &center, &start, &angle))
                {   [self addArc:center :start :angle toList:cList];
                    continue;
                }
            }
            [self addCurve:p0 :p1 :p2 :p3 toList:cList];
        }
        else if ( [scanner scanString:LINE intoString:NULL] )		// line
        {
            if (cCnt < 4)
            {	NSLog(@"PSImport: Line, Stack underflow!");
                ok = NO; break;
            }
            p0.x = c[cCnt-4]*DESCALE; p0.y = c[cCnt-3]*DESCALE;
            p1.x = c[cCnt-2]*DESCALE; p1.y = c[cCnt-1]*DESCALE;
            [self updateBounds:p0];
            [self updateBounds:p1];
            [self addLine:p0 :p1 toList:cList];
            cCnt = 0;
        }
        else if ( [scanner scanString:TEXT intoString:NULL] )		// text
        {   float	m[6];
            float	size, angle, sx, sy, ar;

            if (cCnt < 8 || [s count] < 2)
            {	NSLog(@"PSImport: Text, Stack underflow!");
                ok = NO; break;
            }
            p0.x = c[cCnt-8]/2.0; p0.y = c[cCnt-7]/2.0;

            m[0] = c[cCnt-6]*DESCALE; m[1] = c[cCnt-5]*DESCALE;
            m[2] = c[cCnt-4]*DESCALE; m[3] = c[cCnt-3]*DESCALE;
            m[4] = c[cCnt-2]*DESCALE; m[5] = c[cCnt-1]*DESCALE;

            angle = (m[0]) ? RadToDeg(atan(m[1]/m[0])) : 90.0;
            size = ((!angle) ? m[0]/cos(DegToRad(angle)) : m[1]/sin(DegToRad(angle))) * 1000.0;
            sx = (angle) ? m[1]/ sin(DegToRad(angle)) : m[0]/cos(DegToRad(angle));
            sy = (angle) ? m[2]/-sin(DegToRad(angle)) : m[3]/cos(DegToRad(angle));
            ar = sy/sx;
            [self updateBounds:p0];
            [self addText:[s objectAtIndex:[s count]-2] :[s objectAtIndex:[s count]-1]
                         :angle :size :ar at:p0 toList:list];
            cCnt = 0;
            [s removeAllObjects];
        }
        else if ( [scanner scanString:@"(" intoString:NULL] )		// string
        {
            if ([s count] >= MAXCOORDCNT)
            {	NSLog(@"PSImport: Strings, Stack overflow!");
                ok = NO; break;
            }
            if ( ![s count] )
            {   [scanner setCharactersToBeSkipped:noCharacters];
                if ( ![scanner scanUpToString:@") (" intoString:&string] )	// need space seperator !
                {   NSLog(@"PSImport: ') (' expected");
                    break;
                }
                [scanner setCharactersToBeSkipped:skipCharacters];
            }
            else if ( ![scanner scanUpToString:@") t" intoString:&string] )	// need space seperator !
            {   NSLog(@"PSImport: ') t' expected");
                break;
            }
            [s addObject:string];
            if (![scanner scanString:@")" intoString:NULL])
                NSLog(@"PSImport: ')' expected");
        }
        else if ( [scanner scanFloat:&value] )		// coordinate
        {
            if (cCnt >= MAXCOORDCNT)
            {	NSLog(@"PSImport: Coordinates, Stack overflow!");
                ok = NO; break;
            }
            c[cCnt++] = value;
        }
        else if ( [scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:&string] )
            NSLog(@"PSImport: Unexpected characters in data: '%@'", string);
        else
            break;
    }

    if (ok && [cList count])
    {   [self addStrokeList:cList toList:list];
        [cList removeAllObjects];
    }

    bounds.origin = ll;
    bounds.size.width = ur.x - ll.x;
    bounds.size.height = ur.y - ll.y;
    [self setBounds:bounds];

    [pool release];
    [state.color release]; // see explanation above !

    return ok;
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


/* methods to subclass
 */
- (id)allocateList
{
    return nil;
}

- (void)addFillList:aList toList:bList
{
    NSLog(@"filled path."); 
}

- (void)addStrokeList:aList toList:bList
{
    NSLog(@"stroked path."); 
}

- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList
{
    NSLog(@"line: %f %f %f %f", beg.x, beg.y, end.x, end.y); 
}

- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList
{
    NSLog(@"arc: %f %f %f %f %f", center.x, center.y, start.x, start.y, angle); 
}

- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:aList
{
    NSLog(@"curve: %f %f %f %f %f %f %f %f", p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
}

/* allocate a text object and add it to aList
 * parameter:	text	the text string
 *		font	the font name
 *		angle	rotation angle
 *		size	the font size in pt
 *		ar		aspect ratio height/width
 *		aList	the destination list
 */
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar at:(NSPoint)p toList:aList
{
    NSLog(@"text: %f %f %f %f %f \"%@\" \"%@\"", p.x, p.y, angle, size, ar, text, font); 
}

- (void)setBounds:(NSRect)bounds
{
    NSLog(@"bounds: %f %f %f %f", bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
}
@end
