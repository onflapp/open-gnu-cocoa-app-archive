/* Type1Font.m
 * Type 1 Font object used for the type 1 import
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-11-26
 * modified: 2012-02-07 (-writeToFile: 2x use -writeToFile:...encoding:error:)
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
#include <VHFShared/vhfCommonFunctions.h>
#include "PreferencesMacros.h"
#include "locations.h"
#include "Graphics.h"
#include "messages.h"
#include "Type1Font.h"
#include "type1Encoding.h"	// private header

@interface Type1Font(PrivateMethods)
- (BOOL)getCharStringFromList:(CharStrings*)charString name:(const char*)name index:(int)index list:(NSArray*)list;
- (int)setSidebearing:(int)sbx width:(int)wx :(unsigned char*)code;
- (int)setVStems:(int*)vStems :(int)vCnt :(unsigned char*)code;
- (int)setHStems:(int*)hStems :(int)hCnt :(unsigned char*)code;
- (int)setGraphic:(id)obj :(unsigned char*)code;
@end

@implementation Type1Font

+ (Type1Font*)font
{
    return [[[Type1Font allocWithZone:[self zone]] init] autorelease];
}

/* initialize
 */
- init
{
    gridOffset = 150.0; // 150.0;
    afmNoPlace = [[NSArray alloc] initWithObjects:@"Aacute", @"Acircumflex", @"Adieresis", @"Agrave", @"Aring", @"Atilde", @"Ccedilla", @"Eacute", @"Ecircumflex", @"Edieresis", @"Egrave", @"Eth", @"Iacute", @"Icircumflex", @"Idieresis", @"Igrave", @"Ntilde", @"Oacute", @"Ocircumflex", @"Odieresis", @"Ograve", @"Otilde", @"Thorn", @"Uacute", @"Ucircumflex", @"Udieresis", @"Ugrave", @"Yacute", @"aacute", @"acircumflex", @"adieresis", @"agrave", @"aring", @"atilde", @"ccedilla", @"copyright", @"divide", @"eacute", @"ecircumflex", @"edieresis", @"egrave", @"eth", @"iacute", @"icircumflex", @"idieresis", @"igrave", @"logicalnot", @"mu", @"multiply", @"ntilde", @"oacute", @"ocircumflex", @"odieresis", @"ograve", @"onehalf", @"onequarter", @"onesuperior", @"otilde", @"plusminus", @"registered", @"thorn", @"threequarters", @"threesuperior", @"twosuperior", @"uacute", @"ucircumflex", @"udieresis", @"ugrave", @"yacute", @"ydieresis", nil];
    afmNoPlaceCnt = [afmNoPlace count];
    metricsCnt = 0;
    scale = 10.0; // back scale when we save !!
    list = [[NSMutableArray allocWithZone:[self zone]] init];	/* the object list */
    fontName = @"";
    return [super init];
}
- (void)setGridOffset:(float)value		{ gridOffset = value; }
- (float)gridOffset				{ return gridOffset; }

- (Encoding*)standardEncoding	{ return standardEncoding; }
- (int)standardEncodingCnt	{ return StandardEncodingCnt; }
- (Encoding*)isoLatin1Encoding	{ return isoLatin1Encoding; }
- (int)isoLatin1EncodingCnt	{ return IsoLatin1EncodingCnt; }

- (void)setFontName:(NSString*)s	{ [fontName release]; fontName = [s retain]; }
- (NSString*)fontName			{ return fontName; }

- (void)setPaintType:(int)type	{ paintType = type; }
- (int)paintType		{ return paintType; }
- (void)setFontType:(int)type	{ fontType = type; }
- (int)fontType			{ return fontType; }
- (void)setUniqueID:(int)uid	{ uniqueID = uid; }
- (int)uniqueID			{ return uniqueID; }

- (void)setFontMatrix:(float*)fmatrix
{   int i;

    for (i=0; i<6; i++)
        fontMatrix[i] = fmatrix[i];
}
- (float*)fontMatrix		{ return fontMatrix; }

- (void)setFontBBox:(float*)fbbox
{   int i;

    for (i=0; i<4; i++)
        fontBBox[i] = fbbox[i];
}
- (float*)fontBBox		{ return fontBBox; }

- (void)setFontInfo:(NSMutableDictionary*)fiDict
{
    [fontInfo.copyright release];
    fontInfo.copyright = [[fiDict stringForKey:@"copyright"] mutableCopy];
    [fontInfo.version release];
    fontInfo.version = [[fiDict stringForKey:@"version"] mutableCopy];
    [fontInfo.notice release];
    fontInfo.notice = [[fiDict stringForKey:@"notice"] mutableCopy];
    [fontInfo.fullName release];
    fontInfo.fullName = [[fiDict stringForKey:@"fullName"] mutableCopy];
    [fontInfo.familyName release];
    fontInfo.familyName = [[fiDict stringForKey:@"familyName"] mutableCopy];
    [fontInfo.weight release];
    fontInfo.weight = [[fiDict stringForKey:@"weight"] mutableCopy];
    fontInfo.italicAngle = [[fiDict objectForKey:@"italicAngle"] intValue];
    fontInfo.isFixedPitch = [[fiDict objectForKey:@"isFixedPitch"] intValue];
    fontInfo.underlinePosition = [[fiDict objectForKey:@"underlinePosition"] longValue];
    fontInfo.underlineThickness = [[fiDict objectForKey:@"underlineThickness"] longValue];
}
- (NSMutableDictionary*)fontInfo;
{   NSMutableDictionary	*fiDict = [NSMutableDictionary dictionaryWithCapacity:10];

    [fiDict setObject:fontInfo.copyright forKey:@"copyright"];
    [fiDict setObject:fontInfo.version forKey:@"version"];
    [fiDict setObject:fontInfo.notice forKey:@"notice"];
    [fiDict setObject:fontInfo.fullName forKey:@"fullName"];
    [fiDict setObject:fontInfo.familyName forKey:@"familyName"];
    [fiDict setObject:fontInfo.weight forKey:@"weight"];
    [fiDict setObject:[NSNumber numberWithInt:fontInfo.italicAngle] forKey:@"italicAngle"];
    [fiDict setObject:[NSNumber numberWithShort:fontInfo.isFixedPitch] forKey:@"isFixedPitch"];
    [fiDict setObject:[NSNumber numberWithLong:fontInfo.underlinePosition] forKey:@"underlinePosition"];
    [fiDict setObject:[NSNumber numberWithLong:fontInfo.underlineThickness] forKey:@"underlineThickness"];
    return fiDict;
}

