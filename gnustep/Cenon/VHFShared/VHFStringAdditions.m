/* VHFStringAdditions.m
 * vhf NSString additions
 *
 * Copyright (C) 1997-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997-07-08
 * modified: 2012-02-07 (-writeToFile:atomically:encoding:error: added for backward compatibility)
 *           2011-09-01 (-stringWithContentsOfFile: loads flexible on Apple)
 *           2008-11-08 (inactive method for NSMutableArray parked here)
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

#include "VHFStringAdditions.h"

@implementation NSString(VHFStringAdditions)

/* Methods to replace deprecated methods */
#ifdef __APPLE__
+ (id)stringWithContentsOfFile:(NSString*)path
{   NSStringEncoding	enc;
    NSString            *string;

    string = [self stringWithContentsOfFile:path usedEncoding:&enc error:NULL];
    if ( !string )
        string = [self stringWithContentsOfFile:path encoding:NSASCIIStringEncoding error:NULL];
    return string;
}

/* Methods added in certain versions of Mac OS X */
#   if MAC_OS_X_VERSION_MAX_ALLOWED < 1050 /*MAC_OS_X_VERSION_10_5*/
    - (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile
               encoding:(NSStringEncoding)enc error:(NSError **)error
    {
        //printf("writeToFile: replacement\n");
        return [self writeToFile:path atomically:useAuxiliaryFile];    // <= 10.4
    }
#   endif
#endif


/* return string from float with 4 decimals
 */
+ (NSString*)stringWithFloat:(float)value
{   int			i;
    NSMutableString	*string;
    NSRange		range;
    char		c;

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

/* created:      2006-02-24 (2004-12-12)
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
+ (NSString*)stringWithFloat:(float)value decimals:(int)decimals
{   int			i;
    NSString		*format = [NSString stringWithFormat:@"%%.%df", decimals];
    NSMutableString	*string;
    NSRange		range;
    char		c;

    value += 0.000005;

    //if (value < limits.min)
    //    value = limits.min;
    //if (value > limits.max)
    //    value = limits.max;
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



- (NSString*)stringByRemovingTrailingCharacters:(NSString*)chars
{   NSRange	range;
    int		ix = [self length];

    while (1)
    {
        range = [self rangeOfString:chars options:NSBackwardsSearch range:NSMakeRange(0, ix)];
        if ( !range.length || range.location < ix-1 )
            break;
        ix = range.location;
    }
    return [self substringToIndex:ix];
}

/* created:  1997-11-20
 * modified: 2001-01-19
 * replace all apearances of 'from' by 'to'
 */
- (NSString*)stringByReplacing:(NSString*)from by:(NSString*)to
{
    return [self stringByReplacing:from by:to all:YES];
}
- (NSString*)stringByReplacing:(NSString*)from by:(NSString*)to all:(BOOL)replaceAll;
{   NSRange         range, searchRange;
    NSMutableString *mutString = [NSMutableString string];
    int             start = 0;

    searchRange = NSMakeRange(0, [self length]);
    while ( searchRange.length )
    {
        range = [self rangeOfString:from options:NSCaseInsensitiveSearch range:searchRange];
        if ( !range.length )
            break;
        [mutString appendString:[self substringWithRange:NSMakeRange(start, range.location-start)]];
        [mutString appendString:to];

        start = searchRange.location = range.location+[from length];
        if (!replaceAll)
            break;
        searchRange.length = [self length] - searchRange.location;
    }
    [mutString appendString:[self substringFromIndex:start]];

    return mutString;
}

/* modified: 2000-11-13
 *
 * range of sequence
 * '#' -> skip number "0123456789-+."
 * '*' -> skip all
 * '_' -> skip white space " \t"
 * '?' -> skip single character
 *
 * sequence = "In the year #"
 */
- (NSString*)stringByReplacingSequence:(NSString*)sequence by:(NSString*)to
{   NSDictionary	*wildcards = [NSDictionary dictionaryWithObjectsAndKeys:@"#", @"skipNum", @"*", @"skipAll", @"_", @"skipSpace", @"?", @"skipChar", @"|", @"skipChars", @"", @"chars", nil];

    return [self stringByReplacingSequence:sequence by:to wildcards:wildcards];
}
/*
 * wildcards =
 * {
 *     skipNum = "#";
 *     skipAll = "*";
 *     skipSpace = "_";
 *     skipChar = "?";
 *     skipChars = "|";
 *     chars = "bla";
 * }
 */
- (NSString*)stringByReplacingSequence:(NSString*)sequence by:(NSString*)to wildcards:(NSDictionary*)wildcards
{   NSRange		range, searchRange;
    NSMutableString	*mutString = [NSMutableString string];
    int			start = 0;

    searchRange = NSMakeRange(0, [self length]);
    while ( searchRange.length )
    {
        range = [self rangeOfSequence:sequence options:NSCaseInsensitiveSearch range:searchRange wildcards:wildcards];
        if ( !range.length )
            break;
        [mutString appendString:[self substringWithRange:NSMakeRange(start, range.location-start)]];
        [mutString appendString:to];

        start = searchRange.location = range.location + range.length;
        searchRange.length = [self length] - searchRange.location;
    }
    [mutString appendString:[self substringFromIndex:start]];

    return mutString;
}

/* 14.000 -> 14000
 * 14,000 -> 14000
 * 14.00 -> 14.00
 * 14,00 -> 14.00
 * 14,- -> 14
 * and so on
 */
- (NSString*)stringByAdjustingDecimal
{   NSString	*string;
    int		j, i, d;

    /* copy up to non digit to string (14.000 -> 14) */
    for ( j=0; j<(int)[self length]; j++ )
        if ( !strchr("0123456789", [self characterAtIndex:j]) )
            break;
    j = (j<0) ? 0 : (j>(int)[self length]) ? (int)[self length] : j;
    string = [self substringWithRange:NSMakeRange(0, j)];

    /* j = . or , */
    if ( j<(int)[self length] && ([self characterAtIndex:j] == '.' || [self characterAtIndex:j] == ',') )
    {
        j++;
        for ( i=j, d=0; i<(int)[self length]; i++, d++ )
            if ( !strchr("0123456789", [self characterAtIndex:i]) )
                break;
        if ( d>=3 )
            string = [string stringByAppendingString:[self substringWithRange:NSMakeRange(j, d)]];
        else if ( d )
            string = [string stringByAppendingFormat:@".%@", [self substringWithRange:NSMakeRange(j, d)]];
    }

    return string;
}

/* created: 1999-02-16
 * < 0 -> right aligned
 * > 0 -> left  aligned
 */
- (NSString*)stringWithLength:(int)length
{
    return [self stringWithLength:length fillCharacter:@" "];
}

- (NSString*)stringWithLength:(int)length fillCharacter:(NSString*)fillChar
{   int             i, space;
    NSMutableString *newString;
    BOOL            alignLeft = YES;

    if (length < 0)
    {
        alignLeft = NO;
        length = -length;
    }

    /* ok */
    if ( (int)[self length] == length )
        return self;
    /* too long */
    if ( (int)[self length] > length )
        return [self substringToIndex:length];
    /* too short */
    newString = (NSMutableString*)[NSMutableString string];
    space = length - [self length];
    for ( i=0; i<space; i++ )
        [newString appendString:fillChar];
    if ( alignLeft )
        return [self stringByAppendingString:newString];
    else
        [newString appendString:self];
    return newString;
}


/*
 */
- (int)appearanceCountOfCharacter:(unsigned char)c
{   int	i, cnt = [self length], num = 0;

    for (i=0; i<cnt; i++)
        if ( [self characterAtIndex:i] == c )
            num++;
    return num;
}

/* created: 2004-05-22
 */
- (int)countOfCharacter:(unsigned char)c inRange:(NSRange)range
{   int	i, num = 0;

    for (i=range.location; i<range.location+range.length; i++)
        if ( [self characterAtIndex:i] == c )
            num++;
    return num;
}



/* created:  1997-05-31
 * modified: 2000-11-13
 *
 * range of sequence
 * '#' -> skip number "0123456789-+."
 * '~' -> skip all
 * '?' -> skip single character
 * '_' -> skip white space " \t"
 * '|' -> skip characters;
 *
 * characters = ".,;- \t"
 * sequence = "EZ #/" or "Blondine~Jahre"
 */
- (NSRange)rangeOfSequence:(NSString*)sequence options:(int)options
{
    return [self rangeOfSequence:sequence options:options range:NSMakeRange(0, [self length])];
}

- (NSRange)rangeOfSequence:(NSString*)sequence options:(int)options range:(NSRange)sRange
{   NSDictionary	*wildcards = [NSDictionary dictionaryWithObjectsAndKeys:@"#", @"skipNum", @"~", @"skipAll", @"_", @"skipSpace", @"?", @"skipChar", @"|", @"skipChars", @".,- \t", @"chars", nil];

    return [self rangeOfSequence:sequence options:options range:sRange wildcards:(NSDictionary*)wildcards];
}

/*
 * return range of sequence (mask of string with wildcards) within self
 *
 * wildcards =
 * {
 *     skipNum   = "#";         // "#"       skip digits (0123456789) also skips trailing ".,-"
 *     skipAll   = "~";         // "~"       skip any characters
 *     skipSpace = "_";         // "_"       skip space
 *     skipChar  = "?";         // "?"       skip single character
 *     skipChars = "|";         // "|"       skip range of characters containing chars
 *     chars     = ".,- \t";    // ".,- \t"  characters to be skipped
 * }
 * TODO: we should add a regexp syntax: [0-9] instead, and remove ".,-" from #
 */
- (NSRange)rangeOfSequence:(NSString*)sequence options:(int)options
                     range:(NSRange)sRange wildcards:(NSDictionary*)wildcards
{   NSMutableArray	*tokens = [NSMutableArray array];
    NSString		*skipNum   = [wildcards objectForKey:@"skipNum"];
    NSString		*skipAll   = [wildcards objectForKey:@"skipAll"];
    NSString		*skipChar  = [wildcards objectForKey:@"skipChar"];
    NSString		*skipSpace = [wildcards objectForKey:@"skipSpace"];
    NSString		*skipChars = [wildcards objectForKey:@"skipChars"];
    NSMutableString	*mutString = [NSMutableString string];
    NSCharacterSet	*wildcardSet;
    NSCharacterSet	*digitsSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    NSCharacterSet 	*whiteSpaceSet = [NSCharacterSet characterSetWithCharactersInString:@" \t"];
    NSCharacterSet 	*charsSet = nil;
    NSRange		searchRange, range, seqRange = NSMakeRange(0, 0);
    int			i, cnt, j;
    BOOL		start = YES;

    if (skipChars && [wildcards objectForKey:@"chars"])
        charsSet = [NSCharacterSet characterSetWithCharactersInString:[wildcards objectForKey:@"chars"]];

    if (skipAll)
        [mutString appendString:skipAll];
    if (skipNum)
        [mutString appendString:skipNum];
    if (skipSpace)
        [mutString appendString:skipSpace];
    if (skipChar)
        [mutString appendString:skipChar];
    if (skipChars && !charsSet)
        [mutString appendString:skipChars];
    wildcardSet = [NSCharacterSet characterSetWithCharactersInString:mutString];

    options &= NSCaseInsensitiveSearch;

    searchRange = NSMakeRange(0, [sequence length]);
    while ( 1 )
    {
        range = [sequence rangeOfCharacterFromSet:wildcardSet options:0 range:searchRange];
        if ( !range.length )
            break;
        if ( range.location && range.location!=searchRange.location )
            [tokens addObject:[sequence substringWithRange:NSMakeRange(searchRange.location, range.location-searchRange.location)]];
        [tokens addObject:[sequence substringWithRange:range]];
        searchRange.location = range.location + range.length;
        searchRange.length = [sequence length] - searchRange.location;
    }
    if ( searchRange.location < [sequence length] )
        [tokens addObject:[sequence substringFromIndex:searchRange.location]];

    searchRange = sRange;
    while ( searchRange.length )
    {
        for ( i=0, cnt=[tokens count]; i<cnt; i++ )
        {   NSString	*token = [tokens objectAtIndex:i];

            if ( !searchRange.length )
                break;
            if ( skipSpace && [token isEqual:skipSpace] )
            {
                if (!i)
                {
                    range = [self rangeOfCharacterFromSet:whiteSpaceSet options:0 range:searchRange];
                    if (!range.length)
                        return seqRange;
                    seqRange.location = searchRange.location = range.location;
                    searchRange.length = [self length] - searchRange.location;
                }
                for ( j = searchRange.location; j<(int)(searchRange.location+searchRange.length); j++ )
                    if ( !strchr(" \t", [self characterAtIndex:j]) )
                        break;
                if ( j == (int)searchRange.location )
                    break;
                searchRange.location = j;
            }
            else if ( skipChar && [token isEqual:skipChar] )
            {
                searchRange.location++;
                if (!i)
                    seqRange.location = searchRange.location;
            }
            else if ( skipChars && [token isEqual:skipChars] )
            {
                if (!i)
                {
                    if ( start && !searchRange.location )	// start of line is a char too
                    {   seqRange.location = 0;
                        start = NO;
                    }
                    else
                    {   range = [self rangeOfCharacterFromSet:charsSet options:0 range:searchRange];
                        if (!range.length)
                            return seqRange;
                        seqRange.location = range.location;
                        searchRange.location = range.location + range.length;
                        searchRange.length = [self length] - searchRange.location;
                    }
                }
                else
                {
                    for ( j = searchRange.location; j<(int)(searchRange.location+searchRange.length); j++ )
                        if ( !strchr([[wildcards objectForKey:@"chars"] cString], [self characterAtIndex:j]) )
                            break;
                    if ( j == (int)searchRange.location )
                        break;
                    searchRange.location = j;
                }
            }
            else if ( skipAll && [token isEqual:skipAll] )
            {
                if (!i)	/* not supported */
                    return seqRange;
                if ( i+1 < (int)[tokens count] )
                    range = [self rangeOfString:[tokens objectAtIndex:i+1] options:options range:searchRange];
                else	/* up to white space */
                    range = [self rangeOfCharacterFromSet:whiteSpaceSet options:0 range:searchRange];
                if ( !range.length )	// end of string 'string*'
                {
                    if (i+1 == cnt)	// no tokens left -> successfully done
                        searchRange.location = searchRange.location + searchRange.length;
                    else		// we can't fullfill the remaining tokens -> no success
                        break;
                }
                else
                    searchRange.location = range.location;
            }
            else if ( skipNum && [token isEqual:skipNum] )
            {
                if (!i)
                {
                    range = [self rangeOfCharacterFromSet:digitsSet options:0 range:searchRange];
                    if (!range.length)
                        return seqRange;
                    seqRange.location = searchRange.location = range.location;
                    searchRange.length = [self length] - searchRange.location;
                }
                for ( j=searchRange.location; j<(int)(searchRange.location+searchRange.length); j++ )
                    if ( !strchr("0123456789.,-", [self characterAtIndex:j]) )
                        break;
                if ( j == (int)searchRange.location )
                    break;
                searchRange.location = j;
            }
            else
            {
                range = [self rangeOfString:token options:options range:searchRange];
                if ( !range.length )
                    return seqRange;
                if ( !i )
                    seqRange.location = range.location;
                else if ( range.location>searchRange.location )
                    break;
                searchRange.location = range.location + range.length;
            }
            searchRange.length = [self length] - searchRange.location;
        }
        if ( i>=cnt )
        {   seqRange.length = searchRange.location - seqRange.location;
            break;
        }
    }
    return seqRange;
}

#if 0   // should go into NSMutableString
/* created: 2008-11-08
 *
 * wildcards:
 * '#' -> skip number "0123456789-+."
 * '*' -> skip all
 * '_' -> skip white space " \t"
 * '?' -> skip single character
 *
 * sequence = "In the year #"
 */
- (void)replaceCharactersAfterSequence:(NSString*)seqFr toSequence:(NSString*)seqTo by:(NSString*)string
{   NSRange     range;
    int         frIx, toIx;
    NSDictionary	*wildcards = [NSDictionary dictionaryWithObjectsAndKeys:
                    @"#", @"skipNum",
                    @"*", @"skipAll",
                    @"_", @"skipSpace",
                    @"?", @"skipChar",
                    @"|", @"skipChars", @"", @"chars", nil];

    range = [self rangeOfSequence:seqFr options:0 /*range:NSMakeRange(0. [string length]) wildcards:wildcards*/];
    if (!range.length)
        return;
    frIx = range.location+range.length;
    range = [self rangeOfSequence:seqTo options:0 range:NSMakeRange(frIx, [self length]-frIx) /*wildcards:wildcards*/];
    if (!range.length)
        return;
    toIx = range.location;
    return [self replaceCharactersInRange:NSMakeRange(frIx, toIx-frIx) withString:string];
}
#endif

@end
