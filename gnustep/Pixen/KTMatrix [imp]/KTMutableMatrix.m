//
//  KTMutableMatrix
//  KTMatrix collection class cluster
//
//  Extends the KTMatrix class cluster with mutator methods
//
//  Copyright (c) 2002 Chris Purcell. All rights reserved.
//
//  You may use this code for whatever purposes you wish.
//  This code comes with no warranties, implied or otherwise.
//  Using it may damage your data. It shouldn't, but save a copy first.
//  That's a good idea anyway, actually.
//

#import "KTMutableMatrix.h"
#import "KTPlaceholderMutableMatrix.h"
#import "KTMutableMatrixSparseImp.h"
#import "KTMutableMatrixDenseImp.h"
#import "KTCuboidHash.h"

@implementation KTMutableMatrix

//// Allocators
+ (id)alloc
{
    if ([self isEqual:[KTMutableMatrix class]])
        return [KTPlaceholderMutableMatrix alloc];
    else
        return [super alloc];
}
+ (id)allocWithZone:(NSZone *)zone
{
    if ([self isEqual:[KTMutableMatrix class]])
        return [KTPlaceholderMutableMatrix allocWithZone:zone];
    else
        return [super allocWithZone:zone];
}

//// Constructors
+ (id)matrixWithMatrix:(KTMatrix *)matrix
{
    if (([[matrix locationHash] hashBound] == 0) ||
        ([matrix count] < [[matrix locationHash] hashBound]/3))
        return [KTMutableMatrixSparseImp matrixWithMatrix:matrix];
    else
        return [KTMutableMatrixDenseImp matrixWithMatrix:matrix];
}
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash;
{
    return [self matrixWithCapacity:0
                       locationHash:hash];
}
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                     objects:(NSArray *)objects
                 atLocations:(NSArray *)loc1s
                 byLocations:(NSArray *)loc2s
{
    if (([hash hashBound] == 0) || ([objects count] < [hash hashBound]/3))
        return [KTMutableMatrixSparseImp matrixWithLocationHash:hash
                                                        objects:objects
                                                    atLocations:loc1s
                                                    byLocations:loc2s];
    else
        return [KTMutableMatrixDenseImp matrixWithLocationHash:hash
                                                       objects:objects
                                                   atLocations:loc1s
                                                   byLocations:loc2s];
}
+ (id)matrixWithCapacity:(unsigned)numItems
          locationHash:(id<KTLocationHash>)hash
{
    if (([hash hashBound] == 0) || (numItems < [hash hashBound]/3))
        return [KTMutableMatrixSparseImp matrixWithCapacity:numItems
                                               locationHash:hash];
    else
        return [KTMutableMatrixDenseImp matrixWithCapacity:numItems
                                              locationHash:hash];
}
+ (id)matrixWithCapacity:(unsigned)numItems
        cuboidBoundArray:(NSArray *)bounds
{
    id<KTLocationHash> hash = [[KTCuboidHash allocWithZone:NULL]
        initWithBounds:bounds];
    id ret = [self matrixWithCapacity:numItems
                       locationHash:hash];
    [hash release];
    return ret;
}
+ (id)matrixWithCapacity:(unsigned)numItems
            cuboidBounds:(unsigned)bound1,...
{
    NSMutableArray *array
    = [NSMutableArray arrayWithObject:[NSNumber numberWithInt:bound1]];
    unsigned bound;
    va_list args;
    if (bound1 == 0)
        {  // Creating a 0-dimensional array. Riiiight...
        [array removeLastObject];
        }
    else
        {
        va_start(args, bound1);

        while (bound = va_arg(args, unsigned))
            [array addObject:[NSNumber numberWithInt:bound]];

        va_end(args);
        }
    return [self matrixWithCapacity:numItems
                   cuboidBoundArray:array];
}
+ (id)matrixWithCuboidBoundsObjectAtCoordinates:(unsigned)bound1,...
{
    KTCuboidHash *hash; // The hashing object to use
    va_list args;       // To trawl through the arguments
    id ret;             // The object being returned
    id object;          // Used to store the object in the arguments

    va_start(args, bound1);
    hash = [[KTCuboidHash alloc] initWithBoundsList:bound1 :&args];
    object = va_arg(args, id);

    if ([self isEqual:[KTMutableMatrix class]])
        {   // Can optimize away some inefficiencies
        unsigned loc = [hash hashForCoordinatesList:&args];

        if (([hash hashBound] != 0) && ([hash hashBound] <= 3))
            ret = [KTMutableMatrixDenseImp alloc];
        else
            ret = [KTMutableMatrixSparseImp alloc];
        ret = [[ret initWithLocationHash:hash
                                  object:object
                        atHashedLocation:loc] autorelease];
        }
    else
        {
        unsigned i, dimension = [hash dimension];
        NSMutableArray *coord = [[NSMutableArray alloc] init];
        NSNumber *number;

        for (i = 0; i < dimension; i++)
            {
            number = [[NSNumber alloc] initWithInt:va_arg(args, unsigned)];
            [coord addObject:number];
            [number release];
            }

        ret = [self matrixWithLocationHash:hash
                                    object:object
                         atCoordinateArray:coord];
        [coord release];
        }

    [hash release];
    va_end(args);
    return ret;
}
+ (id)matrixWithCuboidBoundsObjectsAtCoordinates:(unsigned)bound1,...
{
    KTCuboidHash *hash; // The hashing object to use
    va_list args;       // To trawl through the arguments
    id object;          // Used to store the objects in the arguments
    id ret;             // The object being returned

    // Read in data for the cuboid hash
    va_start(args, bound1);
    hash = [[KTCuboidHash alloc] initWithBoundsList:bound1 :&args];

    if ([self isEqual:[KTMutableMatrix class]])
        {   // Can optimize away some inefficiencies
            // Need a mutable temporary to store all the objects
        KTMutableMatrixSparseImp *temp;
        // SELs/IMPs to speed up repeated method calls
        SEL hashListSEL = @selector(hashForCoordinatesList:);
        SEL setObjSEL = @selector(setObject:atHashedLocation:);
        unsigned (*hashListIMP)(id, SEL, ...);
        void (*setObjIMP)(id, SEL, ...);

        // Allocate the temporary mutable matrix
        temp = [[KTMutableMatrixSparseImp alloc] initWithCapacity:0
                                                     locationHash:hash];

        // Read in objects and coordinates
        hashListIMP = (unsigned (*)(id, SEL, ...))
            [hash methodForSelector:hashListSEL];
        setObjIMP = (void (*)(id, SEL, ...))
            [temp methodForSelector:setObjSEL];
        while (object = va_arg(args, id))
            setObjIMP(temp, setObjSEL, object,
                      hashListIMP(hash,hashListSEL,&args));

        // Make a mutable copy of the object
        if (([hash hashBound] == 0) ||
            ([temp count] < [hash hashBound]/3))
            ret = [temp retain];
        else
            ret = [temp mutableCopyWithZone:NULL];
        [temp release];
        [ret autorelease];
        }
    else
        {   // Version for derived classes
        unsigned dimension = [hash dimension];
        NSMutableArray *objects = [[NSMutableArray alloc] init];
        NSMutableArray *coords  = [[NSMutableArray alloc] init];
        NSNumber *number;
        unsigned i;
        NSMutableArray *coord;

        // Fill a couple of arrays with the objects and coordinates
        while (object = va_arg(args, id))
            {
            [objects addObject:object];
            coord = [NSMutableArray array];
            for (i = 0; i < dimension; i++)
                {
                number = [[NSNumber alloc] initWithInt:va_arg(args, unsigned)];
                [coord addObject:number];
                [number release];
                }
            [coords addObject:coord];
            }

        ret = [self matrixWithLocationHash:hash
                                   objects:objects
                        atCoordinateArrays:coords];
        [objects release];
        [coords release];
        }

    [hash release];
    va_end(args);
    return ret;
}

