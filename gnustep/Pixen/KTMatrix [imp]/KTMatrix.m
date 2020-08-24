//
//  KTMatrix
//  KTMatrix collection class cluster
//
//  Stores a matrix of objects
//
//  It works like this:
//    - A set of keys is used to denote the matrix axes
//    - A dictionary is used to access individual elements
//    - (A hash is used to transform this dictionary into a key)
//    - The axis values must be NSNumbers
//  This differs from a dictionary with dictionary keys only in that
//    the hash does not depend on the key type
//  Also, if two locations hash the same, they are treated as identical
//
//  Copyright (c) 2002 Chris Purcell. All rights reserved.
//
//  You may use this code for whatever purposes you wish.
//  This code comes with no warranties, implied or otherwise.
//  Using it may damage your data. It shouldn't, but save a copy first.
//  That's a good idea anyway, actually.
//

#import "KTMatrix.h"
#import "KTPlaceholderMatrix.h"
#import "KTMatrixSparseImp.h"
#import "KTMatrixDenseImp.h"
#import "KTMutableMatrix.h"
#import "KTMutableMatrixSparseImp.h"
#import "KTMutableMatrixDenseImp.h"
#import "KTCuboidHash.h"

@implementation KTMatrix

//// Allocators
+ (id)alloc
{
    if ([self isEqual:[KTMatrix class]])
        return [KTPlaceholderMatrix alloc];
    else
        return [super alloc];
}
+ (id)allocWithZone:(NSZone *)zone
{
    if ([self isEqual:[KTMatrix class]])
        return [KTPlaceholderMatrix allocWithZone:zone];
    else
        return [super allocWithZone:zone];
}

//// Constructors
+ (id)matrix
{
    id<KTLocationHash> hash = [[KTCuboidHash allocWithZone:NULL] init];
    id ret = [self matrixWithLocationHash:hash];
    [hash release];
    return ret;
}
+ (id)matrixWithMatrix:(KTMatrix *)matrix
{
    if (([[matrix locationHash] hashBound] == 0) ||
        ([matrix count] < [[matrix locationHash] hashBound]/3))
        return [KTMatrixSparseImp matrixWithMatrix:matrix];
    else
        return [KTMatrixDenseImp matrixWithMatrix:matrix];
}

+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
{
    if ([self isEqual:[KTMatrix class]])
        return [KTMatrixSparseImp matrixWithLocationHash:hash];
    else
        {
        [NSException raise:NSGenericException
                    format:
            @"Must implement a complete subclass of KTMatrix!"];
        return NULL;
        }
}
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                      object:(id)object
                  atLocation:(NSDictionary *)loc
{
    return [self matrixWithLocationHash:(id<KTLocationHash>)hash
                                objects:[NSArray arrayWithObject:object]
                            atLocations:[NSArray arrayWithObject:loc]
                            byLocations:[NSArray arrayWithObject:
                              [NSDictionary dictionary]]];
}
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                      object:(id)object
                  atLocation:(NSDictionary *)loc1
                  byLocation:(NSDictionary *)loc2
{
    return [self matrixWithLocationHash:(id<KTLocationHash>)hash
                                objects:[NSArray arrayWithObject:object]
                            atLocations:[NSArray arrayWithObject:loc1]
                            byLocations:[NSArray arrayWithObject:loc2]];
}
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                     objects:(NSArray *)objects
                 atLocations:(NSArray *)locs
{
    NSDictionary *empty = [[NSDictionary alloc] init];
    NSMutableArray *temp = [[NSMutableArray alloc] initWithCapacity:
        [locs count]];
    id ret;
    unsigned i;
    for (i = 0; i < [locs count]; i++)
        [temp addObject:empty];
    [empty release];
    ret = [self matrixWithLocationHash:(id<KTLocationHash>)hash
                               objects:objects
                           atLocations:locs
                           byLocations:temp];
    [temp release];
    return ret;
}
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                     objects:(NSArray *)objects
                 atLocations:(NSArray *)loc1s
                  byLocation:(NSDictionary *)loc2
{
    NSMutableArray *temp = [[NSMutableArray alloc] initWithCapacity:
        [loc1s count]];
    unsigned i;
    id ret;
    for (i = 0; i < [loc1s count]; i++)
        [temp addObject:loc2];
    ret = [self matrixWithLocationHash:(id<KTLocationHash>)hash
                                objects:objects
                            atLocations:loc1s
                            byLocations:temp];
    [temp release];
    return ret;
}
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                     objects:(NSArray *)objects
                 atLocations:(NSArray *)loc1s
                 byLocations:(NSArray *)loc2s
{
    if (([hash hashBound] == 0) || ([objects count] < [hash hashBound]/3))
        return [KTMatrixSparseImp matrixWithLocationHash:hash
                                                 objects:objects
                                             atLocations:loc1s
                                             byLocations:loc2s];
    else
        return [KTMatrixDenseImp matrixWithLocationHash:hash
                                                objects:objects
                                            atLocations:loc1s
                                            byLocations:loc2s];
}
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
          objectsAtLocations:(id)object1,...
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
    return [self matrixWithLocationHash:(id<KTLocationHash>)hash
                                objects:objects
                            atLocations:loc1s
                            byLocations:loc2s];
}
+ (id)     matrixWithLocationHash:(id<KTLocationHash>)hash
    objectsAtLocationsByLocations:(id)object1,...
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
    return [self matrixWithLocationHash:(id<KTLocationHash>)hash
                                objects:objects
                            atLocations:loc1s
                            byLocations:loc2s];
}