- (void)setFontPrivate:(NSMutableDictionary*)pDict;
{
    privateDict.blueFuzz = [[pDict objectForKey:@"blueFuzz"] longValue];
    if ( [pDict objectForKey:@"blueScale"] )
        privateDict.blueScale = [[pDict objectForKey:@"blueScale"] floatValue];
    privateDict.blueShift = [[pDict objectForKey:@"blueShift"] longValue];
    if ( [(NSArray*)[pDict objectForKey:@"blueValues"] count] == 6 )
    {   int	i;

        for (i=0; i<6; i++)
            privateDict.blueValues[i] = [[[pDict objectForKey:@"blueValues"] objectAtIndex:i] floatValue];
    }

    if ( [(NSArray*)[pDict objectForKey:@"minFeature"] count] == 2 )
    {   privateDict.minFeature[0] = [[[pDict objectForKey:@"minFeature"] objectAtIndex:0] floatValue];
        privateDict.minFeature[1] = [[[pDict objectForKey:@"minFeature"] objectAtIndex:1] floatValue];
    }
    privateDict.uniqueID = [[pDict objectForKey:@"uniqueID"] longValue];
    privateDict.source = [[pDict stringForKey:@"source"] mutableCopy];
    privateDict.otherSubrs = [[pDict stringForKey:@"otherSubrs"] mutableCopy];
}
- (NSMutableDictionary*)fontPrivate;
{   int	i;
    NSMutableDictionary	*pDict = [NSMutableDictionary dictionaryWithCapacity:26];
    NSMutableArray	*array = [NSMutableArray arrayWithCapacity:6];
    NSMutableArray	*array2 = [NSMutableArray arrayWithCapacity:2];

    [pDict setObject:[NSNumber numberWithLong:privateDict.blueScale] forKey:@"blueScale"];
    [pDict setObject:[NSNumber numberWithFloat:privateDict.blueFuzz] forKey:@"blueFuzz"];
    [pDict setObject:[NSNumber numberWithLong:privateDict.blueShift] forKey:@"blueShift"];

    for (i=0; i<6; i++)
        [array addObject:[NSNumber numberWithFloat:privateDict.blueValues[i]]];
    [pDict setObject:array forKey:@"blueValues"];

    [array2 addObject:[NSNumber numberWithFloat:privateDict.minFeature[0]]];
    [array2 addObject:[NSNumber numberWithFloat:privateDict.minFeature[1]]];
    [pDict setObject:array2 forKey:@"minFeature"];

    [pDict setObject:[NSNumber numberWithInt:privateDict.uniqueID] forKey:@"uniqueID"];
    [pDict setObject:privateDict.source forKey:@"source"];
    [pDict setObject:privateDict.otherSubrs forKey:@"otherSubrs"];

    return pDict;
}

- (void)setFontPrivateSubrs:(Subrs*)subrs :(int)subrsCnt
{   int	i;


    privateDict.subrsCnt = subrsCnt;
    if ( !(privateDict.subrs = malloc(privateDict.subrsCnt*sizeof(Subrs))) )
    {	printf("Font Import, /PrivateSubrs: Out of Memory\n");
        return;
    }
    for (i=0; i<subrsCnt; i++)
    {
        if ( !(privateDict.subrs[i].proc = malloc((subrs[i].length+4)*sizeof(UBYTE))) )
        {   printf("Font Import, /PrivateSubrs: Out of Memory\n");
            return;
        }
        memcpy(privateDict.subrs[i].proc+4, subrs[i].proc, subrs[i].length);
        privateDict.subrs[i].length = subrs[i].length + 4;
        privateDict.subrs[i].proc = encryptCharString(privateDict.subrs[i].proc, privateDict.subrs[i].length);
    }
}
- (int)fontPrivateSubrs:(Subrs**)subrs
{   int	i;

    if ( !(*subrs = malloc(privateDict.subrsCnt*sizeof(Subrs))) )
    {	printf("Font Import, subrs: Out of Memory\n");
        return 0;
    }
    for (i=0; i<privateDict.subrsCnt; i++)
    {
        (*subrs)[i].length = privateDict.subrs[i].length;
        if ( !((*subrs)[i].proc = malloc((privateDict.subrs[i].length)*sizeof(UBYTE))) )
        {   printf("Font Import, subrs: Out of Memory\n");
            return 0;
        }
        memcpy((*subrs)[i].proc, privateDict.subrs[i].proc, privateDict.subrs[i].length);
    }
    return privateDict.subrsCnt;
}

- (void)setFontEncoding:(Encoding*)en :(int)enCnt
{   int	i;

    encodingCnt = enCnt;
    if (!(encoding = malloc(encodingCnt*sizeof(Encoding))))
    {	printf("Font Import, /Encoding: Out of Memory\n");
        return;
    }
    for (i=0; i<encodingCnt; i++)
    {
        encoding[i].index = en[i].index;
        strcpy(encoding[i].name, en[i].name);
    }
}
- (int)fontEncoding:(Encoding**)en
{   int	i;

    if (!(*en = malloc(encodingCnt*sizeof(Encoding))))
    {	printf("Font Import, encoding: Out of Memory\n");
        return 0;
    }
    for (i=0; i<encodingCnt; i++)
    {
        (*en)[i].index = encoding[i].index;
        strcpy((*en)[i].name, encoding[i].name);
    }
    return encodingCnt;
}
- (void)setFontCharStrings:(CharStrings*)chStrs :(int)chCnt
{   int	i;

    charStringCnt = chCnt;
    for (i=0; i<charStringCnt; i++)
    {
        strcpy(charStrings[i].name, chStrs[i].name);
        charStrings[i].length = chStrs[i].length;
        if ( !(charStrings[i].code = malloc(chStrs[i].length*sizeof(UBYTE))) )
        {   printf("Font Import, /CharStrings: Out of Memory\n");
            return;
        }
        memcpy(charStrings[i].code, chStrs[i].code, chStrs[i].length);
        //charStrings[i].code[chStrs[i].length] = 0;
    }
}
- (int)fontCharStrings:(CharStrings**)chStrs
{   int	i;

    if ( !(*chStrs = malloc(256*sizeof(CharStrings))) )
    {	printf("Font Import, CharStrings: Out of Memory\n");
        return 0;
    }
    for (i=0; i<charStringCnt; i++)
    {
        strcpy((*chStrs)[i].name, charStrings[i].name);
        (*chStrs)[i].length = charStrings[i].length;
        if ( !((*chStrs)[i].code = malloc(charStrings[i].length*sizeof(UBYTE))) )
        {   printf("Font Import, charStrings: Out of Memory\n");
            return 0;
        }
        memcpy((*chStrs)[i].code, charStrings[i].code, charStrings[i].length);
        //chStrs[i].code[charStrings[i].length] = 0;
    }
    return charStringCnt;
}

