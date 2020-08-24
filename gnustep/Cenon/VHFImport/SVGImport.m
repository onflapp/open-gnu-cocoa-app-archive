/* SVGImport.m
 * SVG import object
 *
 * Copyright (C) 2010-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2010-07-03
 * modified: 2012-05-21 (coordFromString() added for svg-width/hight to support units, scale only once)
 *           2012-01-05
 *
 * SVG Specs: http://www.w3.org/TR/2003/REC-SVG11-20030114
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

#include "SVGImport.h"
//#include "../VHFShared/vhfCFGFunctions.h"
#include "../VHFShared/types.h"
#include "../VHFShared/VHFDictionaryAdditions.h"
#include "../VHFShared/VHFStringAdditions.h"

#define DEBUG_SVG   0

typedef struct _svgColorMap
{
    const NSString  *name;
    int             r, g, b;
} SVGColorMap;
static const SVGColorMap svgColorMap[] =
{
    { @"aliceblue",            240,248,255},
    { @"antiquewhite",         250,235,215},
    { @"aqua",                   0,255,255},
    { @"aquamarine",           127,255,212},
    { @"azure",                240,255,255},
    { @"beige",                245,245,220},
    { @"bisque",               255,228,196},
    { @"black",                  0,  0,  0},
    { @"blanchedalmond",       255,235,205},
    { @"blue",                   0,  0,255},
    { @"blueviolet",           138, 43,226},
    { @"brown",                165, 42, 42},
    { @"burlywood",            222,184,135},
    { @"cadetblue",             95,158,160},
    { @"chartreuse",           127,255,  0},
    { @"chocolate",            210,105, 30},
    { @"coral",                255,127, 80},
    { @"cornflowerblue",       100,149,237},
    { @"cornsilk",             255,248,220},
    { @"crimson",              220, 20, 60},
    { @"cyan",                   0,255,255},
    { @"darkblue",               0,  0,139},
    { @"darkcyan",               0,139,139},
    { @"darkgoldenrod",        184,132, 11},
    { @"darkgray",             169,169,168},
    { @"darkgreen",              0,100,  0},
    { @"darkgrey",             169,169,169},
    { @"darkkhaki",            189,183,107},
    { @"darkmagenta",          139,  0,139},
    { @"darkolivegreen",        85,107, 47},
    { @"darkorange",           255,140,  0},
    { @"darkorchid",           153, 50,204},
    { @"darkred",              139,  0,  0},
    { @"darksalmon",           233,150,122},
    { @"darkseagreen",         143,188,143},
    { @"darkslateblue",         72, 61,139},
    { @"darkslategray",         47, 79, 79},
    { @"darkslategrey",         47, 79, 79},
    { @"darkturquoise",          0,206,209},
    { @"darkviolet",           148,  0,211},
    { @"deeppink",             255, 20,147},
    { @"deepskyblue",            0,191,255},
    { @"dimgray",              105,105,105},
    { @"dimgrey",              105,105,105},
    { @"dodgerblue",            30,144,255},
    { @"firebrick",            178, 34, 34},
    { @"floralwhite" ,         255,255,240},
    { @"forestgreen",           34,139, 34},
    { @"fuchsia",              255,  0,255},
    { @"gainsboro",            220,220,220},
    { @"ghostwhite",           248,248,255},
    { @"gold",                 215,215,  0},
    { @"goldenrod",            218,165, 32},
    { @"gray",                 128,128,128},
    { @"grey",                 128,128,128},
    { @"green",                  0,128,  0},
    { @"greenyellow",          173,255, 47},
    { @"honeydew",             240,255,240},
    { @"hotpink",              255,105,180},
    { @"indianred",            205, 92, 92},
    { @"indigo",                75,  0,130},
    { @"ivory",                255,255,240},
    { @"khaki",                240,230,140},
    { @"lavender",             230,230,250},
    { @"lavenderblush",        255,240,245},
    { @"lawngreen",            124,252,  0},
    { @"lemonchiffon",         255,250,205},
    { @"lightblue",            173,216,230},
    { @"lightcoral",           240,128,128},
    { @"lightcyan",            224,255,255},
    { @"lightgoldenrodyellow", 250,250,210},
    { @"lightgray",            211,211,211},
    { @"lightgreen",           144,238,144},
    { @"lightgrey",            211,211,211},
    { @"lightpink",            255,182,193},
    { @"lightsalmon",          255,160,122},
    { @"lightseagreen",         32,178,170},
    { @"lightskyblue",         135,206,250},
    { @"lightslategray",       119,136,153},
    { @"lightslategrey",       119,136,153},
    { @"lightsteelblue",       176,196,222},
    { @"lightyellow",          255,255,224},
    { @"lime",                   0,255,  0},
    { @"limegreen",             50,205, 50},
    { @"linen",                250,240,230},
    { @"magenta",              255,  0,255},
    { @"maroon",               128,  0,  0},
    { @"mediumaquamarine",     102,205,170},
    { @"mediumblue",             0,  0,205},
    { @"mediumorchid",         186, 85,211},
    { @"mediumpurple",         147,112,219},
    { @"mediumseagreen",        60,179,113},
    { @"mediumslateblue",      123,104,238},
    { @"mediumspringgreen",      0,250,154},
    { @"mediumturquoise",       72,209,204},
    { @"mediumvioletred",      199, 21,133},
    { @"mediumnightblue",       25, 25,112},
    { @"mintcream",            245,255,250},
    { @"mintyrose",            255,228,225},
    { @"moccasin",             255,228,181},
    { @"navajowhite",          255,222,173},
    { @"navy",                   0,  0,128},
    { @"oldlace",              253,245,230},
    { @"olive",                128,128,  0},
    { @"olivedrab",            107,142, 35},
    { @"orange",               255,165,  0},
    { @"orangered",            255, 69,  0},
    { @"orchid",               218,112,214},
    { @"palegoldenrod",        238,232,170},
    { @"palegreen",            152,251,152},
    { @"paleturquoise",        175,238,238},
    { @"palevioletred",        219,112,147},
    { @"papayawhip",           255,239,213},
    { @"peachpuff",            255,218,185},
    { @"peru",                 205,133, 63},
    { @"pink",                 255,192,203},
    { @"plum",                 221,160,203},
    { @"powderblue",           176,224,230},
    { @"purple",               128,  0,128},
    { @"red",                  255,  0,  0},
    { @"rosybrown",            188,143,143},
    { @"royalblue",             65,105,225},
    { @"saddlebrown",          139, 69, 19},
    { @"salmon",               250,128,114},
    { @"sandybrown",           244,164, 96},
    { @"seagreen",              46,139, 87},
    { @"seashell",             255,245,238},
    { @"sienna",               160, 82, 45},
    { @"silver",               192,192,192},
    { @"skyblue",              135,206,235},
    { @"slateblue",            106, 90,205},
    { @"slategray",            112,128,144},
    { @"slategrey",            112,128,114},
    { @"snow",                 255,255,250},
    { @"springgreen",            0,255,127},
    { @"steelblue",             70,130,180},
    { @"tan",                  210,180,140},
    { @"teal",                   0,128,128},
    { @"thistle",              216,191,216},
    { @"tomato",               255, 99, 71},
    { @"turquoise",             64,224,208},
    { @"violet",               238,130,238},
    { @"wheat",                245,222,179},
    { @"white",                255,255,255},
    { @"whitesmoke",           245,245,245},
    { @"yellow",               255,255,  0},
    { @"yellowgreen",          154,205, 50}
};

@interface SVGImport(PrivateMethods)
- (NSScanner*)scannerWithString:(NSString*)string;
- (BOOL)scanArgs:(NSScanner*)scanner args:(float*)args numArgs:(int)numArgs;
- (NSArray*)parsePath:(NSString*)pathString;
@end

@implementation SVGImport

- init
{
    [super init];

    /* init bounds */
    ll.x = ll.y = LARGE_COORD;
    ur.x = ur.y = LARGENEG_COORD;

    ctm = [NSAffineTransform transform];
    state.width       = stateGroup.width       = 0.0;
    state.fillColor   = stateGroup.fillColor   = [NSColor blackColor];
    state.strokeColor = stateGroup.strokeColor = [NSColor blackColor];
    style      = [[NSMutableDictionary dictionary] retain];
    styleGroup = [[NSMutableDictionary dictionary] retain];
    scale = 1.0;
    flipHeight = 0.0;
    drawElements = YES;
    defs = nil;
    elementStack = [[NSMutableArray array] retain];
    groupStack   = [[NSMutableArray array] retain];
    groupId = nil;
    useDict = [[NSMutableDictionary dictionary] retain];

    return self;
}

