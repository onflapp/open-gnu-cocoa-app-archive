//
//  KTMatrixSparseImp
//  KTMatrix collection class cluster
//
//  KTMatrix class cluster implementation subclass
//  Uses hash tables to reference a mass-allocated chunk of memory
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

#import "KTMatrixSparseImp.h"
#import "KTMatrixSparseEnumerator.h"

static int compare(const void * elem1, const void * elem2 )
{
    if (((const struct KTMatrixSparseElement *)elem1)->hashedLocation >
        ((const struct KTMatrixSparseElement *)elem2)->hashedLocation)
        return 1;
    if (((const struct KTMatrixSparseElement *)elem1)->hashedLocation <
        ((const struct KTMatrixSparseElement *)elem2)->hashedLocation)
        return -1;
    return 0;
}

#define SearchAndLocate(_aim, ret) \
{ \
    unsigned low = 0, high = count, middle; \
    unsigned aim = _aim; \
    struct KTMatrixSparseElement *elements = memory; \
    while (high > low + 1) \
        { \
        middle = (high - low)/2+low; \
        if (elements[middle].hashedLocation == aim) \
            high = low = middle; \
        else if (elements[middle].hashedLocation < aim) \
            low = middle + 1; \
        else \
            high = middle; \
        } \
    middle = (high - low)/2+low; \
    if (elements[middle].hashedLocation == aim) \
        ret = elements[middle].object; \
    else \
        ret = NULL; \
}


@implementation KTMatrixSparseImp

+ (id)matrixWithMatrix:(KTMatrix *)other
{ return [[[self alloc] initWithMatrix:other] autorelease]; }
+ (id)matrixWithLocationHash:(id<KTLocationHash>)locationHash
{ return [[[self alloc] initWithLocationHash:locationHash] autorelease]; }
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
            struct KTMatrixSparseElement *elements;
            id object;

            // Deal with the hashing object
            if (NSShouldRetainWithZone([other locationHash], [self zone]))
                hash = [[other locationHash] retain];
            else
                hash = [[other locationHash] copyWithZone:[self zone]];
            hashIsCoordinateOptimized = [hash conformsToProtocol:
                @protocol(KTLocationHashCoordinatesOptimization)];

            // Allocate memory
            count = 0;
            memory = NSZoneCalloc([self zone],
                                  [other count],
                                  sizeof(struct KTMatrixSparseElement));
            elements = memory;

            // Fill the memory
            while ((object = [j nextObject]))
                {
                elements[count].hashedLocation = [j hashedLocation];
                elements[count].object = [object retain];
                count++;
                }
            qsort(elements, count, sizeof(struct KTMatrixSparseElement),
                  compare);
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

        count = 0;
        memory = nil;
        }
    return self;
}
- (id)initWithMatrixData:(NSDictionary *)matrixData
            locationHash:(id<KTLocationHash>)locationHash
{
    if ((self = [super init]))
        {
        struct KTMatrixSparseElement *elements;
        NSNumber *key;
        NSEnumerator *j = [matrixData keyEnumerator];

        // Deal with the hashing object
        if (NSShouldRetainWithZone(locationHash, [self zone]))
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
        hashIsCoordinateOptimized = [hash conformsToProtocol:
            @protocol(KTLocationHashCoordinatesOptimization)];

        // Allocate memory
        count = 0;
        memory = NSZoneCalloc([self zone],
                              count,
                              sizeof(struct KTMatrixSparseElement));
        elements = memory;

        // Fill the memory
        while ((key = [j nextObject]))
            {
            elements[count].hashedLocation = [key intValue];
            elements[count].object = [[matrixData objectForKey:key] retain];
            count++;
            }
        qsort(elements + 1, count, sizeof(struct KTMatrixSparseElement),
              compare);
        }
    return self;
}
- (id)initWithLocationHash:(id<KTLocationHash>)locationHash
                    object:(id)object
          atHashedLocation:(unsigned)loc
{
    if ((self = [super init]))
        {
        struct KTMatrixSparseElement *element;
        unsigned i;

        // Deal with the hashing object
        if (NSShouldRetainWithZone(locationHash, [self zone]))
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
        hashIsCoordinateOptimized = [hash conformsToProtocol:
           @protocol(KTLocationHashCoordinatesOptimization)];

        // Allocate memory
        count = 1;
        memory = NSZoneMalloc([self zone],
                              sizeof(struct KTMatrixSparseElement));
        element = memory;

        // Fill the memory
        for (i = 0; i < count; i++)
            {
            element->hashedLocation = loc;
            element->object = [object retain];
            }
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
        struct KTMatrixSparseElement *elements;
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

        // Allocate memory
        count = [objects count];
        memory = NSZoneCalloc([self zone],
                              count,
                              sizeof(struct KTMatrixSparseElement));
        elements = memory;

        // Fill the memory
        for (i = 0; i < count; i++)
            {
            elements[i].hashedLocation = [hash
                    hashForLocation:[loc1s objectAtIndex:i]
                         byLocation:[loc2s objectAtIndex:i]];
            elements[i].object = [[objects objectAtIndex:i] retain];
            }
        qsort(elements, count, sizeof(struct KTMatrixSparseElement),
              compare);
        }
    return self;
}

// Accessor methods
- (id)objectAtLocation:(NSDictionary *)loc
            byLocation:(NSDictionary *)loc2;
{
    unsigned low = 0, high = count, middle;
    unsigned aim = [hash hashForLocation:loc byLocation:loc2];
    struct KTMatrixSparseElement *elements = memory;
    while (high > low + 1)
        {
        middle = (high - low)/2+low;
        if (elements[middle].hashedLocation == aim)
            high = low = middle;
        else if (elements[middle].hashedLocation < aim)
            low = middle + 1;
        else
            high = middle;
        }
    middle = (high - low)/2+low;
    if (elements[middle].hashedLocation == aim)
        return elements[middle].object;
    else
        return NULL;
}

//// Optimized algorithms
- (id)objectAtCoordinates:(unsigned)x,...
{
    va_list args;

    va_start(args, x);

    if (hashIsCoordinateOptimized)
        {
        id ret;
        SearchAndLocate([(id)hash hashForCoordinatesList:x :&args], ret);
        va_end(args);
        return ret;
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
            dictionaryWithCapacity:count];
    struct KTMatrixSparseElement *i =
        ((struct KTMatrixSparseElement *)memory);
    struct KTMatrixSparseElement *iend = i + count;
    for (; i < iend; i++)
        [data setObject:i->object
                 forKey:[NSNumber numberWithInt:i->hashedLocation]];
    return data;
}

- (NSEnumerator *)objectEnumerator
{
    return [[[KTMatrixSparseEnumerator allocWithZone:[self zone]]
        initWithArray:memory
                count:count
           collection:self] autorelease];
}
- (NSEnumerator *)objectEnumeratorRetained
{
    return [[KTMatrixSparseEnumerator allocWithZone:[self zone]]
        initWithArray:memory
                count:count
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
    struct KTMatrixSparseElement *i =
    ((struct KTMatrixSparseElement *)memory);
    struct KTMatrixSparseElement *iend = i + count;
    for (; i < iend; i++)
        [i->object release];
    [hash release];
    NSZoneFree([self zone], memory);
    [super dealloc];
}
@end
