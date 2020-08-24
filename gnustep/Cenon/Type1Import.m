/* Type1Import.m
 * Type1 import object
 *
 * Copyright (C) 2000-2006 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2000-11-14
 * modified: 2006-02-08
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

#include "Type1Import.h"
#include <VHFShared/types.h>

@interface Type1Import(PrivateMethods)
- (void)createFontGrid;
- (BOOL)interpret:(NSString*)data;
- (BOOL) encodeCharStrings;
- newChar:(char*)name index:(int)index;
- sidebearing:(int)x :(int)y width:(int)w;
- hstem:(int)y :(int)dy;
- vstem:(int)x :(int)dx;
- moveto:(int)x :(int)y;
- lineto:(int)x :(int)y;
- curveto:(int)x1 :(int)y1 :(int)x2 :(int)y2 :(int)x3 :(int)y3;
- closepath;
- (void)updateBounds:(NSPoint)p;
@end

@implementation Type1Import

/* created:   25.01.96
 * modified:  18.09.96 19.06.00
 * parameter: psData	the PostScript stream
 * purpose:   start interpretation of the contents of psData
 */
- importType1:(NSData*)fontData
{
    fontObject = [Type1Font font];
    //fontObject = [self allocateFontObject];
    list = [self allocateList];
    ll.x = ll.y = 10.0;
    ur.x = ur.y = 0.0;

    state.width = 0.0;
    gridOffset = [fontObject gridOffset];
    state.color = [NSColor blackColor];

    /* interpret data
     */
    if ( ![self interpret:[[[NSMutableString alloc] initWithData:fontData
                                                        encoding:NSASCIIStringEncoding] autorelease]] )
        return nil;

    [fontObject setFontList:list];
    [list release];
    return fontObject;
}

/* private methods
 */
typedef struct _Token
{
    char	string[30];
    int		index;
}Token;
#define T_COMMENT				2
#define T_END					3
#define	T_UNIQUEID				4
#define T_FONTINFO				10
#define T_FONTNAME				11
#define T_PAINTTYPE				12
#define	T_FONTTYPE				13
#define	T_FONTMATRIX			14
#define	T_ENCODING				15
#define	T_FONTBBOX				16
Token documentTokens[] = {{"%", 2}, {"/UniqueID", 4}, {"/FontInfo", 10}, {"/FontName", 11}, {"/PaintType", 12}, {"/FontType", 13}, {"/FontMatrix", 14}, {"/Encoding", 15}, {"/FontBBox", 16}, {"", 0}};
#define T_VERSION				10
#define T_NOTICE				11
#define	T_FULLNAME				12
#define	T_FAMILYNAME			13
#define	T_WEIGHT				14
#define	T_ITALICANGLE			15
#define	T_ISFIXEDPITCH			16
#define	T_UNDERLINEPOSITION		17
#define	T_UNDERLINETHICKNESS	18
#define	T_COPYRIGHT				19
Token fontInfoTokens[] = {{"%", 2}, {"end", 3}, {"/version", 10}, {"/Notice", 11}, {"/FullName", 12}, {"/FamilyName", 13}, {"/Weight", 14}, {"/ItalicAngle", 15}, {"/isFixedPitch", 16}, {"/UnderlinePosition", 17}, {"/UnderlineThickness", 18}, {"/Copyright", 19}, {"", 0}};
#define	T_DUP					10
#define	T_DEF					11
Token encodingTokens[] = {{"%", 2}, {"dup", 10}, {"def", 11}, {"", 0}};
#define	T_RD					12
#define	T_ND					13
#define T__X					14
#define T_X_					15
Token subrsTokens[] = {{"%", 2}, {"end", 3}, {"dup", 10}, {"def", 11}, {"RD", 12}, {"ND", 13}, {"-|", 14}, {"|-", 15}, {"", 0}};
#define T_BLUEVALUES			10
#define	T_MINFEATURE			11
#define	T_PASSWORD				12
#define	T_SUBRS					13
#define	T_SOURCE				14
#define	T_OTHERSUBRS			15
#define T_CHARSTRINGS			16
Token privateTokens[] = {{"%", 2}, {"end", 3}, {"/UniqueID", 4}, {"/BlueValues", 10}, {"/MinFeature", 11}, {"password", 12}, {"/Subrs", 13}, {"/Source", 14}, {"/OtherSubrs", 15}, {"/CharStrings", 16}, {"", 0}};
#define	T_CHARSTRING			10
Token charStringsTokens[] = {{"%", 2}, {"end", 3}, {"/", 10}, {"", 0}};

//#define GotoNextData(c)	(c)+=strspn((c)+=strcspn((c), SEPARATORS), SEPARATORS)
static __inline__ char* gotoNextData(char *c)
{
    c += strcspn(c, SEPARATORS);
    c += strspn(c, SEPARATORS);
    return c;
}

