//
//  KTMatrixImp
//  KTMatrix
//
//  Implements an immutable KTMatrix subclass
//
//  Copyright (c) 2002 Chris Purcell. All rights reserved.
//
//  You may use this code for whatever purposes you wish.
//  This code comes with no warranties, implied or otherwise.
//  Using it may damage your data. It shouldn't, but save a copy first.
//  That's a good idea anyway, actually.
//

#import "KTMatrix.h"

@interface KTMatrixImp : KTMatrix
{
    NSDictionary *matrix;
    id<KTLocationHash> hash;
}

- (id)initWithMatrixData:(NSDictionary *)matrixData
            locationHash:(id<KTLocationHash>)locationHash;

@end
