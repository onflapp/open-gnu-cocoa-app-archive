//
//  KTMutableMatrixSparseImp
//  KTMatrix collection class cluster
//
//  KTMatrix class cluster mutable implementation subclass
//  Uses hash tables to reference on-the-fly allocated memory
//  Ideal for sparsely-populated matrices
//  Sacrifices some speed for a considerable potential memory saving
//  Sacrifices some of those memory savings for mutability
//  Same object retrieval time as any hash table-based storage
//
//  Copyright (c) 2002 Chris Purcell. All rights reserved.
//
//  You may use this code for whatever purposes you wish.
//  This code comes with no warranties, implied or otherwise.
//  Using it may damage your data. It shouldn't, but save a copy first.
//  That's a good idea anyway, actually.
//

#import <Foundation/Foundation.h>
#import "KTMutableMatrix.h"

@interface KTMutableMatrixSparseImp : KTMutableMatrix
{
    NSHashTable *matrix;
    id<KTLocationHash> hash;
    BOOL hashIsCoordinateOptimized;
    void *cache;
}

- (id)initWithMatrixData:(NSDictionary *)matrixData
            locationHash:(id<KTLocationHash>)locationHash;
- (id)initWithLocationHash:(id<KTLocationHash>)locationHash
                    object:(id)object
          atHashedLocation:(unsigned)loc;

- (void)   setObject:(id)object
    atHashedLocation:(unsigned)loc;

@end