- (void)updateBounds:(NSPoint)p
{
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);
}

NSPoint flipAndScale(NSPoint p, float flipHeight, float scale)
{
    if ( flipHeight )
        p.y = flipHeight - p.y;
    p.x *= scale;
    p.y *= scale;
    return p;
}

/* return coordinate or length and recognice unit
 * created: 2012-05-21
 */
double coordFromString(NSString *str)
{   double  v = [str doubleValue], s = 1.0;
    int     strLen = [str length];
    char    cStr[3];    // "px", "pt", "pc", "mm", "cm", "in"

    if ( strLen <= 2 )
        return v;
    cStr[0] = [str characterAtIndex:strLen-2];
    if ( isdigit(cStr[0]) )
        return v;
    cStr[1] = [str characterAtIndex:strLen-1];
    cStr[2] = 0;

    if (      ! strcmp(cStr, "px") )    // user unit
        s = 1.0 / 1.25;         // 0.8
    else if ( ! strcmp(cStr, "pt") )    // 1pt = 1.25px
        s = 1.0;
    else if ( ! strcmp(cStr, "pc") )    // 1pc = 15px
        s = 1.0 / 1.25 * 15;    // 12
    else if ( ! strcmp(cStr, "mm") )    // 1mm = 3.543307px
        s = 72.0 / 25.4;
    else if ( ! strcmp(cStr, "cm") )    // 1cm = 35.43307px
        s = 72.0 / 2.54;
    else if ( ! strcmp(cStr, "in") )    // 1in = 90px
        s = 72.0;
    else
        NSLog(@"SVGImport, coordFromString(): unrecognized unit %s", cStr);

    return v * s;
}
/* get Color from name or RGB code
 * "#aabbcc" -> NSColor
 */