- (int)fontMetrics:(Metrics**)met
{   int	i;

    if ( !(*met = malloc(metricsCnt*sizeof(Metrics))) )
    {	printf("Font Import, Metrics: Out of Memory\n");
        return 0;
    }
    for (i=0; i<metricsCnt; i++)
    {
        (*met)[i].name = [NSString stringWithString:metrics[i].name];
        (*met)[i].index = metrics[i].index;
        (*met)[i].width = metrics[i].width;
        (*met)[i].bbox[0] = metrics[i].bbox[0];
        (*met)[i].bbox[1] = metrics[i].bbox[1];
        (*met)[i].bbox[2] = metrics[i].bbox[2];
        (*met)[i].bbox[3] = metrics[i].bbox[3];
    }
    return metricsCnt;
}
- (float)capHeight	{   return capHeight; }
- (float)xHeight	{   return xHeight; }
- (float)descender	{   return descender; }

-(void)setFontList:(NSMutableArray*)aList
{
    [list release];
    list = [aList retain];
}
-(NSMutableArray*)fontList
{
    return list;
}

-(int)nameInAfmNoPlaceArray:(NSString*)name
{   int	i;

    for (i=0; i<afmNoPlaceCnt; i++)
        if ( [name isEqual:[afmNoPlace objectAtIndex:i]] )
            return YES;
    return NO;
}

typedef struct _MetricsState
{
    NSPoint	origin;
    NSPoint	ll;
    NSPoint	ur;
    float	width;
}MetricsState;