// create FontGrid with gridOffset and standardEncoding
//static NSArray *gridCharArray = (F, E, D, C, B, A, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0);
- (void)createFontGrid
{   NSArray	*gridCharArray = [NSArray arrayWithObjects:@"F", @"E", @"D", @"C", @"B", @"A", @"9", @"8", @"7", @"6", @"5", @"4", @"3", @"2", @"1", @"0", nil];
    NSString	*charFontStr = @"Helvetica-Light";
    NSString	*gridFontStr = @"DINMittelschrift";
    NSPoint	begin, end;
    float	fontSize;
    int		i, c;

    for (i=0; i<17; i++) // grid lines horicontal
    {
        begin.y = end.y = (float)i * gridOffset;
        begin.x = gridOffset*0.5;
        end.x = 17.0 * gridOffset;
        [self addLine:begin :end toList:list];
    }
    for (i=1; i<18; i++) // grid lines vertical
    {
        begin.x = end.x = (float)i * gridOffset;
        begin.y = 0.0;
        end.y = 16.5 * gridOffset;
        [self addLine:begin :end toList:list];
    }
    for (i=0; i<16; i++) // baseline horicontal
    {
        begin.y = end.y = (float)i * gridOffset + 0.25*gridOffset;
        begin.x = gridOffset;
        end.x = 17.0 * gridOffset;
        [self addLine:begin :end toList:list];
    }
    fontSize = gridOffset/5.0;
    for (i=0, c=0; i<16; i++, c++) // grid chars vertical
    {   NSString	*text;
        NSPoint		origin;

        text = [gridCharArray objectAtIndex:c];
        origin.x = gridOffset - fontSize;
        origin.y = (float)i*gridOffset + (0.5*gridOffset - fontSize*0.4);

        [self addText:text :[gridFontStr copy] :0.0 :fontSize :1.2 at:origin toList:list];
    }
    for (i=1, c=15; i<17; i++, c--) // grid chars horicontal
    {   NSString	*text;
        NSPoint		origin;

        text = [gridCharArray objectAtIndex:c];
        origin.x = (float)i*gridOffset + (0.5*gridOffset - fontSize*0.3);
        origin.y = 16.0*gridOffset + 0.1*gridOffset;

        [self addText:text :[gridFontStr copy] :0.0 :fontSize :1.2 at:origin toList:list];
    }
    fontSize = gridOffset/11.0;
    for (i=0; i<encodingCnt; i++)
    {   NSString	*text;
        NSPoint		origin;

        text = [NSString stringWithFormat:@"%s", encoding[i].name];
        origin.x = (encoding[i].index/16+1) * gridOffset + gridOffset*0.04;
        origin.y = (gridOffset + (15-(encoding[i].index%16)) * gridOffset) - (fontSize + gridOffset*0.025);

        [self addText:text :[charFontStr copy] :0.0 :fontSize :1.0 at:origin toList:list];
    }
}

- (int) getCharStringIndexFromEncoding:(int) index
{   int		i, j;

    for (i=0; i<encodingCnt; i++)
        if (encoding[i].index == index)
        {   char	*np = encoding[i].name;
            for (j=0; j<255; j++)
            {
                if (!strcmp(charStrings[j].name, np))
                    return j;
            }
        }
    return 0;
}

/* search for /Fontinfo, start at begin, interpret until end
 * search for keywords until def
 */
- (char*) getFontInfo:(char*)cp
{   NSMutableDictionary	*fiDict = [NSMutableDictionary dictionaryWithCapacity:10];
    char		*cString;
    int			intVal;
    BOOL		boolVal;

    if ( !(cp = strstr(cp, "begin")) )
    {	printf("Type1Import, FontInfo: unexpected end of file\n");
        return 0;
    }

    while (*cp)
    {	Token	*token;
        int	i;

        cp += strspn(cp, SEPARATORS);	/* goto begin of data */
        for (i=0; (token = fontInfoTokens+i) && token->index; i++)
        {
            if ( !strncmp(cp, token->string, strlen(token->string)) )
            {	switch (token->index)
                {
                    case T_COMMENT:
                        cp += strcspn(cp, NEWLINE);		// goto end of line
                        break;
                    case T_VERSION:
                        cp = gotoNextData(cp);
                        cString = getString(cp);
                        [fiDict setObject:[NSString stringWithUTF8String:cString] forKey:@"version"];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import: No 'def' for /version found");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_ITALICANGLE:
                        cp = gotoNextData(cp);
                        intVal = getInt(cp);
                        [fiDict setObject:[NSNumber numberWithInt:intVal] forKey:@"italicAngle"];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import: No 'def' for /ItalicAngle found");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_NOTICE:
                        cp = gotoNextData(cp);
                        cString = getString(cp);
                        [fiDict setObject:[NSString stringWithUTF8String:cString] forKey:@"notice"];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import: No 'def' for /Notice found");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_COPYRIGHT:
                        cp = gotoNextData(cp);
                        cString = getString(cp);
                        [fiDict setObject:[NSString stringWithUTF8String:cString] forKey:@"copyright"];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import: No 'def' for /Copyright found");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_FULLNAME:
                        cp += strlen(token->string);
                        cString = getString(cp);
                        [fiDict setObject:[NSString stringWithUTF8String:cString] forKey:@"fullName"];
                        if (!(cp = strstr(cp, "def")))
                        { printf("Type1Import: No 'def' for /FullName found"); return 0; }
                        cp += strlen("def");
                        break;
                    case T_FAMILYNAME:
                        cp += strlen(token->string);
                        cString = getString(cp);
                        [fiDict setObject:[NSString stringWithUTF8String:cString] forKey:@"familyName"];
                        if (!(cp = strstr(cp, "def")))
                        { printf("Type1Import: No 'def' for /FamilyName found"); return 0; }
                        cp += strlen("def");
                        break;
                    case T_WEIGHT:
                        cp = gotoNextData(cp);
                        cString = getString(cp);
                        [fiDict setObject:[NSString stringWithUTF8String:cString] forKey:@"weight"];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import: No 'def' for /Weight found");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_ISFIXEDPITCH:
                        cp = gotoNextData(cp);
                        boolVal = getBool(cp);
                        [fiDict setObject:[NSNumber numberWithShort:boolVal] forKey:@"isFixedPitch"];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import: No 'def' for /isFixedPitch found");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_UNDERLINEPOSITION:
                        cp = gotoNextData(cp);
                        intVal = getInt(cp);
                        [fiDict setObject:[NSNumber numberWithLong:intVal] forKey:@"underlinePosition"];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import: No 'def' for /UnderlinePosition found");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_UNDERLINETHICKNESS:
                        cp = gotoNextData(cp);
                        intVal = getInt(cp);
                        [fiDict setObject:[NSNumber numberWithLong:intVal] forKey:@"underlineThickness"];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import: No 'def' for /UnderlineThickness found");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_END:
                        cp += strlen(token->string);
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import, FontInfo: Unexpected end of file\n");
                            return 0;
                        }
                        cp += strlen("def");
                        [fontObject setFontInfo:fiDict];
                        return cp;
                    default:
                        cp += strcspn(cp, SEPARATORS);	/* goto next separator */
                        break;
                }
                break;
            }
        }
        if (!token->index)
            cp += strcspn(cp, NEWLINE);	/* goto next newline */
    }
    [fontObject setFontInfo:fiDict];
    return cp;
}

