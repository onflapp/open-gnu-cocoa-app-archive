/*
 * vhfCommonFunctions.m
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-25
 * modified: 2012-02-28 (vhfMOdulo() added)
 *           2012-02-06 (vhfUserDocuments())
 *
 * This file is part of the vhf Shared Library.
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

#include <AppKit/AppKit.h>

#include "vhfCommonFunctions.h"
#include "types.h"
#include "VHFStringAdditions.h"
//#include "VHFScannerAdditions.h"

/* sort popup entries
 *
 * created:  03.05.93
 * modified: 03.05.93 01.03.97
 */
void sortPopup(NSPopUpButton *popupButton, int startIx)
{   int i, cnt = [popupButton numberOfItems];

    for (i=startIx; i<cnt-1; i++)
    {	int	j, change = 0;

        for (j=i+1; j<cnt; j++)
            if ( [[popupButton itemTitleAtIndex:((!change) ? i : change)] compare:[popupButton itemTitleAtIndex:j]] > 0 )
                change = j;
        if (change)
        {   NSString	*title1, *title2;

            title1 = [[popupButton itemTitleAtIndex:i] retain];
            title2 = [[popupButton itemTitleAtIndex:change] retain];
            [popupButton removeItemAtIndex:i];
            [popupButton removeItemAtIndex:(change>i) ? change-1 : change];
            [popupButton insertItemWithTitle:title2 atIndex: (i>change) ? i-1 : i];
            [popupButton insertItemWithTitle:title1 atIndex:change];
            [title1 release];
            [title2 release];
        }
    }
}

NSString *stringWithConvertedChars(NSString *string, NSDictionary *conversionDict)
{   NSMutableString	*mString;
    NSArray		*keys;
    NSScanner		*scanner;
    NSString		*str;

    if ( !string )
        return nil;
    if ( !conversionDict )
        return string;

    mString = (NSMutableString*)[NSMutableString string];
    keys = [conversionDict allKeys];
    scanner = [NSScanner scannerWithString:string];
    [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@""]];
    while ( ![scanner isAtEnd] )
    {   int	loc = [scanner scanLocation], nextKeyLoc = [string length], k, keyIx = -1;

        for ( k=0; k<(int)[keys count]; k++ )
        {   int	keyLoc;

            if ( [scanner scanString:[keys objectAtIndex:k] intoString:NULL] )
            {
                keyIx = k;
                [scanner setScanLocation:loc];
                break;
            }
            [scanner scanUpToString:[keys objectAtIndex:k] intoString:NULL];
            if ( (keyLoc = [scanner scanLocation]) < nextKeyLoc )
            {   nextKeyLoc = keyLoc;
                keyIx = k;
            }
            [scanner setScanLocation:loc];
        }
        if ( keyIx>=0 )
        {   NSString	*key = [keys objectAtIndex:keyIx];

            if ( [scanner scanUpToString:key intoString:&str] )
            {   [mString appendString:str];
                [scanner setScanLocation:[scanner scanLocation]+[key length]];
            }
            else if ( ![scanner scanString:[keys objectAtIndex:k] intoString:NULL] )
                NSLog(@"stringWithConvertedChars(): key '%@' expected!", key);
            [mString appendString:[conversionDict objectForKey:key]];
        }
        else
        {   [mString appendString:[string substringFromIndex:[scanner scanLocation]]];
            break;
        }
    }
    return mString;
}

void checkPoint(NSPoint p)
{
    if ( p.x < 0.0/*LARGENEG_COORD*/ )
        NSLog(@"point.x < minimum");
    else if ( p.x > 1000.0/*LARGE_COORD*/ )
        NSLog(@"point.x > maximum");
    else if ( p.y < 0.0/*LARGENEG_COORD*/ || p.y== 0xffc00000 )
        NSLog(@"point.y < minimum");
    else if ( p.y > 1000.0/*LARGE_COORD*/ )
        NSLog(@"point.y > maximum");
}

/* return library paths
 * modified: 2008-02-28
 */
/* return library paths
 * modified: 2008-02-28
 */
