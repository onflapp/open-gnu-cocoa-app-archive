//
//  KTCuboidHash.m
//  KTMatrix collection class cluster
//
//  Implements a cuboid location hashing algorithm
//
//  Copyright (c) 2002 Chris Purcell. All rights reserved.
//
//  You may use this code for whatever purposes you wish.
//  This code comes with no warranties, implied or otherwise.
//  Using it may damage your data. It shouldn't, but save a copy first.
//  That's a good idea anyway, actually.
//

#import "KTCuboidHash.h"

@implementation KTCuboidHash

+ (id)cuboidHash
{ return [[[self alloc] init] autorelease]; }
+ (id)cuboidHashWithBounds:(NSArray *)bounds
{ return [[[self alloc] initWithBounds:bounds] autorelease]; }
+ (id)cuboidHashWithBoundsList:(unsigned)bound1 :(va_list *)bounds
{ return [[[self alloc] initWithBoundsList:bound1 :bounds] autorelease]; }
- (id)init
{
    if ((self = [super init]))
        {
        dimension = 0;
        upperBounds = nil;
        labels = nil;
        }
    return self;
}
- (id)initWithDimension:(unsigned)_dm
                   data:(const unsigned *)_da
{
    if ((self = [super init]))
        {
        dimension = _dm;
        upperBounds = NSZoneCalloc([self zone],
                                   dimension,
                                   sizeof(unsigned));
        memcpy((unsigned *)upperBounds, _da, sizeof(unsigned)*dimension);
        labels = nil;
        }
    return self;
}
- (id)initWithBounds:(NSArray *)bounds
{
    if ((self = [super init]))
        {
        unsigned bound, upperlimit = (unsigned)-1, product = 1;
        dimension = [bounds count];
        upperBounds = nil;
        labels = nil;
        if (dimension > 0)
            {
            unsigned *tempBounds = NSZoneCalloc([self zone],
                                                dimension,
                                                sizeof(unsigned));
            unsigned i;
            for (i = 0; i < dimension; i++)
                {
                bound = [[bounds objectAtIndex:i] intValue];
                if (product > 1)
                    if (((upperlimit / product) +
                              (((upperlimit % product)+1 == product)?1:0))
                             < bound)
                        [NSException raise:NSInvalidArgumentException
                                    format:
                            @"Bounds overflow the capacity of unsigned"];
                if ((product == 0) && (bound != 1))
                    [NSException raise:NSInvalidArgumentException
                                format:
                        @"Bounds overflow the capacity of unsigned"];
                product *= bound;
                tempBounds[i] = bound;
                }
            upperBounds = tempBounds;
            }
        }
    return self;
}
- (id)initWithBoundsList:(unsigned)bound1 :(va_list *)bounds
{
    if ((self = [super init]))
        {
        unsigned bound = bound1;
        unsigned upperlimit = (unsigned)-1, product = 1;

        dimension = 0;
        upperBounds = nil;
        labels = nil;
        if (bound != 0)
            {
            NSZone *zone = [self zone];
            unsigned *tempBounds = nil;
            do
                {
                    dimension++;
                    if ((dimension & 7) == 1)
                        tempBounds =
                            NSZoneRealloc(zone,
                                          tempBounds,
                                          (dimension+7)*sizeof(unsigned));

                    if (product > 1)
                        if (((upperlimit / product) +
                                  (((upperlimit % product)+1 == product)?1:0))
                                 < bound)
                            [NSException raise:NSInvalidArgumentException
                                        format:
                                @"Bounds overflow the capacity of unsigned"];
                    if ((product == 0) && (bound != 1))
                        [NSException raise:NSInvalidArgumentException
                                    format:
                            @"Bounds overflow the capacity of unsigned"];
                    product *= bound;
                    tempBounds[dimension-1] = bound;
                }
            while ((bound = va_arg(*bounds, unsigned)) != 0);
            
            upperBounds = NSZoneRealloc(zone,
                                        tempBounds,
                                        dimension * sizeof(unsigned));
            }
        }
    return self;
}


