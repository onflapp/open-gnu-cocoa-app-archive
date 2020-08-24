//
//  KTMatrix
//  KTMatrix collection class cluster
//
//  Stores a matrix of objects
//  Class cluster
//
//  It works like this:
//    - A set of keys is used to denote the matrix axes
//    - A dictionary is used to access individual elements
//    - (A hash is used to transform this dictionary into a key)
//    - The axis values should be NSNumbers
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

#import <Foundation/Foundation.h>

// Any hash used by a KTMatrix object must conform to this protocol
@protocol KTLocationHash <NSObject, NSCopying>
// Return the hashed location for the information given in the two dictionaries
// This is the most flexible - and hence slowest - form of location storage
// All methods use this if no efficiency protocol are implemented
- (unsigned)hashForLocation:(NSDictionary *)loc1
                 byLocation:(NSDictionary *)loc2;
    // Return the axes used by the hashing object
    // Used to translate coordinates into locations
    // If coordinates are not used, this need not be meaningfully implemented
- (NSArray *)axes;
    // Return the lower bound for a given oxis
    // Need not be meaningfully implemented
- (unsigned)lowerBoundForAxis:(id)axis;
    // Return the lower bound for a given oxis
    // Need not be meaningfully implemented
- (unsigned)upperBoundForAxis:(id)axis;
    // Return a bound on the largest hash value that can be returned
    // Used to select optimal implementations of the matrix
    // Return 0 if any unsigned hash value could be returned
    // (This disables dense implementations of the matrix)
- (unsigned)hashBound;
@end

@protocol KTLocationHashInverse
- (id)locationForHash:(unsigned)hash;
@end

// Conforming your hash to this can speed up coordinate-based methods manyfold
@protocol KTLocationHashCoordinatesOptimization
// Take a va_list object and extract the required coordinates from it
- (unsigned)hashForCoordinatesList:(va_list *)coords;
    // As before, except the first value is supplied in x
- (unsigned)hashForCoordinatesList:(unsigned)x :(va_list *)coords;
    // Return [[self axes] count], or equivalent implementation
- (unsigned)dimension;
    // Return [self lowerBoundForAxis:[NSNumber numberWithInt:dim]]
    // Or equivalent implementation
- (unsigned)lowerBoundForDimension:(unsigned)dim;
    // Return [self upperBoundForAxis:[NSNumber numberWithInt:dim]]
    // Or equivalent implementation
- (unsigned)upperBoundForDimension:(unsigned)dim;
@end

@protocol KTMatrixEnumerator
- (unsigned)hashedLocation;
@end

@interface KTMatrix
: NSObject <NSCoding,NSCopying,NSMutableCopying> { }

// Constructors
+ (id)matrix;
+ (id)matrixWithMatrix:(KTMatrix *)matrix; // Primitive

+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash; // Primitive
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                      object:(id)object
                  atLocation:(NSDictionary *)loc;
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                      object:(id)object
                  atLocation:(NSDictionary *)loc1
                  byLocation:(NSDictionary *)loc2;
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                     objects:(NSArray *)objects
                 atLocations:(NSArray *)locs;
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                     objects:(NSArray *)objects
                 atLocations:(NSArray *)loc1s
                  byLocation:(NSDictionary *)loc2;
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash // Primitive
                     objects:(NSArray *)objects
                 atLocations:(NSArray *)loc1s
                 byLocations:(NSArray *)loc2s;
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
          objectsAtLocations:(id)object1,...;
+ (id)       matrixWithLocationHash:(id<KTLocationHash>)hash
      objectsAtLocationsByLocations:(id)object1,...;

+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                      object:(id)object
           atCoordinateArray:(NSArray *)coord;
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                      object:(id)object
               atCoordinates:(unsigned)x,...;
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
                     objects:(NSArray *)objects
          atCoordinateArrays:(NSArray *)coords;
+ (id)matrixWithLocationHash:(id<KTLocationHash>)hash
        objectsAtCoordinates:(id)object1,...;

+ (id)matrixWithCuboidBoundArray:(NSArray *)bounds;
+ (id)matrixWithCuboidBoundArray:(NSArray *)bounds
                          object:(id)object
               atCoordinateArray:(NSArray *)coord;
+ (id)matrixWithCuboidBoundArray:(NSArray *)bounds
                          object:(id)object
                   atCoordinates:(unsigned)x,...;
+ (id)matrixWithCuboidBoundArray:(NSArray *)bounds
                         objects:(NSArray *)objects
              atCoordinateArrays:(NSArray *)coords;
+ (id)matrixWithCuboidBoundArray:(NSArray *)bounds
            objectsAtCoordinates:(id)object1,...;