- (id)init
{
    return (self = [super init]);
}
- (id)initWithMatrix:(KTMatrix *)matrix
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMutableMatrix!"];
    [self release];
    return NULL;
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
{ return (self = [self initWithCapacity:0 locationHash:hash]); }
- (id)initWithCapacity:(unsigned)numItems
          locationHash:(id<KTLocationHash>)hash
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMutableMatrix!"];
    [self release];
    return NULL;
}
- (id)initWithCapacity:(unsigned)numItems
      cuboidBoundArray:(NSArray *)bounds;
{
    id<KTLocationHash> hash = [[KTCuboidHash allocWithZone:[self zone]]
        initWithBounds:bounds];
    self = [self initWithCapacity:numItems
                     locationHash:hash];
    [hash release];
    return self;
}
- (id)initWithCapacity:(unsigned)numItems
          cuboidBounds:(unsigned)bound1,...
{
    va_list args;
    id<KTLocationHash> hash;

    va_start(args, bound1);
    hash = [[KTCuboidHash allocWithZone:[self zone]]
                initWithBoundsList:bound1 :&args];
    self = [self initWithCapacity:numItems locationHash:hash];
    [hash release];
    va_end(args);
    
    return self;
}

//// Accessor methods
- (id)objectAtLocation:(NSDictionary *)loc1
            byLocation:(NSDictionary *)loc2;
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMutableMatrix!"];
    return NULL;
}
- (id<KTLocationHash>)locationHash
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMutableMatrix!"];
    return NULL;
}

