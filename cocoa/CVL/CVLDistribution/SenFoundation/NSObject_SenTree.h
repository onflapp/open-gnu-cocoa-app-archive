/*$Id: NSObject_SenTree.h,v 1.17 2005/09/15 12:34:44 phink Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/NSObject.h>
#import <Foundation/NSEnumerator.h>
#import "SenTrees.h"


@interface NSObject(SenTree)

- (id) parent;
- (NSArray *) children;

- (id) root;

- (BOOL) isLeaf;
- (BOOL) isRoot;
- (BOOL) isDescendantOf:(id)anAncestor;

- (BOOL) isEqualToTree:(id) anotherTree;
- (BOOL) isEqualToNode:(id) anotherNode;
- (BOOL) areChildren:(NSArray *) ourChildren equalToChildren:(NSArray *)otherChildren;

- (int) depth;
- (unsigned) childrenCount;
- (unsigned) descendantCount;
- (int) rank;

- (NSEnumerator *) objectEnumeratorWithTraversalType:(SenTreeTraversalType)traversalType;
- (NSEnumerator *) depthFirstEnumerator;
- (NSEnumerator *) breadthFirstEnumerator;

- (NSArray *) pathAsNodes;
- (NSArray *) pathAsRanks;
@end

@interface NSObject(SenTreeTraversals)

- (id) traversePreorder:(SEL) aSelector;
- (id) traversePreorder:(SEL) aSelector withObject:(id) anObject;
- (id) traversePreorder:(SEL) aSelector withObject:(id) anObject withObject:(id) anotherObject;

- (id) traversePostorder:(SEL) aSelector;
- (id) traversePostorder:(SEL) aSelector withObject:(id) anObject;
- (id) traversePostorder:(SEL) aSelector withObject:(id) anObject withObject:(id) anotherObject;

@end
