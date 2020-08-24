/*
 * GSPropertyListSerialization.m
 *
 * Copyright (C) 2003,2004 Free Software Foundation, Inc.
 * Written by:       Richard Frith-Macdonald <rfm@gnu.org>
 *                   Fred Kiefer <FredKiefer@gmx.de>
 * Modifications by: Georg Fleischmann
 *
 * This class has been extracted from the GNUstep implementation of
 * NSPropertyList to achieve best compatibility of the Property List
 * formats between Mac OS X, GNUstep, OpenStep...
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * created:  2008-03-06 (extracted from NSPropertyList.m)
 * modified: 2008-03-09
 */

#include "GSPropertyListSerialization.h"

@implementation GSPropertyListSerialization

static const char	*indentStrings[] = {
    "",
    "  ",
    "    ",
    "      ",
    "\t",
    "\t  ",
    "\t    ",
    "\t      ",
    "\t\t",
    "\t\t  ",
    "\t\t    ",
    "\t\t      ",
    "\t\t\t",
    "\t\t\t  ",
    "\t\t\t    ",
    "\t\t\t      ",
    "\t\t\t\t",
    "\t\t\t\t  ",
    "\t\t\t\t    ",
    "\t\t\t\t      ",
    "\t\t\t\t\t",
    "\t\t\t\t\t  ",
    "\t\t\t\t\t    ",
    "\t\t\t\t\t      ",
    "\t\t\t\t\t\t"
};

/*
 * Cache classes and method implementations for speed.
 */
static Class    NSDataClass;
static Class    NSStringClass;
static Class    NSMutableStringClass;

static Class    plArray;
static id       (*plAdd)(id, SEL, id) = 0;
static Class    plDictionary;
static id       (*plSet)(id, SEL, id, id) = 0;


#define IS_BIT_SET(a,i) ((((a) & (1<<(i)))) > 0)

static NSCharacterSet *quotables = nil;
static NSCharacterSet *oldQuotables = nil;
static NSCharacterSet *xmlQuotables = nil;

//static unsigned const char *quotablesBitmapRep = NULL;
//#define GS_IS_QUOTABLE(X) IS_BIT_SET(quotablesBitmapRep[(X)/8], (X) % 8)

