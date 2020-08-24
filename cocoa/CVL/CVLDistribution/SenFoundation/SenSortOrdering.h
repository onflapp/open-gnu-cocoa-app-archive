/*$Id: SenSortOrdering.h,v 1.3 2003/07/25 16:07:44 phink Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#ifndef RHAPSODY

#import <Foundation/Foundation.h>

@interface SenSortOrdering : NSObject
{
    SEL selector;
    NSString *key;
}

+ (id) sortOrderingWithKey:(NSString *) aKey selector:(SEL) aSelector;

- (id) initWithKey:(NSString *) aKey selector:(SEL) aSelector;
- (NSString *) key;
- (SEL) selector;
@end


@interface NSArray (SenKeyBasedSorting)
- (NSArray *) arrayBySortingOnKeyOrderArray:(NSArray *) orderArray;
@end


@interface NSMutableArray (SenKeyBasedSorting)
- (void) sortOnKeyOrderArray:(NSArray *) orderArray;
@end


@interface NSObject (SenSortOrderingComparison)
- (NSComparisonResult) compareAscending:(id) other;
- (NSComparisonResult) compareDescending:(id) other;
@end


#define SenCompareAscending @selector(compareAscending:)
#define SenCompareDescending @selector(compareDescending:)

#endif
