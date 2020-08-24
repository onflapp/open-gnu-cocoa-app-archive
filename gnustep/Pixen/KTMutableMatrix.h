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

#import <Foundation/Foundation.h>
#import "KTMatrix.h"

@interface KTMutableMatrix : KTMatrix { }

// Constructors
// Note: matrixWithLocationHash no longer primitive (calls WithCapacity:0)
//       Nor is initWithLocationCache (ditto)
+ (id)matrixWithCapacity:(unsigned)numItems
          locationHash:(id<KTLocationHash>)hash; // Primitive
+ (id)matrixWithCapacity:(unsigned)numItems
        cuboidBoundArray:(NSArray *)bounds; 
+ (id)matrixWithCapacity:(unsigned)numItems
            cuboidBounds:(unsigned)bound1,...;
- (id)initWithCapacity:(unsigned)numItems
          locationHash:(id<KTLocationHash>)hash; // Primitive
- (id)initWithCapacity:(unsigned)numItems
      cuboidBoundArray:(NSArray *)bounds;
- (id)initWithCapacity:(unsigned)numItems
          cuboidBounds:(unsigned)bound1,...;

// Setters
- (void)setMatrix:(KTMatrix *)matrix; // Primitive

- (void)setObject:(id)object
       atLocation:(NSDictionary *)loc1;
- (void)setObject:(id)object
       atLocation:(NSDictionary *)loc1
       byLocation:(NSDictionary *)loc2; // Primitive
- (void)        setObject:(id)object
        atCoordinateArray:(NSArray *)coords;
- (void)    setObject:(id)object
        atCoordinates:(unsigned)x,...;
- (void)setObjects:(NSArray *)objects
       atLocations:(NSArray *)locs;
- (void)setObjects:(NSArray *)objects
       atLocations:(NSArray *)loc1s
        byLocation:(NSDictionary *)loc2;
- (void)setObjects:(NSArray *)objects
       atLocations:(NSArray *)loc1s
       byLocations:(NSArray *)loc2s;
- (void)setObjectsAtLocations:(id)firstObject,...;
- (void)setObjectsAtLocationsByLocations:(id)firstObject,...;
- (void)        setObjects:(NSArray *)objects
        atCoordinateArrays:(NSArray *)coordinateArrays;
- (void)setObjectsAtCoordinates:(id)firstObject,...;

- (void)removeObjectAtLocation:(NSDictionary *)loc;
- (void)removeObjectAtLocation:(NSDictionary *)loc1
                    byLocation:(NSDictionary *)loc2; // Primitive
- (void)removeObjectAtCoordinateArray:(NSArray *)coords;
- (void)removeObjectAtCoordinates:(unsigned)x,...;
- (void)removeObjectsAtLocations:(NSArray *)locs;
- (void)removeObjectsAtLocations:(NSArray *)loc1s
                      byLocation:(NSDictionary *)loc2;
- (void)removeObjectsAtLocations:(NSArray *)loc1s
                     byLocations:(NSArray *)loc2s;
- (void)removeObjectsAtCoordinateArrays:(NSArray *)coordinateArrays;

- (void)removeAllObjects; // Primitive

@end