static void setupQuotables(void)
{
    if (oldQuotables == nil)
    {   NSMutableCharacterSet   *s;
        //NSData                  *bitmap;

        s = [[NSCharacterSet characterSetWithCharactersInString:
                             @"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                             @"abcdefghijklmnopqrstuvwxyz!#$%&*+-./:?@|~_^"] mutableCopy];
        [s invert];
        quotables = [s copy];
        [s release];

        /*bitmap = RETAIN([quotables bitmapRepresentation]);
        quotablesBitmapRep = [bitmap bytes];*/

        s = [[NSCharacterSet characterSetWithCharactersInString:
                             @"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                             @"abcdefghijklmnopqrstuvwxyz$./_"] mutableCopy];
        [s invert];
        oldQuotables = [s copy];
        [s release];

        s = [[NSCharacterSet characterSetWithCharactersInString:
                             @"&<>'\\\""] mutableCopy];
        [s addCharactersInRange: NSMakeRange(0x0001, 0x001f)];
        [s removeCharactersInRange: NSMakeRange(0x0009, 0x0002)];
        [s removeCharactersInRange: NSMakeRange(0x000D, 0x0001)];
        [s addCharactersInRange: NSMakeRange(0xD800, 0x07FF)];
        [s addCharactersInRange: NSMakeRange(0xFFFE, 0x0002)];
        xmlQuotables = [s copy];
        [s release];
    }
}

static char base64[]
= "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static void encodeBase64(NSData *source, NSMutableData *dest)
{   int		length = [source length];
    int		enclen = length / 3;
    int		remlen = length - 3 * enclen;
    int		destlen = 4 * ((length + 2) / 3);
    unsigned char *sBuf;
    unsigned char *dBuf;
    int		sIndex = 0;
    int		dIndex = [dest length];

    [dest setLength: dIndex + destlen];

    if (length == 0)
        return;
    sBuf = (unsigned char*)[source bytes];
    dBuf = [dest mutableBytes];

    for (sIndex = 0; sIndex < length - 2; sIndex += 3, dIndex += 4)
    {
        dBuf[dIndex] = base64[sBuf[sIndex] >> 2];
        dBuf[dIndex + 1] = base64[((sBuf[sIndex] << 4) | (sBuf[sIndex + 1] >> 4)) & 0x3f];
        dBuf[dIndex + 2] = base64[((sBuf[sIndex + 1] << 2) | (sBuf[sIndex + 2] >> 6)) & 0x3f];
        dBuf[dIndex + 3] = base64[sBuf[sIndex + 2] & 0x3f];
    }

    if (remlen == 1)
    {
        dBuf[dIndex] = base64[sBuf[sIndex] >> 2];
        dBuf[dIndex + 1] = (sBuf[sIndex] << 4) & 0x30;
        dBuf[dIndex + 1] = base64[dBuf[dIndex + 1]];
        dBuf[dIndex + 2] = '=';
        dBuf[dIndex + 3] = '=';
    }
    else if (remlen == 2)
    {
        dBuf[dIndex] = base64[sBuf[sIndex] >> 2];
        dBuf[dIndex + 1] = (sBuf[sIndex] << 4) & 0x30;
        dBuf[dIndex + 1] |= sBuf[sIndex + 1] >> 4;
        dBuf[dIndex + 1] = base64[dBuf[dIndex + 1]];
        dBuf[dIndex + 2] = (sBuf[sIndex + 1] << 2) & 0x3c;
        dBuf[dIndex + 2] = base64[dBuf[dIndex + 2]];
        dBuf[dIndex + 3] = '=';
    }
}

/*
 * Output a string escaped for OpenStep style property lists.
 * The result is ascii data.
 */
static void PString(NSString *obj, NSMutableData *output)
{   unsigned	length;

    if ((length = [obj length]) == 0)
        [output appendBytes: "\"\"" length: 2];
    else if (   [obj rangeOfCharacterFromSet: oldQuotables].length > 0
             || [obj characterAtIndex: 0] == '/')
    {   unichar         tmp[length <= 1024 ? length : 0];
        unichar         *ustring;
        unichar         *from;
        unichar         *end;
        unsigned char   *ptr;
        int             base = [output length];
        int             len = 0;

        if (length <= 1024)
            ustring = tmp;
        else
            ustring = NSZoneMalloc(NSDefaultMallocZone(), length*sizeof(unichar));
        end = &ustring[length];
        [obj getCharacters: ustring];
        for (from = ustring; from < end; from++)
        {
            switch (*from)
            {
                case '\t':
                case '\r':
                case '\n':
                    len++;
                    break;

                case '\a':
                case '\b':
                case '\v':
                case '\f':
                case '\\':
                case '"' :
                    len += 2;
                    break;

                default:
                    if (*from < 128)
                    {
                        if (isprint(*from) || *from == ' ')
                            len++;
                        else
                            len += 4;
                    }
                    else
                        len += 6;
                    break;
            }
        }

        [output setLength: base + len + 2];
        ptr = [output mutableBytes] + base;
        *ptr++ = '"';
        for (from = ustring; from < end; from++)
        {
            switch (*from)
            {
                case '\t':
                case '\r':
                case '\n':
                    *ptr++ = *from;
                    break;

                case '\a': 	*ptr++ = '\\'; *ptr++ = 'a';  break;
                case '\b': 	*ptr++ = '\\'; *ptr++ = 'b';  break;
                case '\v': 	*ptr++ = '\\'; *ptr++ = 'v';  break;
                case '\f': 	*ptr++ = '\\'; *ptr++ = 'f';  break;
                case '\\': 	*ptr++ = '\\'; *ptr++ = '\\'; break;
                case '"' : 	*ptr++ = '\\'; *ptr++ = '"';  break;

                default:
                    if (*from < 128)
                    {
                        if (isprint(*from) || *from == ' ')
                            *ptr++ = *from;
                        else
                        {   unichar	c = *from;

                            *ptr++ = '\\';
                            ptr[2] = (c & 7) + '0';
                            c >>= 3;
                            ptr[1] = (c & 7) + '0';
                            c >>= 3;
                            ptr[0] = (c & 7) + '0';
                            ptr += 3;
                        }
                    }
                    else
                    {   unichar	c = *from;

                        *ptr++ = '\\';
                        *ptr++ = 'U';
                        ptr[3] = (c & 15) > 9 ? (c & 15) + 55 : (c & 15) + 48;
                        c >>= 4;
                        ptr[2] = (c & 15) > 9 ? (c & 15) + 55 : (c & 15) + 48;
                        c >>= 4;
                        ptr[1] = (c & 15) > 9 ? (c & 15) + 55 : (c & 15) + 48;
                        c >>= 4;
                        ptr[0] = (c & 15) > 9 ? (c & 15) + 55 : (c & 15) + 48;
                        ptr += 4;
                    }
                    break;
            }
        }
        *ptr++ = '"';

        if (ustring != tmp)
            NSZoneFree(NSDefaultMallocZone(), ustring);
    }
    else
    {   NSData	*d = [obj dataUsingEncoding: NSASCIIStringEncoding];

        [output appendData: d];
    }
}

/*
 * Output a string escaped for use in xml.
 * Result is utf8 data.
 */
static void
XString(NSString* obj, NSMutableData *output)
{   static char	*hexdigits = "0123456789ABCDEF";
    unsigned	end;

    end = [obj length];
    if (end == 0)
        return;

    if ([obj rangeOfCharacterFromSet: xmlQuotables].length > 0)
    {   unichar	*base;
        unichar	*map;
        unichar	c;
        unsigned	len;
        unsigned	rpos;
        unsigned	wpos;

        base = NSZoneMalloc(NSDefaultMallocZone(), end * sizeof(unichar));
        [obj getCharacters: base];
        for (len = rpos = 0; rpos < end; rpos++)
        {
            c = base[rpos];
            switch (c)
            {
                case '&':
                    len += 5;
                    break;
                case '<':
                case '>':
                    len += 4;
                    break;
                case '\'':
                case '"':
                    len += 6;
                    break;
                default:
                    if (   (c < 0x20 && (c != 0x09 && c != 0x0A && c != 0x0D))
                        || (c > 0xD7FF && c < 0xE000) || c > 0xFFFD)
                    {
                        len += 6;
                    }
                    else
                        len++;
                    break;
            }
        }
        map = NSZoneMalloc(NSDefaultMallocZone(), len * sizeof(unichar));
        for (wpos = rpos = 0; rpos < end; rpos++)
        {
            c = base[rpos];
            switch (c)
            {
                case '&':
                    map[wpos++] = '&';
                    map[wpos++] = 'a';
                    map[wpos++] = 'm';
                    map[wpos++] = 'p';
                    map[wpos++] = ';';
                    break;
                case '<':
                    map[wpos++] = '&';
                    map[wpos++] = 'l';
                    map[wpos++] = 't';
                    map[wpos++] = ';';
                    break;
                case '>':
                    map[wpos++] = '&';
                    map[wpos++] = 'g';
                    map[wpos++] = 't';
                    map[wpos++] = ';';
                    break;
                case '\'':
                    map[wpos++] = '&';
                    map[wpos++] = 'a';
                    map[wpos++] = 'p';
                    map[wpos++] = 'o';
                    map[wpos++] = 's';
                    map[wpos++] = ';';
                    break;
                case '"':
                    map[wpos++] = '&';
                    map[wpos++] = 'q';
                    map[wpos++] = 'u';
                    map[wpos++] = 'o';
                    map[wpos++] = 't';
                    map[wpos++] = ';';
                    break;
                default:
                    if ((c < 0x20 && (c != 0x09 && c != 0x0A && c != 0x0D))
                        || (c > 0xD7FF && c < 0xE000) || c > 0xFFFD)
                    {
                        map[wpos++] = '\\';
                        map[wpos++] = 'U';
                        map[wpos++] = hexdigits[(c>>12) & 0xf];
                        map[wpos++] = hexdigits[(c>>8) & 0xf];
                        map[wpos++] = hexdigits[(c>>4) & 0xf];
                        map[wpos++] = hexdigits[c & 0xf];
                    }
                    else
                        map[wpos++] = c;
                    break;
            }
        }
        NSZoneFree(NSDefaultMallocZone(), base);
        obj = [[NSString alloc] initWithCharacters: map length: len];
        [output appendData: [obj dataUsingEncoding: NSUTF8StringEncoding]];
        [obj release];
    }
    else
        [output appendData: [obj dataUsingEncoding: NSUTF8StringEncoding]];
}

/*
 * obj    the object to be written out
 * loc    the locale for formatting (or nil to indicate no formatting)
 * lev    the level of indentation to use
 * step   the indentation step (0 = 0, 1 = 2, 2 = 4, 3 = 8)
 * x      an indicator for xml or old/new openstep property list format
 * dest   the output data
 */
static void append(id obj, NSDictionary *loc, unsigned lev, unsigned step,
                   NSPropertyListFormat format, NSMutableData *dest)
{
    if ([obj isKindOfClass: [NSString class]])
    {
        if (format == NSPropertyListXMLFormat_v1_0)
        {
            [dest appendBytes: "<string>" length: 8];
            XString(obj, dest);
            [dest appendBytes: "</string>\n" length: 10];
        }
        else
            PString([obj description], dest);
    }
    else if ([obj isKindOfClass: [NSNumber class]])
    {   const char  *t = [obj objCType];

        if (*t ==  'c' || *t == 'C')
        {   BOOL	val = [obj boolValue];

            if (val == YES)
            {
                if (format == NSPropertyListXMLFormat_v1_0)
                    [dest appendBytes: "<true/>\n" length: 8];
                else if (format == NSPropertyListGNUstepFormat)
                    [dest appendBytes: "<*BY>" length: 5];
                else
                    PString([obj description], dest);
            }
            else
            {
                if (format == NSPropertyListXMLFormat_v1_0)
                    [dest appendBytes: "<false/>\n" length: 9];
                else if (format == NSPropertyListGNUstepFormat)
                    [dest appendBytes: "<*BN>" length: 5];
                else
                    PString([obj description], dest);
            }
        }
        else if (strchr("sSiIlLqQ", *t) != 0)
        {
            if (format == NSPropertyListXMLFormat_v1_0)
            {
                [dest appendBytes: "<integer>" length: 9];
                XString([obj stringValue], dest);
                [dest appendBytes: "</integer>\n" length: 11];
            }
            else if (format == NSPropertyListGNUstepFormat)
            {
                [dest appendBytes: "<*I" length: 3];
                [dest appendData: [[obj stringValue] dataUsingEncoding: NSASCIIStringEncoding]];
                [dest appendBytes: ">" length: 1];
            }
            else
                PString([obj description], dest);
        }
        else
        {
            if (format == NSPropertyListXMLFormat_v1_0)
            {
                [dest appendBytes: "<real>" length: 6];
                XString([obj stringValue], dest);
                [dest appendBytes: "</real>\n" length: 8];
            }
            else if (format == NSPropertyListGNUstepFormat)
            {
                [dest appendBytes: "<*R" length: 3];
                [dest appendData: [[obj stringValue] dataUsingEncoding: NSASCIIStringEncoding]];
                [dest appendBytes: ">" length: 1];
            }
            else
                PString([obj description], dest);
        }
    }
    else if ([obj isKindOfClass: [NSData class]])
    {
        if (format == NSPropertyListXMLFormat_v1_0)
        {
            [dest appendBytes: "<data>\n" length: 7];
            encodeBase64(obj, dest);
            [dest appendBytes: "</data>\n" length: 8];
        }
        else
        {   const unsigned char *src;
            unsigned char       *dst;
            int                 length;
            int                 i;
            int                 j;

            src = [obj bytes];
            length = [obj length];
#define num2char(num) ((num) < 0xa ? ((num)+'0') : ((num)+0x57))

            j = [dest length];
            [dest setLength: j + 2*length+(length > 4 ? (length-1)/4+2 : 2)];
            dst = [dest mutableBytes];
            dst[j++] = '<';
            for (i = 0; i < length; i++, j++)
            {
                dst[j++] = num2char((src[i]>>4) & 0x0f);
                dst[j] = num2char(src[i] & 0x0f);
                if ((i & 3) == 3 && i < length-1)
                {
                    /* if we've just finished a 32-bit int, print a space */
                    dst[++j] = ' ';
                }
            }
            dst[j++] = '>';
        }
    }
    else if ([obj isKindOfClass: [NSDate class]])
    {   static NSTimeZone	*z = nil;

        if (z == nil)
            z = [[NSTimeZone timeZoneForSecondsFromGMT: 0] retain];
        if (format == NSPropertyListXMLFormat_v1_0)
        {
            [dest appendBytes: "<date>" length: 6];
            obj = [obj descriptionWithCalendarFormat: @"%Y-%m-%dT%H:%M:%SZ"
                                            timeZone: z locale: nil];
            obj = [obj dataUsingEncoding: NSASCIIStringEncoding];
            [dest appendData: obj];
            [dest appendBytes: "</date>\n" length: 8];
        }
        else if (format == NSPropertyListGNUstepFormat)
        {
            [dest appendBytes: "<*D" length: 3];
            obj = [obj descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S %z"
                                            timeZone: z locale: nil];
            obj = [obj dataUsingEncoding: NSASCIIStringEncoding];
            [dest appendData: obj];
            [dest appendBytes: ">" length: 1];
        }
        else
        {
            obj = [obj descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S %z"
                                            timeZone: z locale: nil];
            PString(obj, dest);
        }
    }
    else if ([obj isKindOfClass: [NSArray class]])
    {   const char	*iBaseString;
        const char	*iSizeString;
        unsigned	level = lev;

        if (level*step < sizeof(indentStrings)/sizeof(id))
            iBaseString = indentStrings[level*step];
        else
            iBaseString = indentStrings[sizeof(indentStrings)/sizeof(id)-1];
        level++;
        if (level*step < sizeof(indentStrings)/sizeof(id))
            iSizeString = indentStrings[level*step];
        else
            iSizeString = indentStrings[sizeof(indentStrings)/sizeof(id)-1];

        if (format == NSPropertyListXMLFormat_v1_0)
        {   NSEnumerator	*e;

            [dest appendBytes: "<array>\n" length: 8];
            e = [obj objectEnumerator];
            while ((obj = [e nextObject]))
            {
                [dest appendBytes: iSizeString length: strlen(iSizeString)];
                append(obj, loc, level, step, format, dest);
            }
            [dest appendBytes: iBaseString length: strlen(iBaseString)];
            [dest appendBytes: "</array>\n" length: 9];
        }
        else
        {   unsigned		count = [obj count];
            unsigned		last = count - 1;
            NSString		*plists[count];
            unsigned		i;

            if ([obj isProxy] == YES)
            {
                for (i = 0; i < count; i++)
                    plists[i] = [obj objectAtIndex: i];
            }
            else
                [obj getObjects: plists];

            if (loc == nil)
            {
                [dest appendBytes: "(" length: 1];
                for (i = 0; i < count; i++)
                {   id	item = plists[i];

                    append(item, nil, 0, step, format, dest);
                    if (i != last)
                        [dest appendBytes: ", " length: 2];
                }
                [dest appendBytes: ")" length: 1];
            }
            else
            {
                [dest appendBytes: "(\n" length: 2];
                for (i = 0; i < count; i++)
                {   id	item = plists[i];

                    [dest appendBytes: iSizeString length: strlen(iSizeString)];
                    append(item, loc, level, step, format, dest);
                    if (i == last)
                        [dest appendBytes: "\n" length: 1];
                    else
                        [dest appendBytes: ",\n" length: 2];
                }
                [dest appendBytes: iBaseString length: strlen(iBaseString)];
                [dest appendBytes: ")" length: 1];
            }
        }
    }
    else if ([obj isKindOfClass: [NSDictionary class]])
    {   const char  *iBaseString;
        const char  *iSizeString;
        SEL         objSel = @selector(objectForKey:);
        IMP         myObj = [obj methodForSelector: objSel];
        unsigned    i;
        NSArray     *keyArray = [obj allKeys];
        unsigned    numKeys = [keyArray count];
        NSString    *plists[numKeys];
        NSString    *keys[numKeys];
        BOOL        canCompare = YES;
        Class       lastClass = 0;
        unsigned    level = lev;
        BOOL        isProxy = [obj isProxy];

        if (level*step < sizeof(indentStrings)/sizeof(id))
            iBaseString = indentStrings[level*step];
        else
            iBaseString = indentStrings[sizeof(indentStrings)/sizeof(id)-1];
        level++;
        if (level*step < sizeof(indentStrings)/sizeof(id))
            iSizeString = indentStrings[level*step];
        else
            iSizeString = indentStrings[sizeof(indentStrings)/sizeof(id)-1];

        if (isProxy == YES)
        {
            for (i = 0; i < numKeys; i++)
                keys[i] = [keyArray objectAtIndex: i];
        }
        else
            [keyArray getObjects: keys];

        if (format == NSPropertyListXMLFormat_v1_0)
        {
            /* This format can only use strings as keys */
            lastClass = [NSString class];
            for (i = 0; i < numKeys; i++)
            {
                if ([keys[i] isKindOfClass: lastClass] == NO)
                {
                    [NSException raise: NSInvalidArgumentException
                                format: @"Bad key in property list: '%@'", keys[i]];
                }
            }
        }
        else
        {
            /* All keys must respond to -compare: for sorting */
            for (i = 0; i < numKeys; i++)
            {   Class   x = [keys[i] class];

                if (x == lastClass) // FIXME: slower as GNUstep - where is the class pointer?
                    continue;
                if ([keys[i] respondsToSelector: @selector(compare:)] == NO)
                {
                    canCompare = NO;
                    break;
                }
                lastClass = x;
            }
        }

        if (canCompare == YES)
        {
#define STRIDE_FACTOR 3
            unsigned	c,d, stride;
            BOOL		found;
            NSComparisonResult	(*comp)(id, SEL, id) = 0;
            unsigned int	count = numKeys;
#ifdef	GSWARN
            BOOL		badComparison = NO;
#endif

            stride = 1;
            while (stride <= count)
            {
                stride = stride * STRIDE_FACTOR + 1;
            }
            lastClass = 0;
            while (stride > (STRIDE_FACTOR - 1))
            {
	      // loop to sort for each value of stride
                stride = stride / STRIDE_FACTOR;
                for (c = stride; c < count; c++)
                {
                    found = NO;
                    if (stride > c)
                    {
                        break;
                    }
                    d = c - stride;
                    while (!found)
                    {   id                  a = keys[d + stride];
                        id                  b = keys[d];
                        Class               x = [a class];
                        NSComparisonResult  r;

                        if (x != lastClass)
                        {
                            lastClass = x;
                            comp = (NSComparisonResult (*)(id, SEL, id))
                                [a methodForSelector: @selector(compare:)];
                        }
                        r = (*comp)(a, @selector(compare:), b);
                        if (r < 0)
                        {
#ifdef	GSWARN
                            if (r != NSOrderedAscending)
                                badComparison = YES;
#endif
                            keys[d + stride] = b;
                            keys[d] = a;
                            if (stride > d)
                                break;
                            d -= stride;
                        }
                        else
                        {
#ifdef	GSWARN
                            if (r != NSOrderedDescending && r != NSOrderedSame)
                                badComparison = YES;
#endif
                            found = YES;
                        }
                    }
                }
            }
#ifdef	GSWARN
            if (badComparison == YES)
                NSWarnFLog(@"Detected bad return value from comparison");
#endif
        }
        
        if (isProxy == YES)
        {
            for (i = 0; i < numKeys; i++)
                plists[i] = [(NSDictionary*)obj objectForKey: keys[i]];
        }
        else
        {
            for (i = 0; i < numKeys; i++)
                plists[i] = (*myObj)(obj, objSel, keys[i]);
        }

        if (format == NSPropertyListXMLFormat_v1_0)
        {
            [dest appendBytes: "<dict>\n" length: 7];
            for (i = 0; i < numKeys; i++)
            {
                [dest appendBytes: iSizeString length: strlen(iSizeString)];
                [dest appendBytes: "<key>" length: 5];
                XString(keys[i], dest);
                [dest appendBytes: "</key>\n" length: 7];
                [dest appendBytes: iSizeString length: strlen(iSizeString)];
                append(plists[i], loc, level, step, format, dest);
            }
            [dest appendBytes: iBaseString length: strlen(iBaseString)];
            [dest appendBytes: "</dict>\n" length: 8];
        }
        else if (loc == nil)
        {
            [dest appendBytes: "{" length: 1];
            for (i = 0; i < numKeys; i++)
            {
                append(keys[i],   nil, 0, step, format, dest);
                [dest appendBytes: " = " length: 3];
                append(plists[i], nil, 0, step, format, dest);
                [dest appendBytes: "; " length: 2];
            }
            [dest appendBytes: "}" length: 1];
        }
        else
        {
            [dest appendBytes: "{\n" length: 2];
            for (i = 0; i < numKeys; i++)
            {
                [dest appendBytes: iSizeString length: strlen(iSizeString)];
                append(keys[i],   loc, level, step, format, dest);
                [dest appendBytes: " = " length: 3];
                append(plists[i], loc, level, step, format, dest);
                [dest appendBytes: ";\n" length: 2];
            }
            [dest appendBytes: iBaseString length: strlen(iBaseString)];
            [dest appendBytes: "}" length: 1];
        }
    }
    else
    {   NSString	*cls;

        if (obj == nil)
        {
            obj = @"(nil)";
            cls = @"(nil)";
        }
        else
            cls = NSStringFromClass([obj class]);

        if (format == NSPropertyListXMLFormat_v1_0)
        {
            NSLog(@"Non-property-list class (%@) encoded as string", cls);
            [dest appendBytes: "<string>" length: 8];
            XString([obj description], dest);
            [dest appendBytes: "</string>" length: 9];
        }
        else
        {
            NSLog(@"Non-property-list class (%@) encoded as string", cls);
            PString([obj description], dest);
        }
    }
}

static BOOL	classInitialized = NO;

+ (void) initialize
{
    if (classInitialized == NO)
    {
        classInitialized = YES;

#if	HAVE_LIBXML
        /* Cache XML node information */
        XML_ELEMENT_NODE = [GSXMLNode typeFromDescription: @"XML_ELEMENT_NODE"];
#endif
        NSStringClass = [NSString class];
        NSMutableStringClass = [NSMutableString class];
        NSDataClass = [NSData class];

        plAdd = (id (*)(id, SEL, id))
            [plArray instanceMethodForSelector: @selector(addObject:)];

        plSet = (id (*)(id, SEL, id, id))
            [plDictionary instanceMethodForSelector: @selector(setObject:forKey:)];

        //setupHexdigits();
        setupQuotables();
        //setupWhitespace();
    }
}

+ (NSData*)dataFromPropertyList:(id)plist
                         format:(NSPropertyListFormat)format
               errorDescription:(NSString**)errorString
{   NSMutableData           *dest = [NSMutableData dataWithCapacity: 1024];
    NSDictionary            *loc = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    int                     step = 2;
    //NSPropertyListFormat    format = NSPropertyListOpenStepFormat;

    if (format == NSPropertyListXMLFormat_v1_0)
    {
        const char	*prefix =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist "
        "PUBLIC \"-//GNUstep//DTD plist 0.9//EN\" "
        "\"http://www.gnustep.org/plist-0_9.xml\">\n"
        "<plist version=\"0.9\">\n";

        [dest appendBytes: prefix length: strlen(prefix)];
        append(plist, loc, 0, step > 3 ? 3 : step, format, dest);
        [dest appendBytes: "</plist>" length: 8];
    }
    //else if (format == NSPropertyListGNUstepBinaryFormat)
    //    [NSSerializer serializePropertyList: plist intoData: dest];
    else if (format == NSPropertyListBinaryFormat_v1_0)
        NSLog(@"dataFromPropertyList: NSPropertyListBinaryFormat_v1_0 not implemented");
    //    [BinaryPLGenerator serializePropertyList: plist intoData: dest];
    else
        append(plist, loc, 0, step > 3 ? 3 : step, format, dest);

    return dest;
}

+ (NSString*)stringFromPropertyList:(id)plist
{   NSMutableString     *mutStr = [NSMutableString string];
    NSEnumerator        *keyEnum = [plist keyEnumerator];
    id                  key;

    [mutStr appendString:@"{\n"];

    while ((key = [keyEnum nextObject]))
    {   id  val = [plist objectForKey:key];

        [mutStr appendFormat:@"  \"%@\" = ", key];

        if ([val isKindOfClass:[NSString class]])
            [mutStr appendFormat:@"\"%@\"", val];
        else if ([val isKindOfClass:[NSNumber class]])
            [mutStr appendFormat:@"\"%@\"", [val stringValue]];
        else if ([val isKindOfClass:[NSArray class]])
            NSLog(@"FIXME, VHFPropertyListSerialization: Object of NSArray class not implemented!");
        else if ([val isKindOfClass:[NSDictionary class]])
            NSLog(@"FIXME, VHFPropertyListSerialization: Object of NSDictionary class not implemented!");
        else if ([val isKindOfClass:[NSData class]])
            NSLog(@"FIXME, VHFPropertyListSerialization: Object of NSData class not implemented!");
        else
            NSLog(@"VHFPropertyListSerialization: Object of %@ class not implemented!", [val class]);

        [mutStr appendString:@";\n"];
    }

    [mutStr appendString:@"}\n"];

    return mutStr;
}
@end