/* get encoding vectors
 */
- (char*)getEncoding:(char*)cp
{   //int	n=0;

encoding = [fontObject standardEncoding];
encodingCnt = [fontObject standardEncodingCnt];
#if 0
    cp += strspn(cp, " \t");	/* goto data */
    if (!strcspn(cp, "-.0123456789"))	/* digits */
    {
        encodingCnt = getInt(cp);

        if (!(encoding = malloc(encodingCnt*sizeof(Encoding))))
        {   printf("Type1Import, /Encoding: Out of Memory\n");
            return 0;
        }

        while (*cp)
        {   Token	*token;
            int		i;

            cp += strspn(cp, SEPARATORS);	/* goto begin of data */
            for (i=0; (token = encodingTokens+i) && token->index; i++)
            {
                if ( !strncmp(cp, token->string, strlen(token->string)) )
                {   switch (token->index)
                    {
                        case T_COMMENT:
                            cp += strcspn(cp, NEWLINE);		/* goto end of line */
                            break;
                        case T_DUP:
                            if (n>encodingCnt)
                            {	printf("Type1Import, /Encoding: Too many entries in encoding table\n");
                                return 0;
                            }
                            cp += strlen(token->string);
                            cp = gotoNextData(cp);
                            encoding[n].index = getInt(cp);
                            cp = gotoNextData(cp);
                            //strncpy(encoding[n].name, cp, strcspn(cp, SEPARATORS));
                            if ( *cp == '/' )
                                cp++;
                            strncpy(encoding[n].name, cp, strcspn(cp, SEPARATORS));
                            encoding[n].name[strcspn(cp, SEPARATORS)] = 0;
                            if (!(cp = strstr(cp, "put")))
                            {	printf("Type1Import, /Encoding: unexpected end of file");
                                return 0;
                            }
                            cp += strlen("put");
                            n++;
                            break;
                        case T_DEF:
                            cp = gotoNextData(cp);
                            [fontObject setFontEncoding:encoding :encodingCnt];
                            return cp;
                            break;
                        default:
                            cp += strcspn(cp, SEPARATORS);	/* goto next separator */
                            break;
                    }
                    break;
                }
            }
            if (!token->index)
                cp += strcspn(cp, SEPARATORS);	/* goto next separator */
        }
    }
    else if (!strncmp(cp, "StandardEncoding", strlen("StandardEncoding")))
    {   encoding = [fontObject standardEncoding];
        encodingCnt = [fontObject standardEncodingCnt];
    }
    else if (!strncmp(cp, "IsoLatin1Encoding", strlen("IsoLatin1Encoding")))
    {
        encoding = [fontObject standardEncoding];
        encodingCnt = [fontObject standardEncodingCnt];
        //encoding = [fontObject isoLatin1Encoding];
        //encodingCnt = [fontObject isoLatin1EncodingCnt];
	//encoding = isoLatin1Encoding;
        //encodingCnt = IsoLatin1EncodingCnt;
    }
#endif

    if (!(cp = strstr(cp, "def")))
    {	printf("Type1Import, /Encoding: unexpected end of file\n");
            return 0;
    }
    cp += strlen("def");
    [fontObject setFontEncoding:encoding :encodingCnt];
    return cp;
}

/* get subrs array
 */
- (char*) getSubrs:(char*)cp
{   int	n=0;

    cp += strspn(cp, " \t");		// goto data
    if (!strcspn(cp, "-.0123456789"))	// digits
    {	privateDict.subrsCnt = getInt(cp);

        if (!(privateDict.subrs = malloc(privateDict.subrsCnt*sizeof(Subrs))))
        {   printf("Type1Import, /Subrs: Out of Memory\n");
            return 0;
        }

        while (*cp)
        {   Token	*token;
            int		i, j;

            cp += strspn(cp, SEPARATORS);	/* goto begin of data */
            for (i=0; (token = subrsTokens+i) && token->index; i++)
            {
                if ( !strncmp(cp, token->string, strlen(token->string)) )
                {
                    switch (token->index)
                    {
                        case T_COMMENT:
                            cp += strcspn(cp, NEWLINE);		/* goto end of line */
                            break;
                        case T_DUP:
                            if (n>privateDict.subrsCnt)
                            {	printf("Type1Import, /Subrs: Too many entries in subrs array\n");
                                return 0;
                            }
                            cp += strlen(token->string);
                            cp = gotoNextData(cp);
                            j = getInt(cp);
                            if (j > privateDict.subrsCnt)
                            {	printf("Type1Import, /Subrs: Too large id:%d\n", j);
                                return 0;
                            }
                            cp = gotoNextData(cp);
                            privateDict.subrs[j].length = getInt(cp);	/* length of routine */
                            cp = gotoNextData(cp);	/* goto RD */
                            cp += strlen("RD");
                            cp++;
                            privateDict.subrs[j].proc = decryptCharString((unsigned char*)cp, privateDict.subrs[j].length);
                            cp += privateDict.subrs[j].length;
                            privateDict.subrs[j].length -= 4;
                            //	if (!(cp = strstr(cp, "put")) && !(cp = strstr(cp, "NP")) )
                            //	{	printf("Type1Import, /Subrs: unexpected end of file; 'put' or 'NP' expected\n");
                            //		return cp;
                            //	}
                            cp = gotoNextData(cp);
                            n++;
                            break;
                        case T_DEF:
                        case T_ND:
                        case T_X_:
                            cp = gotoNextData(cp);
                        case T_END:
                            [fontObject setFontPrivateSubrs:privateDict.subrs :privateDict.subrsCnt];
                            return cp;
                            break;
                        default:
                            cp += strcspn(cp, SEPARATORS);	/* goto next separator */
                            break;
                    }
                    break;
                }
            }
            if (!token->index)
                cp += strcspn(cp, SEPARATORS);	/* goto next separator */
        }
    }
    if (!(cp = strstr(cp, "def")))
    {	printf("Type1Import, /Subrs: unexpected end of file; 'def' expected!\n");
        return 0;
    }
    cp += strlen("def");
    [fontObject setFontPrivateSubrs:privateDict.subrs :privateDict.subrsCnt];
    return cp;
}

