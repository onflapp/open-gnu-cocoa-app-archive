/* Type1Font.h
 * Type 1 Font object used for the type 1 import
 *
 * Copyright (C) 1996-2006 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-03-13
 * modified: 2006-02-06 (cleanup)
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

#ifndef VHF_H_TYPE1FONT
#define VHF_H_TYPE1FONT

#include <VHFShared/types.h>
#include "type1Funs.h"

#define MAXCHARNAMELEN	20
#define COPYRIGHT	"Copyright (C) 2006 vhf interservice GmbH.  All rights reserved."

#define FONTTAG_GRID		1
#define FONTTAG_STEM		2
#define FONTTAG_SIDEBEARING	3
#define FONTTAG_FONT		4

typedef struct _Metrics
{
    int		index;
    NSString	*name;
    float	bbox[4];
    float	width;
}Metrics;

typedef struct _T1FontInfo
{
    NSString	*copyright;
    NSString	*version;
    NSString	*notice;
    NSString	*fullName;
    NSString	*familyName;
    NSString	*weight;
    int		italicAngle;
    BOOL	isFixedPitch;
    long	underlinePosition;
    long	underlineThickness;
}T1FontInfo;

typedef struct _Encoding
{
    char	name[MAXCHARNAMELEN];
    int		index;
}Encoding;

typedef struct _Subrs
{
    UBYTE	*proc;
    int		length;
}Subrs;

typedef struct _Private
{
    long	blueFuzz;
    float	blueScale;
    long	blueShift;
    float	blueValues[6];
    //long	familyBlues[];
    //long	familyOtherBlues[];
    BOOL	forceBold;
    long	languageGroup;
    long	lenIV;
    float	minFeature[2];
    UBYTE	nd;
    UBYTE	np;
    //long	otherBlues[];
    //long	otherSubrs[];
    long	password;
    UBYTE	rd;
    BOOL	rndStemUp;
    //long	stdHW[];
    //long	stdVW[];
    //long	stemSnapH[];
    //long	stemSnapV[];
    int		subrsCnt;
    Subrs	*subrs;
    long	uniqueID;
    NSString	*source;
    NSString	*otherSubrs;
}Private;

typedef struct _CharStrings
{
    char	name[MAXCHARNAMELEN];
    UBYTE	*code;
    int		length;
}CharStrings;

@interface Type1Font:NSObject
{
    NSMutableArray*	list;		/* the base list for all contents */
    int			metricsCnt;
    Metrics		*metrics;
    float		scale;
    float		capHeight;
    float		xHeight;
    float		descender;
    NSMutableArray	*afmNoPlace;
    int			afmNoPlaceCnt;
    float		gridOffset;

    T1FontInfo		fontInfo;
    NSString		*fontName;
    int			encodingCnt;
    Encoding		*encoding;
    int			paintType;
    int			fontType;
    float		fontMatrix[6];
    float		fontBBox[4];
    long		uniqueID;
    //metrics;
    int			strokeWidth;
    Private		privateDict;
    int			charStringCnt;
    CharStrings		charStrings[256];
    //FID;

    int			nocurrentpoint;
    unsigned char	*code;
    NSPoint		curPoint;
}

/* class methods */
+ (Type1Font*)font;

/* font methods */
- (Encoding*)standardEncoding;
- (int)standardEncodingCnt;
- (Encoding*)isoLatin1Encoding;
- (int)isoLatin1EncodingCnt;

- (void)setGridOffset:(float)value;
- (float)gridOffset;

- (void)setFontName:(NSString*)s;
- (NSString*)fontName;

- (void)setPaintType:(int)type;
- (int)paintType;
- (void)setFontType:(int)type;
- (int)fontType;
- (void)setUniqueID:(int)uid;
- (int)uniqueID;

- (void)setFontMatrix:(float*)fmatrix;
- (float*)fontMatrix;
- (void)setFontBBox:(float*)fbbox;
- (float*)fontBBox;

- (void)setFontInfo:(NSMutableDictionary*)fiDict;
- (NSMutableDictionary*)fontInfo;
- (void)setFontPrivate:(NSMutableDictionary*)pDict;
- (NSMutableDictionary*)fontPrivate;
- (void)setFontPrivateSubrs:(Subrs*)subrs :(int)subrsCnt;
- (int)fontPrivateSubrs:(Subrs**)subrs;

- (void)setFontEncoding:(Encoding*)en :(int)enCnt;
- (int)fontEncoding:(Encoding**)en;
- (void)setFontCharStrings:(CharStrings*)chStrs :(int)chCnt;
- (int)fontCharStrings:(CharStrings**)chStrs;
- (int)fontMetrics:(Metrics**)met;
- (float)capHeight;
- (float)xHeight;
- (float)descender;

-(void)setFontList:(NSMutableArray*)aList;
-(NSMutableArray*)fontList;

- (void)updateFontMetrics;
- (void)update;

- (BOOL)writeToFile:(NSString*)filename;

@end

#endif // VHF_H_TYPE1FONT
