//
//  KTMatrixSparseImp
//  KTMatrix collection class cluster
//
//  KTMatrix class cluster implementation subclass
//  Fast access to a mass-allocated chunk of memory
//  Ideal for sparsely-populated matrices
//  Sacrifices some speed for a considerable potential memory saving
//  Uses a O(log(n)) binary search algorithm to find object
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

@interface KTMatrixSparseImp : KTMatrix
{   // The hashing object, used to translate locations to useful numbers
    id<KTLocationHash> hash;
    BOOL hashIsCoordinateOptimized;

    // A count of the objects we are storing
    unsigned count;
    
    // memory stores the elements of the matrix
    // It is sorted by hash value to enable fast binary searching
    void *memory;
}

- (id)initWithMatrixData:(NSDictionary *)matrixData
            locationHash:(id<KTLocationHash>)locationHash;
- (id)initWithLocationHash:(id<KTLocationHash>)locationHash
                    object:(id)object
          atHashedLocation:(unsigned)loc;

@end