- (char*)getPrivateDict:(char*)cp
{   NSMutableDictionary	*pDict = [NSMutableDictionary dictionaryWithCapacity:26];
    char		*cString;
    int			intVal;

    if ( !(cp = strstr(cp, "begin")) )
    {	printf("Type1Import, PrivateDict: unexpected end of file\n");
        return 0;
    }
    cp += strspn(cp, " \t");	/* goto data */
    while (*cp)
    {	Token	*token;
        int		i;

        cp += strspn(cp, SEPARATORS);	/* goto begin of data */
        for (i=0; (token = privateTokens+i) && token->index; i++)
        {
            if ( !strncmp(cp, token->string, strlen(token->string)) )
            {	switch (token->index)
                {
                    case T_COMMENT:
                        cp += strcspn(cp, NEWLINE);		/* goto end of line */
                        break;
                    case T_BLUEVALUES:
                    {   int			b;
                        float		blueValues[6];
                        NSMutableArray	*array = [NSMutableArray arrayWithCapacity:6];
                        cp += strlen(token->string);
                        cp = getArray(cp, blueValues);
                        for (b=0; b<6; b++)
                            [array addObject:[NSNumber numberWithFloat:blueValues[b]]];
                        [pDict setObject:array forKey:@"blueValues"];
                    }
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import, PrivateDict, BlueValues: unexpected end of file");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_MINFEATURE:
                    {   float		minFeature[2];
                        NSMutableArray	*array = [NSMutableArray arrayWithCapacity:2];

                        cp += strlen(token->string);
                        cp = getArray(cp, minFeature);

                        [array addObject:[NSNumber numberWithFloat:minFeature[0]]];
                        [array addObject:[NSNumber numberWithFloat:minFeature[1]]];
                        [pDict setObject:array forKey:@"minFeature"];
                    }
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import, PrivateDict, MinFeature: unexpected end of file");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_PASSWORD:
                        cp = gotoNextData(cp);
                        intVal = getInt(cp);
                        [pDict setObject:[NSNumber numberWithLong:intVal] forKey:@"password"];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import, PrivateDict, password: unexpected end of file");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_UNIQUEID:
                        cp += strlen(token->string);
                        intVal = getInt(cp);
                        [pDict setObject:[NSNumber numberWithInt:intVal] forKey:@"uniqueID"];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import, PrivateDict, UniqueID: unexpected end of file");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_SOURCE:
                        cp += strlen(token->string);
                        cString = getString(cp);
                        [pDict setObject:[NSString stringWithUTF8String:cString] forKey:@"source"];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import, PrivateDict, /Source: unexpected end of file");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_OTHERSUBRS:
                        cp += strlen(token->string);
                        cString = getOtherSubrs(cp);
                        [pDict setObject:[NSString stringWithUTF8String:cString] forKey:@"otherSubrs"];
                        cp += strlen(cString);
                        break;
                    case T_SUBRS:
                        cp += strlen(token->string);
                        cp = [self getSubrs:cp];
                        if (strstr(cp, "/Subrs"))	/* to get Helvetica-Light Oblique */
                        {   cp = strstr(cp, "/Subrs")+strlen("/Subrs");
                            cp = [self getSubrs:cp];
                        }
                        break;
                    case T_END:
                        cp += strlen(token->string);
                    case T_CHARSTRINGS:
                        [fontObject setFontPrivate:pDict];
                        return cp;
                        break;
                    default:
                        cp += strcspn(cp, SEPARATORS);	/* goto next separator */
                        break;
                }
                break;
            }
        }
        if (!token->index)
        cp += strcspn(cp, SEPARATORS);	/* goto next separator */
    }
    [fontObject setFontPrivate:pDict];
    return cp;
}

- (char*)getCharStrings:(char*)cp
{   int	cnt;

    if ( !(cp = strstr(cp, "/CharStrings")) )
    {	printf("Type1Import, CharStrings: unexpected end of file\n");
        return 0;
    }
    cp += strlen("/CharStrings");
    cp += strspn(cp, " \t");	/* goto data */
    if (strcspn(cp, "-.0123456789"))	/* digits */
    {	printf("Type1Import, /CharStrings: unexpected character; number expected!\n");
        return 0;
    }
    cnt = getInt(cp);

//	if (!(privateDict.subrs = malloc(cnt*sizeof(Subrs))))
//	{	printf("Type1Import, /Subrs: Out of Memory\n");
//		return 0;
//	}

    charStringCnt = 0;
    cp += strspn(cp, " \t");	/* goto data */
    while (cp && *cp)
    {	int	i;

        cp += strspn(cp, SEPARATORS);	/* goto begin of data */
        for (i=encodingCnt-1; i>=0; i--)
        {   char	name[MAXCHARNAMELEN];

            strncpy(name, cp+1, strcspn(cp+1, SEPARATORS));
            name[strcspn(cp+1, SEPARATORS)] = 0;
            if ( *cp == '/' && !strcmp(name, encoding[i].name) )
            {
                strcpy(charStrings[charStringCnt].name, encoding[i].name);
                cp = gotoNextData(cp);	/* goto number */
                charStrings[charStringCnt].length = getInt(cp);
                cp = gotoNextData(cp);	/* goto RD */
                cp += strlen("RD");
                cp++;
                charStrings[charStringCnt].code = decryptCharString((unsigned char*)cp, charStrings[charStringCnt].length);
                cp += charStrings[charStringCnt].length;
                charStrings[charStringCnt].length -= 4;
                charStringCnt++;
            }
        }
        if (i<0)
        {   Token	*token;
            int		i, j;

            for (i=0; (token = charStringsTokens+i) && token->index; i++)
            {
                if ( !strncmp(cp, token->string, strlen(token->string)) )
                {   switch (token->index)
                    {
                        case T_COMMENT:
                            cp += strcspn(cp, NEWLINE);		/* goto end of line */
                            break;
                        case T_CHARSTRING:
                        {   char	str[20];
                            int		l = strcspn(cp, SEPARATORS);
                            if ( l > 19 ) l = 19;
                            strncpy(str, cp, l);
                            str[l] = 0;
                            printf("Type1Import, CharStrings: %s not in encoding table\n", str);
                        }
                            cp = gotoNextData(cp);	/* goto number */
                            if (strcspn(cp, "123456789"))	/* no number! */
                                break;
                            j = getInt(cp);
                            cp = gotoNextData(cp);	/* goto RD */
                            cp += strlen("RD");
                            cp++;
                            cp += j;
                            break;
                        case T_END:
                            cp += strlen(token->string);
                            [fontObject setFontCharStrings:charStrings :charStringCnt];
                            return cp;
                            break;
                    }
                }
            }
            if (!token->index)
                cp += strcspn(cp, SEPARATORS);	/* goto next separator */
        }
    }
    [fontObject setFontCharStrings:charStrings :charStringCnt];
    return cp;
}