static int _svgColorCmp(const void *a, const void *b)
{   const NSString      *needle   = a;
    const SVGColorMap   *haystack = b;

    return [needle caseInsensitiveCompare:(NSString*)(haystack->name)];
}
static NSColor *colorWithXMLString(NSString *xmlColor, float alpha)
{   int     r, g, b;
    NSRange range;

    if ( [xmlColor length] < 3 )
        return [NSColor blackColor];
    range = [xmlColor rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
    if ( range.location == 0 )  // there is leading white space
        xmlColor = [xmlColor substringFromIndex:range.location+range.length];
    /* "#RRGGBB" or "#RGB" */
    if ( [xmlColor characterAtIndex:0] == '#' )
    {   const char  *cStr = [xmlColor UTF8String] + 1;
        char        cBuf[7];

        if ( [xmlColor length] == 4 )   // "#RGB" -> "#RRGGBB"
        {   cBuf[0] = cBuf[1] = [xmlColor characterAtIndex:1];
            cBuf[2] = cBuf[3] = [xmlColor characterAtIndex:2];
            cBuf[4] = cBuf[5] = [xmlColor characterAtIndex:3];
            cBuf[6] = 0;
            cStr = cBuf;
        }
        sscanf(cStr, "%2x%2x%2x", &r, &g, &b);
    }
    /* rgb(Red, Green, Blue) */
    else if ( [xmlColor hasPrefix:@"rgb("] )
    {   int cnt;

        cnt = sscanf([xmlColor UTF8String], "rgb( %d, %d, %d", &r, &g, &b);
        if ( cnt < 3 )
            NSLog(@"SVGImport, parsing of color string failed %@", xmlColor);
    }
    /* url(#Id) */
    else if ( [xmlColor hasPrefix:@"url("] )
    {   NSRange     range, range1, range2;
        NSString    *rel;

        range1 = [xmlColor rangeOfString:@"("];
        range2 = [xmlColor rangeOfString:@")"];
        if ( range2.length )
        {   range = NSMakeRange(range1.location+1, range2.location - range1.location - 1);
            if ( [xmlColor characterAtIndex:range.location] == '#' )
            {   range.location += 1; range.length -= 1;
                rel = [xmlColor substringWithRange:range];
                return (NSColor*)rel; // this is a hack, we check if we have a NSColor or NSString
            }
            else
                NSLog(@"SVGImport, TODO: absolute links to colors %@", xmlColor);
        }
        return nil;
    }
    /* Color Name */
    else
    {   SVGColorMap *mapEntry;

        mapEntry = bsearch (xmlColor, svgColorMap,
                            (sizeof(svgColorMap)/sizeof((svgColorMap)[0])),
                            sizeof (SVGColorMap), _svgColorCmp);
        if ( !mapEntry )
            return nil;
        r = mapEntry->r;
        g = mapEntry->g;
        b = mapEntry->b;
    }
    return [NSColor colorWithDeviceRed:(float)r/255.0 green:(float)g/255.0 blue:(float)b/255.0 alpha:alpha];
}
/* "0" - "1" or "0%" - "100%"
 */
float percentWithXMLString(NSString *string)
{
    if ( [string rangeOfString:@"%"].length )
        return ((float)[string intValue]) / 100.0;
    else
        return [string floatValue];
    NSLog(@"SVGImport, percentWithXMLString(): unidentified percentage argument '%@'", string);
    return 0.0;
}
NSString *valueFromStyle(NSString *styleStr, NSString *key)
{   NSRange range = [styleStr rangeOfString:key], range1, sRange;

    if ( range.length )
    {
        sRange.location = range.location+range.length+1;
        sRange.length   = [styleStr length] - sRange.location;
        range1 = [styleStr rangeOfString:@";" options:0 range:sRange];
        if ( ! range1.length )  // at end
            range1.location = [styleStr length];
        range = NSMakeRange(sRange.location, range1.location - sRange.location);
        return [styleStr substringWithRange:range];
    }
    return nil;
}
SVGState setStyleFromString(SVGState *style, NSString *string)
{   NSArray     *components = [string componentsSeparatedByString:@";"];
    int         i;

    for ( i=0; i<[components count]; i++ )
    {   NSString    *entry = [components objectAtIndex:i];
        NSRange     range;

        range = [entry rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
        if ( range.location == 0 )  // remove leading white space
            entry = [entry substringFromIndex:range.location+range.length];

        if ( [entry hasPrefix:@"fill:"] )
        {   NSString    *colStr = [entry substringFromIndex:[@"fill:" length]];
            style->fillColor   = colorWithXMLString(colStr, 1.0);
        }
        else if ( [entry hasPrefix:@"stroke:"] )
        {   NSString    *colStr = [entry substringFromIndex:[@"stroke:" length]];
            style->strokeColor = colorWithXMLString(colStr, 1.0);
        }
        else if ( [entry hasPrefix:@"stroke-width:"] )
        {   NSString    *wStr = [entry substringFromIndex:[@"stroke-width:" length]];
            style->width = [wStr floatValue];
        }
        // TODO: add remaining styles
    }
    return *style;
}
NSAffineTransform *getMatrixFromString(NSString *string)
{   NSString            *key, *parms;
    NSAffineTransform   *matrix = [NSAffineTransform transform];
    NSRange             range, range1;
    double              args[6];
    int                 nArgs, ix;
    const char          *str;

    range = [string rangeOfString:@"("];
    if ( ! range.location || ! range.length )
    {   NSLog(@"SVGImport, '(' expected in transform: %@", string);
        return matrix;
    }
    key = [string substringToIndex:range.location];
    range1 = [string rangeOfString:@")"];
    if ( ! range1.location || ! range1.length )
    {   NSLog(@"SVGImport, ')' expected in transform: %@", string);
        return matrix;
    }
    parms = [string substringWithRange:NSMakeRange(range.location+1, (range1.location-range.location)-1)];

    //nArgs = sscanf([parms UTF8String], "%lf%*[, ]%lf%*[, ]%lf%*[, ]%lf%*[, ]%lf%*[, ]%lf",
    //nArgs = sscanf([parms UTF8String], "%lf, %lf, %lf, %lf, %lf, %lf",
    //               &args[0], &args[1], &args[2], &args[3], &args[4], &args[5]);
    str = [parms UTF8String];
    for (nArgs = 0, ix = 0; ; nArgs++)
    {   char    c;
        char    *end_ptr;

	    while ( str[ix] == ' ' )    // skip white space
            ix++;
	    c = str[ix];
	    if ( isdigit(c) || c == '+' || c == '-' || c == '.' )
        {
            if ( nArgs == (sizeof(args)/sizeof((args)[0])) )
            {   NSLog(@"SVGImport, to many arguments in transform: %@", string);
                return matrix;
            }
            args[nArgs] = strtod(str + ix, &end_ptr);
            ix = end_ptr - str;
            while ( str[ix] == ' ' )
                ix++;
            if (str[ix] == ',') // skip optional comma
                ix++;
	    }
        else if ( !c || c == ')' )
            break;
	    else
        {   NSLog(@"SVGImport, unexpected character '%c' in transform: %@", c, string);
            return matrix;
        }
	}

	if ( [key isEqual:@"matrix"] )
    {   NSAffineTransformStruct transformStruct;

	    if (nArgs != 6)
        {   NSLog(@"SVGImport, wrong number of arguments in transform: %@", string);
            return matrix;
        }
        transformStruct.m11 = args[0]; transformStruct.m12 = args[1];
        transformStruct.m21 = args[2]; transformStruct.m22 = args[3];
        transformStruct.tX  = args[4]; transformStruct.tY  = args[5];
        [matrix setTransformStruct:transformStruct];
	}
    else if ( [key isEqual:@"translate"] )
    {
        if (nArgs == 1)
            args[1] = 0;
	    else if (nArgs != 2)
        {   NSLog(@"SVGImport, wrong number of arguments in transform: %@", string);
            return matrix;
        }
        [matrix translateXBy:args[0] yBy:args[1]];
	}
    else if ( [key isEqual:@"scale"] )
    {
        if (nArgs == 1)
            args[1] = args[0];
	    else if (nArgs != 2)
        {   NSLog(@"SVGImport, wrong number of arguments in transform: %@", string);
            return matrix;
        }
        [matrix scaleXBy:args[0] yBy:args[1]];
	}
    else if ( [key isEqual:@"rotate"] )
    {
	    if (nArgs != 1)
        {   NSLog(@"SVGImport, wrong number of arguments in transform: %@", string);
            return matrix;
        }
        [matrix rotateByDegrees:args[0]];
	}
    else if ( [key isEqual:@"skewX"] )
    {   NSAffineTransformStruct transformStruct;
        double  rad;

	    if (nArgs != 1)
        {   NSLog(@"SVGImport, wrong number of arguments in transform: %@", string);
            return matrix;
        }
        rad = Pi * args[0] / 180.0;
        transformStruct.m11 = 1.0;      transformStruct.m12 = 0.0;
        transformStruct.m21 = tan(rad); transformStruct.m22 = 1.0;
        transformStruct.tX  = 0.0;      transformStruct.tY  = 0.0;
        [matrix setTransformStruct:transformStruct];
	}
    else if ( [key isEqual:@"skewY"] )
    {   NSAffineTransformStruct transformStruct;
        double  rad;

	    if (nArgs != 1)
        {   NSLog(@"SVGImport, wrong number of arguments in transform: %@", string);
            return matrix;
        }
        rad = Pi * args[0] / 180.0;
        transformStruct.m11 = 1.0; transformStruct.m12 = tan(rad);
        transformStruct.m21 = 0.0; transformStruct.m22 = 1.0;
        transformStruct.tX  = 0.0; transformStruct.tY  = 0.0;
        [matrix setTransformStruct:transformStruct];
	}
    else
	    NSLog(@"SVGImport, unknown keyword in transform: '%@'", string);
    return matrix;
}

float transformWidth(float w, NSAffineTransform *matrix)
{   NSSize  s = NSMakeSize(w, w);

    s = [matrix transformSize:s];
    return ( Abs(s.width) + Abs(s.height) ) / 2;
}

/* created:   2010-07-03
 * modified:  2010-07-03
 * parameter: svgData   the SVG data stream
 * purpose:   start interpretation of the contents of svgData
 */
- (id)importSVG:(NSData*)svgData
{   NSXMLParser *xmlParser = [[[NSXMLParser alloc] initWithData:svgData] autorelease];

    list = [self allocateList];

    [xmlParser setDelegate:self];
    [xmlParser parse];

    /* if we couldn't determine how to scale, we scale now from the bounds we collected */
    if ( scale == 1.0 && flipHeight == 0.0 )
    {   viewRect.origin      = ll;
        viewRect.size.width  = ur.x - ll.x;
        viewRect.size.height = ur.y - ll.y;
        scale = tgtSize.width / viewRect.size.width;
        flipHeight = ur.y;
        [self setBounds:viewRect];
    }
    else
    {   flipHeight = 0; // don't flip again
        scale = 1.0;    // don't scale again
        [self setBounds:viewRect];
    }

    return [list autorelease];
}


- (void)parserDidStartDocument:(NSXMLParser *)parser
{
#   if DEBUG_SVG
    NSLog(@"found file and started parsing");
#   endif
}

- (void)parser:(NSXMLParser*)parser parseErrorOccurred:(NSError*)parseError
{
#   if DEBUG_SVG
    NSLog(@"SVGImport: Error parsing XML: %d", [parseError code]);
#   endif
}

- (void)parser:(NSXMLParser*)parser didStartElement:(NSString*)elementName
  namespaceURI:(NSString*)namespaceURI qualifiedName:(NSString*)qName
    attributes:(NSDictionary*)attributeDict
{   NSString    *elemId = [attributeDict objectForKey:@"id"];

#   if DEBUG_SVG
    NSLog(@"beg element:  %@", elementName);
    if ( [[attributeDict allKeys] count] > 0 )
        NSLog(@"  attributes: %@", attributeDict);
#   endif
    if ( [elementName hasPrefix:@"svg:"] )
        elementName = [elementName substringFromIndex:[elementName rangeOfString:@":"].location+1];
    [elementStack addObject:elementName]; currentElement = elementName;
    attributes = attributeDict;

    if ([elementName isEqualToString:@"svg"])       // width, height, viewBox
    {
        if ([attributeDict objectForKey:@"viewBox"])
        {   NSScanner   *scanner = [self scannerWithString:[attributeDict objectForKey:@"viewBox"]];
            float       args[4];

            [self scanArgs:scanner args:args numArgs:4];
            viewRect = NSMakeRect(args[0], args[1], args[2], args[3]);
        }
        else
            viewRect = NSZeroRect;
        tgtSize = viewRect.size;
        if ( [attributeDict objectForKey:@"width"] )
        {   tgtSize.width  = coordFromString([attributeDict stringForKey:@"width" ]);
            tgtSize.height = coordFromString([attributeDict stringForKey:@"height"]);
        }
        while ( tgtSize.width > 10000 || tgtSize.height > 10000 )
        {   tgtSize.width  /= 10.0;
            tgtSize.height /= 10.0;
        }
        /* we use width/height and viewBox to determine a scale factor for on the fly scaling */
        if ( [attributeDict objectForKey:@"viewBox"] )
        {   scale = tgtSize.width / viewRect.size.width;
            flipHeight = viewRect.size.height;
        }
    }
    else if ([elementName isEqualToString:@"defs"])             // definitions
    {
        if ( ! defs )
            defs = [NSMutableDictionary dictionary];
        drawElements = NO;
    }
    else if ([elementName isEqualToString:@"linearGradient"])   // linear gradient: id
    {   NSMutableDictionary *grad = [NSMutableDictionary dictionary];
        NSString            *ref = [attributeDict objectForKey:@"xlink:href"];

        if ( [ref characterAtIndex:0] == '#' ) // local reference
        {   NSDictionary    *dict = [defs objectForKey:[ref substringFromIndex:1]];
            [grad addEntriesFromDictionary:dict];
        }
        else
            NSLog(@"SVGImport: TODO: linearGradient, external reference");  // TODO
        //TODO: linearGradient: gradienUnits, gradientTransform, x1, y1, x2, y2
        if ( elemId )
        {   currentElemId = elemId;
            [defs setObject:grad forKey:elemId];
        }
    }
    else if ([elementName isEqualToString:@"radialGradient"])   // radial gradient: id, ...
    {   NSMutableDictionary *grad = [NSMutableDictionary dictionary];
        NSString            *ref = [attributeDict objectForKey:@"xlink:href"];

        if ( [ref characterAtIndex:0] == '#' ) // local reference
        {   NSDictionary    *dict = [defs objectForKey:[ref substringFromIndex:1]];
            [grad addEntriesFromDictionary:dict];
        }
        else
            NSLog(@"SVGImport: TODO: radialGradient, external reference");  // TODO
        if ( [attributeDict objectForKey:@"cx"] )
            [grad setObject:[attributeDict objectForKey:@"cx"] forKey:@"cx"];
        if ( [attributeDict objectForKey:@"cy"] )
            [grad setObject:[attributeDict objectForKey:@"cy"] forKey:@"cy"];
        //TODO: radialGradient: gradienUnits, gradientTransform, fx, fy, r
        if ( elemId )
        {   currentElemId = elemId;
            [defs setObject:grad forKey:elemId];
        }
    }
    else if ([elementName isEqualToString:@"stop"])             // stop (gradient): offset, stop-color
    {   NSString            *elemId = currentElemId;
        NSMutableDictionary *grad = [defs objectForKey:elemId];
        NSColor             *stopColor = colorWithXMLString([attributeDict objectForKey:@"stop-color"], 1.0);
        float               offset = percentWithXMLString([attributeDict objectForKey:@"offset"]);
        NSString            *styleStr = [attributeDict objectForKey:@"style"];
        NSString            *keyCol = @"begCol", *keyOff = @"begOff";

        if (styleStr)
        {   NSString    *val = valueFromStyle(styleStr, @"stop-opacity");
            float       alpha = (val) ? [val floatValue] : 1.0;

            stopColor = colorWithXMLString(valueFromStyle(styleStr, @"stop-color"), alpha);
        }
        // TODO: add opacity
        if ( [grad objectForKey:@"begCol"] )
        {   keyCol = @"endCol"; keyOff = @"endOff"; }
        [grad setObject:stopColor                         forKey:keyCol];
        [grad setObject:[NSNumber numberWithFloat:offset] forKey:keyOff];
    }
    else if ([elementName isEqualToString:@"clipPath"])         // clip path
    {
        NSLog(@"SVGImport, TODO: clipPath");    // TODO: clipPath
        drawElements = NO;
    }
    else if ([elementName isEqualToString:@"path"])             // path: d, fill, stroke, stroke-width
    {   float               w = [attributeDict floatForKey:@"stroke-width"];
        NSColor             *fillColor   = colorWithXMLString([attributeDict objectForKey:@"fill"],   1.0);
        NSColor             *strokeColor = colorWithXMLString([attributeDict objectForKey:@"stroke"], 1.0);
        NSString            *pathString = [attributeDict objectForKey:@"d"];    // M, m, L, l, C, c, H, h, V, v, A, a, z
        NSArray             *pathList = nil;
        NSAffineTransform   *ctmPrev = ctm;

        if ( [attributeDict objectForKey:@"transform"] )
        {   NSAffineTransform   *matrix = getMatrixFromString([attributeDict objectForKey:@"transform"]);
            ctm = [[[NSAffineTransform alloc] initWithTransform:ctm] autorelease];
            [ctm prependTransform:matrix];
        }
        state.width       = stateGroup.width;
        state.fillColor   = stateGroup.fillColor;
        state.strokeColor = stateGroup.strokeColor;
        setStyleFromString(&state, [attributeDict objectForKey:@"style"]);
        if ( [attributeDict objectForKey:@"stroke-width"] )
            state.width       = w * scale;
        if ( [attributeDict objectForKey:@"fill"] )
            state.fillColor   = fillColor;
        if ( [attributeDict objectForKey:@"stroke"] )
            state.strokeColor = strokeColor;

        if ( drawElements )
        {   pathList = [self parsePath:pathString];
            /*if ( ! closedPath && ![attributeDict objectForKey:@"fill"] )
                state.fillColor = nil;  // we don't fill open paths*/
            state.width = transformWidth(state.width, ctm);
            [self addFillList:pathList toList:(groupList) ? groupList : list];
        }
        if ( elemId && pathList )
            [useDict setObject:pathList forKey:elemId];
        ctm = ctmPrev;
    }
    else if ([elementName isEqualToString:@"circle"])       // Circle: cx, cy, r
    {   float               w = [attributeDict floatForKey:@"stroke-width"];
        NSColor             *fillColor   = colorWithXMLString([attributeDict objectForKey:@"fill"],   1.0);
        NSColor             *strokeColor = colorWithXMLString([attributeDict objectForKey:@"stroke"], 1.0);
        NSAffineTransform   *ctmPrev = ctm;
        NSPoint             cp, p;
        float               r;
        
        if ( [attributeDict objectForKey:@"transform"] )
        {   NSAffineTransform   *matrix = getMatrixFromString([attributeDict objectForKey:@"transform"]);
            ctm = [[[NSAffineTransform alloc] initWithTransform:ctm] autorelease];
            [ctm prependTransform:matrix];
        }
        state.width       = stateGroup.width;
        state.fillColor   = stateGroup.fillColor;
        state.strokeColor = stateGroup.strokeColor;
        setStyleFromString(&state, [attributeDict objectForKey:@"style"]);
        if ( [attributeDict objectForKey:@"stroke-width"] )
            state.width       = w * scale;
        if ( [attributeDict objectForKey:@"fill"] )
            state.fillColor   = fillColor;
        if ( [attributeDict objectForKey:@"stroke"] )
            state.strokeColor = strokeColor;
        
        if ( drawElements )
        {   cp.x = [attributeDict floatForKey:@"cx"];
            cp.y = [attributeDict floatForKey:@"cy"];
            r    = [attributeDict floatForKey:@"r"];
            p.x = cp.x + r;
            p.y = cp.y;
            cp = [ctm transformPoint:cp]; [self updateBounds:cp];
            cp = flipAndScale(cp, flipHeight, scale);
            p  = [ctm transformPoint:p];  [self updateBounds:p];
            p = flipAndScale(p, flipHeight, scale);
            state.width = transformWidth(state.width, ctm);
            [self addArc:cp :p :360.0 toList:(groupList) ? groupList : list];
        }
        //TODO: if ( elemId )
        //    [useDict setObject:groupList forKey:elemId];
        ctm = ctmPrev;
    }
    else if ([elementName isEqualToString:@"line"])             // Line: x1, y1, x2, y2
    {   float               w = [attributeDict floatForKey:@"stroke-width"];
        NSColor             *fillColor   = colorWithXMLString([attributeDict objectForKey:@"fill"],   1.0);
        NSColor             *strokeColor = colorWithXMLString([attributeDict objectForKey:@"stroke"], 1.0);
        NSAffineTransform   *ctmPrev = ctm;
        NSPoint             p0, p1;

        if ( [attributeDict objectForKey:@"transform"] )
        {   NSAffineTransform   *matrix = getMatrixFromString([attributeDict objectForKey:@"transform"]);
            ctm = [[[NSAffineTransform alloc] initWithTransform:ctm] autorelease];
            [ctm prependTransform:matrix];
        }
        state.width       = stateGroup.width;
        state.fillColor   = stateGroup.fillColor;
        state.strokeColor = stateGroup.strokeColor;
        setStyleFromString(&state, [attributeDict objectForKey:@"style"]);
        if ( [attributeDict objectForKey:@"stroke-width"] )
            state.width       = w * scale;
        if ( [attributeDict objectForKey:@"fill"] )
            state.fillColor   = fillColor;
        if ( [attributeDict objectForKey:@"stroke"] )
            state.strokeColor = strokeColor;

        if ( drawElements )
        {   p0.x = [attributeDict floatForKey:@"x1"];
            p0.y = [attributeDict floatForKey:@"y1"];
            p1.x = [attributeDict floatForKey:@"x2"];
            p1.y = [attributeDict floatForKey:@"y2"];
            p0 = [ctm transformPoint:p0]; [self updateBounds:p0];
            p0 = flipAndScale(p0, flipHeight, scale);
            p1 = [ctm transformPoint:p1]; [self updateBounds:p1];
            p1 = flipAndScale(p1, flipHeight, scale);
            state.width = transformWidth(state.width, ctm);
            [self addLine:p0 :p1 toList:(groupList) ? groupList : list];
        }
        //TODO: if ( elemId )
        //    [useDict setObject:groupList forKey:elemId];
        ctm = ctmPrev;
    }
    else if ([elementName isEqualToString:@"polygon"])             // Polygon: points
    {   float               w = [attributeDict floatForKey:@"stroke-width"];
        NSColor             *fillColor   = colorWithXMLString([attributeDict objectForKey:@"fill"],   1.0);
        NSColor             *strokeColor = colorWithXMLString([attributeDict objectForKey:@"stroke"], 1.0);
        NSAffineTransform   *ctmPrev = ctm;
        NSString            *ptsStr = [attributeDict objectForKey:@"points"];
        NSPoint             *pts;
        int                 pCnt;

        if ( [attributeDict objectForKey:@"transform"] )
        {   NSAffineTransform   *matrix = getMatrixFromString([attributeDict objectForKey:@"transform"]);
            ctm = [[[NSAffineTransform alloc] initWithTransform:ctm] autorelease];
            [ctm prependTransform:matrix];
        }
        state.width       = stateGroup.width;
        state.fillColor   = stateGroup.fillColor;
        state.strokeColor = stateGroup.strokeColor;
        setStyleFromString(&state, [attributeDict objectForKey:@"style"]);
        if ( [attributeDict objectForKey:@"stroke-width"] )
            state.width       = w * scale;
        if ( [attributeDict objectForKey:@"fill"] )
            state.fillColor   = fillColor;
        if ( [attributeDict objectForKey:@"stroke"] )
            state.strokeColor = strokeColor;

        if ( ! (pCnt = [ptsStr countOfCharacter:' ' inRange:NSMakeRange(0, [ptsStr length])]) )
            pCnt = [ptsStr countOfCharacter:',' inRange:NSMakeRange(0, [ptsStr length])];
        pts = NSZoneMalloc([self zone], (pCnt+10) * 2 * sizeof(NSPoint));
        {   NSScanner       *scanner = [NSScanner scannerWithString:ptsStr];
            NSCharacterSet  *skipSet = [NSCharacterSet characterSetWithCharactersInString:@" ,"];

            [scanner setCharactersToBeSkipped:skipSet];
            for ( pCnt=0; ![scanner isAtEnd]; )
            {   double  d;
                NSPoint p;

                [scanner scanDouble:&d]; p.x = d;
                [scanner scanDouble:&d]; p.y = d;
                pts[pCnt] = [ctm transformPoint:p];
                if (drawElements)
                    [self updateBounds:pts[pCnt]];
                pts[pCnt] = flipAndScale(pts[pCnt], flipHeight, scale);
                pCnt++;
            }
            pts[pCnt++] = pts[0];
        }
        if ( drawElements )
        {   state.width = transformWidth(state.width, ctm);
            [self addPolyLine:pts count:pCnt toList:(groupList) ? groupList : list];
        }
        //TODO: if ( elemId )
        //    [useDict setObject:groupList forKey:elemId];
        NSZoneFree([self zone], pts);
        ctm = ctmPrev;
    }
    else if ([elementName isEqualToString:@"rect"])             // Rect: x, y, width, height
    {   float               w = [attributeDict floatForKey:@"stroke-width"];
        NSColor             *fillColor   = colorWithXMLString([attributeDict objectForKey:@"fill"],   1.0);
        NSColor             *strokeColor = colorWithXMLString([attributeDict objectForKey:@"stroke"], 1.0);
        NSAffineTransform   *ctmPrev = ctm;
        NSRect              rect;

        if ( [attributeDict objectForKey:@"transform"] )
        {   NSAffineTransform   *matrix = getMatrixFromString([attributeDict objectForKey:@"transform"]);
            ctm = [[[NSAffineTransform alloc] initWithTransform:ctm] autorelease];
            [ctm prependTransform:matrix];
        }
        state.width       = stateGroup.width;
        state.fillColor   = stateGroup.fillColor;
        state.strokeColor = stateGroup.strokeColor;
        setStyleFromString(&state, [attributeDict objectForKey:@"style"]);
        if ( [attributeDict objectForKey:@"stroke-width"] )
            state.width       = w * scale;
        if ( [attributeDict objectForKey:@"fill"] )
            state.fillColor   = fillColor;
        if ( [attributeDict objectForKey:@"stroke"] )
            state.strokeColor = strokeColor;

        if ( drawElements )
        {   rect.origin.x = [attributeDict floatForKey:@"x"];
            rect.origin.y = [attributeDict floatForKey:@"y"];
            rect.size.width  = [attributeDict floatForKey:@"width"];
            rect.size.height = [attributeDict floatForKey:@"height"];
            if ( 0 )    // we can't transform a rectangle in Cenon with ctm
            {   rect.origin = [ctm transformPoint:rect.origin];
                rect.size   = [ctm transformSize: rect.size];
                [self addRectangle:rect toList:(groupList) ? groupList : list];
            }
            else
            {   NSPoint pts[4], p = rect.origin, s = NSMakePoint(rect.size.width, rect.size.height);
                int     i;
                pts[0] = [ctm transformPoint:p];
                pts[1] = [ctm transformPoint:NSMakePoint(p.x+s.x, p.y)];
                pts[2] = [ctm transformPoint:NSMakePoint(p.x+s.x, p.y+s.y)];
                pts[3] = [ctm transformPoint:NSMakePoint(p.x,     p.y+s.y)];
                for (i=0; i<4; i++)
                {   [self updateBounds:pts[i]];
                    pts[i] = flipAndScale(pts[i], flipHeight, scale);
                }
                state.width = transformWidth(state.width, ctm);
                [self addPolyLine:pts count:4 toList:(groupList) ? groupList : list];
            }
        }
        //TODO: if ( elemId )
        //    [useDict setObject:groupList forKey:elemId];
        ctm = ctmPrev;
    }
    else if ([elementName isEqualToString:@"text"])         // Text: x, y
    {
        attributes = attributeDict;
    }
    else if ([elementName isEqualToString:@"g"])        // fill, stroke, stroke-width, stroke-miterlimit
    {   float   w = [attributeDict floatForKey:@"stroke-width"];
        NSColor *fillColor   = colorWithXMLString([attributeDict objectForKey:@"fill"],   1.0);
        NSColor *strokeColor = colorWithXMLString([attributeDict objectForKey:@"stroke"], 1.0);

        if ( [attributeDict objectForKey:@"transform"] )
        {   NSAffineTransform   *matrix = getMatrixFromString([attributeDict objectForKey:@"transform"]);
            ctm = [[[NSAffineTransform alloc] initWithTransform:ctm] autorelease];
            [ctm appendTransform:matrix];
        }
        stateGroup.width       = w * scale;
        stateGroup.fillColor   = fillColor;
        stateGroup.strokeColor = strokeColor;
        setStyleFromString(&stateGroup, [attributeDict objectForKey:@"style"]);
        [styleGroup setObject:[NSNumber numberWithFloat:w*scale] forKey:@"width"];
        if ( fillColor )
            [styleGroup setObject:fillColor   forKey:@"fillColor"];
        if ( strokeColor )
            [styleGroup setObject:strokeColor forKey:@"strokeColor"];
        if ( ctm )
            [styleGroup setObject:ctm forKey:@"ctm"];

        groupList = [self allocateList];
        [groupList addObject:[[styleGroup copy] autorelease]];  // we store the style in the group list
        [groupStack addObject:groupList];
        if ( elemId && groupList )
            [useDict setObject:groupList forKey:elemId];
    }
    else if ([elementName isEqualToString:@"use"])  // re-use transformed
    {   NSString    *ref = [attributeDict objectForKey:@"xlink:href"];
        id          element = nil;

        if ( [ref characterAtIndex:0] == '#' ) // local reference
            element = [useDict objectForKey:[ref substringFromIndex:1]];
        else
            NSLog(@"SVGImport: TODO: use, external reference"); // TODO

        if ( element )
        {   NSAffineTransform   *matrix = getMatrixFromString([attributeDict objectForKey:@"transform"]);

            if ( [[element objectAtIndex:0] isKindOfClass:[NSDictionary class]] )
            {   [style release];
                style = [[element objectAtIndex:0] retain];
                state.width       = [style floatForKey:@"width"];
                state.fillColor   = [style objectForKey:@"fillColor"];
                state.strokeColor = [style objectForKey:@"strokeColor"];
            }
            if ( scale != 1.0 )
            {   NSAffineTransformStruct transformStruct = [matrix transformStruct];

                transformStruct.tX *= scale;
                transformStruct.tY *= scale;
                [matrix setTransformStruct:transformStruct];
            }
            //if ( [ref hasPrefix:@"path"] )
            //    [self addFillList:element toList:(groupList) ? groupList : list];
            [self addGroupList:element toList:(groupList) ? groupList : list withTransform:matrix];
        }
        else
            NSLog(@"SVGImport: TODO: no element for reference '%@'", ref);
    }
}

- (void)parser:(NSXMLParser*)parser didEndElement:(NSString*)elementName
  namespaceURI:(NSString*)namespaceURI qualifiedName:(NSString*)qName
{
#   if DEBUG_SVG
    NSLog(@"end element: %@", elementName);
#   endif
    if ( [elementName hasPrefix:@"svg:"] )
        elementName = [elementName substringFromIndex:[elementName rangeOfString:@":"].location+1];
    if ( [elementName isEqualToString:@"g"] )
    {
        if ( drawElements )
        {   id  parentGroup = nil;

            state.width       = stateGroup.width;
            state.fillColor   = stateGroup.fillColor;
            state.strokeColor = stateGroup.strokeColor;
            if ( [groupStack count] > 1 )
                parentGroup = [groupStack objectAtIndex:[groupStack count]-2];
            [self addGroupList:groupList toList:(parentGroup) ? parentGroup : list  /*withTransform:ctm*/];
        }
        [groupStack removeObjectAtIndex:[groupStack count]-1];
        [groupId   release]; groupId   = nil;
        [groupList release]; groupList = nil;
        if ([groupStack count]) // restore parent group
        {   groupList = [groupStack objectAtIndex:[groupStack count]-1];
            [style release]; style = [[groupList objectAtIndex:0] retain];
            state.width       = [style floatForKey:@"width"];
            state.fillColor   = [style objectForKey:@"fillColor"];
            state.strokeColor = [style objectForKey:@"strokeColor"];
            ctm = [style objectForKey:@"ctm"];
        }
        else
        {
            ctm = [NSAffineTransform transform];
            stateGroup.width = 0.0;
            stateGroup.fillColor   = [NSColor blackColor];
            stateGroup.strokeColor = [NSColor blackColor];
        }
    }
    /*else if ( [elementName isEqualToString:@"path"] )
    {
        ctm = ctmPrev;  // restore ctm from element transformation
    }*/
    else if ( [elementName isEqualToString:@"text"] )
    {   NSDictionary        *attributeDict = attributes;
        float               w = [attributeDict floatForKey:@"stroke-width"];
        NSColor             *fillColor   = colorWithXMLString([attributeDict objectForKey:@"fill"],   1.0);
        NSColor             *strokeColor = colorWithXMLString([attributeDict objectForKey:@"stroke"], 1.0);
        NSAffineTransform   *ctmPrev = ctm;
        NSPoint             p;
        float               fontSize = 12.0, angle = 0.0, ar = 1.0;
        NSString            *fontName = nil;
        NSString            *styleStr = [attributeDict objectForKey:@"style"];

        if ( [attributeDict objectForKey:@"transform"] )
        {   NSAffineTransform   *matrix = getMatrixFromString([attributeDict objectForKey:@"transform"]);
            ctm = [[[NSAffineTransform alloc] initWithTransform:ctm] autorelease];
            [ctm prependTransform:matrix];
        }
        state.width       = stateGroup.width;
        state.fillColor   = stateGroup.fillColor;
        state.strokeColor = stateGroup.strokeColor;
        setStyleFromString(&state, styleStr);
        if ( [attributeDict objectForKey:@"stroke-width"] )
            state.width       = w * scale;
        if ( [attributeDict objectForKey:@"fill"] )
            state.fillColor   = fillColor;
        if ( [attributeDict objectForKey:@"stroke"] )
            state.strokeColor = strokeColor;

        p.x = [attributeDict floatForKey:@"x"];
        p.y = [attributeDict floatForKey:@"y"];
        if (styleStr)
            fontSize = [valueFromStyle(styleStr, @"font-size") floatValue];
            //TODO: valueFromStyle(styleStr, @"font-family")
        else
            fontSize = [attributeDict floatForKey:@"font-size"];
        p = [ctm transformPoint:p];
        if ( drawElements )
            [self addText:stringFound :fontName :angle :fontSize :ar at:p toList:(groupList) ? groupList : list];
        //TODO: if ( elemId )
        //    [useDict setObject:groupList forKey:elemId];
        ctm = ctmPrev;
    }
    else if ( [elementName isEqualToString:@"defs"] )
    {
        drawElements = YES;
    }
    else if ( [elementName isEqualToString:@"clipPath"] )
    {
        drawElements = YES;
    }

    [elementStack removeObjectAtIndex:[elementStack count]-1];
    if ([elementStack count])
        currentElement = [elementStack objectAtIndex:[elementStack count]-1];
}

- (void)parser:(NSXMLParser*)parser foundCharacters:(NSString*)string
{
#   if DEBUG_SVG
    if ( [string length] )
        NSLog(@"  found characters: %@", string);
#   endif
    /* save the characters for the current item... */
    if ( [currentElement isEqualToString:@"title"] )
        title = [string retain];
    else
        stringFound = string;
}

- (void)parserDidEndDocument:(NSXMLParser*)parser
{
    //[activityIndicator stopAnimating];
    //[activityIndicator removeFromSuperview];

#   if DEBUG_SVG
    NSLog(@"Done!");
#   endif
    //NSLog(@"categories array has %d entries", [categories count]);
    //[newsTable reloadData];
}


- (NSScanner*)scannerWithString:(NSString*)string
{   NSScanner       *scanner;
    NSCharacterSet  *skipSet = [NSCharacterSet characterSetWithCharactersInString:@" ,"];

    if ( ! string )
        return nil;
    scanner = [NSScanner scannerWithString:string];
    [scanner setCharactersToBeSkipped:skipSet];
    return scanner;
}

- (BOOL)scanArgs:(NSScanner*)scanner args:(float*)args numArgs:(int)numArgs
{   int i;

    for ( i=0; i < numArgs; i++ )
    {
        if ( ! [scanner scanFloat:&args[i]] )
        {   if ( i )
                NSLog(@"SVGImport, -scanArgs: float argument expected");
            return NO;
        }
    }
    return YES;
}
int numArgs(char op)
{
    switch (op)
    {
        case 'M':
        case 'm':
        case 'L':
        case 'l': return 2;
        case 'V':
        case 'v':
        case 'H':
        case 'h': return 1;
        case 'C':
        case 'c': return 6;
        case 'S':
        case 's':
        case 'Q':
        case 'q': return 4;
        case 'T':
        case 't': return 2;
        case 'A':
        case 'a': return 7;
        case 'Z':
        case 'z': return 0;
        default:  NSLog(@"SVGImport, numArgs: unknown op %c", op);
    }
    return -1;
}
- (NSArray*)parsePath:(NSString*)pathString
{   NSMutableArray  *pathList = [NSMutableArray array];
    NSScanner       *scanner = [NSScanner scannerWithString:pathString];
    NSCharacterSet  *skipSet = [NSCharacterSet characterSetWithCharactersInString:@" ,"];
    NSCharacterSet  *opSet   = [NSCharacterSet characterSetWithCharactersInString:@"AaCcHhQqLlMmSsTtVvZz"];
    NSPoint         p0 = NSZeroPoint, pt0 = NSZeroPoint, pStart = NSZeroPoint, reflectedCurveP = NSZeroPoint;
    char            lastOp = '-';

    [scanner setCharactersToBeSkipped:skipSet];

    closedPath = NO;
    while ( ! [scanner isAtEnd] )
    {   NSString    *str;
        char        op;
        NSPoint     p1, p2, p3, pt1, pt2, pt3;
        float       args[7];

        [scanner scanUpToCharactersFromSet:opSet intoString:NULL];
        if ( ![scanner scanCharactersFromSet:opSet intoString:&str] )
        {   NSLog(@"SVGImport, parsePath: operator expected, aborting path!"); return pathList; }
        op = [str characterAtIndex:0];
        while ( 1 )
        {   int argCnt = numArgs(op);

            if ( argCnt && ![self scanArgs:scanner args:args numArgs:argCnt] )
                break; // analog: svglib's _svg_str_parse_csv_doubles
            switch (op)
            {
                case 'm':   // MoveTo relative
                    args[0] += p0.x; args[1] += p0.y;
                    op = 'l';   // move continues as LineTo
                case 'M':   // MoveTo absolute
                    p0.x = args[0]; p0.y = args[1];
                    pt0 = [ctm transformPoint:p0];
                    pStart = p0;
                    [self updateBounds:pt0];
                    if ( op == 'L')
                        op = 'L';
                    lastOp = 'M';
                    break;
                case 'l':   // LineTo relative
                    args[0] += p0.x; args[1] += p0.y;
                case 'L':   // LineTo absolute
                    p1.x = args[0]; p1.y = args[1];
                    pt1 = [ctm transformPoint:p1];
                    [self updateBounds:pt1];
                    [self addLine:flipAndScale(pt0, flipHeight, scale)
                                 :flipAndScale(pt1, flipHeight, scale) toList:pathList];
                    p0 = p1; pt0 = pt1;
                    lastOp = 'L';
                    break;
                case 'v':   // Vertical line relative
                    args[0] += p0.y;
                case 'V':   // Vertical line absolute
                    p1.x = p0.x; p1.y = args[0];
                    pt1 = [ctm transformPoint:p1];
                    [self updateBounds:pt1];
                    [self addLine:flipAndScale(pt0, flipHeight, scale)
                                 :flipAndScale(pt1, flipHeight, scale) toList:pathList];
                    p0 = p1; pt0 = pt1;
                    lastOp = 'L';
                    break;
                case 'h':   // Horicontal line relative
                    args[0] += p0.x;
                case 'H':   // Horicontal line absolute
                    p1.x = args[0]; p1.y = p0.y;
                    pt1 = [ctm transformPoint:p1];
                    [self updateBounds:pt1];
                    [self addLine:flipAndScale(pt0, flipHeight, scale)
                                 :flipAndScale(pt1, flipHeight, scale) toList:pathList];
                    p0 = p1; pt0 = pt1;
                    lastOp = 'L';
                    break;
                case 'c':   // CurveTo relative
                    args[0] += p0.x; args[1] += p0.y;
                    args[2] += p0.x; args[3] += p0.y;
                    args[4] += p0.x; args[5] += p0.y;
                case 'C':   // CurveTo absolute
                    p1.x = args[0]; p1.y = args[1];
                    p2.x = args[2]; p2.y = args[3];
                    p3.x = args[4]; p3.y = args[5];
                    pt1 = [ctm transformPoint:p1];
                    pt2 = [ctm transformPoint:p2];
                    pt3 = [ctm transformPoint:p3];
                    [self updateBounds:pt1]; [self updateBounds:pt2]; [self updateBounds:pt3];
                    [self addCurve:flipAndScale(pt0, flipHeight, scale)
                                  :flipAndScale(pt1, flipHeight, scale)
                                  :flipAndScale(pt2, flipHeight, scale)
                                  :flipAndScale(pt3, flipHeight, scale) toList:pathList];
                    reflectedCurveP.x = p3.x + p3.x - p2.x;
                    reflectedCurveP.y = p3.y + p3.y - p2.y;
                    p0 = p3; pt0 = pt3;
                    lastOp = 'C';
                    break;
                case 's':   // Smooth CurveTo relative
                    args[0] += p0.x; args[1] += p0.y;
                    args[2] += p0.x; args[3] += p0.y;
                case 'S':   // Smooth CurveTo absolute
                    p1 = (lastOp == 'C') ? reflectedCurveP : p0;
                    p2.x = args[0]; p2.y = args[1];
                    p3.x = args[2]; p3.y = args[3];
                    pt1 = [ctm transformPoint:p1];
                    pt2 = [ctm transformPoint:p2];
                    pt3 = [ctm transformPoint:p3];
                    [self updateBounds:pt1]; [self updateBounds:pt2]; [self updateBounds:pt3];
                    [self addCurve:flipAndScale(pt0, flipHeight, scale)
                                  :flipAndScale(pt1, flipHeight, scale)
                                  :flipAndScale(pt2, flipHeight, scale)
                                  :flipAndScale(pt3, flipHeight, scale) toList:pathList];
                    reflectedCurveP.x = p3.x + p3.x - p2.x;
                    reflectedCurveP.y = p3.y + p3.y - p2.y;
                    p0 = p3; pt0 = pt3;
                    lastOp = 'C';
                    break;
                case 'q':
                case 'Q':
                    // TODO
                    lastOp = 'C';
                case 't':
                case 'T':
                    // TODO
                    lastOp = 'C';
                    NSLog(@"TODO: SVGImport, -parsePath: operator %c not implemented, skipping", op);
                    break;
                case 'a':   // ArcTo relative
                    args[5] += p0.x; args[6] += p0.y;
                case 'A':   // ArcTo absolute
                {   double  rx = args[0], ry = args[1]; // radius before rotation
                    double  xAxisRotation = args[2];    // rotation angle
                    int     largeArcFlag  = args[3];    // 0 = arc < 180, 1 = arc > 180
                    int     sweepFlag     = args[4];    // sweep: 0 = neg angle, 1 = pos angle
                    double  sin_th, cos_th;
                    double  a00, a01, a10, a11;
                    double  x, y, x0, y0, x1, y1, xc, yc;
                    double  d, sfactor, sfactor_sq;
                    double  th0, th1, th_arc;
                    int     i, n_segs;
                    double  dx, dy, dx1, dy1, Pr1, Pr2, Px, Py, check;
                    double  curx = p0.x, cury = p0.y;
                    NSPoint endP, endPT;

                    endP.x = x = args[5]; endP.y = y = args[6];
                    endPT  = [ctm transformPoint:endP];

                    /* The ellipse and arc code below are:
                     * Copyright (C) 2000 Eazel, Inc.
                     * Author: Raph Levien <raph@artofcode.com>
                     * This is adapted from svg-path in Gill.
                     * This program is free software; you can redistribute it and/or
                     * modify it under the terms of the GNU General Public License as
                     * published by the Free Software Foundation; either version 2 of the
                     * License, or (at your option) any later version.
                     */
                    sin_th = sin (xAxisRotation * (M_PI / 180.0));
                    cos_th = cos (xAxisRotation * (M_PI / 180.0));

                    dx = (curx - x) / 2.0;
                    dy = (cury - y) / 2.0;
                    dx1 =  cos_th * dx + sin_th * dy;
                    dy1 = -sin_th * dx + cos_th * dy;
                    Pr1 = rx * rx;
                    Pr2 = ry * ry;
                    Px = dx1 * dx1;
                    Py = dy1 * dy1;
                    /* Spec: check if radii are large enough */
                    check = Px / Pr1 + Py / Pr2;
                    if (check > 1)
                    {   rx = rx * sqrt(check);
                        ry = ry * sqrt(check);
                    }

                    a00 = cos_th / rx;
                    a01 = sin_th / rx;
                    a10 = -sin_th / ry;
                    a11 = cos_th / ry;
                    x0 = a00 * curx + a01 * cury;
                    y0 = a10 * curx + a11 * cury;
                    x1 = a00 * x + a01 * y;
                    y1 = a10 * x + a11 * y;
                    /* (x0, y0) is current point in transformed coordinate space.
                       (x1, y1) is new point in transformed coordinate space.
                       The arc fits a unit-radius circle in this space.
                     */
                    d = (x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0);
                    sfactor_sq = 1.0 / d - 0.25;
                    if (sfactor_sq < 0) sfactor_sq = 0;
                    sfactor = sqrt (sfactor_sq);
                    if (sweepFlag == largeArcFlag) sfactor = -sfactor;
                    xc = 0.5 * (x0 + x1) - sfactor * (y1 - y0);
                    yc = 0.5 * (y0 + y1) + sfactor * (x1 - x0);
                    /* (xc, yc) is center of the circle. */
                    
                    th0 = atan2 (y0 - yc, x0 - xc);
                    th1 = atan2 (y1 - yc, x1 - xc);
                    
                    th_arc = th1 - th0;
                    if (th_arc < 0 && sweepFlag)
                        th_arc += 2 * M_PI;
                    else if (th_arc > 0 && !sweepFlag)
                        th_arc -= 2 * M_PI;

                    n_segs = ceil (fabs (th_arc / (M_PI * 0.5 + 0.001)));
                    for (i = 0; i < n_segs; i++)
                    {   double  a00, a01, a10, a11;
                        double  x1, y1, x2, y2, x3, y3;
                        double  t, th_half;
                        double  th0a, th1a;

                        /* 4/3 * (1-cos 45deg)/sin 45deg = 4/3 * sqrt(2) - 1 */
                        th0a = th0 + i       * th_arc / n_segs;
                        th1a = th0 + (i + 1) * th_arc / n_segs;

                        /* inverse transform compared to above */
                        a00 = cos_th * rx;
                        a01 = -sin_th * ry;
                        a10 = sin_th * rx;
                        a11 = cos_th * ry;

                        th_half = 0.5 * (th1a - th0a);
                        t = (8.0 / 3.0) * sin(th_half * 0.5) * sin(th_half * 0.5) / sin (th_half);
                        x1 = xc + cos(th0a) - t * sin(th0a);
                        y1 = yc + sin(th0a) + t * cos(th0a);
                        x3 = xc + cos(th1a);
                        y3 = yc + sin(th1a);
                        x2 = x3 + t * sin(th1a);
                        y2 = y3 - t * cos(th1a);

                        p1.x = a00 * x1 + a01 * y1;
                        p1.y = a10 * x1 + a11 * y1;
                        p2.x = a00 * x2 + a01 * y2;
                        p2.y = a10 * x2 + a11 * y2;
                        p3.x = a00 * x3 + a01 * y3;
                        p3.y = a10 * x3 + a11 * y3;
                        pt1  = [ctm transformPoint:p1]; [self updateBounds:pt1];
                        pt2  = [ctm transformPoint:p2]; [self updateBounds:pt2];
                        pt3  = [ctm transformPoint:p3]; [self updateBounds:pt3];
                        [self addCurve:pt0 :pt1 :pt2 :pt3 toList:pathList];
                        p0 = p3; pt0 = pt3;
                    }
                    p0 = endP; pt0 = endPT;
                    lastOp = 'A';
                    break;
                }
                case 'z':
                case 'Z':
                    pt1 = [ctm transformPoint:pStart];
                    [self addLine:flipAndScale(pt0, flipHeight, scale)
                                 :flipAndScale(pt1, flipHeight, scale) toList:pathList];
                    p0 = pStart;
                    lastOp = 'Z';
                    break;
                default:
                    NSLog(@"SVGImport, -parsePath: skipping unknown operator %c", op);
            }
            if ( [scanner isAtEnd] || ! argCnt )
                break;
        }
    }
    if ( Diff(p0.x, pStart.x) < 0.001 && Diff(p0.y, pStart.y) < 0.001 )
        closedPath = YES;

    return pathList;
}


/* the graphics list
 */
- (id)list;
{
    return list;
}

- (void)dealloc
{
    //[currentElement release];
    //[groupId release];
    [title release];
    [useDict release];
    [style release];
    [styleGroup release];
    [elementStack release];
    [groupStack release];

    [super dealloc];
}

/* methods to be subclassed
 */
- (id)allocateList
{
    return nil;
}

- (void)addFillList:aList toList:bList
{
    NSLog(@"filled path.");
}

- (void)addGroupList:aList toList:bList
{
    NSLog(@"group."); 
}

- (void)addGroupList:aList toList:bList withTransform:(NSAffineTransform*)matrix
{
    NSLog(@"group with transform %@.", matrix); 
}

- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList
{
    NSLog(@"line: %f %f %f %f", beg.x, beg.y, end.x, end.y); 
}

- (void)addPolyLine:(NSPoint*)pts count:(int)pCnt toList:aList
{   NSMutableString *string = [NSMutableString string];
    int i;

    for (i=0; i<pCnt; i++)
        [string appendFormat:@"%f %f ", pts[i].x, pts[i].y];
    NSLog(@"polyLine: %@", string); 
}

- (void)addRectangle:(NSRect)rect toList:aList
{
    NSLog(@"rectangle: %f %f %f %f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height); 
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
    NSLog(@"text: %f %f %f %f %f \"%s\" \"%s\"\n", p.x, p.y, angle, size, ar, text, font); 
}

- (void)setBounds:(NSRect)bounds
{
    NSLog(@"bounds: %f %f %f %f", bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
}
@end
