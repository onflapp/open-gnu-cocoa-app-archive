/* NSString_RevisionComparison.h created by vincent on Fri 22-May-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>

struct CVLSortedRevisionArrayWithKeyContext
{
    id		key;
    BOOL	ascendingOrder;
};

@interface NSString (RevisionComparison)

int keySort(id dict1, id dict2, void *context); // Context is of type struct CVLSortedRevisionArrayWithKeyContext *

- (NSComparisonResult) compareRevision: (NSString*) aString;
- (NSComparisonResult) compareModifs: (NSString*) aString;

@end