- (BOOL)interpret:(NSString*)fData
{   char	*cp, *decryptedData, *fontData, *cString;
    int		dataLen, decryptedLen, intVal;
    float	fontMatrix[6], fontBBox[4];
    NSRect	bounds;

    // get char from data
    dataLen = [fData length]; // +1 -> 0
    fontData = malloc(dataLen+1);
    // if ( [[fData description] canBeConvertedToEncoding:NSNonLossyASCIIStringEncoding] ) //NSStringEncoding
    [[fData description] getCString:fontData];
//fontData = [[fData description] lossyCString];
    // else return NO;

    if (!(cp=strstr(fontData, "eexec")))
    {
        printf("Type1Import: No eexec found");
        return NO;
    }
    cp += strlen("eexec");
    cp += strspn(cp, "\r\n \t");	// go to the beginning of the source

    dataLen -= (cp-fontData);
    decryptedData = (char*)decryptEexec((unsigned char*)cp, dataLen, &decryptedLen);

/*{ NSString	*eexecStr=[NSString stringWithCString:decryptedData length:dataLen];
  NSString	*filename = [NSString stringWithFormat:@"/Net/nesquick/Users/ilonka/Tempo/Test/arcade1Subrs"];
[eexecStr writeToFile:filename atomically:YES];
}*/
    /* start interpretation
     * search for document keywords like /Fontinfo
     *
     * jump from token to token
     * check for keywords
     */
    cp = fontData;
    while (*cp)
    {	Token	*token;
        int	i;

        cp += strspn(cp, SEPARATORS);	// goto begin of data
        for (i=0; (token = documentTokens+i) && token->index; i++)
        {
            if ( !strncmp(cp, token->string, strlen(token->string)) )
            {
                switch (token->index)
                {
                    case T_COMMENT:
                        cp += strcspn(cp, NEWLINE);		// goto end of line
                        break;
                    case T_FONTINFO:
                        cp = [self getFontInfo:cp];
                        break;
                    case T_FONTNAME:
                        cp = gotoNextData(cp);
                        cString = getName(cp)+1;
                        [fontObject setFontName:[NSString stringWithUTF8String:cString]];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import: No 'def' for FontName found");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_PAINTTYPE:
                        cp = gotoNextData(cp);
                        intVal = getInt(cp);
                        [fontObject setPaintType:intVal];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import: No 'def' for PaintType found");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_FONTTYPE:
                        cp = gotoNextData(cp);
                        intVal = getInt(cp);
                        [fontObject setFontType:intVal];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import: No 'def' for FontType found");
                            return 0;
                        }
                        cp += strlen("def");
                        break;
                    case T_FONTMATRIX:
                        cp += strlen(token->string);
                        cp = getArray(cp, fontMatrix);
                        [fontObject setFontMatrix:fontMatrix];
                        if (!(cp = strstr(cp, "def")))
                        {   printf("Type1Import: No 'def' for FontMatrix found");
                            return 0;
                        }
                            cp += strlen("def");
                        break;
                    case T_ENCODING:
                        cp += strlen(token->string);
                        [self getEncoding:cp];
                        break;
                    case T_FONTBBOX:
                        cp += strlen(token->string);
                        cp = getArray(cp, fontBBox);
                        [fontObject setFontBBox:fontBBox];
                        if (!(cp = strstr(cp, "def")))
                        {	printf("Type1Import: No 'def' for FontBBox found");
                            return 0;
                        }
                            cp += strlen("def");
                        break;
                        break;
                    case T_UNIQUEID:
                        cp = gotoNextData(cp);
                        intVal = getInt(cp);
                        [fontObject setUniqueID:intVal];
                        if (!(cp = strstr(cp, "def")))
                        {	printf("Type1Import: No 'def' for UniqueID found");
                            return 0;
                        }
                            cp += strlen("def");
                        break;
                    default:
                        cp += strcspn(cp, SEPARATORS);	/* goto next separator */
                        break;
                }
                break;
                }
            }
        if (!token->index)
        {
            cp += strcspn(cp, NEWLINE);	/* goto next newline */
        }
    }

    cp = [self getPrivateDict:decryptedData+4];
    [self getCharStrings:cp];

    if ( ![self encodeCharStrings] )
        return NO;
    free(decryptedData);
    free(fontData);

    /* font grid, character name */
    state.color = [NSColor grayColor];
    state.width = 0.0;
    gridOffset = [fontObject gridOffset];
    [self createFontGrid]; // added to list

    bounds.origin = ll;
    bounds.size.width = ur.x - ll.x;
    bounds.size.height = ur.y - ll.y;
    [self setBounds:bounds];

    return YES;
}