NSString *vhfLocalLibrary(NSString* append)
{
#   if defined(GNUSTEP_BASE_VERSION) || defined(__APPLE__)
    NSFileManager	*fileManager = [NSFileManager defaultManager];
    NSString		*lPath, *sPath;

    /* here we return the local path or the system path, whichever exists
     * the local library has priority.
     * We do this to allow systems like Debian to place the library in the system folder
     */
    /* "/Library/Application Support/..." */
    lPath = vhfPathWithPathComponents(
            [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES) objectAtIndex:0],
            @"Application Support", append, nil );
    if ( lPath && [fileManager fileExistsAtPath:lPath] )
        return lPath;
    /* "/Library/..."  (Default) */
    lPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES) objectAtIndex:0]
            stringByAppendingPathComponent:append];
    if ( lPath && [fileManager fileExistsAtPath:lPath] )
        return lPath;
    /* "/System/Library/..." */
    sPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) objectAtIndex:0]
             stringByAppendingPathComponent:append];
    if ( sPath && [fileManager fileExistsAtPath:sPath] )
        return sPath;
    return lPath;
#   else	// OpenStep: /LocalLibrary
    return vhfPathWithPathComponents(@"/LocalLibrary", append, nil);
#   endif
}
NSString *vhfUserLibrary(NSString* append)
{
#   if defined(GNUSTEP_BASE_VERSION) || defined(__APPLE__)
    NSFileManager	*fileManager = [NSFileManager defaultManager];
    NSString		*lPath;

    /* "$HOME/Library/Application Support/..." */
    lPath = vhfPathWithPathComponents(
            [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0],
            @"Application Support", append, nil );
    if ( lPath && [fileManager fileExistsAtPath:lPath] )
        return lPath;
    /* "$HOME/Library/..."  (Default) */
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0]
            stringByAppendingPathComponent:append];
#   else	// OpenStep: $HOME/Library
    return vhfPathWithPathComponents(NSHomeDirectory(), @"Library", append, nil);
#   endif
}
NSString *vhfUserDocuments(NSString* append)
{
#   if defined(GNUSTEP_BASE_VERSION) || defined(__APPLE__)
    //NSFileManager	*fileManager = [NSFileManager defaultManager];

    /* "$HOME/Documents/..." */
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
            stringByAppendingPathComponent:append];
#   else	// OpenStep
    return nil;
#   endif
}
/* Cenon.app/...Resources/Library/append or CAM.bundle/...Resources/Library/append */
NSString *vhfBundleLibrary(NSBundle *bundle, NSString* append)
{   NSString    *rscPath = [bundle resourcePath], *path;

    path = vhfPathWithPathComponents(rscPath, @"Library", append, nil);
    return path;
}
/* return "path/" instead of "path" ()
 * DEPRECATED !, use vhfPathWithPathComponents(NSHomeDirectory(), ...) or the NSString method
 */
NSString *vhfHomeDirectory(void)	// deprecated !
{
    if ( [NSHomeDirectory() hasSuffix:@"/"] )
        return NSHomeDirectory();
    return [NSString stringWithFormat:@"%@/", NSHomeDirectory()];
}

/* build complete path from single path components.
 * the path components are separated with path separators.
 * parameter: nil terminated list of path components
 * created: 2005-11-13
 */
NSString *vhfPathWithPathComponents(NSString *seg1, ...)
{   va_list     arg_p;
    void        *arg;
    NSString    *path = seg1;

    va_start(arg_p, seg1);
    while ( (arg = va_arg(arg_p, void*)) != nil )
    {
        path = [path stringByAppendingPathComponent:arg];
    }
    va_end(arg_p);
    return path;
}

/* return 1st path+name that fits a name alternative within a list of paths
 * created: 2012-06-22
 */
NSString    *vhfFilePathForNamesInPaths(id name, NSString *seq1, ...)
{   va_list         arg_p;
    NSString        *path = seq1;
    NSFileManager   *fileManager = [NSFileManager defaultManager];
    NSArray         *names = ([name isKindOfClass:[NSArray class]]) ? name : nil;

    va_start(arg_p, seq1);
    while ( 1 )
    {   NSString    *fileName;

        if ( names )    // array of name choices
        {   int i;

            for ( i = 0; i < [names count]; i++)
            {   fileName = [path stringByAppendingPathComponent:[names objectAtIndex:i]];
                if ( [fileManager fileExistsAtPath:fileName] )
                {   va_end(arg_p);
                    return fileName;
                }
            }
        }
        else            // single string
        {
            fileName = [path stringByAppendingPathComponent:name];  // userLibrary() + "name.cenon"
            if ( [fileManager fileExistsAtPath:fileName] )
            {   va_end(arg_p);
                return fileName;
            }
        }

        if ( ! (path = va_arg(arg_p, void*)) )
            break;
    }
    va_end(arg_p);
    return nil;
}

