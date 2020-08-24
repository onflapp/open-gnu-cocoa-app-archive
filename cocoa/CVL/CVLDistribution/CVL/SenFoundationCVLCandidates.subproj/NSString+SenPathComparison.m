/* NSString+SenPathComparison.m created by stephanec on Mon 13-Dec-1999 */
/* Copyright (c) 1997, Sen:te Ltd.  All rights reserved. */

#import "NSString+SenPathComparison.h"

@implementation NSString(SenPathComparison)

- (BOOL) senIsParentOf:(NSString *)aPath immediately:(BOOL)isImmediateParent
{
    NSArray			*pathComponents = [self pathComponents];
    NSArray			*otherPathComponents = [aPath pathComponents];
    int				count = [pathComponents count], otherCount = [otherPathComponents count];
    NSEnumerator	*pathComponentEnum;
    NSEnumerator	*otherPathComponentEnum;
    NSString		*aPathComponent;

    if(count >= otherCount)
        return NO;

    if(isImmediateParent && count != otherCount - 1)
        return NO;

    pathComponentEnum = [pathComponents objectEnumerator];
    otherPathComponentEnum = [otherPathComponents objectEnumerator];

    while ( (aPathComponent = [pathComponentEnum nextObject]) ) {
        if(![aPathComponent isEqualToString:[otherPathComponentEnum nextObject]])
            return NO;
    }
    return YES;
}

+ (NSString *) longestCommonPathOfPaths:(NSArray *)somePaths
    /*" This method returns the longest common path of all the paths contained 
        in the array somePaths. It is assumed that all the paths in somePaths 
        start at the same place in the file system. If there is not a common 
        path or if somePaths is nil or empty then an empty string is returned.
    "*/
{
    NSEnumerator *anEnumerator = nil;
    NSString *aPath = nil;
    NSString *theShortestPath = nil;
    NSMutableArray *somePathsLessTheShortest = nil;
    BOOL theShortestPathIsParent = NO;
    
    if ( isNilOrEmpty(somePaths) ) return @"";
    
    // First get the shortest path.
    anEnumerator = [somePaths objectEnumerator];
    while ( (aPath = [anEnumerator nextObject]) ) {
        if ( theShortestPath == nil ) {
            theShortestPath = aPath;
        } else {
            if ( [theShortestPath length] > [aPath length] ) {
                theShortestPath = aPath;
            }
        }
    }
    // Fill an array with all the paths but the shortest.
    somePathsLessTheShortest = [NSMutableArray arrayWithArray:somePaths];
    [somePathsLessTheShortest removeObject:theShortestPath];
    
    // Now compare the shortest path with the other paths
    while ( (theShortestPathIsParent == NO) && isNotEmpty(theShortestPath) ) {
        theShortestPathIsParent = YES; // Assume true until proven false.
        anEnumerator = [somePathsLessTheShortest objectEnumerator];
        while ( (aPath = [anEnumerator nextObject]) ) {
            if ( [theShortestPath senIsParentOf:aPath immediately:NO] == YES ) {
                continue;
            } else {
                theShortestPathIsParent = NO;
                theShortestPath = [theShortestPath stringByDeletingLastPathComponent];
                break;
            }
        }
    }
    return theShortestPath;
}

@end
