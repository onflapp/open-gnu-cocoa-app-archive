/*$Id: SenValueTree.h,v 1.3 2003/07/25 16:07:45 phink Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenMutableTree.h"

// SenValueTree implements a tree with a value stored at each node.

@interface SenValueTree : SenMutableTree
{
    @private
    id value;
}

+ valueTreeWithPropertyList:(NSString *) aString;
- initWithPropertyList:(NSString *) aString;
- initWithSExpression:(NSArray *) anArray;
/* Initializes a SenValueTree from a S-expression like property list.
   For instance: (a (b c))  ==>    a
                                  / \
                                 b   c
*/

+ valueTreeWithOutlineString:(NSString *) aString;
- initWithOutlineString:(NSString *) aString;
/* Initializes a SenValueTree from an indented outline.
   For instance: a     ==>    a
                   b         / \
                   c        b   c
*/

- initWithValue:(id) aValue;
- (id) value;
- (void) setValue:(id) aValue;

@end