#if 0
/* scan up to sequence
 * a sequence is separated by space
 * sequence: '\" = \"'
 */
NSString *scanUpToSequence(NSScanner *scanner, NSString *sequence)
{   NSArray		*array = [sequence componentsSeparatedByString:@" "];
    int			i, cnt = [array count], location, start = [scanner scanLocation];
    NSString		*part;
    NSMutableString	*string = [NSMutableString string];

    if ( ![array count] )
        return nil;
    while ( ![scanner isAtEnd] )
    {
        if ( ![scanner scanUpToString:[array objectAtIndex:0] intoString:&part] )
            return nil;
        location = [scanner scanLocation];
        [string appendString:part];
        for ( i=0; i<cnt; i++ )
        {
            if ( ![scanner scanString:[array objectAtIndex:i] intoString:&part] )
            {   [string appendString:part];
                break;
            }
        }
        if ( i>=cnt )
        {   [scanner setScanLocation:location];
            return string;
        }
    }
    [scanner setScanLocation:start];
    return nil;
}
#endif

/* created:      2004-12-12
 * modified:     2004-12-12
 * purpose:      build a string from a value
 *               'string' is a representation of 'value' with a maximum of n decimals
 *               the value will stay within limits
 *               '.' and ',' are regarded as decimal points, there are no thousands separators !
 * parameter:    value
 *               limits
 *               decimals
 * return value: string
 */
NSString *buildDecimalString(float value, VHFLimits limits, int digits)
{   int			i;
    NSString		*format = [NSString stringWithFormat:@"%%.%df", digits];
    NSMutableString	*string;
    NSRange		range;
    char		c;

    value += 0.000005;

    if (value < limits.min)
        value = limits.min;
    if (value > limits.max)
        value = limits.max;
    string = [NSMutableString stringWithFormat:format, value];

    /* avoid 0 as last character */
    for (i=[string length]-1; i && [string characterAtIndex:i]=='0'; i--)
    {	range.location = i;
        range.length=1;
        [string deleteCharactersInRange:range];
    }

    /* avoid point as last character */
    c = [string characterAtIndex:[string length]-1];
    if ( c == '.' || c == ',' )
    {	range.location = [string length]-1;
        range.length=1;
        [string deleteCharactersInRange:range];
    }

    /* workaround for OpenStep */
    if ( [NSDecimalSeparator isEqual:@","] )
        return [string stringByReplacing:@"." by:@","];

    return string;
}

/* created:      1993-08-07
 * modified:     2010-01-18
 * purpose:      build a string from a value
 *               'string' is a representation of 'value' with a maximum of 4 decimals
 *               'string' can't become less than 'limitL' or larger than 'limitH'
 *               '.' and ',' are regarded as decimal points, there are no thousands separators !
 * parameter:    value
 *               limitL, limitH
 * return value: string
 */
NSString *buildRoundedString(float value, float limitL, float limitH)
{   int             i;
    NSMutableString *string;
    NSRange         range;
    char            c;

    //value += 0.000005;
    value = floor((value + 0.000005) * 100000.0) / 100000.0;    // 2010-01-18: round

    if (value < limitL)
        value = limitL;
    if (value > limitH)
        value = limitH;
    string = [NSMutableString stringWithFormat:@"%.4f", value];

    /* avoid 0 as last character */
    for (i=[string length]-1; i && [string characterAtIndex:i]=='0'; i--)
    {	range.location = i;
        range.length=1;
        [string deleteCharactersInRange:range];
    }

    /* avoid point as last character */
    c = [string characterAtIndex:[string length]-1];
    if ( c == '.' || c == ',' )
    {	range.location = [string length]-1;
        range.length=1;
        [string deleteCharactersInRange:range];
    }

    /* workaround for OpenStep */
    if ( [NSDecimalSeparator isEqual:@","] )
        return [string stringByReplacing:@"." by:@","];

    return string;
}
NSString *vhfStringWithFloat(float value)
{   int             i;
    NSMutableString *string;
    NSRange         range;
    char            c;

    value += 0.000005;
    string = [NSMutableString stringWithFormat:@"%.4f", value];

    /* avoid 0 as last character */
    for (i=[string length]-1; i && [string characterAtIndex:i] == '0'; i--)
    {	range.location = i;
        range.length = 1;
        [string deleteCharactersInRange:range];
    }

    /* avoid point as last character */
    c = [string characterAtIndex:[string length]-1];
    if ( c == '.' || c == ',' )
    {	range.location = [string length]-1;
        range.length=1;
        [string deleteCharactersInRange:range];
    }

    /* workaround for OpenStep */
    if ( [NSDecimalSeparator isEqual:@","] )
        return [string stringByReplacing:@"." by:@","];

    return string;
}
/* double offers 16 digits resolution
 */