+ (id)matrixWithCuboidBounds:(unsigned)bound1,...;
+ (id)matrixWithCuboidBoundsObjectAtCoordinates:(unsigned)bound1,...;
+ (id)matrixWithCuboidBoundsObjectsAtCoordinateArrays:(unsigned)bound1,...;
+ (id)matrixWithCuboidBoundsObjectsAtCoordinates:(unsigned)bound1,...;

- (id)init;
- (id)initWithMatrix:(KTMatrix *)matrix;  // Primitive

- (id)initWithLocationHash:(id<KTLocationHash>)hash;
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                    object:(id)object
                atLocation:(NSDictionary *)loc;
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                     object:(id)object
                atLocation:(NSDictionary *)loc1
                byLocation:(NSDictionary *)loc2;
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                   objects:(NSArray *)objects
               atLocations:(NSArray *)locs;
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                   objects:(NSArray *)objects
               atLocations:(NSArray *)loc1s
                byLocation:(NSDictionary *)loc2;
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                   objects:(NSArray *)objects
               atLocations:(NSArray *)loc1s
               byLocations:(NSArray *)loc2s;
- (id)initWithLocationHash:(id<KTLocationHash>)hash
        objectsAtLocations:(id)object1,...;
- (id)         initWithLocationHash:(id<KTLocationHash>)hash
      objectsAtLocationsByLocations:(id)object1,...;

- (id)initWithLocationHash:(id<KTLocationHash>)hash
                    object:(id)object
         atCoordinateArray:(NSArray *)coord;
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                    object:(id)object
             atCoordinates:(unsigned)x,...;
- (id)initWithLocationHash:(id<KTLocationHash>)hash
                   objects:(NSArray *)objects
        atCoordinateArrays:(NSArray *)coords;
- (id)initWithLocationHash:(id<KTLocationHash>)hash
      objectsAtCoordinates:(id)object1,...;

- (id)initWithCuboidBoundArray:(NSArray *)bounds;
- (id)initWithCuboidBoundArray:(NSArray *)bounds
                        object:(id)object
             atCoordinateArray:(NSArray *)coord;
- (id)initWithCuboidBoundArray:(NSArray *)bounds
                        object:(id)object
                 atCoordinates:(unsigned)x,...;
- (id)initWithCuboidBoundArray:(NSArray *)bounds
                       objects:(NSArray *)objects
            atCoordinateArrays:(NSArray *)coords;
- (id)initWithCuboidBoundArray:(NSArray *)bounds
          objectsAtCoordinates:(id)object1,...;
- (id)initWithCuboidBounds:(unsigned)bound1,...;
- (id)initWithCuboidBoundsObjectAtCoordinates:(unsigned)bound1,...;
- (id)initWithCuboidBoundsObjectsAtCoordinateArrays:(unsigned)bound1,...;
- (id)initWithCuboidBoundsObjectsAtCoordinates:(unsigned)bound1,...;

    // Accessor methods
- (id)objectAtLocation:(NSDictionary *)loc;
- (id)objectAtLocation:(NSDictionary *)loc1
            byLocation:(NSDictionary *)loc2; // Primitive
- (NSArray *)objectsAtLocations:(NSArray *)locs
                 notFoundMarker:(id)anObject;
- (NSArray *)objectsAtLocations:(NSArray *)loc1s
                     byLocation:(NSDictionary *)loc2
                 notFoundMarker:(id)anObject;
- (NSArray *)objectsAtLocations:(NSArray *)loc1s
                    byLocations:(NSArray *)loc2s
                 notFoundMarker:(id)anObject;
- (id)objectAtCoordinateArray:(NSArray *)coords;
- (NSArray *)objectsAtCoordinateArrays:(NSArray *)coords
                        notFoundMarker:(id)anObject;
- (id)objectAtCoordinates:(unsigned)x,...;

- (id<KTLocationHash>)locationHash; // Primitive

    // Internal use accessors
- (NSDictionary *)matrixData; // Primitive

    // Convenience methods fall straight through to hash equivalents
- (NSArray *)axes;
- (unsigned)dimension;
- (unsigned)lowerBoundForAxis:(id)axis;
- (unsigned)lowerBoundForDimension:(unsigned)dimension;
- (unsigned)upperBoundForAxis:(id)axis;
- (unsigned)upperBoundForDimension:(unsigned)dimension;

    // Object methods
- (NSArray *)allObjects;
- (unsigned)count; // Primitive
- (NSEnumerator *)objectEnumerator; // Primitive
- (NSEnumerator *)objectEnumeratorRetained;
- (NSEnumerator *)reverseObjectEnumerator;

@end
