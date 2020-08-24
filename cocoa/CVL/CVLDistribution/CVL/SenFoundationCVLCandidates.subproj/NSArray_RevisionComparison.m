/* NSArray_RevisionComparison.m created by vincent on Wed 27-May-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSArray_RevisionComparison.h"
#import "NSString_RevisionComparison.h"

@implementation NSArray (RevisionComparison)

- (NSArray*) sortedRevisionArrayWithKey: (NSString*) aKey ascendingOrder:(BOOL)ascendingOrder
{
    struct CVLSortedRevisionArrayWithKeyContext	context;

    context.key = aKey;
    context.ascendingOrder = ascendingOrder;
    
    return [self sortedArrayUsingFunction: keySort context:(void *)&context];
}

@end
