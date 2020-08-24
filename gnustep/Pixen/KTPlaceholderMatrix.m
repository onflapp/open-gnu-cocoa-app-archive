//
//  KTPlaceholderMatrix
//  KTMatrix collection class cluster
//
//  KTMatrix class cluster initialisation subclass
//
//  Copyright (c) 2002 Chris Purcell. All rights reserved.
//
//  You may use this code for whatever purposes you wish.
//  This code comes with no warranties, implied or otherwise.
//  Using it may damage your data. It shouldn't, but save a copy first.
//  That's a good idea anyway, actually.
//

#import "KTPlaceholderMatrix.h"
#import "KTCuboidHash.h"
#import "KTMatrixSparseImp.h"
#import "KTMatrixDenseImp.h"
#import "KTMutableMatrixSparseImp.h"

@implementation KTPlaceholderMatrix

//// Primitive methods
- (id)init
{
    NSZone *zone = [self zone];
    KTCuboidHash *hash = [[KTCuboidHash alloc] init];
    [self release];
    self = [[KTMatrixSparseImp allocWithZone:zone]
        initWithLocationHash:hash];
    [hash release];
    return self;
}
- (id)initWithMatrix:(KTMatrix *)matrix
{
    NSZone *zone = [self zone];
    [self release];
    if (([[matrix locationHash] hashBound] == 0) ||
        ([matrix count] < [[matrix locationHash] hashBound]/3))
        self = [KTMatrixSparseImp allocWithZone:zone];
    else
        self = [KTMatrixDenseImp allocWithZone:zone];
    self = [self initWithMatrix:matrix];
    return self;
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
{
    NSZone *zone = [self zone];
    [self release];
    return [[KTMatrixSparseImp allocWithZone:zone] initWithLocationHash:hash];
}
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                   objects:(NSArray *)objects
               atLocations:(NSArray *)loc1s
               byLocations:(NSArray *)loc2s
{
    NSZone *zone = [self zone];
    [self release];
    if (([hash hashBound] == 0) || ([objects count] < [hash hashBound]/3))
        self = [KTMatrixSparseImp allocWithZone:zone];
    else
        self = [KTMatrixDenseImp allocWithZone:zone];
    self = [self initWithLocationHash:hash
                              objects:objects
                          atLocations:loc1s
                          byLocations:loc2s];
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
        self = [KTMatrixDenseImp alloc];
    else
        self = [KTMatrixSparseImp alloc];
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

    // Make an immutable copy of the object
    self = [temp copyWithZone:zone];
    [temp release];

    [hash release];
    va_end(args);
    return self;
}
@end
