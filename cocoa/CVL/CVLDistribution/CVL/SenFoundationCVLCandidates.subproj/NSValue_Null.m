/* NSValue_Null.m created by ja on Wed 12-Feb-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSValue_Null.h"
#import <SenFoundation/SenFoundation.h>

@implementation NSValue (Null)
static NSValue *nullValue=nil;

+ (NSValue *)nullValue
{
    if (!nullValue) {
        ASSIGN(nullValue, [NSValue valueWithPointer:nil]);
    }
    return nullValue;
}

- (BOOL)isNull
{
    return (nullValue==self);
}

@end
