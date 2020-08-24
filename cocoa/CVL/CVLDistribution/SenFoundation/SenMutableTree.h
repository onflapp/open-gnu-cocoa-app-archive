/*$Id: SenMutableTree.h,v 1.2 2003/07/25 16:07:43 phink Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/NSObject.h>
#import <SenFoundation/NSObject_SenTree.h>

@class NSMutableArray;

@interface SenMutableTree:NSObject <SenTrees, NSCopying, NSCoding>
{
    id parent;
    NSMutableArray *children;
}
@end


@interface SenMutableTree (MutableTreePrimitives)
- (void) setParent:anObject;
- (void) addChild:(id) anObject;
- (void) removeChild:(id) anObject;
@end


@interface SenMutableTree (EOCompatibility)
//- (void) setChildren:(NSMutableArray *) value;

- (void) addToChildren:(id) value;
- (void) removeFromChildren:(id) value;
@end


@interface NSObject (SenTree_PFSExtensions)
- (int) maximumDepth;
- (BOOL) isEmpty;
@end

