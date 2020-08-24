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

#import "KTMutableMatrixSparseImp.h"
#import "KTMatrixSparseEnumerator.h"

static unsigned KTCallback_hash(NSHashTable *table,
                         const void *elem)
{ return ((const struct KTMatrixSparseElement *)elem)->hashedLocation; }
static BOOL KTCallback_isEqual(NSHashTable *table, const void *_1,
                               const void *_2)
{
    return (((const struct KTMatrixSparseElement *)_1)->hashedLocation ==
            ((const struct KTMatrixSparseElement *)_2)->hashedLocation);
}
static void KTCallback_retain(NSHashTable *table, const void *elem)
{ [(((const struct KTMatrixSparseElement *)elem)->object) retain]; }
static void KTCallback_release(NSHashTable *table, void *elem)
{
    [(((const struct KTMatrixSparseElement *)elem)->object) release];
    free(elem);
}
static NSString *KTCallback_describe(NSHashTable *table, const void *elem)
{ return [(((const struct KTMatrixSparseElement *)elem)->object) description];}



@implementation KTMutableMatrixSparseImp

+ (id)matrixWithMatrix:(KTMatrix *)other
{
    return [[[self alloc] initWithMatrix:other] autorelease];
}
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
    NSEnumerator<KTMatrixEnumerator> *j = [other objectEnumeratorRetained];
    if ([j conformsToProtocol:@protocol(KTMatrixEnumerator)])
        {
        if ((self = [super init]))
            {
            struct KTMatrixSparseElement *element;
            NSHashTableCallBacks callback;
            id object;

            callback.hash = KTCallback_hash;
            callback.isEqual = KTCallback_isEqual;
            callback.retain = KTCallback_retain;
            callback.release = KTCallback_release;
            callback.describe = KTCallback_describe;

            // Deal with the hashing object
            if (NSShouldRetainWithZone([other locationHash], [self zone]))
                hash = [[other locationHash] retain];
            else
                hash = [[other locationHash] copyWithZone:[self zone]];
            hashIsCoordinateOptimized = [hash conformsToProtocol:
                @protocol(KTLocationHashCoordinatesOptimization)];

            // Allocate memory for the hashing table and cache
            matrix = NSCreateHashTableWithZone(callback,
                                               [other count],
                                               [self zone]);
            cache = NSZoneMalloc([self zone],
                                 sizeof(struct KTMatrixSparseElement));

            // Fill the hashing table
            while ((object = [j nextObject]))
                {
                element = NSZoneMalloc([self zone],
                                       sizeof(struct KTMatrixSparseElement));
                element->hashedLocation = [j hashedLocation];
                element->object = object;
                NSHashInsert(matrix, element);
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
{ // Same method: setMatrix
    if ((self = [super init]))
        {
        struct KTMatrixSparseElement *element;
        NSHashTableCallBacks callback;
        NSNumber *key;
        NSEnumerator *j = [matrixData keyEnumerator];

        callback.hash = KTCallback_hash;
        callback.isEqual = KTCallback_isEqual;
        callback.retain = KTCallback_retain;
        callback.release = KTCallback_release;
        callback.describe = KTCallback_describe;

        // Deal with the hashing object
        if (NSShouldRetainWithZone(locationHash, [self zone]))
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
        hashIsCoordinateOptimized = [hash conformsToProtocol:
            @protocol(KTLocationHashCoordinatesOptimization)];

        // Allocate memory for the hashing table and cache
        matrix = NSCreateHashTableWithZone(callback,
                                           [matrixData count],
                                           [self zone]);
        cache = NSZoneMalloc([self zone],
                             sizeof(struct KTMatrixSparseElement));

        // Fill the hashing table
        while ((key = [j nextObject]))
            {
            element = NSZoneMalloc([self zone],
                                   sizeof(struct KTMatrixSparseElement));
            element->hashedLocation = [key intValue];
            element->object = [matrixData objectForKey:key];
            NSHashInsert(matrix, element);
            }
        }
    return self;
}
- (id)initWithLocationHash:(id<KTLocationHash>)locationHash
{
    if ((self = [super init]))
        {
        NSHashTableCallBacks callback;

        callback.hash = KTCallback_hash;
        callback.isEqual = KTCallback_isEqual;
        callback.retain = KTCallback_retain;
        callback.release = KTCallback_release;
        callback.describe = KTCallback_describe;

        // Deal with the hashing object
        if (NSShouldRetainWithZone(locationHash, [self zone]))
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
        hashIsCoordinateOptimized = [hash conformsToProtocol:
            @protocol(KTLocationHashCoordinatesOptimization)];

        // Allocate memory for the hashing table and cache
        matrix = NSCreateHashTableWithZone(callback,
                                           0,
                                           [self zone]);
        cache = NSZoneMalloc([self zone],
                             sizeof(struct KTMatrixSparseElement));
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
        struct KTMatrixSparseElement *element;
        NSHashTableCallBacks callback;
        unsigned i;

        callback.hash = KTCallback_hash;
        callback.isEqual = KTCallback_isEqual;
        callback.retain = KTCallback_retain;
        callback.release = KTCallback_release;
        callback.describe = KTCallback_describe;

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

        // Allocate memory for the hashing table and cache
        matrix = NSCreateHashTableWithZone(callback,
                                           [objects count],
                                           [self zone]);
        cache = NSZoneMalloc([self zone],
                             sizeof(struct KTMatrixSparseElement));
        
        // Fill the cache and the hashing table
        for (i = 0; i < [loc1s count]; i++)
            {
            element = NSZoneMalloc([self zone],
                                   sizeof(struct KTMatrixSparseElement));
            element->hashedLocation = [hash
                    hashForLocation:[loc1s objectAtIndex:i]
                         byLocation:[loc2s objectAtIndex:i]];
            element->object = [objects objectAtIndex:i];
            NSHashInsert(matrix, element);
            }
        }
    return self;
}
- (id)initWithCapacity:(unsigned)numItems
          locationHash:(id<KTLocationHash>)locationHash
{
    if ((self = [super init]))
        {
        NSHashTableCallBacks callback;

        callback.hash = KTCallback_hash;
        callback.isEqual = KTCallback_isEqual;
        callback.retain = KTCallback_retain;
        callback.release = KTCallback_release;
        callback.describe = KTCallback_describe;

        // Deal with the hashing object
        if (NSShouldRetainWithZone(locationHash, [self zone]))
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
        hashIsCoordinateOptimized = [hash conformsToProtocol:
            @protocol(KTLocationHashCoordinatesOptimization)];

        // Allocate memory for the hashing table and cache
        matrix = NSCreateHashTableWithZone(callback,
                                           numItems,
                                           [self zone]);
        cache = NSZoneMalloc([self zone],
                             sizeof(struct KTMatrixSparseElement));
        }
    return self;
}

//// Optimized versions
- (id)initWithLocationHash:(id<KTLocationHash>)locationHash
                    object:(id)object
          atHashedLocation:(unsigned)loc
{
    if ((self = [super init]))
        {
        struct KTMatrixSparseElement *element;
        NSHashTableCallBacks callback;

        callback.hash = KTCallback_hash;
        callback.isEqual = KTCallback_isEqual;
        callback.retain = KTCallback_retain;
        callback.release = KTCallback_release;
        callback.describe = KTCallback_describe;

        // Deal with the hashing object
        if (NSShouldRetainWithZone(locationHash, [self zone]))
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
        hashIsCoordinateOptimized = [hash
            conformsToProtocol:@protocol(KTLocationHashCoordinatesOptimization)];

        // Allocate memory for the hashing table and cache
        matrix = NSCreateHashTableWithZone(callback,
                                           1,
                                           [self zone]);
        cache = NSZoneMalloc([self zone],
                             sizeof(struct KTMatrixSparseElement));

        // Fill the cache and the hashing table
        element = NSZoneMalloc([self zone],
                               sizeof(struct KTMatrixSparseElement));
        element->hashedLocation = loc;
        element->object = object;
        NSHashInsert(matrix, element);
        }
    return self;
}


// Accessor methods
- (id)objectAtLocation:(NSDictionary *)loc
            byLocation:(NSDictionary *)loc2;
{
    struct KTMatrixSparseElement *elem;
    ((struct KTMatrixSparseElement *)cache)->hashedLocation = [hash
            hashForLocation:loc byLocation:loc2];
    elem = (struct KTMatrixSparseElement *)NSHashGet(matrix, cache);
    if (elem != NULL)
        return (elem)->object;
    else
        return NULL;
}

//// Optimized algoritms
- (id)objectAtCoordinates:(unsigned)x,...
{
    va_list args;

    va_start(args, x);

    if (hashIsCoordinateOptimized)
        {
        struct KTMatrixSparseElement *elem;
        ((struct KTMatrixSparseElement *)cache)->hashedLocation =
            [(id)hash hashForCoordinatesList:x :&args];
        va_end(args);

        elem = (struct KTMatrixSparseElement *)NSHashGet(matrix, cache);
        if (elem != NULL)
            return (elem)->object;
        else
            return NULL;
        }
    else
        {
        NSMutableArray *array
        = [NSMutableArray arrayWithObject:[NSNumber numberWithInt:x]];
        unsigned axes = [self dimension];

        while ([array count] < axes)
            [array addObject:[NSNumber numberWithInt:va_arg(args, unsigned)]];

        va_end(args);

        return [self objectAtCoordinateArray:array];
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
            dictionaryWithCapacity:[self count]];
    NSHashEnumerator i = NSEnumerateHashTable(matrix);
    struct KTMatrixSparseElement *elem;
    while ((elem =
            (struct KTMatrixSparseElement *)NSNextHashEnumeratorItem(&i)))
        [data setObject:elem->object
                 forKey:[NSNumber numberWithInt:elem->hashedLocation]];
    NSEndHashTableEnumeration(&i);
        
    return data;
}

- (NSEnumerator *)objectEnumerator
{
    return [[[KTMutableMatrixSparseEnumerator allocWithZone:[self zone]]
            initWithHashEnumerator:NSEnumerateHashTable(matrix)
                        collection:self] autorelease];
}
- (NSEnumerator *)objectEnumeratorRetained
{
    return [[KTMutableMatrixSparseEnumerator allocWithZone:[self zone]]
            initWithHashEnumerator:NSEnumerateHashTable(matrix)
                        collection:self];
}
- (unsigned)count
{ return NSCountHashTable(matrix); }


    //// Mutator methods
- (void)setMatrix:(KTMatrix *)other
{
    struct KTMatrixSparseElement *element;
    NSEnumerator<KTMatrixEnumerator> *j = [other objectEnumerator];
    NSHashTableCallBacks callback;

    [hash release];
    NSFreeHashTable(matrix);

    callback.hash = KTCallback_hash;
    callback.isEqual = KTCallback_isEqual;
    callback.retain = KTCallback_retain;
    callback.release = KTCallback_release;
    callback.describe = KTCallback_describe;

    // Deal with the hashing object
    if (NSShouldRetainWithZone([other locationHash], [self zone]))
        hash = [[other locationHash] retain];
    else
        hash = [[other locationHash] copyWithZone:[self zone]];
    hashIsCoordinateOptimized =
        [hash conformsToProtocol:@protocol(KTLocationHashCoordinatesOptimization)];
    
    // Allocate memory for the hashing table
    matrix = NSCreateHashTableWithZone(callback,
                                       [other count],
                                       [self zone]);
    
    // Fill the hashing table
    if ([j conformsToProtocol:@protocol(KTMatrixEnumerator)])
        {
        id object;
        while ((object = [j nextObject]))
            {
            element = NSZoneMalloc([self zone],
                                   sizeof(struct KTMatrixSparseElement));
            element->hashedLocation = [j hashedLocation];
            element->object = object;
            NSHashInsert(matrix, element);
            }
        }
    else
        {
        NSDictionary *matrixData = [other matrixData];
        NSNumber *key;
        NSEnumerator *k = [matrixData keyEnumerator];
        
        while ((key = [k nextObject]))
            {
            element = NSZoneMalloc([self zone],
                                   sizeof(struct KTMatrixSparseElement));
            element->hashedLocation = [key intValue];
            element->object = [matrixData objectForKey:key];
            NSHashInsert(matrix, element);
            }
        }
}
- (void)setObject:(id)object
       atLocation:(NSDictionary *)loc1
       byLocation:(NSDictionary *)loc2
{
    struct KTMatrixSparseElement *elem;
    ((struct KTMatrixSparseElement *)cache)->hashedLocation = [hash
        hashForLocation:loc1 byLocation:loc2];
    elem = (struct KTMatrixSparseElement *)NSHashGet(matrix, cache);
    if (elem)
        {   // Just change object if the location is occupied
        [elem->object release];
        elem->object = object;
        }
    else
        {   // Else allocate more memory
        elem = NSZoneMalloc([self zone],
                            sizeof(struct KTMatrixSparseElement));
        elem->hashedLocation =
            ((struct KTMatrixSparseElement *)cache)->hashedLocation;
        elem->object = object;
        NSHashInsertKnownAbsent(matrix, elem);
        }
}
- (void)   setObject:(id)object
    atHashedLocation:(unsigned)loc
{
    struct KTMatrixSparseElement *elem;
    ((struct KTMatrixSparseElement *)cache)->hashedLocation = loc;

    elem = (struct KTMatrixSparseElement *)NSHashGet(matrix, cache);
    if (elem)
        {   // Just change object if the location is occupied
        [elem->object release];
        elem->object = object;
        }
    else
        {   // Else allocate more memory
        elem = NSZoneMalloc([self zone],
                            sizeof(struct KTMatrixSparseElement));
        elem->hashedLocation =
            ((struct KTMatrixSparseElement *)cache)->hashedLocation;
        elem->object = object;
        NSHashInsertKnownAbsent(matrix, elem);
        }
}
- (void)removeObjectAtLocation:(NSDictionary *)loc1
                    byLocation:(NSDictionary *)loc2;
{
    ((struct KTMatrixSparseElement *)cache)->hashedLocation = [hash
            hashForLocation:loc1 byLocation:loc2];
    NSHashRemove(matrix, cache);
}
- (void)removeAllObjects
{ NSResetHashTable(matrix); }

//// Optimized versions
- (void)    setObject:(id)object
        atCoordinates:(unsigned)x,...
{
    va_list args;

    va_start(args, x);

    if (hashIsCoordinateOptimized)
        {
        struct KTMatrixSparseElement *elem;
        ((struct KTMatrixSparseElement *)cache)->hashedLocation =
            [(id)hash hashForCoordinatesList:x :&args];

        elem = (struct KTMatrixSparseElement *)NSHashGet(matrix, cache);
        if (elem)
            {   // Just change object if the location is occupied
            [elem->object release];
            elem->object = object;
            }
        else
            {   // Else allocate more memory
            elem = NSZoneMalloc([self zone],
                                sizeof(struct KTMatrixSparseElement));
            elem->hashedLocation =
                ((struct KTMatrixSparseElement *)cache)->hashedLocation;
            elem->object = object;
            NSHashInsertKnownAbsent(matrix, elem);
            }
        }
    else
        {
        NSMutableArray *array = [NSMutableArray arrayWithObject:
            [NSNumber numberWithInt:x]];
        unsigned axes = [self dimension];
        
        while ([array count] < axes)
            [array addObject:[NSNumber numberWithInt:va_arg(args, unsigned)]];

        va_end(args);
        [self setObject:object
      atCoordinateArray:array];
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
        ((struct KTMatrixSparseElement *)cache)->hashedLocation = [(id)hash
            hashForCoordinatesList:x :&args];
        NSHashRemove(matrix, cache);
        }
    else
        {
        NSMutableArray *array = [NSMutableArray arrayWithObject:
            [NSNumber numberWithInt:x]];
        unsigned axes = [self dimension];

        while ([array count] < axes)
            [array addObject:[NSNumber numberWithInt:va_arg(args, unsigned)]];
        [self removeObjectAtCoordinateArray:array];
        }

    va_end(args);
}

- (void)dealloc
{
    [hash release];
    NSFreeHashTable(matrix);
    NSZoneFree([self zone], cache);
    [super dealloc];
}

@end
