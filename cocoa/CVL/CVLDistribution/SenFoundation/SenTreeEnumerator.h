/*$Id: SenTreeEnumerator.h,v 1.8 2005/04/22 10:12:53 phink Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/NSEnumerator.h>
#import "SenTrees.h"


@class NSArray;


@interface SenTreeEnumerator : NSEnumerator
{
    @private
    SenTreeTraversalType traversalType;
    NSMutableArray *queue;
	id tree;
	SEL isExpendingNodeSelector;
}

+ (SenTreeEnumerator *) enumeratorWithTree:(id <SenTrees, NSObject>)aTree traversalType:(SenTreeTraversalType)aTraversalType;
+ (SenTreeEnumerator *) enumeratorWithTree:(id <SenTrees, NSObject>)aTree;

- (id) initWithTree:(id <SenTrees, NSObject>)aTree traversalType:(SenTreeTraversalType)aTraversalType;
- (id) initWithTree:(id <SenTrees, NSObject>)aTree;

- (void) setExpandingNodeSelector:(SEL) anExpendingNodeSelector;

@end
