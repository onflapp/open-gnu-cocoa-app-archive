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

#import <Foundation/Foundation.h>
#import "KTMatrix.h"

struct KTMatrixSparseElement
{
    unsigned hashedLocation;
    id object;
} ;


@interface KTMatrixSparseEnumerator : NSEnumerator<KTMatrixEnumerator>
{
    const struct KTMatrixSparseElement *array;
    BOOL broken;
    unsigned count;
    unsigned offset;
    id source;
}

- (id)initWithArray:(const struct KTMatrixSparseElement *)array
              count:(unsigned)count
         collection:(id)collection;

@end


@interface KTMutableMatrixSparseEnumerator : NSEnumerator<KTMatrixEnumerator>
{
    NSHashEnumerator data;
    struct KTMatrixSparseElement *lastLocation;
    id source;
}

- (id)initWithHashEnumerator:(NSHashEnumerator)enumerator
                  collection:(id)collection;

@end
