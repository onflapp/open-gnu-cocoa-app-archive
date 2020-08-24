//
//  KTMatrixSparseEnumerator and KTMutableMatrixSparseEnumerator
//  KTMatrix collection class cluster
//
//  Enumerator classes for the sparse implementations of KTMatrix
//
//  Copyright (c) 2002 Chris Purcell. All rights reserved.
//
//  You may use this code for whatever purposes you wish.
//  This code comes with no warranties, implied or otherwise.
//  Using it may damage your data. It shouldn't, but save a copy first.
//  That's a good idea anyway, actually.
//

#import "KTMatrixSparseEnumerator.h"


@implementation KTMatrixSparseEnumerator

- (id)initWithArray:(const struct KTMatrixSparseElement *)_ar
              count:(unsigned)_co
         collection:(id)collection;
{
    if ((self = [super init]))
        {
        array = _ar;
        broken = NO;
        count = _co;
        offset = 0;
        source = [collection retain];
        }
    return self;
}
- (id)nextObject
{
    if (broken && (offset < count))
        offset++;
    broken = YES;
    if (offset < count)
        return array[offset].object;
    else
        return NULL;
}
- (unsigned)hashedLocation
{
    if (offset < count)
        return array[offset].hashedLocation;
    else
        return count;
}

- (void)dealloc
{
    [source release];
    [super dealloc];
}

@end


@implementation KTMutableMatrixSparseEnumerator

- (id)initWithHashEnumerator:(NSHashEnumerator)enumerator
                  collection:(id)collection
{
    if ((self = [super init]))
        {
        source = [collection retain];
        data = enumerator;
        }
    return self;
}
- (id)nextObject
{
    lastLocation = (struct KTMatrixSparseElement *)
    NSNextHashEnumeratorItem(&data);
    if (lastLocation)
        return lastLocation->object;
    else
        return NULL;
}
- (unsigned)hashedLocation
{
    if (lastLocation)
        return lastLocation->hashedLocation;
    else
        return 0;
}

- (void)dealloc
{
    NSEndHashTableEnumeration(&data);
    [source release];
    [super dealloc];
}

@end
