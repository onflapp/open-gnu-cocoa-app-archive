/* VHFDictionaryAdditions.m
 * vhf NSDictionary additions
 *
 * Copyright (C) 1997-2009 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997-07-08
 * modified: 2009-04-18 (-v3PointForKey:, -setV3Point:forKey:)
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

#include "VHFDictionaryAdditions.h"

@implementation NSDictionary(VHFDictionaryAdditions)

/* created:  1997-08-20
 * modified: 
 */
- (NSString*)stringForKey:(id)key
{   id	obj = [self objectForKey:key];

    if ( [obj isKindOfClass:[NSNumber class]] )
        return [obj stringValue];
    //else if ( [obj isKindOfClass:[NSCalendarDate class]] )
    //    return [obj descriptionWithCalendarFormat:calendarFormat];
    else if ( [obj isKindOfClass:[NSDate class]] )
        return [obj description];
    return obj;
}

/* created:  20.08.97
 * modified:
 */
- (NSNumber*)numberForKey:(id)key
{   id	obj = [self objectForKey:key];

    if ( [obj isKindOfClass:[NSString class]] )
        return [NSNumber numberWithInt:[obj intValue]];
    else if ( [obj isKindOfClass:[NSNumber class]] )
        return obj;
    return [NSNumber numberWithInt:0];
}

/* created:  2010-05-07
 * modified: 
 */
- (BOOL)boolForKey:(id)key
{   id	obj = [self objectForKey:key];

    if ( [obj isKindOfClass:[NSString class]] )
    {   unichar ch = [obj characterAtIndex:0];

        if ( ch == 'Y' || ch == 'y' || [obj intValue] )
            return YES;
    }
    else if ( [obj isKindOfClass:[NSNumber class]] && [obj intValue])
        return YES;
    return NO;
}

/* created:  20.08.97
 * modified:
 */
- (int)intForKey:(id)key
{   id	obj = [self objectForKey:key];

    if ( [obj respondsToSelector:@selector(intValue)] )
        return [obj intValue];
    return 0;
}

/* created:  20.08.97
 * modified:
 */
- (float)floatForKey:(id)key
{   id	obj = [self objectForKey:key];

    if ( [obj respondsToSelector:@selector(floatValue)] )
        return [obj floatValue];
    return 0.0;
}

/* created:  20.08.97
 * modified:
 */
- (double)doubleForKey:(id)key
{   id	obj = [self objectForKey:key];

    if ( [obj respondsToSelector:@selector(doubleValue)] )
        return [obj doubleValue];
    return 0.0;
}

/* created: 22.10.97
 */
- (BOOL)containsPrefix:(NSString*)prefix
{   NSEnumerator	*enumerator = [self keyEnumerator];
    NSString		*key;

    while ( (key = [enumerator nextObject]) )
        if ( [key hasPrefix:prefix] )
            return YES;
    return NO;
}


- (V3Point)v3PointForKey:(id)key
{   V3Point pt;
    NSArray *components = [[self objectForKey:key] componentsSeparatedByString:@" "];

    if ([components count] < 3)
    {   pt.x = pt.y = pt.z = 0.0;
        return pt;
    }
    pt.x = [[components objectAtIndex:0] floatValue];
    pt.y = [[components objectAtIndex:1] floatValue];
    pt.z = [[components objectAtIndex:2] floatValue];
    return pt;
}

@end


@implementation NSMutableDictionary(VHFDictionaryAdditions)
- (void)setInt:(int)i forKey:(id)key
{
    [self setObject:[NSNumber numberWithInt:i] forKey:key];
}

- (void)setFloat:(float)f forKey:(id)key
{
    [self setObject:[NSNumber numberWithFloat:f] forKey:key];
}

- (void)setDouble:(double)d forKey:(id)key
{
    [self setObject:[NSNumber numberWithDouble:d] forKey:key];
}

- (void)setV3Point:(V3Point) pt forKey:(id)key
{
    [self setObject:[NSString stringWithFormat:@"%g %g %g", pt.x, pt.y, pt.z]
             forKey:key];
}


/* compressed property list
 */
/*- (NSString)descriptionCompressed:(BOOL)flag
{   NSArray	*keys = [self allKeys];
    int		i;

    for (i=0, cnt=[keys count]; i<cnt; i++)
    {
        [[self objectForKey:[keys objectAtIndex:i]] description];
    }
}*/

@end
