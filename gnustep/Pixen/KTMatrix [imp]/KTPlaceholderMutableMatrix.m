//
//  KTPlaceholderMutableMatrix
//  KTMatrix collection class cluster
//
//  KTMutableMatrix class cluster initialisation subclass
//
//  Copyright (c) 2002 Chris Purcell. All rights reserved.
//
//  You may use this code for whatever purposes you wish.
//  This code comes with no warranties, implied or otherwise.
//  Using it may damage your data. It shouldn't, but save a copy first.
//  That's a good idea anyway, actually.
//

#import "KTPlaceholderMutableMatrix.h"
#import "KTCuboidHash.h"
#import "KTMutableMatrixSparseImp.h"
#import "KTMutableMatrixDenseImp.h"

@implementation KTPlaceholderMutableMatrix

- (id)init
{
    NSZone *zone = [self zone];
    id<KTLocationHash> hash = [[KTCuboidHash allocWithZone:zone] init];
    [self release];
    self = [[KTMutableMatrixSparseImp allocWithZone:zone]
        initWithCapacity:0 locationHash:hash];
    [hash release];
    return self;
}
- (id)initWithMatrix:(KTMatrix *)matrix
{
    NSZone *zone = [self zone];
    [self release];
    if (([[matrix locationHash] hashBound] == 0) ||
        ([matrix count] < [[matrix locationHash] hashBound]/3))
        self = [KTMutableMatrixSparseImp allocWithZone:zone];
    else
        self = [KTMutableMatrixDenseImp allocWithZone:zone];
    [self initWithMatrix:matrix];
    return self;
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                   objects:(NSArray *)objects
               atLocations:(NSArray *)loc1s
               byLocations:(NSArray *)loc2s
{
    NSZone *zone = [self zone];
    [self release];
    if (([hash hashBound] == 0) ||
        ([objects count] < [hash hashBound]/3))
        self = [KTMutableMatrixSparseImp allocWithZone:zone];
    else
        self = [KTMutableMatrixDenseImp allocWithZone:zone];
    self = [self initWithLocationHash:hash
                              objects:objects
                          atLocations:loc1s
                          byLocations:loc2s];
    return self;
}
- (id)initWithCapacity:(unsigned)numItems
          locationHash:(id<KTLocationHash>)hash
{
    NSZone *zone = [self zone];
    [self release];
    if (([hash hashBound] == 0) || (numItems < [hash hashBound]/3))
        self = [KTMutableMatrixSparseImp allocWithZone:zone];
    else
        self = [KTMutableMatrixDenseImp allocWithZone:zone];
    [self initWithCapacity:numItems
              locationHash:hash];
    return self;
}

//// Efficient implementations of other methods
- (id)initWithCuboidBoundsObjectAtCoordinates:(unsigned)bound1,...
{
    NSZone *zone = [self zone];
    KTCuboidHash *hash;
    id object = nil;
    va_list args;

    [self release];

    va_start(args, bound1);
    hash = [[KTCuboidHash allocWithZone:zone]
                initWithBoundsList:bound1 :&args];

    object = va_arg(args, id);

    if (([hash hashBound] != 0) && ([hash hashBound] <= 3))
        self = [KTMutableMatrixDenseImp alloc];
    else
        self = [KTMutableMatrixSparseImp alloc];
    self = [(id)self initWithLocationHash:hash
                                   object:object
                         atHashedLocation:[hash hashForCoordinatesList:&args]];

    va_end(args);
    [hash release];
    return self;
}
- (id)initWithCuboidBoundsObjectsAtCoordinates:(unsigned)bound1,...
{   // Can optimize away some inefficiencies
    NSZone *zone = [self zone];
    KTCuboidHash *hash; // The hashing object to use
    va_list args;       // To trawl through the arguments
    id object;          // Used to store the objects in the arguments

    // Need a mutable temporary to store all the objects
    KTMutableMatrixSparseImp *temp;
    // SELs/IMPs to speed up repeated method calls
    SEL hashListSEL = @selector(hashForCoordinatesList:);
    SEL setObjSEL = @selector(setObject:atHashedLocation:);
    unsigned (*hashListIMP)(id, SEL, ...);
    void (*setObjIMP)(id, SEL, ...);

    [self release];

    // Read in data for the cuboid hash
    va_start(args, bound1);
    hash = [[KTCuboidHash allocWithZone:zone]
                initWithBoundsList:bound1 :&args];

    // Allocate the temporary mutable matrix
    temp = [[KTMutableMatrixSparseImp allocWithZone:zone]
                initWithCapacity:0
                    locationHash:hash];

    // Read in objects and coordinates
    hashListIMP = (unsigned (*)(id, SEL, ...))
        [hash methodForSelector:hashListSEL];
    setObjIMP = (void (*)(id, SEL, ...))
        [temp methodForSelector:setObjSEL];
    while (object = va_arg(args, id))
        setObjIMP(temp, setObjSEL, object,
                  hashListIMP(hash,hashListSEL,&args));

    // Make a mutable copy of the object if necessary
    if (([hash hashBound] == 0) ||
        ([temp count] < [hash hashBound]/3))
        self = [temp retain];
    else
        self = [temp mutableCopyWithZone:zone];
    [temp release];

    [hash release];
    va_end(args);
    return self;
}

@end