#define ERR_STACKUNDERFLOW	1
- psErrorCode:(int)code commandName:(char*)name
{//	struct timeval	currentTime;
//	char			*time;
    NSString	*time = [[NSCalendarDate date] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S"];
    NSString	*type1Str = [NSString stringWithFormat:@"Type1Import"];
	/* ask for the time here */
//	gettimeofday (&currentTime, NULL);
	/* set the month, day and year */
//	time = ctime(&(currentTime.tv_sec));

    switch (code)
    {
        case ERR_STACKUNDERFLOW:
            printf("%s, %s: %%%%[ Error:stackunderflow; OffendingCommand:%s ]%%%%\n", [time UTF8String], [type1Str UTF8String], name);
            break;
        default:
            printf("%s, %s: %%%%[ Error:unknown Error Code, %s ]%%%%\n", [time UTF8String], [type1Str UTF8String], name);
    }

    return self;
}

- (void)decodeCharString:(unsigned char*)code length:(int)len
{   static int		stack[50], stackTop = 0, seac = 0;
    static NSPoint	currentPoint = {0.0, 0.0};
    static int		flex = 0, flexStack[20], flexTop = 0;
    Proc		*cp, *end;
    int			psStack[2] = {0, 0};

    if (!code)
    {   NSLog(@"Type1Import decodeCharString: got Null code");
        return;
    }
    for (cp=(unsigned char*)code, end=cp+len; cp<end; cp++)
    {
        if (stackTop < 0)
            stackTop = 0;

        switch (*cp)
        {
            case  1:	/* y dy hstem */
                if (stackTop < 2)
                    [self psErrorCode:ERR_STACKUNDERFLOW commandName:"hstem"];
                [self hstem:stack[stackTop-2] :stack[stackTop-1]];
                stackTop = 0;
                break;
            case  3:	/* x dx vstem */
                if (stackTop < 2)
                    [self psErrorCode:ERR_STACKUNDERFLOW commandName:"vstem"];
                [self vstem:stack[stackTop-2] :stack[stackTop-1]];
                stackTop = 0;
                break;
            case  4:	/* dy vmoveto */
                if (stackTop < 1)
                    [self psErrorCode:ERR_STACKUNDERFLOW commandName:"vmoveto"];
                if (flex)
                {	flexStack[flexTop++] = 0;
                    flexStack[flexTop++] = stack[stackTop-1];
                }
                    else
                    {	currentPoint.y += stack[stackTop-1];
                        [self moveto:currentPoint.x :currentPoint.y];
                    }
                    stackTop = 0;
                break;
            case  5:	/* dx dy rlineto */
                if (stackTop < 2)
                    [self psErrorCode:ERR_STACKUNDERFLOW commandName:"rlineto"];
                currentPoint.x += stack[stackTop-2];
                currentPoint.y += stack[stackTop-1];
                [self lineto:currentPoint.x :currentPoint.y];
                stackTop = 0;
                break;
            case  6:	/* dx hlineto */
                if (stackTop < 1)
                    [self psErrorCode:ERR_STACKUNDERFLOW commandName:"hlineto"];
                currentPoint.x += stack[stackTop-1];
                [self lineto:currentPoint.x :currentPoint.y];
                stackTop = 0;
                break;
            case  7:	/* dy vlineto */
                if (stackTop < 1)
                    [self psErrorCode:ERR_STACKUNDERFLOW commandName:"vlineto"];
                currentPoint.y += stack[stackTop-1];
                [self lineto:currentPoint.x :currentPoint.y];
                stackTop = 0;
                break;
            case  8:	/* dx1 dy1 dx2 dy2 dx3 dy3 rrcurveto */
            {	NSPoint	d1, d2;

                if (stackTop < 6)
                    [self psErrorCode:ERR_STACKUNDERFLOW commandName:"rrcurveto"];
                d1.x = currentPoint.x + stack[stackTop-6];
                d1.y = currentPoint.y + stack[stackTop-5];
                d2.x = d1.x + stack[stackTop-4];
                d2.y = d1.y + stack[stackTop-3];
                currentPoint.x = d2.x + stack[stackTop-2];
                currentPoint.y = d2.y + stack[stackTop-1];
                [self curveto:d1.x :d1.y :d2.x :d2.y :currentPoint.x :currentPoint.y];
                stackTop = 0;
                break;
            }
            case  9:	/* closepath */
                [self closepath];
                stackTop = 0;
                break;
            case 10:	/* subr# callsubr */
                if (stackTop < 1)
                    [self psErrorCode:ERR_STACKUNDERFLOW commandName:"callsubr"];
                stackTop --;
                switch (stack[stackTop])
                {	NSPoint	d1, d2, d3;

                    case 1:	/* start flex control */
                        flex = 1; flexTop = 0;
                        break;
                    case 2:	/* flex control */
                        break;
                    case 0:	/* end flex control */
                        d1.x = currentPoint.x + flexStack[flexTop-14] + flexStack[flexTop-12];
                        d1.y = currentPoint.y + flexStack[flexTop-13] + flexStack[flexTop-11];
                        d2.x = d1.x + flexStack[flexTop-10];
                        d2.y = d1.y + flexStack[flexTop-9];
                        d3.x = d2.x + flexStack[flexTop-8];
                        d3.y = d2.y + flexStack[flexTop-7];
                        [self curveto:d1.x :d1.y :d2.x :d2.y :d3.x :d3.y];
                        d1.x = d3.x + flexStack[flexTop-6];
                        d1.y = d3.y + flexStack[flexTop-5];
                        d2.x = d1.x + flexStack[flexTop-4];
                        d2.y = d1.y + flexStack[flexTop-3];
                        d3.x = d2.x + flexStack[flexTop-2];
                        d3.y = d2.y + flexStack[flexTop-1];
                        [self curveto:d1.x :d1.y :d2.x :d2.y :d3.x :d3.y];
                        currentPoint = d3;
                        flex = 0; flexTop = 0;
                        break;
                    default:
                        [self decodeCharString:privateDict.subrs[stack[stackTop]].proc
                                        length:privateDict.subrs[stack[stackTop]].length];
                }
                    break;
            case 11:	/* return */
                return;
                break;
            case 12:	/* 2-byte command */
                cp++;
                switch (*cp)
                {
                    case  0:	/* dotsection */
//						printf("dotsection\n");
                        stackTop = 0;
                        break;
                    case  1:	/* x0 dx0 x1 dx1 x2 dx2 vstem3 */
                        if (stackTop < 6)
                            [self psErrorCode:ERR_STACKUNDERFLOW commandName:"vstem3"];
                        [self vstem:stack[stackTop-6] :stack[stackTop-5]];
                        [self vstem:stack[stackTop-4] :stack[stackTop-3]];
                        [self vstem:stack[stackTop-2] :stack[stackTop-1]];
                        stackTop = 0;
                        break;
                    case  2:	/* y0 dy0 y1 dy1 y2 dy2 hstem3 */
                        if (stackTop < 6)
                            [self psErrorCode:ERR_STACKUNDERFLOW commandName:"hstem3"];
                        [self hstem:stack[stackTop-6] :stack[stackTop-5]];
                        [self hstem:stack[stackTop-4] :stack[stackTop-3]];
                        [self hstem:stack[stackTop-2] :stack[stackTop-1]];
                        stackTop = 0;
                        break;
                    case  6:	/* asb adx ady bchar achar seac */
                    {	int			b, a;
                        NSPoint	p;

                        if (stackTop < 5)
                            [self psErrorCode:ERR_STACKUNDERFLOW commandName:"seac"];
                        b = [self getCharStringIndexFromEncoding: stack[stackTop-2]];
                        a = [self getCharStringIndexFromEncoding: stack[stackTop-1]];
                                                // relativ to leftsidebearing point not to origin
                                                // -> add leftsidebearing point - only x direction !
                        p.x = currentPoint.x + stack[stackTop-4];
                        p.y = stack[stackTop-3];
                        [self decodeCharString:charStrings[b].code length:charStrings[b].length];
                        currentPoint = p;
                        seac = 1;
                        [self decodeCharString:charStrings[a].code length:charStrings[a].length];
                        seac = 0;
                        stackTop = 0;
                        break;
                    }
                    case  7:	/* sbx sby wx wy sbw */
                        if (stackTop < 4)
                            [self psErrorCode:ERR_STACKUNDERFLOW commandName:"sbw"];
                        if (!seac)
                        {	currentPoint.x = stack[stackTop-4];
                            currentPoint.y = stack[stackTop-3];
                            [self sidebearing:currentPoint.x :currentPoint.y width:stack[stackTop-2]];
                        }
                            stackTop = 0;
                        break;
                    case 12:	/* num1 num2 div */
                        if (stackTop < 2)
                            [self psErrorCode:ERR_STACKUNDERFLOW commandName:"div"];
                        stack[stackTop-2] = stack[stackTop-2] / stack[stackTop-1];
                        stackTop --;
                        break;
                    case 16:	/* arg1 ... argn n othersubr# callothersubr */
                        if (stackTop < 1)
                            [self psErrorCode:ERR_STACKUNDERFLOW commandName:"callothersubr"];
                        //	printf("%d callothersubr\n", stack[stackTop-1]);
                        psStack[0] = stack[0];
                        psStack[1] = stack[1];
                        stackTop = 0;
                        break;
                    case 17:	/* pop */
                        //	printf("pop\n");
                        stack[stackTop] = psStack[0];
                        psStack[0] = psStack[1];
                        stackTop ++;
                        break;
                    case 33:	/* x y setcurrentpoint */
                        if (stackTop < 2)
                            [self psErrorCode:ERR_STACKUNDERFLOW commandName:"setcurrentpoint"];
                        printf("setcurrentpoint\n");
                        currentPoint.x = stack[stackTop-2];
                        currentPoint.y = stack[stackTop-1];
                        [self moveto:currentPoint.x :currentPoint.x];
                        stackTop = 0;
                        break;
                    default:
                        printf("Type1Import: bad command: 12 %d\n", *cp);
                        break;
                }
                break;
            case 13:	// sbx wx hsbw
                if (stackTop < 2)
                    [self psErrorCode:ERR_STACKUNDERFLOW commandName:"hsbw"];
                if (!seac)
                {   currentPoint.x = stack[stackTop-2];
                    [self sidebearing:currentPoint.x :0 width:stack[stackTop-1]];
                }
                stackTop = 0;
                break;
            case 14:	// endchar
                stackTop = 0;
                currentPoint.x = currentPoint.y = 0;
                return;
            case 21:	// dx dy rmoveto
                if (stackTop < 2)
                    [self psErrorCode:ERR_STACKUNDERFLOW commandName:"rmoveto"];
                if (flex)
                {	flexStack[flexTop++] = stack[stackTop-2];
                    flexStack[flexTop++] = stack[stackTop-1];
                }
                    else
                    {	currentPoint.x += stack[stackTop-2];
                        currentPoint.y += stack[stackTop-1];
                        [self moveto:currentPoint.x :currentPoint.y];
                    }
                    stackTop = 0;
                break;
            case 22:	/* dx hmoveto */
                if (stackTop < 1)
                    [self psErrorCode:ERR_STACKUNDERFLOW commandName:"rmoveto"];
                if (flex)
                {	flexStack[flexTop++] = stack[stackTop-1];
                    flexStack[flexTop++] = 0;
                }
                    else
                    {	currentPoint.x += stack[stackTop-1];
                        [self moveto:currentPoint.x :currentPoint.y];
                    }
                    stackTop = 0;
                break;
            case 30:	/* dy1 dx2 dy2 dx3 vhcurveto */
            {	NSPoint	d1, d2;

                if (stackTop < 4)
                    [self psErrorCode:ERR_STACKUNDERFLOW commandName:"vhcurveto"];
                d1.x = currentPoint.x;
                d1.y = currentPoint.y + stack[stackTop-4];
                d2.x = d1.x + stack[stackTop-3];
                d2.y = d1.y + stack[stackTop-2];
                currentPoint.x = d2.x + stack[stackTop-1];
                currentPoint.y = d2.y;
                [self curveto:d1.x :d1.y :d2.x :d2.y :currentPoint.x :currentPoint.y];
                stackTop = 0;
                break;
            }
            case 31:	/* dx1 dx2 dy2 dy3 hvcurveto */
            {	NSPoint	d1, d2;

                if (stackTop < 4)
                    [self psErrorCode:ERR_STACKUNDERFLOW commandName:"hvcurveto"];
                d1.x = currentPoint.x + stack[stackTop-4];
                d1.y = currentPoint.y;
                d2.x = d1.x + stack[stackTop-3];
                d2.y = d1.y + stack[stackTop-2];
                currentPoint.x = d2.x;
                currentPoint.y = d2.y + stack[stackTop-1];
                [self curveto:d1.x :d1.y :d2.x :d2.y :currentPoint.x :currentPoint.y];
                stackTop = 0;
                break;
            }
            default:
                if (*cp >= 32)
                {   cp = decodeNumber(cp, stack+stackTop)-1;
                    stackTop++;
                }
        }
    }
}

- (int) indexForCharName:(char*)name
{   int	i;

    for (i=0; i<encodingCnt; i++)
    {
        if ( !strcmp(encoding[i].name, name) )
            return encoding[i].index;
    }
    return 0;
}

NSPoint	currentPoint={0.0, 0.0}, startPoint, offset={0.0, 0.0}, gridCell;
NSPoint	scale, sidebearing;

- (BOOL)encodeCharStrings
{   int		cnt = charStringCnt; // 256
    int		i;

    scale.x = scale.y = 0.1; // 0.01;

    for (i=0; i<cnt; i++)
    {
        /* make new character at index */
        if (*charStrings[i].name)
        {
            pList = [self allocateList];
            [self newChar:charStrings[i].name index:[self indexForCharName:charStrings[i].name]];
            [self decodeCharString:charStrings[i].code length:charStrings[i].length];

            [self addStrokeList:pList toList:list];
            [pList release]; // ?? grs in list will not copied
        }
    }
    return YES;
}

int	allreadySet;
- newChar:(char*)name index:(int)index
{
    allreadySet = 0;
    gridCell.x = offset.x = (index/16+1) * gridOffset;
    offset.y = (15-(index%16)) * gridOffset + gridOffset*0.25;
    return self;
}

- sidebearing:(int)x :(int)y width:(int)w
{   NSPoint	begin, end;

    sidebearing.x = x*scale.x;
    sidebearing.y = y*scale.y;

    if (!allreadySet)
    {
     	offset.x += (gridOffset-(w*scale.x))/2.0;
        allreadySet = 1;

        begin.x = end.x = offset.x;
        begin.y = offset.y - (0.15*gridOffset);
        end.y = begin.y + (0.8*gridOffset);
        state.color = [NSColor colorWithCalibratedRed:0.0 green:1.0 blue:0.0 alpha:1.0];
        [self addLine:begin :end toList:list];
        begin.x = end.x = offset.x + (w*scale.x);
        [self addLine:begin :end toList:list];
        state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];
    }
    return self;
}

