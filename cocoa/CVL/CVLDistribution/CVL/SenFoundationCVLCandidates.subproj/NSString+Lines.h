/* NSString+Lines.h created by stephane on Mon 05-Feb-2001 */

// Copyright (c) 1997-2000, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>


@interface NSString(Lines)

- (NSArray *) lines;
    // Use -lines instead of -componentsSeparatedByString: to get lines
    // from a string.
    // Thanks to Moritz Thomas <motho@gmx.net> for this suggestion


@end