+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                      object:(id)object
           atCoordinateArray:(NSArray *)coord
{
    NSMutableDictionary *loc1 = [[NSMutableDictionary alloc] init];
    NSDictionary *loc2 = [[NSDictionary alloc] init];
    NSEnumerator *axes = [[hash axes] objectEnumerator];
    NSEnumerator *coords = [coord objectEnumerator];
    id axis;
    id ret;

    if ([[hash axes] count] != [coord count])
        [NSException raise:NSInvalidArgumentException
                    format:
            @"Dimensions of hash do not agree with number of coordinates"];
    while ((axis = [axes nextObject]))
        [loc1 setObject:[coords nextObject]
                 forKey:axis];
    ret = [self matrixWithLocationHash:hash
                                object:object
                            atLocation:loc1
                            byLocation:loc2];
    [loc1 release];
    [loc2 release];
    return ret;
}
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                      object:(id)object
               atCoordinates:(unsigned)x,...
{
    NSMutableArray *array = [NSMutableArray arrayWithObject:
        [NSNumber numberWithInt:x]];
    unsigned axes = [[hash axes] count];
    va_list args;

    va_start(args, x);

    while ([array count] < axes)
        [array addObject:[NSNumber numberWithInt:va_arg(args, unsigned)]];

    va_end(args);

    return [self matrixWithLocationHash:hash
                                 object:object
                      atCoordinateArray:array];
}
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                     objects:(NSArray *)objects
          atCoordinateArrays:(NSArray *)coords
{
    NSArray *dims = [hash axes];
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
    id ret;

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
    ret = [self matrixWithLocationHash:hash
                               objects:objects
                           atLocations:loc1s
                           byLocations:loc2s];
    [loc1s release];
    [loc2s release];
    [empty release];
    return ret;
}
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
        objectsAtCoordinates:(id)object1,...
{
    NSMutableArray *objects = [NSMutableArray array];
    NSMutableArray *coords  = [NSMutableArray array];
    unsigned dimension = [[hash axes] count];
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
    return [self matrixWithLocationHash:hash
                                objects:objects
                     atCoordinateArrays:coords];
}

