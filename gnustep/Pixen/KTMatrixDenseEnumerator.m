//
//  KTMatrixDenseEnumerator
//  KTMatrix collection class cluster
//
//  Enumerator classes for the dense implementations of KTMatrix
//
//  Copyright (c) 2002 Chris Purcell. All rights reserved.
//
//  You may use this code for whatever purposes you wish.
//  This code comes with no warranties, implied or otherwise.
//  Using it may damage your data. It shouldn't, but save a copy first.
//  That's a good idea anyway, actually.
//

#import "KTMatrixDenseEnumerator.h"


@implementation KTMatrixDenseEnumerator

- (id)initWithArray:(const id *)_ar
         ofCapacity:(unsigned)_ca
         collection:(id)collection;
{
    if ((self = [super init]))
        {
        array = _ar;
        broken = NO;
        capacity = _ca;
        offset = 0;
        source = [collection retain];
        }
    return self;
}
- (id)nextObject
{
    if (broken && (offset < capacity))
        offset++;
    while ((offset < capacity) && (array[offset] == NULL))
        offset++;
    broken = YES;
    if (offset < capacity)
        return array[offset];
    else
        return NULL;
}
- (unsigned)hashedLocation
{ return offset; }

- (void)dealloc
{
    [source release];
    [super dealloc];
}

@end
