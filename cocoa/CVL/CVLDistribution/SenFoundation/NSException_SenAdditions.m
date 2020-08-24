/*$Id: NSException_SenAdditions.m,v 1.5 2003/07/25 16:08:01 phink Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSException_SenAdditions.h"

@implementation NSException (SenAdditions)
- (BOOL) isOfType:(NSString *) aName
{
    return [[self name] isEqual:aName];
}
@end