+ (id)matrixWithCuboidBoundArray:(NSArray *)bounds
{
    id<KTLocationHash> hash = [[KTCuboidHash allocWithZone:NULL]
                                    initWithBounds:bounds];
    id ret = [self matrixWithLocationHash:hash];
    [hash release];
    return ret;
}
+ (id)matrixWithCuboidBoundArray:(NSArray *)bounds
                          object:(id)object
               atCoordinateArray:(NSArray *)coord
{
    NSMutableDictionary *loc1 = [NSMutableDictionary dictionaryWithCapacity:
        [bounds count]];
    NSMutableDictionary *loc2 = [NSMutableDictionary dictionary];
    id<KTLocationHash> hash = [[KTCuboidHash allocWithZone:NULL]
        initWithBounds:bounds];
    unsigned i;
    id ret;

    if ([bounds count] != [coord count])
        [NSException raise:NSInvalidArgumentException
                    format:
            @"Dimension of cuboid and dimension of coordinates not equal"];
    for (i = 0; i < [bounds count]; i++)
        [loc1 setObject:[coord objectAtIndex:i]
                 forKey:[NSNumber numberWithInt:i]];
    ret = [self matrixWithLocationHash:hash
                                object:object
                            atLocation:loc1
                            byLocation:loc2];
    [hash release];
    return ret;
}
+ (id)matrixWithCuboidBoundArray:(NSArray *)bounds
                          object:(id)object
                   atCoordinates:(unsigned)x,...
{
    NSMutableArray *array = [NSMutableArray arrayWithObject:
        [NSNumber numberWithInt:x]];
    unsigned axes = [bounds count];
    id<KTLocationHash> hash = [[KTCuboidHash allocWithZone:NULL]
        initWithBounds:bounds];
    id ret;
    va_list args;

    va_start(args, x);

    while ([array count] < axes)
        [array addObject:[NSNumber numberWithInt:va_arg(args, unsigned)]];

    va_end(args);

    ret = [self matrixWithLocationHash:hash
                                object:object
                     atCoordinateArray:array];
    [hash release];
    return ret;
}
+ (id)matrixWithCuboidBoundArray:(NSArray *)bounds
                         objects:(NSArray *)objects
              atCoordinateArrays:(NSArray *)coords
{
    NSMutableArray *loc1s = [[NSMutableArray alloc] initWithCapacity:
        [coords count]];
    NSMutableArray *loc2s = [[NSMutableArray alloc] initWithCapacity:
        [coords count]];
    NSMutableDictionary *loc;
    NSDictionary *empty = [[NSDictionary alloc] init];
    id<KTLocationHash> hash = [[KTCuboidHash allocWithZone:NULL]
        initWithBounds:bounds];
    unsigned i;

    NSEnumerator *coordArrays = [coords objectEnumerator];
    NSArray *coord;
    id ret;

    while ((coord = [coordArrays nextObject]))
        {
        if ([bounds count] != [coord count])
            [NSException raise:NSInvalidArgumentException
                        format:
                @"Dimensions of cuboid and number of coordinates not equal"];
        loc  = [[NSMutableDictionary alloc] init];
        for (i = 0; i < [bounds count]; i++)
            [loc setObject:[coord objectAtIndex:i]
                    forKey:[NSNumber numberWithInt:i]];
        [loc1s addObject:loc];
        [loc2s addObject:empty];
        [loc release];
        }
    
    ret = [self matrixWithLocationHash:hash
                               objects:objects
                           atLocations:loc1s
                           byLocations:loc2s];
    [hash release];
    [loc1s release];
    [loc2s release];
    [empty release];
    return ret;
}
+ (id)matrixWithCuboidBoundArray:(NSArray *)bounds
            objectsAtCoordinates:(id)object1,...
{
    NSMutableArray *objects = [NSMutableArray array];
    NSMutableArray *coords  = [NSMutableArray array];
    id object = object1;
    va_list args;

    if (object1 != 0)
        {
        va_start(args, object1);

        do
            {
                NSMutableArray *coord = [NSMutableArray arrayWithCapacity:
                    [bounds count]];
                [objects addObject:object];
                while ([coord count] < [bounds count])
                    [coord addObject:[NSNumber numberWithInt:
                        va_arg(args, unsigned)]];
                [coords addObject:coord];
            }
        while (object = va_arg(args, id));

        va_end(args);
        }
    return [self matrixWithCuboidBoundArray:bounds
                                    objects:objects
                         atCoordinateArrays:coords];
}
+ (id)matrixWithCuboidBounds:(unsigned)bound1,...
{
    va_list args;
    id<KTLocationHash> hash;
    id ret;
    
    va_start(args, bound1);
    hash = [[KTCuboidHash allocWithZone:NULL] initWithBoundsList:bound1 :&args];
    ret = [self matrixWithLocationHash:hash];
    [hash release];
    va_end(args);
    return ret;
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

    if ([self isEqual:[KTMatrix class]])
        {   // Can optimize away some inefficiencies
        unsigned loc = [hash hashForCoordinatesList:&args];

        if (([hash hashBound] != 0) && ([hash hashBound] <= 3))
            ret = [KTMatrixDenseImp alloc];
        else
            ret = [KTMatrixSparseImp alloc];
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
+ (id)matrixWithCuboidBoundsObjectsAtCoordinateArrays:(unsigned)bound1,...
{
    NSMutableArray *bounds = [NSMutableArray array];
    unsigned bound = bound1;
    NSMutableArray *objects = [NSMutableArray array];
    NSMutableArray *coords  = [NSMutableArray array];
    id object = NULL;
    va_list args;

    if (bound1 != 0)
        {
        va_start(args, bound1);

        do
            [bounds addObject:[NSNumber numberWithInt:bound]];
        while (bound = va_arg(args, unsigned));

        while (object = va_arg(args, id))
            {
            [objects addObject:object];
            [coords addObject:va_arg(args, id)];
            }

        va_end(args);
        }
    return [self matrixWithCuboidBoundArray:bounds
                                    objects:objects
                         atCoordinateArrays:coords];
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

    if ([self isEqual:[KTMatrix class]])
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

        // Make an immutable copy of the object
        ret = [[temp copyWithZone:NULL] autorelease];
        [temp release];
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
        @"Must implement a complete subclass of KTMatrix!"];
    [self release];
    return NULL;
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
{
    return (self = [self initWithMatrix:
        [KTMatrix matrixWithLocationHash:hash]]);
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                    object:(id)object
                atLocation:(NSDictionary *)loc
{   // Not sure of an efficient way to implement this generally
    NSArray *objects = [NSArray arrayWithObject:object];
    NSArray *loc1s = [NSArray arrayWithObject:loc];
    NSDictionary *empty = [[NSDictionary allocWithZone:NULL] init];
    NSArray *loc2s = [NSArray arrayWithObject:empty];
    self = [self initWithLocationHash:hash
                              objects:objects
                          atLocations:loc1s
                          byLocations:loc2s];
    [empty release];
    return self;
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                    object:(id)object
                atLocation:(NSDictionary *)loc1
                byLocation:(NSDictionary *)loc2
{   // Not sure of a way to implement this generally without autorelease use
    // I suspect NSArray's initWithObjects: may use autorelease
    return [self initWithLocationHash:(id<KTLocationHash>)hash
                              objects:[NSArray arrayWithObject:object]
                          atLocations:[NSArray arrayWithObject:loc1]
                          byLocations:[NSArray arrayWithObject:loc2]];
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                   objects:(NSArray *)objects
               atLocations:(NSArray *)locs
{
    NSDictionary *empty = [[NSDictionary alloc] init];
    NSMutableArray *temp = [[NSMutableArray alloc] initWithCapacity:
        [locs count]];
    unsigned i;
    for (i = 0; i < [locs count]; i++)
        [temp addObject:empty];
    [empty release];
    self = [self initWithLocationHash:(id<KTLocationHash>)hash
                              objects:objects
                          atLocations:locs
                          byLocations:temp];
    [temp release];
    return self;
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                   objects:(NSArray *)objects
               atLocations:(NSArray *)loc1s
                byLocation:(NSDictionary *)loc2
{
    NSMutableArray *temp = [[NSMutableArray alloc] initWithCapacity:
        [loc1s count]];
    unsigned i;
    for (i = 0; i < [loc1s count]; i++)
        [temp addObject:loc2];
    self = [self initWithLocationHash:(id<KTLocationHash>)hash
                              objects:objects
                          atLocations:loc1s
                          byLocations:temp];
    [temp release];
    return self;
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                   objects:(NSArray *)objects
               atLocations:(NSArray *)loc1s
               byLocations:(NSArray *)loc2
{
    return [self initWithMatrix:
        [KTMatrixSparseImp matrixWithLocationHash:hash
                                          objects:objects
                                      atLocations:loc1s
                                      byLocations:loc2]];
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
        objectsAtLocations:(id)object1,...
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
    return [self initWithLocationHash:(id<KTLocationHash>)hash
                              objects:objects
                          atLocations:loc1s
                          byLocations:loc2s];
}
- (id)       initWithLocationHash:(id<KTLocationHash>)hash
    objectsAtLocationsByLocations:(id)object1,...
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
    return [self initWithLocationHash:(id<KTLocationHash>)hash
                              objects:objects
                          atLocations:loc1s
                          byLocations:loc2s];
}

- (id)initWithLocationHash:(id<KTLocationHash>)hash
                    object:(id)object
         atCoordinateArray:(NSArray *)coord
{
    NSMutableDictionary *loc1 = [[NSMutableDictionary alloc] init];
    NSDictionary *loc2 = [[NSDictionary alloc] init];
    NSEnumerator *axes = [[hash axes] objectEnumerator];
    NSEnumerator *coords = [coord objectEnumerator];
    id axis;

    if ([[hash axes] count] != [coord count])
        [NSException raise:NSInvalidArgumentException
                    format:
            @"Dimensions of hash do not agree with number of coordinates"];
    while ((axis = [axes nextObject]))
        [loc1 setObject:[coords nextObject]
                 forKey:axis];
    self = [self initWithLocationHash:hash
                               object:object
                           atLocation:loc1
                           byLocation:loc2];
    [loc1 release];
    [loc2 release];
    return self;
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                    object:(id)object
             atCoordinates:(unsigned)x,...
{
    NSMutableArray *array = [NSMutableArray arrayWithObject:
        [NSNumber numberWithInt:x]];
    unsigned axes = [[hash axes] count];
    va_list args;

    va_start(args, x);

    while ([array count] < axes)
        [array addObject:[NSNumber numberWithInt:va_arg(args, unsigned)]];

    va_end(args);

    return [self initWithLocationHash:hash
                               object:object
                    atCoordinateArray:array];
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                   objects:(NSArray *)objects
        atCoordinateArrays:(NSArray *)coords
{
    NSArray *dims = [hash axes];
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
    self = [self initWithLocationHash:hash
                              objects:objects
                          atLocations:loc1s
                          byLocations:loc2s];
    [loc1s release];
    [loc2s release];
    [empty release];
    return self;
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
      objectsAtCoordinates:(id)object1,...
{
    NSMutableArray *objects = [NSMutableArray array];
    NSMutableArray *coords  = [NSMutableArray array];
    id object = object1;
    va_list args;

    if (object1 != 0)
        {
        va_start(args, object1);

        do
            {
                [objects addObject:object];
                [coords addObject:va_arg(args, id)];
            }
        while (object = va_arg(args, id));

        va_end(args);
        }
    return [self initWithLocationHash:hash
                              objects:objects
                   atCoordinateArrays:coords];
}

- (id)initWithCuboidBoundArray:(NSArray *)bounds
{
    id<KTLocationHash> hash = [[KTCuboidHash allocWithZone:[self zone]]
        initWithBounds:bounds];
    self = [self initWithLocationHash:hash];
    [hash release];
    return self;
}
- (id)initWithCuboidBoundArray:(NSArray *)bounds
                        object:(id)object
             atCoordinateArray:(NSArray *)coord
{
    NSMutableDictionary *loc1 = [NSMutableDictionary dictionaryWithCapacity:
        [bounds count]];
    NSMutableDictionary *loc2 = [NSMutableDictionary dictionary];
    id<KTLocationHash> hash = [[KTCuboidHash allocWithZone:[self zone]]
        initWithBounds:bounds];
    unsigned i;

    if ([bounds count] != [coord count])
        [NSException raise:NSInvalidArgumentException
                    format:
            @"Dimension of cuboid and dimension of coordinates not equal"];
    for (i = 0; i < [bounds count]; i++)
        [loc1 setObject:[coord objectAtIndex:i]
                 forKey:[NSNumber numberWithInt:i]];
    self = [self initWithLocationHash:hash
                               object:object
                           atLocation:loc1
                           byLocation:loc2];
    [hash release];
    return self;
}
- (id)initWithCuboidBoundArray:(NSArray *)bounds
                        object:(id)object
                 atCoordinates:(unsigned)x,...
{
    NSMutableArray *array = [NSMutableArray arrayWithObject:
        [NSNumber numberWithInt:x]];
    unsigned axes = [bounds count];
    id<KTLocationHash> hash = [[KTCuboidHash allocWithZone:[self zone]]
        initWithBounds:bounds];
    va_list args;

    va_start(args, x);

    while ([array count] < axes)
        [array addObject:[NSNumber numberWithInt:va_arg(args, unsigned)]];

    va_end(args);

    self = [self initWithLocationHash:hash
                               object:object
                    atCoordinateArray:array];
    [hash release];
    return self;
}
- (id)initWithCuboidBoundArray:(NSArray *)bounds
                       objects:(NSArray *)objects
            atCoordinateArrays:(NSArray *)coords
{
    NSMutableArray *loc1s = [[NSMutableArray alloc] initWithCapacity:
        [coords count]];
    NSMutableArray *loc2s = [[NSMutableArray alloc] initWithCapacity:
        [coords count]];
    NSMutableDictionary *loc;
    NSDictionary *empty = [[NSDictionary alloc] init];
    id<KTLocationHash> hash = [[KTCuboidHash allocWithZone:[self zone]]
        initWithBounds:bounds];
    unsigned i;

    NSEnumerator *coordArrays = [coords objectEnumerator];
    NSArray *coord;

    while ((coord = [coordArrays nextObject]))
        {
        if ([bounds count] != [coord count])
            [NSException raise:NSInvalidArgumentException
                        format:
                @"Dimensions of cuboid and number of coordinates not equal"];
        loc  = [[NSMutableDictionary alloc] init];
        for (i = 0; i < [bounds count]; i++)
            [loc setObject:[coord objectAtIndex:i]
                    forKey:[NSNumber numberWithInt:i]];
        [loc1s addObject:loc];
        [loc2s addObject:empty];
        [loc release];
        }
    self = [self initWithLocationHash:hash
                              objects:objects
                          atLocations:loc1s
                          byLocations:loc2s];
    [hash release];
    [loc1s release];
    [loc2s release];
    [empty release];
    return self;
}
- (id)initWithCuboidBoundArray:(NSArray *)bounds
          objectsAtCoordinates:(id)object1,...
{
    NSMutableArray *objects = [NSMutableArray array];
    NSMutableArray *coords  = [NSMutableArray array];
    id object = object1;
    va_list args;

    if (object1 != 0)
        {
        va_start(args, object1);

        do
            {
                [objects addObject:object];
                [coords addObject:va_arg(args, id)];
            }
        while (object = va_arg(args, id));

        va_end(args);
        }
    return [self initWithCuboidBoundArray:bounds
                                  objects:objects
                       atCoordinateArrays:coords];
}
- (id)initWithCuboidBounds:(unsigned)bound1,...
{
    va_list args;
    KTCuboidHash *hash;
    
    va_start(args, bound1);
    hash = [[KTCuboidHash allocWithZone:[self zone]]
                initWithBoundsList:bound1 :&args];
    self = [self initWithLocationHash:hash];
    [hash release];
    return self;
}
- (id)initWithCuboidBoundsObjectAtCoordinates:(unsigned)bound1,...
{
    KTCuboidHash *hash;
    unsigned dimension;
    id object = NULL;
    NSMutableArray *coord = [NSMutableArray allocWithZone:NULL];
    NSNumber *number;
    va_list args;

    va_start(args, bound1);
    hash = [[KTCuboidHash allocWithZone:[self zone]]
                initWithBoundsList:bound1 :&args];
    dimension = [hash dimension];

    object = va_arg(args, id);

    coord = [coord initWithCapacity:dimension];
    while ([coord count] < dimension)
        {
        number = [[NSNumber alloc] initWithInt:va_arg(args, unsigned)];
        [coord addObject:number];
        [number release];
        }
    
    self = [self initWithLocationHash:hash
                               object:object
                    atCoordinateArray:coord];

    va_end(args);
    [hash release];
    [coord release];
    return self;
}
- (id)initWithCuboidBoundsObjectsAtCoordinateArrays:(unsigned)bound1,...
{
    NSMutableArray *bounds = [NSMutableArray array];
    unsigned bound = bound1;
    NSMutableArray *objects = [NSMutableArray array];
    NSMutableArray *coords  = [NSMutableArray array];
    id object = NULL;
    va_list args;

    if (bound1 != 0)
        {
        va_start(args, bound1);

        do
            [bounds addObject:[NSNumber numberWithInt:bound]];
        while (bound = va_arg(args, unsigned));

        while (object = va_arg(args, id))
            {
            [objects addObject:object];
            [coords addObject:va_arg(args, id)];
            }

        va_end(args);
        }
    return [self initWithCuboidBoundArray:bounds
                                  objects:objects
                       atCoordinateArrays:coords];
}
- (id)initWithCuboidBoundsObjectsAtCoordinates:(unsigned)bound1,...
{
    KTCuboidHash *hash;
    unsigned dimension;
    NSMutableArray *objects = [[NSMutableArray allocWithZone:NULL] init];
    NSMutableArray *coords  = [[NSMutableArray allocWithZone:NULL] init];
    id object = NULL;
    unsigned i;
    NSMutableArray *coord;
    NSNumber *number;
    va_list args;

    va_start(args, bound1);

    hash = [[KTCuboidHash allocWithZone:[self zone]]
                initWithBoundsList:bound1 :&args];
    dimension = [hash dimension];

    while (object = va_arg(args, id))
        {
        [objects addObject:object];
        coord = [[NSMutableArray allocWithZone:NULL] initWithCapacity:
            dimension];
        for (i = 0; i < dimension; i++)
            {
            number = [[NSNumber alloc] initWithInt:va_arg(args, unsigned)];
            [coord addObject:number];
            [number release];
            }
        [coords addObject:coord];
        [coord release];
        }
    
    self = [self initWithLocationHash:hash
                              objects:objects
                   atCoordinateArrays:coords];

    va_end(args);
    [hash release];
    [objects release];
    [coords release];
    return self;
}

//// Accessor methods
- (id)objectAtLocation:(NSDictionary *)loc
{
    return [self objectAtLocation:loc
                       byLocation:[NSDictionary dictionary]];
}
- (id)objectAtLocation:(NSDictionary *)loc1
            byLocation:(NSDictionary *)loc2;
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMatrix!"];
    return NULL;
}
- (NSArray *)objectsAtLocations:(NSArray *)locs
                 notFoundMarker:(id)anObject
{
    NSEnumerator *i = [locs objectEnumerator];
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[locs count]];
    NSDictionary *empty = [NSDictionary dictionary];
    id loc;
    id object;
    while ((loc = [i nextObject]))
        {
        if ((object = [self objectAtLocation:loc
                                  byLocation:empty]))
            [ret addObject:object];
        else
            [ret addObject:anObject];
        }
    return ret;
}
- (NSArray *)objectsAtLocations:(NSArray *)loc1s
                     byLocation:(NSDictionary *)loc2
                 notFoundMarker:(id)anObject
{
    NSEnumerator *i = [loc1s objectEnumerator];
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[loc1s count]];
    id loc1;
    id object;
    while ((loc1 = [i nextObject]))
        {
        if ((object = [self objectAtLocation:loc1
                                  byLocation:loc2]))
            [ret addObject:object];
        else
            [ret addObject:anObject];
        }
    return ret;
}
- (NSArray *)objectsAtLocations:(NSArray *)loc1s
                    byLocations:(NSArray *)loc2s
                 notFoundMarker:(id)anObject
{
    NSEnumerator *i = [loc1s objectEnumerator];
    NSEnumerator *j = [loc2s objectEnumerator];
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[loc1s count]];
    id loc1, loc2;
    id object;
    if ([loc1s count] != [loc2s count])
        [NSException raise:NSInvalidArgumentException
                    format:
            @"Locations arrays not of equal length"];
    while ((loc1 = [i nextObject]) && (loc2 = [j nextObject]))
        {
        if ((object = [self objectAtLocation:loc1
                                  byLocation:loc2]))
            [ret addObject:object];
        else
            [ret addObject:anObject];
        }
    return ret;
}
- (id)objectAtCoordinateArray:(NSArray *)coords
{
    NSMutableDictionary *loc = [NSMutableDictionary dictionaryWithCapacity:
        [coords count]];
    NSArray *dims = [self axes];
    unsigned axis;

    if ([dims count] != [coords count])
        [NSException raise:NSInvalidArgumentException
                    format:
            @"Dimension of cuboid and dimension of coordinates not equal"];
    for (axis = 0; axis < [coords count]; axis++)
        [loc setObject:[coords objectAtIndex:axis]
                forKey:[dims objectAtIndex:axis]];
    return [self objectAtLocation:loc
                       byLocation:[NSDictionary dictionary]];
}
- (NSArray *)objectsAtCoordinateArrays:(NSArray *)coords
                        notFoundMarker:(id)anObject
{
    NSEnumerator *i = [coords objectEnumerator];
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[coords count]];
    id coord;
    id object;
    NSMutableDictionary *loc = [NSMutableDictionary dictionaryWithCapacity:
        [coords count]];
    NSDictionary *empty = [NSDictionary dictionary];
    NSArray *dims = [self axes];
    unsigned axis;

    while ((coord = [i nextObject]))
        {
        if ([dims count] != [coord count])
            [NSException raise:NSInvalidArgumentException
                        format:
                @"Dimension of cuboid and of coordinates not equal"];
        for (axis = 0; axis < [coord count]; axis++)
            [loc setObject:[coord objectAtIndex:axis]
                    forKey:[dims objectAtIndex:axis]];
        if ((object = [self objectAtLocation:loc
                                  byLocation:empty]))
            [ret addObject:object];
        else
            [ret addObject:anObject];
        }
    return ret;
}
- (id)objectAtCoordinates:(unsigned)x,...
{
    NSMutableArray *array
    = [NSMutableArray arrayWithObject:[NSNumber numberWithInt:x]];
    unsigned axes = [self dimension];
    va_list args;

    va_start(args, x);

    while ([array count] < axes)
        [array addObject:[NSNumber numberWithInt:va_arg(args, unsigned)]];

    va_end(args);

    return [self objectAtCoordinateArray:array];
}
- (id<KTLocationHash>)locationHash
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMatrix!"];
    return NULL;
}

//// Internal use accessors
- (NSDictionary *)matrixData
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMatrix!"];
    return NULL;
}

//// Convenience methods fall straight through to hash equivalents
- (NSArray *)axes
{ return [[self locationHash] axes]; }
- (unsigned)dimension
{ return [[self axes] count]; }
- (unsigned)lowerBoundForAxis:(id)axis
{ return [[self locationHash] lowerBoundForAxis:axis]; }
- (unsigned)lowerBoundForDimension:(unsigned)dim
{
    return [self lowerBoundForAxis:
        [[self axes] objectAtIndex:dim]];
}
- (unsigned)upperBoundForAxis:(id)axis
{ return [[self locationHash] upperBoundForAxis:axis]; }
- (unsigned)upperBoundForDimension:(unsigned)dim
{
    return [self upperBoundForAxis:
        [[self axes] objectAtIndex:dim]];
}

//// Object methods
- (NSArray *)allObjects
{ return [[self objectEnumerator] allObjects]; }
- (unsigned)count
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMatrix!"];
    return 0;
}
- (NSEnumerator *)objectEnumerator
{
    [NSException raise:NSGenericException
                format:
        @"Must implement a complete subclass of KTMatrix!"];
    return NULL;
}
- (NSEnumerator *)objectEnumeratorRetained
{ return [[self objectEnumerator] retain]; }
- (NSEnumerator *)reverseObjectEnumerator
{ return [[self allObjects] reverseObjectEnumerator]; }

//// Inherited NSObject methods
- (BOOL)isEqual:(id)other
{
    if ([other isKindOfClass:[KTMatrix class]])
        return ([[self matrixData] isEqual:[other matrixData]] &&
                [[self locationHash] isEqual:[other locationHash]]);
    return NO;
}


//// Protocols
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[self matrixData]/* forKey:@"matrixData"*/];
    [coder encodeObject:[self locationHash]/* forKey:@"locationHash"*/];
}
- (id)initWithCoder:(NSCoder *)coder
{
    NSDictionary *matrixData = [coder decodeObject/*ForKey:@"matrixData"*/];
    id<KTLocationHash> hash = [coder decodeObject/*ForKey:@"locationHash"*/];
    NSZone *zone = [self zone];
    [self release];
    if (([hash hashBound] == 0) || ([matrixData count] < [hash hashBound]/3))
        self = [[KTMatrixSparseImp allocWithZone:zone]
                   initWithMatrixData:matrixData
                         locationHash:hash];
    else
        self = [[KTMatrixDenseImp allocWithZone:zone]
                   initWithMatrixData:matrixData
                         locationHash:hash];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    if (([[self locationHash] hashBound] == 0) ||
        ([self count] < [[self locationHash] hashBound]/3))
        return [[KTMatrixSparseImp allocWithZone:zone] initWithMatrix:self];
    else
        return [[KTMatrixDenseImp allocWithZone:zone] initWithMatrix:self];
}

- (id)mutableCopyWithZone:(NSZone *)zone;
{
    if (([[self locationHash] hashBound] == 0) ||
        ([self count] < [[self locationHash] hashBound]/3))
        return [[KTMutableMatrixSparseImp allocWithZone:
            zone] initWithMatrix:self];
    else
        return [[KTMutableMatrixDenseImp allocWithZone:
            zone] initWithMatrix:self];
}

@end
