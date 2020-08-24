/*$Id: SenOysterTest.m,v 1.6 2003/07/04 16:39:47 stephane Exp $*/

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenOysterTest.h"
#import "SenOyster.h"
#import <SenFoundation/SenFoundation.h>

static NSString *separator = @", ";
static int count = 10;

@implementation SenOysterTest

- (void) setUp
{
    int i;
    ASSIGN(arrayOfNumbers, [NSMutableArray arrayWithCapacity:count]);
    for (i = 0; i < count; i++) {
        [arrayOfNumbers addObject:[NSNumber numberWithInt:i]];
    }
}


- (NSArray *) arrayOfNumbers
{
    return arrayOfNumbers;
}


- (NSString *) targetString
{
    return [arrayOfNumbers componentsJoinedByString:separator];
}


- (void) testComponentsSeparatedByOperatorCount
{
    int i;
    int result;
    NSString *operator = [NSString stringWithFormat:@"m|%@|", separator];
    for (i = 1; i < count; i++) {
        result = [[[self targetString] componentsSeparatedByOperator:operator count:i] count];
        if (i != 0) {
            should1 (result == i, ([NSString stringWithFormat:@"expected %d got %d", i, result]));                    
        }
    }
}


- (void) testComponentsSeparatedByOperatorNullCount
{
    int result;
    NSString *operator = [NSString stringWithFormat:@"m|%@|", separator];
    result = [[[self targetString] componentsSeparatedByOperator:operator count:0] count];
    should1 (result == count, ([NSString stringWithFormat:@"expected %d got %d", count, result]));
}



- (NSString *) stringValueAtIndex:(int) anIndex
{
    return [[[self arrayOfNumbers] objectAtIndex:anIndex] stringValue];
}


- (void) testMatchOperatorToObjects
{
    NSString *operator = @"m|\\d|g";
    NSString *strings[count];

    [[self targetString] matchOperator:operator toObjects:&strings[0], NULL];
    shouldBeEqual (strings[0], [self stringValueAtIndex:0]);

    [[self targetString] matchOperator:operator toObjects:&strings[0], &strings[1], NULL];
    shouldBeEqual (strings[0], [self stringValueAtIndex:0]);
    shouldBeEqual (strings[1], [self stringValueAtIndex:1]);
}


- (void) tearDown
{
    RELEASE (arrayOfNumbers);
}
@end