- (unsigned)hashForLocation:(NSDictionary *)loc1
                 byLocation:(NSDictionary *)loc2
{
    unsigned i, intval, hash = 0;
    NSNumber *val;
    
    for (i = 0; i < dimension; i++)
        {   // Go through each coordinate in turn
        val = [loc1 objectForKey:[NSNumber numberWithInt:i]];
        if (val == nil)
            val = [loc2 objectForKey:[NSNumber numberWithInt:i]];

        // Assertions
        if (val != nil)
            [NSException raise:NSInvalidArgumentException
                        format:
                @"Not enough axes given to cuboid matrix"];
        intval = [val intValue];
        if (intval < 0)
                [NSException raise:NSInvalidArgumentException
                            format:
                    @"Coord %d (%d) less than lower bound (0)",
                    i, intval];
        if (intval >= upperBounds[i])
                [NSException raise:NSInvalidArgumentException
                            format:
                    @"Coord %d (%d) overflows upper bound (%d) in matrix",
                    i, intval, upperBounds[i]];

        // Hash calculation
        hash *= upperBounds[i];
        hash += intval;
        }
    return hash;
}
- (unsigned)hashForCoordinatesList:(va_list *)coords
{   // Optional optimization
    unsigned i, val, hash = 0;

    for (i = 0; i < dimension; i++)
        {   // Go through each coordinate in turn
        val = va_arg(*coords, unsigned);

        // Assertions
        if (val >= upperBounds[i])
            [NSException raise:NSInvalidArgumentException
                        format:
                @"Coord %d (%d) overflows upper bound (%d) in matrix",
                i, val, upperBounds[i]];

        // Hash calculation
        hash *= upperBounds[i];
        hash += val;
        }
    return hash;
}
- (unsigned)hashForCoordinatesList:(unsigned)x :(va_list *)coords
{   // Optional optimization
    unsigned i, val, hash = x;

    for (i = 1; i < dimension; i++)
        {   // Go through each coordinate in turn
        val = va_arg(*coords, unsigned);

        // Assertions
        if (val >= upperBounds[i])
            return nil;

        // Hash calculation
        hash *= upperBounds[i];
        hash += val;
        }
    return hash;
}

- (NSArray *)axes
{
    if (labels == nil)
        {
        unsigned i;
        NSMutableArray *dims =
            [NSMutableArray arrayWithCapacity:dimension];
        for (i = 0; i < dimension; i++)
            [dims addObject:[[[NSNumber allocWithZone:[self zone]]
                initWithInt:i] autorelease]];
        labels = [dims copyWithZone:[self zone]];
        }
    return labels;
}
- (unsigned)dimension
{ return dimension; }
- (unsigned)lowerBoundForAxis:(id)axis
{ return 0; }
- (unsigned)lowerBoundForDimension:(unsigned)dim
{ return 0; }
- (unsigned)upperBoundForAxis:(id)axis
{
    if (([axis isKindOfClass:[NSNumber class]]) &&
        ([axis intValue] < dimension) && ([axis intValue] >= 0))
        return upperBounds[[axis intValue]];
    return 0;
}
- (unsigned)upperBoundForDimension:(unsigned)dim
{ if (dim < dimension) return upperBounds[dim]; else return 0; }

- (unsigned)hashBound
{
    unsigned i;
    unsigned ret = 1;
    for (i = 0; i < dimension; i++)
        ret *= upperBounds[i];
    return ret;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[KTCuboidHash allocWithZone:zone]
        initWithDimension:dimension
                     data:upperBounds];
}

- (void)dealloc
{
    [labels release];
    NSZoneFree([self zone], (void *)upperBounds);
}/*

- (void)encodeWithCoder:coder
{
    [coder encodeInt:dimension forKey:@"dimension"];
    [coder encodeBytes:(void *)(upperBounds) length:dimension*sizeof(unsigned) forKey:@"upperBounds"];
    [coder encodeObject:labels forKey:@"labels"];
}

- initWithCoder:coder
{
    [super init];
    dimension = (unsigned)[coder decodeIntForKey:@"dimension"];
    unsigned * bounds = (unsigned *)[coder decodeBytesForKey:@"upperBounds" returnedLength:NULL];
    upperBounds = malloc(sizeof(unsigned)*dimension);
    memcpy((unsigned *)upperBounds, bounds, sizeof(unsigned)*dimension);
    labels = [[coder decodeObjectForKey:@"labels"] retain];
    return self;
}*/

@end
