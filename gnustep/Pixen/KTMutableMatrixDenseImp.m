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

#import "KTMutableMatrixDenseImp.h"
#import "KTMatrixDenseEnumerator.h"

@implementation KTMutableMatrixDenseImp

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
+ (id)matrixWithCapacity:(unsigned)numItems
            locationHash:(id<KTLocationHash>)_hs
{
    return [[[self alloc] initWithCapacity:numItems
                              locationHash:_hs] autorelease];
}
- (id)initWithMatrix:(KTMatrix *)other
{
    if ((self = [super init]))
        {
        NSEnumerator<KTMatrixEnumerator> *j = [other objectEnumeratorRetained];

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
        if ([j conformsToProtocol:@protocol(KTMatrixEnumerator)])
            {
            id object;
            while ((object = [j nextObject]))
                {
                array[[j hashedLocation]] = [object retain];
                count++;
                }
            }
        else
            {
            NSNumber *key;
            NSDictionary *matrixData = [other matrixData];
            NSEnumerator *k = [matrixData keyEnumerator];

            while ((key = [k nextObject]))
                {
                array[[key intValue]] = [[matrixData objectForKey:key] retain];
                count++;
                }
            }
        [j release];
        }
    return self;
}
- (id)initWithMatrixData:(NSDictionary *)matrixData
            locationHash:(id<KTLocationHash>)locationHash
{
    if ((self = [super init]))
        {
        NSNumber *key;
        NSEnumerator *k = [matrixData keyEnumerator];
        
        // Deal with the hashing object
        if (NSShouldRetainWithZone(locationHash, [self zone]))
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
        hashIsCoordinateOptimized = [hash conformsToProtocol:
            @protocol(KTLocationHashCoordinatesOptimization)];

        // Allocate memory for the storage array
        count    = 0;
        capacity = [hash hashBound];
        array    = NSZoneCalloc([self zone],
                                capacity,
                                sizeof(unsigned));

        // Fill the array
        while ((key = [k nextObject]))
            {
            array[[key intValue]] = [[matrixData objectForKey:key] retain];
            count++;
            }
        }
    return self;
}
- (id)initWithLocationHash:(id<KTLocationHash>)locationHash
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
        count    = 0;
        capacity = [hash hashBound];
        array    = NSZoneCalloc([self zone],
                                capacity,
                                sizeof(unsigned));
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
        unsigned i;
        id *position;
        
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
        
        // Fill the storage array
        for (i = 0; i < [loc1s count]; i++)
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
- (id)initWithCapacity:(unsigned)numItems
          locationHash:(id<KTLocationHash>)locationHash
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
        count    = 0;
        capacity = [hash hashBound];
        array    = NSZoneCalloc([self zone],
                                capacity,
                                sizeof(unsigned));
        }
    return self;
}

