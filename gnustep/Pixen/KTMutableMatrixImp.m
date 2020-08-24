//
//  KTMutableMatrixImp
//  KTMatrix
//
//  Implements a mutable KTMutableMatrix subclass
//
//  Copyright (c) 2002 Chris Purcell. All rights reserved.
//
//  You may use this code for whatever purposes you wish.
//  This code comes with no warranties, implied or otherwise.
//  Using it may damage your data. It shouldn't, but save a copy first.
//  That's a good idea anyway, actually.
//

#import "KTMutableMatrixImp.h"

@implementation KTMutableMatrixImp

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
    return [[KTMutableMatrixImp alloc] initWithCapacity:numItems
                                           locationHash:_hs];
}
- (id)initWithMatrix:(KTMatrix *)other
{
    if ((self = [super init]))
        {
        matrix = [[other matrixData] mutableCopyWithZone:[self zone]];
        if ([[other locationHash] zone] == [self zone])
            hash = [[other locationHash] retain];
        else
            hash = [[other locationHash] copyWithZone:[self zone]];
        }
    return self;
}
- (id)initWithMatrixData:(NSDictionary *)matrixData
            locationHash:(id<KTLocationHash>)locationHash
{
    if ((self = [super init]))
        {
        matrix = [matrixData mutableCopyWithZone:[self zone]];
        if ([locationHash zone] == [self zone])
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
        }
    return self;
}
- (id)initWithLocationHash:(id<KTLocationHash>)locationHash
{
    if ((self = [super init]))
        {
        matrix = [[NSMutableDictionary allocWithZone:[self zone]] init];
        if ([locationHash zone] == [self zone])
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
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
        NSMutableArray *indices = [[NSMutableArray alloc] initWithCapacity:
            [loc1s count]];
        unsigned i;

        if ([locationHash zone] == [self zone])
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];

        NSAssert([objects count] == [loc1s count],
                 @"Objects and locations arrays not of equal length");
        NSAssert([loc1s count] == [loc2s count],
                 @"Locations arrays not of equal length");
        for (i = 0; i < [loc1s count]; i++)
            {
            [indices addObject:[NSNumber numberWithInt:
                [hash hashForLocation:[loc1s objectAtIndex:i]
                           byLocation:[loc2s objectAtIndex:i]]]];
            }
        matrix = [[NSMutableDictionary allocWithZone:[self zone]]
            initWithObjects:objects
                    forKeys:indices];

        [indices release];
        }
    return self;
}
- (id)initWithCapacity:(unsigned)numItems
          locationHash:(id<KTLocationHash>)locationHash
{
    if ((self = [super init]))
        {
        matrix = [[NSMutableDictionary allocWithZone:[self zone]]
                                  initWithCapacity:numItems];
        if ([locationHash zone] == [self zone])
            hash = [locationHash retain];
        else
            hash = [locationHash copyWithZone:[self zone]];
        }
    return self;
}


// Accessor methods
- (id)objectAtLocation:(NSDictionary *)loc
            byLocation:(NSDictionary *)loc2;
{
    return [matrix objectForKey:[NSNumber numberWithInt:[hash
        hashForLocation:loc byLocation:loc2]]];
}

- (id<KTLocationHash>)locationHash
{ return hash; }
- (NSDictionary *)matrixData
{ return matrix; }

- (NSEnumerator *)objectEnumerator
{ return [matrix objectEnumerator]; }
- (unsigned)count
{ return [matrix count]; }


//// Mutator methods
- (void)setMatrix:(KTMatrix *)other
{
    [matrix release];
    [hash release];
    matrix = [[other matrixData] mutableCopyWithZone:[self zone]];
    if ([[other locationHash] zone] == [self zone])
        hash = [[other locationHash] retain];
    else
        hash = [[other locationHash] copyWithZone:[self zone]];
}
- (void)setObject:(id)object
       atLocation:(NSDictionary *)loc1
       byLocation:(NSDictionary *)loc2
{
    [matrix setObject:object
               forKey:[NSNumber numberWithInt:[hash
                                       hashForLocation:loc1
                                            byLocation:loc2]]];
}
- (void)removeObjectAtLocation:(NSDictionary *)loc1
                    byLocation:(NSDictionary *)loc2;
{
    [matrix removeObjectForKey:[NSNumber numberWithInt:[hash
                                       hashForLocation:loc1
                                            byLocation:loc2]]];
}
- (void)removeAllObjects
{
    [matrix removeAllObjects];
}

- (void)dealloc
{
    [matrix release];
    [hash release];
}
@end
