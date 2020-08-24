/*$Id: SenTreeEnumerator.m,v 1.10 2005/04/22 10:12:53 phink Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenTreeEnumerator.h"
#import "SenUtilities.h"
#import "SenEmptiness.h"
#import <Foundation/NSArray.h>


/* FIXME
   Depthfirst is preorder only. Postorder would be some kind of reverse enumerator. Useful?
*/

@implementation SenTreeEnumerator
+ (SenTreeEnumerator *) enumeratorWithTree:(id <SenTrees, NSObject>)aTree
{
    return [[[self alloc] initWithTree:aTree] autorelease];
}


+ (SenTreeEnumerator *) enumeratorWithTree:(id <SenTrees, NSObject>)aTree traversalType:(SenTreeTraversalType)aTraversalType
{
    return [[[self alloc] initWithTree:aTree traversalType:aTraversalType] autorelease];
}


- (id) initWithTree:(id <SenTrees, NSObject>)aTree traversalType:(SenTreeTraversalType)aTraversalType
{
    self = [super init];
	traversalType = aTraversalType;
	queue = [[NSMutableArray alloc] initWithObjects:aTree, nil];
	tree = [aTree retain];
	isExpendingNodeSelector = (SEL) 0;
    return self;
}


- (id) initWithTree:(id <SenTrees, NSObject>)aTree
{
    return [self initWithTree:aTree traversalType:SenTreeDepthFirst];
}


- (void) dealloc
{
    RELEASE (queue);
	RELEASE (tree);
    [super dealloc];
}


- (void) setExpandingNodeSelector:(SEL) anExpendingNodeSelector
{
	isExpendingNodeSelector = isExpendingNodeSelector;
}


- (id) nextObject
{
    id	car = nil;

    if ([queue count] > 0) {
        car = [queue objectAtIndex:0];
		[queue removeObjectAtIndex:0];

		if ((isExpendingNodeSelector == (SEL) 0) || [car performSelector:isExpendingNodeSelector]) {
			if (traversalType == SenTreeDepthFirst) {
				[queue replaceObjectsInRange:NSMakeRange(0, 0) withObjectsFromArray:[car children]];
			} 
			else {
				[queue addObjectsFromArray:[car children]];
			}
		}
    }
    return car;
}
@end
