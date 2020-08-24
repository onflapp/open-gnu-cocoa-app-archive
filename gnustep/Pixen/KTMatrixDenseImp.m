//
//  KTMatrixDenseImp
//  KTMatrix collection class cluster
//
//  KTMatrix class cluster implementation subclass
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

#import "KTMatrixDenseImp.h"
#import "KTMatrixDenseEnumerator.h"

@implementation KTMatrixDenseImp

+ (id)matrixWithMatrix:(KTMatrix *)other
{ return [[[self alloc] initWithMatrix:other] autorelease]; }
+ (id)matrixWithLocationHash:(id<KTLocationHash>)locationHash
                     objects:(NSArray *)objects
                 atLocations:(NSArray *)loc1s
                 byLocations:(NSArray *)loc2s
{
    return [[[self alloc] initWithLocationHash:locationHash
                                       objects:objects
                                   atLocations:loc1s
                                   byLocations:loc2s] autorelease];
}
- (id)initWithMatrix:(KTMatrix *)other
{
    NSEnumerator<KTMatrixEnumerator> *j = [other objectEnumeratorRetained];
    if ([j conformsToProtocol:@protocol(KTMatrixEnumerator)])
        {
        if ((self = [super init]))
            {
            id object;

            // Deal with the hashing object
            if (NSShouldRetainWithZone([other locationHash], [self zone]))
                hash = [[other locationHash] retain];
            else
                hash = [[other locationHash] copyWithZone:[self zone]];
            hashIsCoordinateOptimized = [hash conformsToProtocol:
                @protocol(KTLocationHashCoordinatesOptimization)];

            // Allocate memory for the storage array
            count    = 0;
            capacity = [hash hashBound];
            array    = NSZoneCalloc([self zone],
                                    capacity,
                                    sizeof(unsigned));

            // Fill the array
            while ((object = [j nextObject]))
                {
                array[[j hashedLocation]] = [object retain];
                count++;
                }
            }
        }
    else
        {
        self = [self initWithMatrixData:[other matrixData]
                           locationHash:[other locationHash]];
        }
    [j release];
    return self;
}
- (id)initWithMatrixData:(NSDictionary *)matrixData
            locationHash:(id<KTLocationHash>)locationHash
{
    if ((self = [super init]))
        {
        NSNumber *key;
        NSEnumerator *j = [matrixData keyEnumerator];

        // Deal with the hashing object
        if (NSShouldRetainWithZone(locationHash, [self zone]))
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
        hashIsCoordinateOptimized = [hash conformsToProtocol:
            @protocol(KTLocationHashCoordinatesOptimization)];

        // Allocate memory for the storage array
        count    = [matrixData count];
        capacity = [hash hashBound];
        array    = NSZoneCalloc([self zone],
                                capacity,
                                sizeof(unsigned));

        // Fill the array
        while ((key = [j nextObject]))
            array[[key intValue]] = [[matrixData objectForKey:key] retain];
        }
    return self;
}
- (id)initWithLocationHash:(id<KTLocationHash>)locationHash
                    object:(id)object
          atHashedLocation:(unsigned)loc
{
    if ((self = [super init]))
        {
        // Deal with the hashing object
        if (NSShouldRetainWithZone(locationHash, [self zone]))
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
        hashIsCoordinateOptimized = [hash conformsToProtocol:
            @protocol(KTLocationHashCoordinatesOptimization)];

        // Allocate memory for the storage array
        count    = 1;
        capacity = [hash hashBound];
        array    = NSZoneCalloc([self zone],
                                capacity,
                                sizeof(unsigned));

        // Fill the array
        array[loc] = [object retain];
        }
    return self;
}
- (id)initWithLocationHash:(id<KTLocationHash>)locationHash
                   objects:(NSArray *)objects
               atLocations:(NSArray *)loc1s
               byLocations:(NSArray *)loc2s
{
    if ((self = [super init]))
        {
        id *position;
        unsigned i;

        // Deal with the hashing object
        if (NSShouldRetainWithZone(locationHash, [self zone]))
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
        hashIsCoordinateOptimized = [hash conformsToProtocol:
            @protocol(KTLocationHashCoordinatesOptimization)];

        // Check the parameters are sane
        if ([objects count] != [loc1s count])
            [NSException raise:NSInvalidArgumentException
                        format:
                @"Objects and locations arrays not of equal length"];
        if ([loc1s count] != [loc2s count])
            [NSException raise:NSInvalidArgumentException
                        format:
                @"Locations arrays not of equal length"];

        // Allocate memory for the storage array
        count    = 0;
        capacity = [hash hashBound];
        array    = NSZoneCalloc([self zone],
                                capacity,
                                sizeof(unsigned));

        // Fill the array
        for (i = 0; i < [objects count]; i++)
            {
            position = &array[[hash
                    hashForLocation:[loc1s objectAtIndex:i]
                         byLocation:[loc2s objectAtIndex:i]]];
            if (*position != NULL)
                [*position release];
            else
                count++;
            *position = [[objects objectAtIndex:i] retain];
            }
        }
    return self;
}

