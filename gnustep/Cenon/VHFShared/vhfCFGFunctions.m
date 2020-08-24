/* vhfCFGFunctions.m
 *
 * functions for accessing device configuration files
 * basically all these functions search for an identifier (id) within a string (data).
 * The information behind the identifier (id) will be returned in a specified manner.
 *
 * Copyright (C) 1992-2008 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1992-12-05
 * modified: 2008-11-13 (setCharactersToBeSkipped to none + skip whitespace characters)
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

#include <Foundation/Foundation.h>
#include "types.h"
#include "vhfCFGFunctions.h"


/*
 * purpose:   returns a string enclosed by '"' at 'id' in 'data'
 *            data will be modified!
 * parameter: data	(string of the kind like the files '*.dev')
 *            id	(identifier e.g. '#MOV')
 *            string (a pointer to a string, memory will be allocated)
 * return:    string
 * modified:  2005-05-20 (return nil, not 0 or NO)
 */
NSString *vhfGetStringFromData(NSMutableString *data, NSString *dataId)
{   NSMutableString *string;
    NSScanner       *scanner;
    NSRange         range;

    if ( !data || !dataId )
        return nil;

    scanner = [NSScanner scannerWithString:data];
    if ( [scanner scanUpToString:dataId intoString:NULL] )
    {   int	location = [scanner scanLocation];

        if ( [scanner isAtEnd] )
            return nil;
        [scanner scanString:dataId intoString:NULL];

        /* to allow multiple equal ids, we simply disable the id */
        [data replaceCharactersInRange:NSMakeRange(location, 1) withString:@"_"];

        [scanner scanUpToString:@"\"" intoString:NULL];
        [scanner scanString:@"\"" intoString:NULL];

        if ( ![scanner scanUpToString:@"\"" intoString:&string] )
            return nil;
        string = [string mutableCopy];

        while ( 1 )
        {
            range = [string rangeOfString:@"\\e"];
            if ( !range.length )
                break;
            [string replaceCharactersInRange:range withString:[NSString stringWithFormat:@"%c", 0x1b]];
        }
        while ( 1 )
        {
            range = [string rangeOfString:@"\\n"];
            if ( !range.length )
                break;
            [string replaceCharactersInRange:range withString:@"\n"];
        }
        while ( 1 )
        {
            range = [string rangeOfString:@"\\\\"];
            if ( !range.length )
                break;
            [string replaceCharactersInRange:range withString:@"\\"];
        }
        while ( 1 )
        {
            range = [string rangeOfString:@"\\r"];
            if ( !range.length )
                break;
            [string replaceCharactersInRange:range withString:@"\r"];
        }
        return string;
    }

    return nil;
}


/*
 * return number of parameters
 * parameter: data	(string of the kind like the files '*.dev')
 *            id	(identifier ex. '#SW1')
 * return:    number of parameter
 * created:   2008-06-05
 * modified:  2008-06-05
 */
