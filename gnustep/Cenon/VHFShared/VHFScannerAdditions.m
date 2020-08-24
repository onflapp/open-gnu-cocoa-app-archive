/* VHFScannerAdditions.m
 * vhf NSScanner additions
 *
 * Copyright (C) 1997-2003 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-04-01
 * modified: 2002-10-25
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

#include "VHFScannerAdditions.h"

@implementation NSScanner(VHFScannerAdditions)

/* scan up to sequence
 * a sequence is separated by space
 * sequence: '\" = \"'
 *
 * we need skip characters set !!!
 *
 * modified: 2000-12-03
 */
- (NSString*)scanUpToSequence:(NSString*)sequence
{   NSArray		*array = [sequence componentsSeparatedByString:@" "];
    int			i, cnt = [array count], location, start = [self scanLocation];
    NSString		*part;
    NSMutableString	*string = [NSMutableString string];

    if ( ![array count] )
        return nil;
    while ( ![self isAtEnd] )
    {
        if ( ![self scanUpToString:[array objectAtIndex:0] intoString:&part] )
            return nil;
        location = [self scanLocation];
        [string appendString:part];
        for ( i=0; i<cnt; i++ )
        {
            //[scanner setCharactersToBeSkipped:[NSScanner whitespaceCharacterSet]];
            //location = [scanner scanLocation];

            /* this was not our sequence
             * this construction skips spaces !!!!
             */
            if ( ![self scanString:[array objectAtIndex:i] intoString:&part] )
            {
                // we should scan starting at location
                [string appendString:part];
                break;
            }
        }
        if ( i>=cnt )
        {   [self setScanLocation:location];
            return string;
        }
    }
    [self setScanLocation:start];
    return nil;
}

@end
