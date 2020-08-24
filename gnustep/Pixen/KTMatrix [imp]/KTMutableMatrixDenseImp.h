//
//  KTMatrixDenseImp
//  KTMatrix collection class cluster
//
//  KTMatrix class cluster mutable implementation subclass
//  Constant-time access to a mass-allocated chunk of memory
//  Ideal for mostly-populated matrices
//  Pointer arithmetic accounts for the speed
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

@interface KTMutableMatrixDenseImp : KTMutableMatrix
{
    id<KTLocationHash> hash;
    BOOL hashIsCoordinateOptimized;
    unsigned count;
    unsigned capacity;
    id *array;
}

- (id)initWithMatrixData:(NSDictionary *)matrixData
            locationHash:(id<KTLocationHash>)locationHash;
- (id)initWithLocationHash:(id<KTLocationHash>)locationHash
                    object:(id)object
          atHashedLocation:(unsigned)loc;

- (void)   setObject:(id)object
    atHashedLocation:(unsigned)loc;

@end