int vhfNumberOfParameters(NSMutableString *data, NSString *dataId)
{   NSScanner		*scanner;
    NSCharacterSet  *newLineSet    = [NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
    NSCharacterSet  *whiteSpaceSet = [NSCharacterSet whitespaceCharacterSet];
    int             begLoc, endLoc, cnt = 0;

    if ( !data || !dataId )
        return 0;

    scanner = [NSScanner scannerWithString:data];
    [scanner setCharactersToBeSkipped:nil];

    if ( ! [scanner scanUpToString:dataId intoString:NULL] )
        return 0;
    begLoc = [scanner scanLocation];
    if ( ! [scanner scanUpToCharactersFromSet:newLineSet intoString:NULL] )
        return 0;
    endLoc = [scanner scanLocation];
    [scanner setScanLocation:begLoc];
    while ([scanner scanLocation] < endLoc)
    {
        /* search for start of parameter and increment count */
        [scanner scanUpToCharactersFromSet:whiteSpaceSet intoString:NULL];
        if ( ![scanner scanCharactersFromSet:whiteSpaceSet intoString:NULL] ||
             [scanner scanLocation] >= endLoc )
            break;

        /* scan parameter, if quoted, we have to scan to the next quote */
        if ([data characterAtIndex:[scanner scanLocation]] == '\"' )
        {
            [scanner setScanLocation:[scanner scanLocation]+1];
            if ( [data characterAtIndex:[scanner scanLocation]] != '\"' &&  // length > 1
                 ! [scanner scanUpToString:@"\"" intoString:NULL] )         // scan up to closing quote
                break;  // not closed, we return what we have
            [scanner setScanLocation:[scanner scanLocation]+1];
            cnt++;
        }
        else if ( [scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL] )   // scan up to white space
            cnt++;
    }

    return cnt;
}

/*
 * modified:    2008-11-13 (setCharactersToBeSkipped to none + skip whitespace characters)
 * purpose:     return some types beginning at the position of 'id' inside 'data'
 *              the single string must not be longer than 100 characters
 * parameter:   data	(string of the kind like the files '*.dev')
 *              types	("sciisWBL")
 *              s	string
 *              S	String between ' ' instead of '"'
 *              c	character
 *              i	integer
 *              B	BYTE
 *              W	WORD
 *              L	LONG
 *              id		(identifier e.g. "#XMX")
 *              value
 * return:      TRUE on success
 */
BOOL vhfGetTypesFromData(NSMutableString *data, NSString *types, NSString *dataId, ...)
{   va_list         flag_p;
    int             i, intValue;
    void            *flag;
    NSMutableString *string;
    NSScanner       *scanner = [NSScanner scannerWithString:data];
    BOOL            ret = YES;

    if ( !data || !dataId )
        return NO;

    if ( [scanner scanUpToString:dataId intoString:NULL] )
    {   int	location = [scanner scanLocation];

        if ( [scanner isAtEnd] )
            return NO;
        [scanner scanString:dataId intoString:NULL];
        [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@""]];

        /* to allow multiple equal ids, we simply disable the id */
        [data replaceCharactersInRange:NSMakeRange(location, 1) withString:@"_"];

        va_start(flag_p, dataId);
        for ( i=0; i < (int)[types length] && (flag = va_arg(flag_p, void*)); i++ )
        {
            [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
            switch ( [types characterAtIndex:i] )
            {
                case 'S':	// scan: string
                    if (![scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&string])
                    {	NSLog(@"string expected at location: %d", [scanner scanLocation]);
                    	va_end(flag_p);
                        string = [NSMutableString string];
                    }
                    *(NSString**)flag = string; // not retained !
                    break;
                case 's':	// scan quoted string: "string"
                    if ( ![scanner scanString:@"\""     intoString:NULL] ||
                         ![scanner scanUpToString:@"\"" intoString:&string] )
                    {   int scanIx = [scanner scanLocation];

                        /* we allow empty quoted strings */
                        if ( [data characterAtIndex:scanIx]   != '"' || [data characterAtIndex:scanIx-1] != '"' )
                        {   NSLog(@"string expected at location: %d", scanIx);
                            va_end(flag_p);
                            ret = NO;
                        }
                        string = [NSMutableString string];
                    }
                    //[scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    *(NSString**)flag = [string retain];
                    [scanner scanString:@"\"" intoString:NULL];
                    break;
                case 'c':	// scan character
                    if (![scanner scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:&string])
                    {	NSLog(@"character expected at location: %d", [scanner scanLocation]);
                    	va_end(flag_p);
                        string = [NSMutableString string];
                    }
                    *(char*)flag = [string characterAtIndex:0];
                    break;
                case 'i':	// scan integer
                    if (![scanner scanInt:(int*)flag])
                    {	NSLog(@"integer expected at location: %d", [scanner scanLocation]);
                    	va_end(flag_p);
                        *(int*)flag = 0;
                    }
                    break;
                case 'B':	// scan byte
                    if (![scanner scanInt:&intValue])
                    {	NSLog(@"byte expected at location: %d", [scanner scanLocation]);
                    	va_end(flag_p);
                        intValue = 0;
                    }
                    *(BYTE*)flag = (BYTE)intValue;
                    break;
                case 'W':	// scan word
                    if (![scanner scanInt:&intValue])
                    {	NSLog(@"word expected at location: %d", [scanner scanLocation]);
                    	va_end(flag_p);
                        intValue = 0;
                    }
                    *(WORD*)flag = (WORD)intValue;
                    break;
                case 'L':	// scan LONG = long (32 bit)
                    if (![scanner scanInt:&intValue])
                    {	NSLog(@"long expected at location: %d", [scanner scanLocation]);
                    	va_end(flag_p);
                        intValue = 0;
                    }
                    *(LONG*)flag = (LONG)intValue;
                    break;
                case 'C':	// scan float (32 bit)
                case 'f':
                    if (![scanner scanFloat:(float*)flag])
                    {	NSLog(@"float expected at location: %d", [scanner scanLocation]);
                    	va_end(flag_p);
                        *(float*)flag = 0.0;
                    }
                    break;
            }
        }
        va_end(flag_p);
        return ret;
    }

    return NO;
}
