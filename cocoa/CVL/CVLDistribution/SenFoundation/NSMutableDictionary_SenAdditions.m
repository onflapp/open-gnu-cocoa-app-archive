/*$Id: NSMutableDictionary_SenAdditions.m,v 1.9 2005/02/28 13:32:29 stephane Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSMutableDictionary_SenAdditions.h"
@implementation NSDictionary (SenAdditions)
- (id) objectForInt:(int) anInt
{
    return [self objectForKey:[[NSNumber numberWithInt:anInt] stringValue]];
}

- (id) senDeepMutableCopy
{
    NSMutableDictionary	*aCopy = [[NSMutableDictionary alloc] initWithCapacity:[self count]];
    NSEnumerator		*anEnum = [self keyEnumerator];
    id					aKey;
    NSZone              *aZone = NSDefaultMallocZone();

    while ( (aKey = [anEnum nextObject]) ) {
        id	aKeyCopy;
        id	aValueCopy;
        id	aValue = [self objectForKey:aKey];

        // Do not use -copy/mutableCopy, because they are defined in NSObject!
        if([aKey respondsToSelector:@selector(senDeepMutableCopy)])
            aKeyCopy = [aKey senDeepMutableCopy];
        else if([aKey respondsToSelector:@selector(mutableCopyWithZone:)])
            aKeyCopy = [aKey mutableCopyWithZone:aZone];
        else if([aKey respondsToSelector:@selector(copyWithZone:)])
            aKeyCopy = [aKey copyWithZone:aZone];
        else
            aKeyCopy = [aKey retain];
        if([aValue respondsToSelector:@selector(senDeepMutableCopy)])
            aValueCopy = [aValue senDeepMutableCopy];
        else if([aValue respondsToSelector:@selector(mutableCopyWithZone:)])
            aValueCopy = [aValue mutableCopyWithZone:aZone];
        else if([aValue respondsToSelector:@selector(copyWithZone:)])
            aValueCopy = [aValue copyWithZone:aZone];
        else
            aValueCopy = [aValue retain];
        [aCopy setObject:aValueCopy forKey:aKeyCopy];
        [aKeyCopy release];
        [aValueCopy release];
    }

    return aCopy;
}

@end

@implementation NSMutableDictionary (SenAdditions)
- (id) objectForKey:(id) aKey setObjectIfAbsent:(id) anObject
{
    id value = [self objectForKey:aKey];
    if (value == nil){
        [self setObject:anObject forKey:aKey];
        return anObject;
    }
    return value;
}
@end
