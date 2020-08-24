//
//  KTCuboidHash.h
//  KTMatrix collection class cluster
//
//  Copyright (c) 2002 Chris Purcell. All rights reserved.
//
//  You may use this code for whatever purposes you wish.
//  This code comes with no warranties, implied or otherwise.
//  Using it may damage your data. It shouldn't, but save a copy first.
//  That's a good idea anyway, actually.
//

#import "KTMatrix.h"

@interface KTCuboidHash
: NSObject<KTLocationHash, KTLocationHashCoordinatesOptimization>
{
    unsigned dimension;
    const unsigned *upperBounds;
    NSArray *labels; // cached for speedy access
}

+ (id)cuboidHash;
+ (id)cuboidHashWithBounds:(NSArray *)bounds;
+ (id)cuboidHashWithBoundsList:(unsigned)bound1 :(va_list *)bounds;
- (id)initWithDimension:(unsigned)axes
                   data:(const unsigned *)data;
- (id)initWithBounds:(NSArray *)bounds;
- (id)initWithBoundsList:(unsigned)bound1 :(va_list *)bounds;

@end