- hstem:(int)y :(int)dy
{   NSPoint	begin, end;

    begin.y = end.y = offset.y + y*scale.y + sidebearing.y;
    begin.x = gridCell.x + (0.05*gridOffset);
    end.x = begin.x + (0.9*gridOffset);
    state.color = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:0.0 alpha:1.0];
    [self addLine:begin :end toList:list];
    begin.y = end.y = offset.y + y*scale.y + dy*scale.y;
    [self addLine:begin :end toList:list];
    state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];
    return self;
}

- vstem:(int)x :(int)dx
{   NSPoint	begin, end;

    begin.x = end.x = offset.x + x*scale.x + sidebearing.x;
    begin.y = offset.y - (0.2*gridOffset);
    end.y = begin.y + (0.9*gridOffset);
    state.color = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:0.0 alpha:1.0];
    [self addLine:begin :end toList:list];
    begin.x = end.x += dx*scale.x;
    [self addLine:begin :end toList:list];
    state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];
    return self;
}

- moveto:(int)x :(int)y
{
    startPoint.x = currentPoint.x = offset.x + x*scale.x;
    startPoint.y = currentPoint.y = offset.y + y*scale.y;
    [self updateBounds:currentPoint];

    return self;
}

- lineto:(int)x :(int)y
{   NSPoint	end;

    end.x = offset.x + x*scale.x;
    end.y = offset.y + y*scale.y;
    if ( Diff(currentPoint.x, end.x) <= TOLERANCE && Diff(currentPoint.y, end.y) <= TOLERANCE )
        return self;
    [self addLine:currentPoint :end toList:pList];
    currentPoint = end;
    [self updateBounds:currentPoint];

    return self;
}

- curveto:(int)x1 :(int)y1 :(int)x2 :(int)y2 :(int)x3 :(int)y3
{   NSPoint	p1, p2, p3;

    p1.x = offset.x + x1*scale.x;
    p1.y = offset.y + y1*scale.y;
    p2.x = offset.x + x2*scale.x;
    p2.y = offset.y + y2*scale.y;
    p3.x = offset.x + x3*scale.x;
    p3.y = offset.y + y3*scale.y;
    [self addCurve:currentPoint :p1 :p2 :p3 toList:pList];
    currentPoint = p3;
    [self updateBounds:p1];
    [self updateBounds:p2];
    [self updateBounds:currentPoint];

    return self;
}

- closepath
{
    [self addLine:currentPoint :startPoint toList:pList];
    return self;
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
- allocateFontObject
{
    return nil;
}

- allocateList
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