//// Internal use accessors
- (NSDictionary *)matrixData
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMutableMatrix!"];
    return NULL;
}

//// Object methods
- (NSEnumerator *)objectEnumerator
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMutableMatrix!"];
    return NULL;
}

//// Mutator methods
- (void)setMatrix:(KTMatrix *)matrix
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMutableMatrix!"];
}
- (void)setObject:(id)object
       atLocation:(NSDictionary *)loc1;
{
    [self setObject:object
         atLocation:loc1
         byLocation:[NSDictionary dictionary]];
}
- (void)setObject:(id)object
       atLocation:(NSDictionary *)loc1
       byLocation:(NSDictionary *)loc2;
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMutableMatrix!"];
}
- (void)        setObject:(id)object
        atCoordinateArray:(NSArray *)coords
{
    NSMutableDictionary *loc = [NSMutableDictionary dictionaryWithCapacity:
        [coords count]];
    unsigned axis = 0;

    for (; axis < [coords count]; axis++)
        [loc setObject:[coords objectAtIndex:axis]
                forKey:[NSNumber numberWithInt:axis]];
    [self setObject:object
         atLocation:loc
         byLocation:[NSDictionary dictionary]];
    return;
}
- (void)    setObject:(id)object
        atCoordinates:(unsigned)x,...
{
    NSMutableArray *array
    = [NSMutableArray arrayWithObject:[NSNumber numberWithInt:x]];
    unsigned axes = [self dimension];
    va_list args;

    va_start(args, x);

    while ([array count] < axes)
        [array addObject:[NSNumber numberWithInt:va_arg(args, unsigned)]];

    va_end(args);

    [self       setObject:object
        atCoordinateArray:array];
}
- (void)setObjects:(NSArray *)objects
       atLocations:(NSArray *)locs
{
    NSEnumerator *i = [objects objectEnumerator];
    NSEnumerator *j = [locs objectEnumerator];
    id object;
    NSDictionary *loc1;
    NSDictionary *loc2 = [[NSDictionary alloc] init];

    if ([objects count] != [locs count])
        [NSException raise:NSInvalidArgumentException
                    format:
            @"Objects and locations arrays not of equal length"];
    while ((object = [i nextObject]) && (loc1 = [j nextObject]))
        [self setObject:object
             atLocation:loc1
             byLocation:loc2];
    [loc2 release];
}
- (void)setObjects:(NSArray *)objects
       atLocations:(NSArray *)loc1s
        byLocation:(NSDictionary *)loc2
{
    NSEnumerator *i = [objects objectEnumerator];
    NSEnumerator *j = [loc1s objectEnumerator];
    id object;
    NSDictionary *loc1;

    if ([objects count] != [loc1s count])
        [NSException raise:NSInvalidArgumentException
                    format:
            @"Objects and locations arrays not of equal length"];
    while ((object = [i nextObject]) && (loc1 = [j nextObject]))
        [self setObject:object
             atLocation:loc1
             byLocation:loc2];
}
- (void)setObjects:(NSArray *)objects
       atLocations:(NSArray *)loc1s
       byLocations:(NSArray *)loc2s
{
    NSEnumerator *i = [objects objectEnumerator];
    NSEnumerator *j = [loc1s objectEnumerator];
    NSEnumerator *k = [loc2s objectEnumerator];
    id object;
    NSDictionary *loc1;
    NSDictionary *loc2;

    if ([objects count] != [loc1s count])
        [NSException raise:NSInvalidArgumentException
                    format:
            @"Objects and locations arrays not of equal length"];
    if ([objects count] != [loc1s count])
        [NSException raise:NSInvalidArgumentException
                    format:
            @"Locations arrays not of equal length"];
    while ((object = [i nextObject]) && (loc1 = [j nextObject]) &&
           (loc2 = [k nextObject]))
        [self setObject:object
             atLocation:loc1
             byLocation:loc2];
}
- (void)setObjectsAtLocations:(id)object1,...
{
    NSDictionary *empty     = [NSDictionary dictionary];
    NSMutableArray *objects = [NSMutableArray array];
    NSMutableArray *loc1s   = [NSMutableArray array];
    NSMutableArray *loc2s   = [NSMutableArray array];
    id object = object1;
    va_list args;

    if (object1 != 0)
        {
        va_start(args, object1);

        do
            {
                [objects addObject:object];
                [loc1s addObject:va_arg(args, id)];
                [loc2s addObject:empty];
            }
        while (object = va_arg(args, id));

        va_end(args);
        }
    [self setObjects:objects
         atLocations:loc1s
         byLocations:loc2s];
}
- (void)setObjectsAtLocationsByLocations:(id)object1,...
{
    NSMutableArray *objects = [NSMutableArray array];
    NSMutableArray *loc1s   = [NSMutableArray array];
    NSMutableArray *loc2s   = [NSMutableArray array];
    id object = object1;
    va_list args;

    if (object1 != 0)
        {
        va_start(args, object1);

        do
            {
                [objects addObject:object];
                [loc1s addObject:va_arg(args, id)];
                [loc2s addObject:va_arg(args, id)];
            }
        while (object = va_arg(args, id));

        va_end(args);
        }
    [self setObjects:objects
         atLocations:loc1s
         byLocations:loc2s];
}
- (void)        setObjects:(NSArray *)objects
        atCoordinateArrays:(NSArray *)coords
{
    NSArray *dims = [self axes];
    NSMutableArray *loc1s = [[NSMutableArray alloc] initWithCapacity:
        [coords count]];
    NSMutableArray *loc2s = [[NSMutableArray alloc] initWithCapacity:
        [coords count]];
    NSMutableDictionary *loc;
    NSDictionary *empty = [[NSDictionary alloc] init];

    NSEnumerator *axes;
    NSEnumerator *coordArrays = [coords objectEnumerator];
    NSEnumerator *vals;
    id axis;
    NSArray *coord;

    while ((coord = [coordArrays nextObject]))
        {
        if ([dims count] != [coord count])
            [NSException raise:NSInvalidArgumentException
                        format:
                @"Dimensions of hash and number of coordinates not equal"];
        axes = [dims objectEnumerator];
        vals = [coord objectEnumerator];
        loc  = [[NSMutableDictionary alloc] init];
        while ((axis = [axes nextObject]))
            [loc setObject:[vals nextObject]
                    forKey:axis];
        [loc1s addObject:loc];
        [loc2s addObject:empty];
        [loc release];
        }
    [self setObjects:objects
         atLocations:loc1s
         byLocations:loc2s];
    [loc1s release];
    [loc2s release];
    [empty release];
}
- (void)setObjectsAtCoordinates:(id)object1,...
{
    NSMutableArray *objects = [NSMutableArray array];
    NSMutableArray *coords  = [NSMutableArray array];
    unsigned dimension = [self dimension];
    id object = object1;
    va_list args;

    if (object1 != 0)
        {
        va_start(args, object1);

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

        va_end(args);
        }
    [self       setObjects:objects
        atCoordinateArrays:coords];
}