//// Optimized versions
- (id)initWithLocationHash:(id<KTLocationHash>)locationHash
                    object:(id)object
          atHashedLocation:(unsigned)loc
{
    if ((self = [super init]))
        {   // Deal with the hashing object
        if (NSShouldRetainWithZone(locationHash, [self zone]))
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
        hashIsCoordinateOptimized = [hash
            conformsToProtocol:@protocol(KTLocationHashCoordinatesOptimization)];

        // Allocate memory for the storage array
        count    = 1;
        capacity = [hash hashBound];
        array    = NSZoneCalloc([self zone],
                                capacity,
                                sizeof(unsigned));

        // Fill the storage array
        array[loc] = [object retain];
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


    //// Mutator methods
- (void)setMatrix:(KTMatrix *)other
{
    NSEnumerator<KTMatrixEnumerator> *j = [other objectEnumerator];

    [hash release];
    NSZoneFree([self zone], array);
    
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
    if ([j conformsToProtocol:@protocol(KTMatrixEnumerator)])
        {
        id object;
        while ((object = [j nextObject]))
            {
            array[[j hashedLocation]] = [object retain];
            count++;
            }
        }
    else
        {
        NSNumber *key;
        NSDictionary *matrixData = [other matrixData];
        NSEnumerator *k = [matrixData keyEnumerator];

        while ((key = [k nextObject]))
            {
            array[[key intValue]] = [[matrixData objectForKey:key] retain];
            count++;
            }
        }
}
- (void)setObject:(id)object
       atLocation:(NSDictionary *)loc1
       byLocation:(NSDictionary *)loc2
{
    id *position = &array[[hash
                    hashForLocation:loc1
                         byLocation:loc2]];
    if (*position != NULL)
        [*position release];
    else
        count++;
    *position = [object retain];
}
- (void)   setObject:(id)object
    atHashedLocation:(unsigned)loc
{
    if (array[loc] != NULL)
        [array[loc] release];
    else
        count++;
    array[loc] = [object retain];
}
- (void)removeObjectAtLocation:(NSDictionary *)loc1
                    byLocation:(NSDictionary *)loc2;
{
    id *position = &array[[hash
                    hashForLocation:loc1
                         byLocation:loc2]];
    if (*position != NULL)
        {
        [*position release];
        *position = NULL;
        count--;
        }
}
- (void)removeAllObjects
{
    unsigned i;

    for (i = 0; i < capacity; i++)
        {
        if (array[i])
            {
            [array[i] release];
            array[i] = NULL;
            }
        }
    count = 0;
}

//// Optimized versions
- (void)    setObject:(id)object
        atCoordinates:(unsigned)x,...
{
    va_list args;

    va_start(args, x);

    if (hashIsCoordinateOptimized)
        {
        id *position = &array[[(id)hash hashForCoordinatesList:x :&args]];
        if (*position != NULL)
            [*position release];
        else
            count++;
        *position = [object retain];
        }
    else
        {
        NSMutableArray *_array = [NSMutableArray arrayWithObject:
            [NSNumber numberWithInt:x]];
        unsigned axes = [self dimension];

        while ([_array count] < axes)
            [_array addObject:[NSNumber numberWithInt:va_arg(args, unsigned)]];

        va_end(args);
        [self setObject:object
      atCoordinateArray:_array];
        return;
        }
}
- (void)setObjectsAtCoordinates:(id)object1,...
{
    id object = object1;
    va_list args;

    if (object1 != 0)
        {
        va_start(args, object1);

        if (hashIsCoordinateOptimized)
            {
            // SELs/IMPs to speed up repeated method calls
            SEL hashListSEL = @selector(hashForCoordinatesList:);
            SEL setObjSEL = @selector(setObject:atHashedLocation:);
            unsigned (*hashListIMP)(id, SEL, ...);
            void (*setObjIMP)(id, SEL, ...);

            hashListIMP = (unsigned (*)(id, SEL, ...))
                [(id)hash methodForSelector:hashListSEL];
            setObjIMP = (void (*)(id, SEL, ...))
                [self methodForSelector:setObjSEL];
            do
                {
                    setObjIMP(self, setObjSEL, object,
                              hashListIMP(hash,hashListSEL,&args));
                }
            while (object = va_arg(args, id));
            }
        else
            {
            NSMutableArray *objects = [NSMutableArray array];
            NSMutableArray *coords  = [NSMutableArray array];
            unsigned dimension = [self dimension];

            do
                {
                    NSMutableArray *coord = [NSMutableArray arrayWithCapacity:
                        dimension];
                    [objects addObject:object];
                    while ([coord count] < dimension)
                        [coord addObject:[NSNumber numberWithInt:
                            va_arg(args, unsigned)]];
                    [coords addObject:coord];
                }
            while (object = va_arg(args, id));

            [self       setObjects:objects
                atCoordinateArrays:coords];
            }
        }

    va_end(args);
}
- (void)removeObjectAtCoordinates:(unsigned)x,...
{
    va_list args;

    va_start(args, x);

    if (hashIsCoordinateOptimized)
        {
        id *position = &array[[(id)hash hashForCoordinatesList:x :&args]];
        if (*position != NULL)
            {
            [*position release];
            *position = NULL;
            count--;
            }
        }
    else
        {
        NSMutableArray *_array = [NSMutableArray arrayWithObject:
            [NSNumber numberWithInt:x]];
        unsigned axes = [self dimension];

        while ([_array count] < axes)
            [_array addObject:[NSNumber numberWithInt:va_arg(args, unsigned)]];
        [self removeObjectAtCoordinateArray:_array];
        }

    va_end(args);
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