NSString *vhfStringWithDouble(double value)
{   int			i;
    NSMutableString	*string;
    NSRange		range;
    char		c;

    value += 0.00000000000000005;	// .16 digits (was .12)
    string = [NSMutableString stringWithFormat:@"%.15f", value];	// 2005-04-23 (was .10)

    /* avoid 0 as last character */
    for (i=[string length]-1; i && [string characterAtIndex:i] == '0'; i--)
    {	range.location = i;
        range.length = 1;
        [string deleteCharactersInRange:range];
    }

    /* avoid point as last character */
    c = [string characterAtIndex:[string length]-1];
    if ( c == '.' || c == ',' )
    {	range.location = [string length]-1;
        range.length=1;
        [string deleteCharactersInRange:range];
    }

    /* workaround for OpenStep */
    if ( [NSDecimalSeparator isEqual:@","] )
        return [string stringByReplacing:@"." by:@","];

    return string;
}

/* Modulo - return v % denom
 * created: 2012-02-28
 */
double vhfModulo(double v, double denom)
{
    return (v - floor(v / denom) * denom);
}

/* created:   16.07.93
 * modified:  16.07.93
 * purpose:   compare function for qsort
 * parameter: value1, value2 
 * return:    value1 < value2 -> -1
 *            value1 > value2 -> 1
 *            value1 = value2 -> 0
 */
static int compareDouble(const void *value1, const void *value2)
{
    if (*(double*)value1 < *(double*)value2)
        return(-1);
    if (*(double*)value1 > *(double*)value2)
        return(1);
    return(0);
}

/* created:   16.07.93
 * modified:  16.07.93 28.02.97
 *
 * purpose:   sort values in 'array' upwards
 * parameter: array
 *            cnt (number of values)
 * return:    none
 */
void sortValues(double *array, int cnt)
{
    qsort(array, cnt, sizeof(double), compareDouble);
}

#if 0
/* count number of apearances of a character in a string
 */
int vhfNumChars(NSString *string, unsigned char c)
{   int	i, cnt = [string length], num = 0;

    for (i=0; i<cnt; i++)
        if ( [string characterAtIndex:i] == c )
            num++;
    return num;
}

/* replaces all apearances of 'from' by 'to'
 */
NSString *vhfReplaceStringPart(NSString *string, NSString *from, NSString *to)
{   NSRange	range;

    while (1)
    {   range = [string rangeOfString:from];
        if ( !range.length )
            break;
        string = [NSString stringWithFormat:@"%@%@%@", [string substringToIndex:range.location], to, [string substringFromIndex:range.location+range.length]];
    }

    return string;
}
#endif

/* exchange values
 * types:   'c', 'd', 'i', 'f', 'p'
 * created: 2004-11-12
 */
void vhfExchangeValues(void *v1, void *v2, char type)
{
    switch (type)
    {
        case 'c':	// char
        {   char v;    v = *(char*)v1;    *(char*)v1    = *(char*)v2;    *(char*)v2    = v;
            return;
        };
        case 'd':	// double
        {   double v;  v = *(double*)v1;  *(double*)v1  = *(double*)v2;  *(double*)v2  = v;
            return;
        };
        case 'f':	// float
        {   float v;   v = *(float*)v1;   *(float*)v1   = *(float*)v2;   *(float*)v2   = v;
            return;
        };
        case 'i':	// int
        {   int v;     v = *(int*)v1;     *(int*)v1     = *(int*)v2;     *(int*)v2     = v;
            return;
        };
        case 'p':	// NSPoint
        {    NSPoint v; v = *(NSPoint*)v1; *(NSPoint*)v1 = *(NSPoint*)v2; *(NSPoint*)v2 = v;
            return;
        };
    }
}