- (void)setCharMetricsFromList:(NSArray*)alist inRect:(NSRect)gridRect :(MetricsState*)met
{   float	xVals[100] = {0.0};
    int		xCnt, i, cnt;

    cnt = [alist count];
    for (i=0, xCnt=0; i<cnt; i++)
    {   id	obj = [alist objectAtIndex:i];

        if ( [obj isKindOfClass:[VPath class]] && NSContainsRect(gridRect, [obj bounds]) )
            [self setCharMetricsFromList:[obj list] inRect:gridRect :met];
        else if ( NSContainsRect(gridRect, [obj bounds]) ) // graphic inside grid cell
        {
            if (![[[obj color] colorSpaceName] isEqual:NSCalibratedRGBColorSpace])
                [obj setColor:[[obj color] colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"]];
            if (![[obj color] redComponent] && [[obj color] greenComponent] )	// sidebearing, width
            {
                switch (xCnt)
                {
                    case 0:
                        xVals[xCnt] = [(VLine*)obj pointWithNum:0].x;
                        xCnt++;
                        break;
                    case 1:
                        xVals[xCnt] = [(VLine*)obj pointWithNum:0].x;
                        met->origin.x = ((xVals[0] < xVals[1]) ? xVals[0] : xVals[1]);
                        met->origin.y = gridRect.origin.y + gridOffset*0.25;
                        met->width = Diff(xVals[0], xVals[1]);
                }
            }
            else if (![[obj color] redComponent] && ![[obj color] greenComponent] && ![[obj color] blueComponent])
            {   NSRect	bounds = [obj bounds];

                if (met->ll.x > bounds.origin.x) met->ll.x =  bounds.origin.x;
                if (met->ll.y > bounds.origin.y) met->ll.y =  bounds.origin.y;
                if (met->ur.x < bounds.origin.x+bounds.size.width) met->ur.x =  bounds.origin.x+bounds.size.width;
                if (met->ur.y < bounds.origin.y+bounds.size.height) met->ur.y =  bounds.origin.y+bounds.size.height;
            }
        }
    }
}

- (void)updateFontMetrics
{   MetricsState	met;
    int			i, m;
    float		fbox[4];

    capHeight = 0.0;
    xHeight = 0.0;
    descender = 0.0;
    //ascender = 0.0;
    fbox[0] = fbox[1] = 10000; fbox[2] = fbox[3] = 0.0;
    // malloc metrics
    if ( metricsCnt ) free(metrics);
    metricsCnt = encodingCnt-1;
    metrics = malloc(metricsCnt*sizeof(Metrics));

    for (m=0, i=1; i<encodingCnt; i++, m++)
    {   NSRect	gridRect;

        gridRect.origin.x = /*gridOffset +*/ (encoding[i].index/16+1) * gridOffset;  // start one right
        gridRect.origin.y = gridOffset*0.5 + (15-(encoding[i].index%16)) * gridOffset;
        gridRect.size.width = gridRect.size.height = gridOffset;

        met.ll.x = met.ll.y = 10000.0;
        met.ur.x = met.ur.y = 0.0;

        metrics[m].index = encoding[i].index; // need decimal !!!
        metrics[m].name = [NSString stringWithFormat:@"%s", encoding[i].name];
        if ( [self nameInAfmNoPlaceArray:metrics[m].name] )
            metrics[m].index = -1;

        [self setCharMetricsFromList:list inRect:gridRect :&met];
        metrics[m].width = met.width*scale;
        if ( met.ll.x != 10000 ) // strcmp(encoding[i].name, "space")
        {   metrics[m].bbox[0] = (met.ll.x - met.origin.x)*scale; // ll of char relativ to origin
            metrics[m].bbox[1] = (met.ll.y - met.origin.y)*scale;
            metrics[m].bbox[2] = (met.ur.x - met.origin.x)*scale; // ur of char relativ to origin
            metrics[m].bbox[3] = (met.ur.y - met.origin.y)*scale;
            // fontBBox
            if ( metrics[m].bbox[0] < fbox[0] ) fbox[0] = metrics[m].bbox[0]; // ll.x
            if ( metrics[m].bbox[1] < fbox[1] ) fbox[1] = metrics[m].bbox[1]; // ll.y
            if ( metrics[m].bbox[2] > fbox[2] ) fbox[2] = metrics[m].bbox[2]; // ur.x
            if ( metrics[m].bbox[3] > fbox[3] ) fbox[3] = metrics[m].bbox[3]; // ur.y

            if ( metrics[m].index >= 0101 && metrics[m].index <= 0132 ) // A - Z
            {   if ( capHeight < metrics[m].bbox[3] )
                    capHeight = metrics[m].bbox[3];
                if ( descender > metrics[m].bbox[1] )
                    descender = metrics[m].bbox[1];
            }
            if ( metrics[m].index >= 0141 && metrics[m].index <= 0172 ) // a - z
            {   if ( xHeight < metrics[m].bbox[3] )
                    xHeight = metrics[m].bbox[3];
                if ( descender > metrics[m].bbox[1] )
                    descender = metrics[m].bbox[1];
            }
            //if ( ascender < metrics[m].bbox[3] )
            //    ascender = metrics[m].bbox[3];
        }
        else if ( !strcmp(encoding[i].name, "space") )
        {   metrics[m].bbox[0] = metrics[m].bbox[1] = metrics[m].bbox[2] = metrics[m].bbox[3] = 0.0; }
        else
        {   metricsCnt--;
            m--; // not in font ! ! !
        }
    }
    [self setFontBBox:fbox];
    // sort metrics
    for (i=0; i<metricsCnt; i++)
    {   int	changed = 0;

        for (m=i+1; m<metricsCnt; m++)
        {
            if ( (metrics[m].index != -1 && metrics[i].index != -1 && metrics[m].index < metrics[i].index) ||
                (metrics[m].index == -1 && metrics[i].index == -1 &&
                 NSOrderedAscending == [metrics[m].name compare:metrics[i].name]) ||
                (metrics[i].index == -1 && metrics[m].index != -1) )
            {   Metrics	buf; // i becomes m and vice versa

                buf.index = metrics[i].index;
                buf.name = [NSString stringWithString:metrics[i].name];
                buf.width = metrics[i].width;
                buf.bbox[0] = metrics[i].bbox[0]; buf.bbox[1] = metrics[i].bbox[1];
                buf.bbox[2] = metrics[i].bbox[2]; buf.bbox[3] = metrics[i].bbox[3];

                metrics[i].index = metrics[m].index;
                metrics[i].name = [NSString stringWithString:metrics[m].name];
                metrics[i].width = metrics[m].width;
                metrics[i].bbox[0] = metrics[m].bbox[0]; metrics[i].bbox[1] = metrics[m].bbox[1];
                metrics[i].bbox[2] = metrics[m].bbox[2]; metrics[i].bbox[3] = metrics[m].bbox[3];

                metrics[m].index = buf.index;
                metrics[m].name = [NSString stringWithString:buf.name];
                metrics[m].width = buf.width;
                metrics[m].bbox[0] = buf.bbox[0]; metrics[m].bbox[1] = buf.bbox[1];
                metrics[m].bbox[2] = buf.bbox[2]; metrics[m].bbox[3] = buf.bbox[3];

                changed++;
                break;
            }
        }
        if ( changed )
            i--;
    }
}

//int	nocurrentpoint;		// moved to interface !
//char	*code;
//NSPoint	curPoint;
/* update font from Cenon document
 */
- (void)update
{   int		i;

    // set char metric
    [self updateFontMetrics];

    //[self setFontInfo];

    code = malloc(8192l);	// FIXME: shouldn't this be freed before ???
    for (i=0, charStringCnt=0; i<encodingCnt;i++)
    {
        curPoint = (NSPoint){0.0, 0.0};
//if ( !strcmp(encoding[i].name, "hyphen") )
//    printf("stop");
        if ([self getCharStringFromList:charStrings+charStringCnt name:encoding[i].name index:encoding[i].index list:list])
            charStringCnt++;
    }

    /* update dicts, write font dict, writefontinfo */
    paintType = 0;	/* 0 fill, 2 stroke */
    privateDict.uniqueID = uniqueID;
    privateDict.source = @"vhf";
    fontInfo.copyright = [NSString stringWithFormat:@"%s", COPYRIGHT];
//	fontInfo.fullName = fontName;
//	fontInfo.familyName = fontName;
    fontInfo.version = @"002.000";
    /* no overshoot positions */
    privateDict.blueValues[0] = privateDict.blueValues[1];
    privateDict.blueValues[3] = privateDict.blueValues[2];
    privateDict.blueValues[5] = privateDict.blueValues[4];

    /* subrs */
     /* done in setFontPrivateSubrs */
#if 0
    for (i=0; i<privateDict.subrsCnt; i++)
    {	unsigned char	*up = privateDict.subrs[i].proc;
        privateDict.subrs[i].proc = malloc(privateDict.subrs[i].length+5);
        memcpy(privateDict.subrs[i].proc+4, up, privateDict.subrs[i].length);
        privateDict.subrs[i].length += 4;
        free(up);
        privateDict.subrs[i].proc = encryptCharString(privateDict.subrs[i].proc, privateDict.subrs[i].length);
    }
#endif
}

typedef struct _FontState
{
    NSRect	gridRect;
    float	width;		/* char width */
    NSPoint	origin;		/* the lower left point of the grid cell */
    float	leftPoint;	/* the most left point of the char */
    NSPoint	scale;
}FontState;

void getFontState(NSArray *alist, FontState *fontState, float gridOffset)
{   float	xVals[100] = {0.0};
    int		xCnt, i, cnt;

    cnt = [alist count];
    for (i=0, xCnt=0; i<cnt; i++)
    {   id	obj = [alist objectAtIndex:i];

        if ( [obj isKindOfClass:[VPath class]] && NSContainsRect(fontState->gridRect, [obj bounds]) )
            getFontState([obj list], fontState, gridOffset);
        else if ( NSContainsRect(fontState->gridRect, [obj bounds]) ) // graphic inside grid cell
        {
            if (![[obj color] redComponent] && [[obj color] greenComponent] )	// sidebearing, width
            {
                switch (xCnt)
                {
                    case 0:
                        xVals[xCnt] = floor([(VLine*)obj pointWithNum:0].x*fontState->scale.x);
                        xCnt++;
                        break;
                    case 1:
                        xVals[xCnt] = floor([(VLine*)obj pointWithNum:0].x*fontState->scale.x);
                        fontState->origin.x = ((xVals[0] < xVals[1]) ? xVals[0] : xVals[1]);
                        fontState->origin.y = floor((fontState->gridRect.origin.y + gridOffset*0.25)*fontState->scale.x);
                        fontState->width = Diff(xVals[0], xVals[1]); // * fontState->scale.x;
                }
            }
            else if ( ![[obj color] redComponent] && ![[obj color] greenComponent] && ![[obj color] blueComponent] )
            {   NSRect	bounds = [obj bounds];

                if ( fontState->leftPoint > floor(bounds.origin.x * fontState->scale.x) )
                    fontState->leftPoint =  floor(bounds.origin.x * fontState->scale.x);
            }
        }
    }

    /* space or other empty character cell */
    if (fontState->leftPoint == MAXCOORD)
        fontState->leftPoint = fontState->origin.x;
}

/* FIXME: these should be interface variables !
 *        we have to pass them as parameters for functions
 */
static FontState	fontState;
static int		vStems[40], hStems[40];
static int		vCnt, hCnt;

//- (int)getCharFromList:(NSArray*)alist :(FontState*)fontState :(unsigned char*)code :(int*)vCnt :(int*)hCnt
int getCharFromList(id self, NSArray *alist, FontState *fontState, unsigned char *code)
{   int	i, codeLen = 0, cnt = [alist count];

    for (i=0; i<cnt; i++)
    {	id	obj = [alist objectAtIndex:i];

        if ( [obj isKindOfClass:[VPath class]] && NSContainsRect(fontState->gridRect, [obj bounds]) )
            codeLen += getCharFromList(self, [(VPath*)obj list], fontState, code+codeLen);
            //codeLen += [self getCharFromList:[(VPath*)obj list] :fontState :code :vCnt :hCnt];
        else if ( NSContainsRect(fontState->gridRect, [obj bounds]) )	/* graphic inside grid cell */
        {

            if ([[obj color] redComponent] && [[obj color] greenComponent] && [obj isKindOfClass:[VLine class]]) /* stems */
            {   NSPoint	s, e;
                [(VLine*)obj getVertices:&s :&e];
                s.x = (s.x * fontState->scale.x);
                s.x = (((s.x) - (int)(s.x)) > 0.7501) ? floor(s.x+1.0) : floor(s.x);
                s.y = (s.y * fontState->scale.y);
                s.y = (((s.y) - (int)(s.y)) > 0.7501) ? floor(s.y+1.0) : floor(s.y);
                e.x = (e.x * fontState->scale.x);
                e.x = (((e.x) - (int)(e.x)) > 0.7501) ? floor(e.x+1.0) : floor(e.x);
                e.y = (e.y * fontState->scale.y);
                e.y = (((e.y) - (int)(e.y)) > 0.7501) ? floor(e.y+1.0) : floor(e.y);
//                s.x = floor(s.x*fontState->scale.x); s.y = floor(s.y*fontState->scale.y);
//                e.x = floor(e.x*fontState->scale.x); e.y = floor(e.y*fontState->scale.y);
                if ((Diff(s.x, e.x) <= 1.0) && vCnt<39)	/* vertical line */
                    vStems[vCnt++] = (s.x - fontState->leftPoint); // * fontState->scale.x;
                else if ((Diff(s.y, e.y) <= 1.0) && hCnt<39)
                    hStems[hCnt++] = (s.y - fontState->origin.y); // * fontState->scale.y;
            }
            else if ( ![[obj color] redComponent] && ![[obj color] greenComponent] && ![[obj color] blueComponent] )// char
                codeLen += [self setGraphic:obj :code+codeLen];
        }
    }
    return codeLen;
}

- (BOOL)getCharStringFromList:(CharStrings*)charString name:(const char*)name index:(int)index list:(NSArray*)alist
{   int		codeLen = 0;
    //int		vCnt, hCnt;
//int		vStems[40], hStems[40];

    fontState.scale.x = fontState.scale.y = 10.0; // 1/0.01 - Fix - ist nicht zu aendern

//if ( !strcmp(name, "a") || !strcmp(name, "P") )
//    printf("stop");

    /* name */
    strcpy(charString->name, name);

    /* charstring */
    fontState.gridRect.origin.x = /*gridOffset +*/ (index/16+1) * gridOffset;  // start one right
    fontState.gridRect.origin.y = gridOffset*0.5 + (15-(index%16)) * gridOffset;
    fontState.gridRect.size.width = fontState.gridRect.size.height = gridOffset;

    fontState.leftPoint = MAXCOORD;
    fontState.width = 0;
    getFontState(alist, &fontState, gridOffset);

    if (!fontState.width)
        return 0;

//	codeLen = 0;
    curPoint.x = fontState.leftPoint;
    curPoint.y = fontState.origin.y;
    nocurrentpoint = 1;
    vCnt = hCnt = 0;

    codeLen = getCharFromList(self, alist, &fontState, code);

    charString->code = malloc(codeLen+vCnt*5+hCnt*5+100);
    charString->length = 4;	// space for random bytes
    charString->length += [self setSidebearing:(fontState.leftPoint-fontState.origin.x)
                                         width:fontState.width :charString->code+charString->length];
    charString->length += [self setVStems:vStems :vCnt :charString->code+charString->length];
    charString->length += [self setHStems:hStems :hCnt :charString->code+charString->length];
    memcpy(charString->code+charString->length, code, codeLen);
    charString->length += codeLen;
    if (codeLen)
        charString->code[charString->length++] = 9;	// closepath
    charString->code[charString->length++] = 14;	// endchar

    charString->code = encryptCharString(charString->code, charString->length);

    return YES;
}

- (int)setSidebearing:(int)sbx width:(int)wx :(unsigned char*)charCode
{   int	len;

    /* sbx wx hsbw (13) */
    len = encodeNumber(sbx, charCode);
    len += encodeNumber(wx, charCode+len);
    charCode[len] = 13;
    len++;

    return len;
}

- (int)setVStems:(int*)vStems :(int)vCnt :(unsigned char*)charCode
{   int	i, j, len=0;

    for (i=0; i<vCnt-1; i++)
    {
        for (j=i; j<vCnt; j++)
        {   if (vStems[j] < vStems[i])
            {	int	b = vStems[i];
                vStems[i] = vStems[j];
                vStems[j] = b;
            }
        }
    }
    for (i=0; i<vCnt-1; i+=2)
    {	int	x, dx;

        x = vStems[i];
        dx = vStems[i+1] - vStems[i];
        if (!dx)
        {   i--;
            continue;
        }
        len += encodeNumber(x, charCode+len);
        len += encodeNumber(dx, charCode+len);
        charCode[len++] = 3;
    }

    return len;
}

- (int)setHStems:(int*)hStems :(int)hCnt :(unsigned char*)charCode
{   int	i, j, len=0;

    for (i=0; i<hCnt-1; i++)
    {
        for (j=i; j<hCnt; j++)
        {   if (hStems[j] < hStems[i])
            {	int	b = hStems[i];
                hStems[i] = hStems[j];
                hStems[j] = b;
            }
        }
    }
    for (i=0; i<hCnt-1; i+=2)
    {	int	y, dy;

        y = hStems[i];
        dy = hStems[i+1] - hStems[i];
        if (!dy)
        {   i--;
            continue;
        }
        len += encodeNumber(y, charCode+len);
        len += encodeNumber(dy, charCode+len);
        charCode[len++] = 1;
    }

    return len;
}

- (int)setGraphic:(id)obj :(unsigned char*)charCode
{   int		len = 0;
    int		dx, dy;

    if ( [obj isKindOfClass:[VLine class]] )
    {   NSPoint	s, e;

        [(VLine*)obj getVertices:&s :&e];
        if ( Diff(s.x, e.x) < 0.05 && Diff(s.y, e.y) < 0.05 )
            return 0; // we do not add this short line
        s.x = (s.x * fontState.scale.x);
        s.x = (((s.x) - (int)(s.x)) > 0.7501) ? floor(s.x+1.0) : floor(s.x);
        s.y = (s.y * fontState.scale.y);
        s.y = (((s.y) - (int)(s.y)) > 0.7501) ? floor(s.y+1.0) : floor(s.y);
        e.x = (e.x * fontState.scale.x);
        e.x = (((e.x) - (int)(e.x)) > 0.7501) ? floor(e.x+1.0) : floor(e.x);
        e.y = (e.y * fontState.scale.y);
        e.y = (((e.y) - (int)(e.y)) > 0.7501) ? floor(e.y+1.0) : floor(e.y);
/*
        s.x = floor(s.x * fontState.scale.x); s.y = floor(s.y * fontState.scale.y);
        e.x = floor(e.x * fontState.scale.x); e.y = floor(e.y * fontState.scale.y);
*/
        if ( Diff(s.x, curPoint.x) > 1.0 || Diff(s.y, curPoint.y) > 1.0 || nocurrentpoint) // 0.01 1.0
        {
            //if (!nocurrentpoint)
            //     code[len++] = 9; /* closepath */
            /* dx dy rmoveto (21) */
            dx = (s.x - curPoint.x); // * fontState.scale.x;
            dy = (s.y - curPoint.y); // * fontState.scale.y;
            len = encodeNumber(dx, charCode);
            len += encodeNumber(dy, charCode+len);
            charCode[len++] = 21;
            nocurrentpoint = 0;
        }
        if ( Diff(s.x, curPoint.x) <= 1.0 && Diff(s.y, curPoint.y) <= 1.0
             && (s.x != curPoint.x || s.y != curPoint.y) )
        {   dx = (e.x - curPoint.x); // else our deltas are wrong
            dy = (e.y - curPoint.y);
        }
        else
        {   /* dx dy rlineto (5) */
            dx = (e.x - s.x); // * fontState.scale.x;
            dy = (e.y - s.y); // * fontState.scale.y;
        }
        len += encodeNumber(dx, charCode+len);
        len += encodeNumber(dy, charCode+len);
        charCode[len++] = 5;
        curPoint = e;
    }
    else if ( [obj isKindOfClass:[VCurve class]] )
    {   NSPoint	p0, p1, p2, p3;

        [(VCurve*)obj getVertices:&p0 :&p1 :&p2 :&p3];
        p0.x = (p0.x * fontState.scale.x);
        p0.x = (((p0.x) - (int)(p0.x)) > 0.7501) ? floor(p0.x+1.0) : floor(p0.x);
        p0.y = (p0.y * fontState.scale.y);
        p0.y = (((p0.y) - (int)(p0.y)) > 0.7501) ? floor(p0.y+1.0) : floor(p0.y);
        p1.x = (p1.x * fontState.scale.x);
        p1.x = (((p1.x) - (int)(p1.x)) > 0.7501) ? floor(p1.x+1.0) : floor(p1.x);
        p1.y = (p1.y * fontState.scale.y);
        p1.y = (((p1.y) - (int)(p1.y)) > 0.7501) ? floor(p1.y+1.0) : floor(p1.y);
        p2.x = (p2.x * fontState.scale.x);
        p2.x = (((p2.x) - (int)(p2.x)) > 0.7501) ? floor(p2.x+1.0) : floor(p2.x);
        p2.y = (p2.y * fontState.scale.y);
        p2.y = (((p2.y) - (int)(p2.y)) > 0.7501) ? floor(p2.y+1.0) : floor(p2.y);
        p3.x = (p3.x * fontState.scale.x);
        p3.x = (((p3.x) - (int)(p3.x)) > 0.7501) ? floor(p3.x+1.0) : floor(p3.x);
        p3.y = (p3.y * fontState.scale.y);
        p3.y = (((p3.y) - (int)(p3.y)) > 0.7501) ? floor(p3.y+1.0) : floor(p3.y);
/*
        p0.x = floor(p0.x * fontState.scale.x); p0.y = floor(p0.y * fontState.scale.y);
        p1.x = floor(p1.x * fontState.scale.x); p1.y = floor(p1.y * fontState.scale.y);
        p2.x = floor(p2.x * fontState.scale.x); p2.y = floor(p2.y * fontState.scale.y);
        p3.x = floor(p3.x * fontState.scale.x); p3.y = floor(p3.y * fontState.scale.y);
*/
        if ( Diff(p0.x, curPoint.x) > 1.0 || Diff(p0.y, curPoint.y) > 1.0 || nocurrentpoint) // 0.01 1.0
        {
            /* dx dy rmoveto (21) */
            dx = (p0.x - curPoint.x); //  * fontState.scale.x;
            dy = (p0.y - curPoint.y); //  * fontState.scale.y;
            len = encodeNumber(dx, charCode);
            len += encodeNumber(dy, charCode+len);
            charCode[len++] = 21;
            nocurrentpoint = 0;
        }

        if ( Diff(p0.x, curPoint.x) <= 1.0 && Diff(p0.y, curPoint.y) <= 1.0
             && (p0.x != curPoint.x || p0.y != curPoint.y) )
        {   dx = (p1.x - curPoint.x); // else our deltas are wrong
            dy = (p1.y - curPoint.y);
        }
        else
        {   /* dx1 dy1 dx2 dy2 dx3 dy3 rrcurveto (8) */
            dx = (p1.x - p0.x); // * fontState.scale.x;
            dy = (p1.y - p0.y); // * fontState.scale.y;
        }
        len += encodeNumber(dx, charCode+len);
        len += encodeNumber(dy, charCode+len);
        dx = (p2.x - p1.x); // * fontState.scale.x;
        dy = (p2.y - p1.y); // * fontState.scale.y;
        len += encodeNumber(dx, charCode+len);
        len += encodeNumber(dy, charCode+len);
        dx = (p3.x - p2.x); // * fontState.scale.x;
        dy = (p3.y - p2.y); // * fontState.scale.y;
        len += encodeNumber(dx, charCode+len);
        len += encodeNumber(dy, charCode+len);
        charCode[len++] = 8;
        curPoint = p3;
    }
    return len;
}

/* fileName = "PATH/FILENAME.font" (font directory)
 */
- (BOOL)writeToFile:(NSString*)filename
{   BOOL            savedOk = NO;
    NSString		*afmfilename = nil;
    NSString		*backupFilename = [filename stringByAppendingString:@"~"];
    NSString		*fileDirectory = nil;
    NSFileManager   *fileManager = [NSFileManager defaultManager];
    BOOL            isDirectory = YES;

//encoding = [self standardEncoding];
//encodingCnt = [self standardEncodingCnt];

    //backupFilename = [[[filename stringByDeletingPathExtension] stringByAppendingString:@"~"] stringByAppendingPathExtension:FONT_EXT];
    /* file not writable */
    if ( [fileManager fileExistsAtPath:filename] && ![fileManager isWritableFileAtPath:filename] )
    {   NSRunAlertPanel(SAVE_TITLE, CANT_CREATE_BACKUP, nil, nil, nil);
        return NO;
    }
    /* rename to backup */
    if ( ([fileManager fileExistsAtPath:backupFilename] && ![fileManager removeFileAtPath:backupFilename handler:nil]) || ([fileManager fileExistsAtPath:filename] && ![fileManager movePath:filename toPath:backupFilename handler:nil]) )
    {   NSRunAlertPanel(SAVE_TITLE, CANT_CREATE_BACKUP, nil, nil, nil);
        return NO;
    }
    /* create file directory */
    else if ( isDirectory && [fileManager createDirectoryAtPath:filename attributes:nil] )
    {
        fileDirectory = filename;
        filename = [fileDirectory stringByAppendingPathComponent:[[filename stringByDeletingPathExtension] lastPathComponent]];
        afmfilename = [fileDirectory stringByAppendingPathComponent:[[[filename stringByDeletingPathExtension] lastPathComponent] stringByAppendingPathExtension:AFM_EXT]];
    }

    /* save */
    if ([fileManager isWritableFileAtPath:fileDirectory])
    {   NSString		*fontStr, *eexecStr, *afmStr;
        int			i, len=0;

        fontStr = [NSString stringWithFormat:@"%%!FontType1-1.0: %@ %@\n", fontName, fontInfo.version];

        fontStr = [fontStr stringByAppendingFormat:@"%%%%CreationDate: %@\n", [[NSCalendarDate date] descriptionWithCalendarFormat:@"%a %b %d %H:%M:%S %Y"]];
	fontStr = [fontStr stringByAppendingFormat:@"%%%%VMusage: %d %d\n", 27647, 34029];
	fontStr = [fontStr stringByAppendingFormat:@"%%%@\n", fontInfo.copyright];

	/* font dict */
	fontStr = [fontStr stringByAppendingFormat:@"14 dict begin\n"];
	/* fontInfo dict */
	fontStr = [fontStr stringByAppendingFormat:@"/FontInfo 10 dict dup begin\n"];
	fontStr = [fontStr stringByAppendingFormat:@"/version (%@) readonly def\n", fontInfo.version];
	fontStr = [fontStr stringByAppendingFormat:@"/Notice (%s) readonly def\n", COPYRIGHT];
	fontStr = [fontStr stringByAppendingFormat:@"/FullName (%@) readonly def\n", fontInfo.fullName];
	fontStr = [fontStr stringByAppendingFormat:@"/FamilyName (%@) readonly def\n", fontInfo.familyName];
	fontStr = [fontStr stringByAppendingFormat:@"/Weight (%@) readonly def\n", fontInfo.weight];
	fontStr = [fontStr stringByAppendingFormat:@"/ItalicAngle %d def\n", 0];
	fontStr = [fontStr stringByAppendingFormat:@"/isFixedPitch %s def\n", (fontInfo.isFixedPitch)? "true" : "false"];
	fontStr = [fontStr stringByAppendingFormat:@"/UnderlinePosition %d def\n", fontInfo.underlinePosition];
	fontStr = [fontStr stringByAppendingFormat:@"/UnderlineThickness %d def\n", fontInfo.underlineThickness];
	fontStr = [fontStr stringByAppendingFormat:@"end readonly def\n"];
	/* font dict */
	fontStr = [fontStr stringByAppendingFormat:@"/FontName /%@ def\n", fontName];
	fontStr = [fontStr stringByAppendingFormat:@"/PaintType %d def\n", paintType];
	if (paintType == 2)
		fontStr = [fontStr stringByAppendingFormat:@"/StrokeWidth %d def\n", 10];
	fontStr = [fontStr stringByAppendingFormat:@"/FontType %d def\n", fontType]; // 1 for type1 fonts
//	m = fontMatrix;
	fontStr = [fontStr stringByAppendingFormat:@"/FontMatrix [0.001 0 0 0.001 0 0] readonly def\n"];
//	NXPrintf(stream, "/FontMatrix [%f %f %f %f %f %f] readonly def\n", m[0], m[1], m[2], m[3], m[4], m[5]);

// Encoding !!!
	fontStr = [fontStr stringByAppendingFormat:@"/Encoding StandardEncoding def\n"];
	fontStr = [fontStr stringByAppendingFormat:@"/FontBBox {%.0f %.0f %.0f %.0f} readonly def\n", fontBBox[0], fontBBox[1], fontBBox[2], fontBBox[3]];
	fontStr = [fontStr stringByAppendingFormat:@"/UniqueID %d def\n", uniqueID];
	fontStr = [fontStr stringByAppendingFormat:@"currentdict end\n"];

	/* eexec */
	fontStr = [fontStr stringByAppendingFormat:@"currentfile eexec\n"];

        eexecStr = [NSString stringWithFormat:@"%s", "]|]®"]; /* 4 random bytes */
	eexecStr = [eexecStr stringByAppendingFormat:@"userdict"];
	eexecStr = [eexecStr stringByAppendingFormat:@"/RD{string currentfile exch readstring pop}executeonly put\n"];
	eexecStr = [eexecStr stringByAppendingFormat:@"userdict/ND{noaccess def}executeonly put\n"];
	eexecStr = [eexecStr stringByAppendingFormat:@"userdict/NP{noaccess put}executeonly put\n"];
	eexecStr = [eexecStr stringByAppendingFormat:@"dup/Private 8 dict dup begin\n"];
	eexecStr = [eexecStr stringByAppendingFormat:@"/BlueValues [%.0f %.0f %.0f %.0f %.0f %.0f] noaccess def\n", privateDict.blueValues[0], privateDict.blueValues[1], privateDict.blueValues[2], privateDict.blueValues[3], privateDict.blueValues[4], privateDict.blueValues[5]];
	eexecStr = [eexecStr stringByAppendingFormat:@"/MinFeature{%.0f %.0f}noaccess def\n", privateDict.minFeature[0], privateDict.minFeature[1]];
	eexecStr = [eexecStr stringByAppendingFormat:@"/password 5839 def\n"];
	eexecStr = [eexecStr stringByAppendingFormat:@"/Source (%@) readonly def\n", privateDict.source];
	eexecStr = [eexecStr stringByAppendingFormat:@"/UniqueID %d def\n", uniqueID];
	eexecStr = [eexecStr stringByAppendingFormat:@"/OtherSubrs[{}{}{}\n\
  {  %% coloring subr number on stack\
     systemdict /internaldict known not\n\
       {pop 3} %% return null subr\n\
       { 1183615869 systemdict /internaldict get exec\n\
         dup /startlock known\n\
           {/startlock get exec} %% return new coloring subr\n\
           { dup /strtlck known %% other name for startlock\n\
	      {/strtlck get exec}\n\
              {pop 3} %% return null subr\n\
	      ifelse}\n\
	 ifelse }\n\
       ifelse\n\
  } executeonly\n\
]noaccess def\n"];

	/* subrs */
        eexecStr = [eexecStr stringByAppendingFormat:@"/Subrs %d array\n", privateDict.subrsCnt];

// done in [fontObhect update]
#if 0
	/* subrs */
	for (i=0; i<privateDict.subrsCnt; i++)
	{   unsigned char	*up = subrs[i].proc;
            subrs[i].proc = malloc(subrs[i].length+5);
            memcpy(subrs[i].proc+4, up, subrs[i].length);
            subrs[i].length += 4;
            free(up);
            subrs[i].proc = encryptCharString(subrs[i].proc, subrs[i].length);
	}
#endif
	//for (i=0; i<subrsCnt; i++)
	for (i=0; i<privateDict.subrsCnt; i++)
	{   NSString	*str = [NSString stringWithCString:(char*)privateDict.subrs[i].proc
                                                length:privateDict.subrs[i].length];

            eexecStr = [eexecStr stringByAppendingFormat:@"dup %d %d RD ", i, privateDict.subrs[i].length];
            eexecStr = [eexecStr stringByAppendingString:str];
            eexecStr = [eexecStr stringByAppendingFormat:@" NP\n"];
	}
	eexecStr = [eexecStr stringByAppendingFormat:@"noaccess def\n", 0];
	eexecStr = [eexecStr stringByAppendingFormat:@"end noaccess put\n", 0];

	/* char strings */
	eexecStr = [eexecStr stringByAppendingFormat:@"dup /CharStrings %d dict dup begin\n", charStringCnt];

// done in [fontObhect update]
#if 0
	/* char strings */
	for (i=0; i<charStringCnt; i++)
        {   unsigned char	*up = charStrings[i].code;
            charStrings[i].code = malloc(charStrings[i].length+5);
            memcpy(charStrings[i].code+4, up, charStrings[i].length);
            charStrings[i].length += 4;
            free(up);
            charStrings[i].code = encryptCharString(charStrings[i].code, charStrings[i].length);
        }
#endif
	for (i=0; i<charStringCnt; i++)	/* georg */
	{   NSString    *str=[NSString stringWithCString:(char*)charStrings[i].code
                                              length:charStrings[i].length];

            eexecStr = [eexecStr stringByAppendingFormat:@"/%s %d RD ", charStrings[i].name, charStrings[i].length];
            eexecStr = [eexecStr stringByAppendingString:str];
            eexecStr = [eexecStr stringByAppendingFormat:@" ND\n"];
	}
	eexecStr = [eexecStr stringByAppendingFormat:@"end\n"];
	eexecStr = [eexecStr stringByAppendingFormat:@"readonly put\n"];
	eexecStr = [eexecStr stringByAppendingFormat:@"dup/FontName get exch definefont pop\n"];
	eexecStr = [eexecStr stringByAppendingFormat:@"mark currentfile closefile\n"];
#   if 0
        { NSString	*file = [NSString stringWithFormat:@"/Net/nesquick/Users/ilonka/Tempo/Test/testSubrs"];
            [eexecStr writeToFile:file atomically:YES];
        }
#   endif
        // NXGetMemoryBuffer(eexecStream, &buf, &len, &maxlen);
        {   char	*eExecCStr, *buffer;

            len = [eexecStr length]; // +1 -> 0
            buffer = malloc(len+1);
            [eexecStr getCString:buffer];
            eExecCStr = (char*)encryptEexec((unsigned char*)buffer, len);
            fontStr = [fontStr stringByAppendingString:[NSString stringWithCString:eExecCStr length:len*2]];
            free(eExecCStr);
            free(buffer);
        }
        // NXWrite(stream, encryptEexec(buf, len), len*2);

        fontStr = [fontStr stringByAppendingFormat:@"\n"];
        for (i=0;i<512;i++)
            fontStr = [fontStr stringByAppendingFormat:@"0"];
        fontStr = [fontStr stringByAppendingFormat:@"\ncleartomark"];

        //savedOk = [fontStr writeToFile:filename atomically:YES];
        savedOk = [fontStr writeToFile:filename atomically:YES
                              encoding:NSUTF8StringEncoding error:NULL];    // >= 10.5

        afmStr = [NSString stringWithFormat:@"StartFontMetrics 2.0\n"];
        afmStr = [afmStr stringByAppendingFormat:@"Comment %s\n", COPYRIGHT];
        afmStr = [afmStr stringByAppendingFormat:@"FontName %@\n", fontName];
        afmStr = [afmStr stringByAppendingFormat:@"EncodingScheme AdobeStandardEncoding\n"];
        afmStr = [afmStr stringByAppendingFormat:@"FullName %@\n", fontInfo.fullName];
        afmStr = [afmStr stringByAppendingFormat:@"FamilyName %@\n", fontInfo.familyName];
        afmStr = [afmStr stringByAppendingFormat:@"Weight %@\n", fontInfo.weight];
        afmStr = [afmStr stringByAppendingFormat:@"ItalicAngle 0.0\n"];
        afmStr = [afmStr stringByAppendingFormat:@"IsFixedPitch %s\n", (fontInfo.isFixedPitch) ? "true" : "false"];
        afmStr = [afmStr stringByAppendingFormat:@"UnderlinePosition %d\n", fontInfo.underlinePosition];
        afmStr = [afmStr stringByAppendingFormat:@"UnderlineThickness %d\n", fontInfo.underlineThickness];
        afmStr = [afmStr stringByAppendingFormat:@"Version %@\n", fontInfo.version];
        afmStr = [afmStr stringByAppendingFormat:@"Notice %s\n", COPYRIGHT];
        afmStr = [afmStr stringByAppendingFormat:@"FontBBox %.0f %.0f %.0f %.0f\n", fontBBox[0], fontBBox[1], fontBBox[2], fontBBox[3]];
        afmStr = [afmStr stringByAppendingFormat:@"CapHeight %.0f\n", capHeight];
        afmStr = [afmStr stringByAppendingFormat:@"XHeight %.0f\n", xHeight];
        afmStr = [afmStr stringByAppendingFormat:@"Descender %.0f\n", descender];
        afmStr = [afmStr stringByAppendingFormat:@"Ascender %.0f\n", capHeight];

        afmStr = [afmStr stringByAppendingFormat:@"StartCharMetrics %d\n", metricsCnt];
        /* metrics */
        for (i=0; i<metricsCnt; i++)
        {
            afmStr = [afmStr stringByAppendingFormat:@"C %d ; WX %.0f ; N %@ ; B %.0f %.0f %.0f %.0f ;\n", metrics[i].index, metrics[i].width, metrics[i].name, metrics[i].bbox[0], metrics[i].bbox[1], metrics[i].bbox[2], metrics[i].bbox[3]];
        }
        afmStr = [afmStr stringByAppendingFormat:@"EndCharMetrics\n"];
        // composites
        afmStr = [afmStr stringByAppendingFormat:@"EndFontMetrics\n"];

        //savedOk = [afmStr writeToFile:afmfilename atomically:YES];
        savedOk = [afmStr writeToFile:afmfilename atomically:YES
                             encoding:NSUTF8StringEncoding error:NULL]; // >= 10.5
    }
    else
        NSRunAlertPanel(SAVE_TITLE, DIR_NOT_WRITABLE, nil, nil, nil);

    /* restore backup */
    if (!savedOk)
    {
        [fileManager removeFileAtPath:fileDirectory handler:nil];	// remove what we just started to write
        [fileManager movePath:backupFilename toPath:fileDirectory handler:nil];	// restore backup
        NSRunAlertPanel(SAVE_TITLE, CANT_SAVE, nil, nil, nil);
    }
    else
    {
        if (Prefs_RemoveBackups)
            [fileManager removeFileAtPath:backupFilename handler:nil];
    }
    return YES;
}

- (void)dealloc
{
//    CharStrings free
    [afmNoPlace release];
    [list release];
    if (code)
        free(code);
    [super dealloc];
}

@end