- (void)removeObjectAtLocation:(NSDictionary *)loc
{
    NSDictionary *empty = [[NSDictionary alloc] init];
    [self removeObjectAtLocation:loc
                      byLocation:empty];
}
- (void)removeObjectAtLocation:(NSDictionary *)loc1
                    byLocation:(NSDictionary *)loc2
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMutableMatrix!"];
}
- (void)removeObjectAtCoordinateArray:(NSArray *)coords
{
    NSMutableDictionary *loc = [NSMutableDictionary dictionaryWithCapacity:
        [coords count]];
    unsigned axis = 0;
    for (; axis < [coords count]; axis++)
        [loc setObject:[coords objectAtIndex:axis]
                forKey:[NSNumber numberWithInt:axis]];
    [self removeObjectAtLocation:loc
                      byLocation:[NSDictionary dictionary]];
}
- (void)removeObjectAtCoordinates:(unsigned)x,...
{
    NSMutableArray *array = [NSMutableArray arrayWithObject:
        [NSNumber numberWithInt:x]];
    unsigned axes = [self dimension];
    va_list args;

    va_start(args, x);

    while ([array count] < axes)
        [array addObject:[NSNumber numberWithInt:va_arg(args, unsigned)]];

    va_end(args);

    [self removeObjectAtCoordinateArray:array];
}
- (void)removeObjectsAtLocations:(NSArray *)locs
{
    NSDictionary *loc1;
    NSDictionary *loc2 = [[NSDictionary alloc] init];
    NSEnumerator *i = [locs objectEnumerator];
    while ((loc1 = [i nextObject]))
        [self removeObjectAtLocation:loc1
                          byLocation:loc2];
    [loc2 release];
}
- (void)removeObjectsAtLocations:(NSArray *)loc1s
                      byLocation:(NSDictionary *)loc2
{
    NSDictionary *loc1;
    NSEnumerator *i = [loc1s objectEnumerator];
    while ((loc1 = [i nextObject]))
        [self removeObjectAtLocation:loc1
                          byLocation:loc2];
}
- (void)removeObjectsAtLocations:(NSArray *)loc1s
                     byLocations:(NSArray *)loc2s
{
    NSDictionary *loc1, *loc2;
    NSEnumerator *i = [loc1s objectEnumerator],
        *j = [loc2s objectEnumerator];

    if ([loc1s count] != [loc2s count])
        [NSException raise:NSInvalidArgumentException
                    format:
@"Inputs to removeObjectsAtLocations:byLocations: not of equal count"];
    while ((loc1 = [i nextObject]) && (loc2 = [j nextObject]))
        [self removeObjectAtLocation:loc1
                          byLocation:loc2];
}
- (void)removeObjectsAtCoordinateArrays:(NSArray *)coords
{
    NSArray *dims = [self axes];
    NSMutableArray *loc1s = [[NSMutableArray alloc] initWithCapacity:
        [coords count]];
    NSMutableArray *loc2s = [[NSMutableArray alloc] initWithCapacity:
        [coords count]];
    NSMutableDictionary *loc;
    NSDictionary *empty = [[NSDictionary alloc] init];

    NSEnumerator *axes;
    NSEnumerator *coordArrays = [coords objectEnumerator];
    NSEnumerator *vals;
    id axis;
    NSArray *coord;

    while ((coord = [coordArrays nextObject]))
        {
        if ([dims count] != [coord count])
            [NSException raise:NSInvalidArgumentException
                        format:
                @"Dimensions of hash and number of coordinates not equal"];
        axes = [dims objectEnumerator];
        vals = [coord objectEnumerator];
        loc  = [[NSMutableDictionary alloc] init];
        while ((axis = [axes nextObject]))
            [loc setObject:[vals nextObject]
                    forKey:axis];
        [loc1s addObject:loc];
        [loc2s addObject:empty];
        [loc release];
        }
    [self removeObjectsAtLocations:loc1s
                       byLocations:loc2s];
    [loc1s release];
    [loc2s release];
    [empty release];
}

- (void)removeAllObjects
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMutableMatrix!"];
}


@end