// Accessor methods
- (id)objectAtLocation:(NSDictionary *)loc
            byLocation:(NSDictionary *)loc2;
{ return array[[hash hashForLocation:loc byLocation:loc2]]; }

    //// Optimized algorithms
- (id)objectAtCoordinates:(unsigned)x,...
{
    va_list args;

    va_start(args, x);

    if (hashIsCoordinateOptimized)
        {
        id ret = array[[(id)hash hashForCoordinatesList:x :&args]];
        va_end(args);
        return ret;
        }
    else
        {
        NSMutableArray *_array
        = [NSMutableArray arrayWithObject:[NSNumber numberWithInt:x]];
        unsigned axes = [self dimension];

        while ([_array count] < axes)
            [_array addObject:[NSNumber numberWithInt:va_arg(args, unsigned)]];

        va_end(args);

        return [self objectAtCoordinateArray:_array];
        }
}
- (unsigned)dimension
{
    if (hashIsCoordinateOptimized) return [(id)hash dimension];
    else return [[self axes] count];
}
- (unsigned)lowerBoundForDimension:(unsigned)dim
{
    if (hashIsCoordinateOptimized) return [(id)hash lowerBoundForDimension:dim];
    else return [self lowerBoundForAxis: [[self axes] objectAtIndex:dim]];
}
- (unsigned)upperBoundForDimension:(unsigned)dim
{
    if (hashIsCoordinateOptimized) return [(id)hash upperBoundForDimension:dim];
    else return [self upperBoundForAxis: [[self axes] objectAtIndex:dim]];
}


- (id<KTLocationHash>)locationHash
{ return hash; }
- (NSDictionary *)matrixData
{
    NSMutableDictionary *data = [NSMutableDictionary
            dictionaryWithCapacity:count];
    unsigned i;

    for (i = 0; i < capacity; i++)
        if (array[i])
            [data setObject:array[i]
                     forKey:[NSNumber numberWithInt:i]];
    return data;
}

- (NSEnumerator *)objectEnumerator
{
    return [[[KTMatrixDenseEnumerator allocWithZone:[self zone]]
        initWithArray:array
           ofCapacity:capacity
           collection:self] autorelease];
}
- (NSEnumerator *)objectEnumeratorRetained
{
    return [[KTMatrixDenseEnumerator allocWithZone:[self zone]]
        initWithArray:array
           ofCapacity:capacity
           collection:self];
}
- (unsigned)count
{ return count; }

- (id)copyWithZone:(NSZone *)zone
{
    if (NSShouldRetainWithZone(self, zone))
        return [self retain];
    else
        return [super copyWithZone:zone];
}

- (void)dealloc
{
    unsigned i;

    for (i = 0; i < capacity; i++)
        if (array[i])
            [array[i] release];
    [hash release];
    NSZoneFree([self zone], array);
    [super dealloc];
}
@end
